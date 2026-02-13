--!strict
--[[
	HitRequestHandler: RemoteEvent handling, rate limiting, and argument validation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TemporalBuffer = require(script.Parent.TemporalBuffer)
type TemporalBuffer = TemporalBuffer.TemporalBuffer

local HitboxValidator = require(script.Parent.HitboxValidator)
local HitboxConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HitboxConfig")) :: any
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types")) :: any
type HitRequest = Types.HitRequest
type HitResult = Types.HitResult

local REMOTE_NAME = "HitboxHitRequest"
local REMOTE_RESULT_NAME = "HitboxHitResult"
local REMOTE_TOKEN_NAME = "HitboxSessionToken"

local HitRequestHandlerModule = {}

type RateLimitEntry = {
	count: number,
	windowStart: number,
}

export type HitRequestHandler = {
	getRemote: (self: HitRequestHandler) -> RemoteEvent,
	getResultRemote: (self: HitRequestHandler) -> RemoteEvent,
	destroy: (self: HitRequestHandler) -> (),
}

local function createRemote(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing :: RemoteEvent
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local function validateRequest(request: any, config: any): (HitRequest?, string?)
	if type(request) ~= "table" then
		return nil, "Invalid request format"
	end

	local timestamp = request.timestamp
	if type(timestamp) ~= "number" or timestamp <= 0 then
		return nil, "Invalid timestamp"
	end

	local now = tick()
	local maxAge = config.bufferWindowMs / 1000
	if timestamp < now - maxAge or timestamp > now + 0.1 then
		return nil, "Timestamp out of buffer window"
	end

	local targetUserId = request.targetUserId
	if type(targetUserId) ~= "number" then
		return nil, "Invalid target"
	end

	local requestId = request.requestId
	if requestId and type(requestId) ~= "string" then
		requestId = nil
	end

	local origin = request.origin
	if type(origin) ~= "Vector3" then
		return nil, "Invalid origin"
	end

	local direction = request.direction
	if type(direction) ~= "Vector3" then
		return nil, "Invalid direction"
	end

	local mag = direction.Magnitude
	if mag < 0.9 or mag > 1.1 then
		return nil, "Direction must be normalized"
	end

	local maxDistance = request.maxDistance
	if type(maxDistance) ~= "number" or maxDistance < config.minRayDistance or maxDistance > config.maxRayDistance then
		return nil, "Invalid max distance"
	end

	return {
		timestamp = timestamp,
		targetUserId = targetUserId,
		origin = origin,
		direction = direction,
		maxDistance = maxDistance,
		requestId = requestId,
	}, nil
end

function HitRequestHandlerModule.new(
	buffer: TemporalBuffer,
	config: any?
): HitRequestHandler
	local cfg = config or require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HitboxConfig")) :: any

	local hitRemote = createRemote(REMOTE_NAME)
	local resultRemote = createRemote(REMOTE_RESULT_NAME)
	local tokenRemote = createRemote(REMOTE_TOKEN_NAME)

	local RequestIntegrity = require(script.Parent.RequestIntegrity)
	local Checksum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Checksum")) :: any

	local integrity = RequestIntegrity.new(cfg.maxReplayHistorySize)

	local rateLimits: { [number]: RateLimitEntry } = {}
	local connection: RBXScriptConnection?

	local function checkRateLimit(userId: number): boolean
		local now = tick()
		local entry = rateLimits[userId]

		if not entry then
			rateLimits[userId] = { count = 1, windowStart = now }
			return true
		end

		local windowAge = (now - entry.windowStart) * 1000
		if windowAge >= cfg.rateLimitWindowMs then
			rateLimits[userId] = { count = 1, windowStart = now }
			return true
		end

		entry.count += 1
		if entry.count > cfg.maxHitsPerSecond then
			return false
		end
		return true
	end

	-- Anti-exploit: session token validation
	local function validateIntegrity(player: Player, request: any): string?
		if cfg.enableSessionTokens then
			if not integrity:validateSessionToken(player, request.sessionToken) then
				return "Invalid session token"
			end
		end

		if cfg.enableReplayProtection and request.requestId then
			if integrity:checkReplay(player, request.requestId) then
				return "Replay detected"
			end
		end

		if cfg.enableSessionTokens and request.sessionToken then
			if not request.checksum or type(request.checksum) ~= "string" then
				return "Missing checksum"
			end
			local payload = Checksum.buildPayload(
				request.timestamp,
				request.targetUserId,
				request.origin,
				request.direction,
				request.maxDistance,
				request.requestId or ""
			)
			local expected = Checksum.compute(payload, request.sessionToken)
			if request.checksum ~= expected then
				return "Invalid checksum"
			end
		end

		return nil
	end

	-- Send session token to client when they join or when requested
	local function sendTokenToPlayer(player: Player)
		if not cfg.enableSessionTokens then return end
		local token = integrity:generateSessionToken(player)
		tokenRemote:FireClient(player, token)
	end

	Players.PlayerAdded:Connect(sendTokenToPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(sendTokenToPlayer, player)
	end

	-- Fallback: client can request token if they missed the initial send
	local requestTokenRemote = createRemote("HitboxRequestToken")
	requestTokenRemote.OnServerEvent:Connect(function(player: Player)
		sendTokenToPlayer(player)
	end)

	connection = hitRemote.OnServerEvent:Connect(function(player: Player, request: any)
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
			return
		end

		if not checkRateLimit(player.UserId) then
			resultRemote:FireClient(player, { valid = false, reason = "Rate limited", requestId = request.requestId })
			return
		end

		local integrityErr = validateIntegrity(player, request)
		if integrityErr then
			resultRemote:FireClient(player, { valid = false, reason = integrityErr, requestId = request.requestId })
			return
		end

		local validatedRequest, err = validateRequest(request, cfg)
		if not validatedRequest then
			resultRemote:FireClient(player, { valid = false, reason = err or "Validation failed", requestId = request.requestId })
			return
		end

		if cfg.enableReplayProtection and validatedRequest.requestId then
			integrity:recordRequest(player, validatedRequest.requestId)
		end

		local result: HitResult = HitboxValidator.validate(validatedRequest, player, buffer, cfg)
		result.requestId = validatedRequest.requestId
		resultRemote:FireClient(player, result)
	end)

	Players.PlayerRemoving:Connect(function(player)
		rateLimits[player.UserId] = nil
	end)

	local self: HitRequestHandler = {
		getRemote = function()
			return hitRemote
		end,
		getResultRemote = function()
			return resultRemote
		end,
		destroy = function(_self: HitRequestHandler)
			if connection then
				connection:Disconnect()
				connection = nil
			end
			integrity:destroy()
			if hitRemote.Parent then hitRemote:Destroy() end
			if resultRemote.Parent then resultRemote:Destroy() end
			if tokenRemote.Parent then tokenRemote:Destroy() end
			if requestTokenRemote and requestTokenRemote.Parent then requestTokenRemote:Destroy() end
		end,
	}

	return self
end

return HitRequestHandlerModule

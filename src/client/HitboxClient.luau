--!strict
--[[
	HitboxClient: Performs raycast from character and fires hit requests to the server.
	Supports configurable input, debug visuals, lag logging, and position prediction.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HitboxConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HitboxConfig")) :: any
local Checksum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Checksum")) :: any
local DebugVisualizer = require(script.Parent.DebugVisualizer)
local PositionPredictor = require(script.Parent.PositionPredictor)
local LagLogger = require(script.Parent.LagLogger)

local REMOTE_NAME = "HitboxHitRequest"
local RESULT_REMOTE_NAME = "HitboxHitResult"
local TOKEN_REMOTE_NAME = "HitboxSessionToken"

local HitboxClientModule = {}

export type HitboxClient = {
	start: (self: HitboxClient) -> (),
	stop: (self: HitboxClient) -> (),
	destroy: (self: HitboxClient) -> (),
}

export type HitboxClientCallbacks = {
	onHitResult: ((result: { valid: boolean, reason: string? }) -> ())?,
	onLagDetected: ((roundTripMs: number, reason: string?) -> ())?,
}

local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
RAYCAST_PARAMS.IgnoreWater = true

local function matchesInput(config: any, input: InputObject): boolean
	for _, name in config.hitInputTypes do
		if input.UserInputType and tostring(input.UserInputType) == name then
			return true
		end
	end
	for _, name in config.hitKeyCodes do
		if input.KeyCode and tostring(input.KeyCode) == name then
			return true
		end
	end
	return false
end

local function generateRequestId(): string
	return tostring(tick()) .. "-" .. tostring(math.random(10000, 99999))
end

function HitboxClientModule.new(configOverride: any?, callbacks: HitboxClientCallbacks?): HitboxClient
	local connection: RBXScriptConnection?
	local resultConnection: RBXScriptConnection?
	local tokenConnection: RBXScriptConnection?
	local remote: RemoteEvent? = ReplicatedStorage:WaitForChild(REMOTE_NAME) :: RemoteEvent?
	local resultRemote: RemoteEvent? = ReplicatedStorage:WaitForChild(RESULT_REMOTE_NAME) :: RemoteEvent?
	local tokenRemote: RemoteEvent? = ReplicatedStorage:FindFirstChild(TOKEN_REMOTE_NAME) :: RemoteEvent?

	local shared = ReplicatedStorage:WaitForChild("Shared")
	local config: any
	if configOverride then
		config = configOverride
	else
		local api = shared:FindFirstChild("HitboxAPI")
		config = api and (require(api :: ModuleScript) :: any):getConfig() or HitboxConfig
	end

	local sessionToken: string? = nil
	local requestTokenRemote: RemoteEvent? = ReplicatedStorage:FindFirstChild("HitboxRequestToken") :: RemoteEvent?
	if tokenRemote then
		tokenConnection = tokenRemote.OnClientEvent:Connect(function(token: string)
			sessionToken = token
		end)
	end
	if config.enableSessionTokens and requestTokenRemote and not sessionToken then
		task.delay(0.5, function()
			if not sessionToken then
				requestTokenRemote:FireServer()
			end
		end)
	end
	local debugVisualizer: DebugVisualizer.DebugVisualizer? = config.debugMode and DebugVisualizer.new({
		hurtBoxColor = config.hurtBoxColor,
		hurtBoxTransparency = config.hurtBoxTransparency,
		hitBoxColor = config.hitBoxColor,
		hitBoxTransparency = config.hitBoxTransparency,
	}) or nil
	local positionPredictor: PositionPredictor.PositionPredictor? = config.predictionEnabled and PositionPredictor.new() or nil
	local lagLogger: LagLogger.LagLogger = LagLogger.new(config.lagWarningThresholdMs)

	local function performRaycast(origin: Vector3, direction: Vector3, maxDistance: number, exclude: { Instance }?): RaycastResult?
		RAYCAST_PARAMS.FilterDescendantsInstances = exclude or {}
		return workspace:Raycast(origin, direction.Unit * maxDistance, RAYCAST_PARAMS)
	end

	local function attemptHit()
		local player = Players.LocalPlayer
		local character = player.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then return end

		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if not humanoid or humanoid.Health <= 0 then return end

		local camera = workspace.CurrentCamera
		local origin = rootPart.Position
		local direction = (camera and camera.CFrame.LookVector) or rootPart.CFrame.LookVector
		local maxDistance = config.maxRayDistance

		local exclude = { character }
		local result = performRaycast(origin, direction, maxDistance, exclude)

		if not result and positionPredictor then
			local extrapolationMs = config.predictionExtrapolationMs
			for _, other in Players:GetPlayers() do
				if other == player then continue end
				local otherChar = other.Character
				if not otherChar then continue end
				local otherHumanoid = otherChar:FindFirstChild("Humanoid") :: Humanoid?
				if not otherHumanoid or otherHumanoid.Health <= 0 then continue end

				local predictedPos = positionPredictor:getPredictedPosition(otherChar, extrapolationMs)
				local toTarget = (predictedPos - origin).Unit
				local predResult = performRaycast(origin, toTarget, maxDistance, exclude)
				if predResult then
					local hitChar = predResult.Instance
					local curr = hitChar
					while curr do
						if curr == otherChar then
							result = predResult
							direction = toTarget
							break
						end
						curr = curr.Parent
					end
					if result then break end
				end
			end
		end

		if not result then
			if debugVisualizer then
				debugVisualizer:updateHitBox(origin, direction, maxDistance)
			end
			return
		end

		local hitInstance = result.Instance
		local current = hitInstance
		while current do
			local hitPlayer = Players:GetPlayerFromCharacter(current)
			if hitPlayer and hitPlayer ~= player then
				local hitHumanoid = current:FindFirstChild("Humanoid") :: Humanoid?
				if hitHumanoid and hitHumanoid.Health > 0 then
					local requestId = generateRequestId()
					lagLogger:recordSend(requestId)

					local timestamp = tick()
					local payload: any = {
						timestamp = timestamp,
						targetUserId = hitPlayer.UserId,
						origin = origin,
						direction = direction,
						maxDistance = maxDistance,
						requestId = requestId,
					}

					if config.enableSessionTokens and sessionToken then
						payload.sessionToken = sessionToken
						local payloadStr = Checksum.buildPayload(timestamp, hitPlayer.UserId, origin, direction, maxDistance, requestId)
						payload.checksum = Checksum.compute(payloadStr, sessionToken)
					end

					if remote then
						if config.enableSessionTokens and not sessionToken then
							return
						end
						remote:FireServer(payload)
					end

					if debugVisualizer then
						debugVisualizer:updateHitBox(origin, direction, maxDistance)
					end
					break
				end
			end
			current = current.Parent
		end
	end

	if resultRemote then
		resultConnection = resultRemote.OnClientEvent:Connect(function(result: { valid: boolean, reason: string?, requestId: string? })
			local roundTripMs = lagLogger:recordReceive(result.requestId)
			if roundTripMs then
				lagLogger:logIfLagging(roundTripMs, result.reason or nil)
				if callbacks and callbacks.onLagDetected and roundTripMs >= (config.lagWarningThresholdMs or 150) then
					callbacks.onLagDetected(roundTripMs, result.reason or nil)
				end
			end

			if callbacks and callbacks.onHitResult then
				callbacks.onHitResult({ valid = result.valid, reason = result.reason })
			end
		end)
	end

	local function onInputBegan(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if matchesInput(config, input) then
			attemptHit()
		end
	end

	local self: HitboxClient = {
		start = function(_self: HitboxClient)
			if connection then return end
			connection = UserInputService.InputBegan:Connect(onInputBegan)
			if debugVisualizer then
				debugVisualizer:start()
			end
		end,
		stop = function(_self: HitboxClient)
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if resultConnection then
				resultConnection:Disconnect()
				resultConnection = nil
			end
			if debugVisualizer then
				debugVisualizer:stop()
			end
		end,
		destroy = function(_self: HitboxClient)
			_self:stop()
			if tokenConnection then
				tokenConnection:Disconnect()
				tokenConnection = nil
			end
			if debugVisualizer then
				debugVisualizer:destroy()
			end
			if positionPredictor then
				positionPredictor:destroy()
			end
			lagLogger:destroy()
		end,
	}

	return self
end

return HitboxClientModule

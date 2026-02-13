--!strict
--[[
	RequestIntegrity: Anti-exploit measures for hit requests.
	- Session tokens: Server-issued tokens that must be included in requests
	- Replay protection: Rejects duplicate requestIds
	- Checksum validation: Verifies payload integrity (optional obfuscation layer)
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Checksum = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Checksum")) :: any

local RequestIntegrityModule = {}

export type RequestIntegrity = {
	generateSessionToken: (self: RequestIntegrity, player: Player) -> string,
	validateSessionToken: (self: RequestIntegrity, player: Player, token: string?) -> boolean,
	checkReplay: (self: RequestIntegrity, player: Player, requestId: string?) -> boolean,
	recordRequest: (self: RequestIntegrity, player: Player, requestId: string) -> (),
	destroy: (self: RequestIntegrity) -> (),
}

local function generateToken(): string
	return HttpService:GenerateGUID(false) .. "-" .. tostring(tick() * 1000)
end

function RequestIntegrityModule.new(maxReplayHistorySize: number?): RequestIntegrity
	local maxHistory = maxReplayHistorySize or 128
	local sessionTokens: { [number]: string } = {}
	local replayHistory: { [number]: { [string]: boolean } } = {}
	local replayOrder: { [number]: { string } } = {}

	local function pruneReplayHistory(userId: number)
		local order = replayOrder[userId]
		local history = replayHistory[userId]
		if not order or not history then return end
		while #order > maxHistory do
			local oldest = table.remove(order, 1)
			history[oldest] = nil
		end
	end

	local self: RequestIntegrity = {
		generateSessionToken = function(_self: RequestIntegrity, player: Player): string
			local token = generateToken()
			sessionTokens[player.UserId] = token
			return token
		end,
		validateSessionToken = function(_self: RequestIntegrity, player: Player, token: string?): boolean
			if not token or type(token) ~= "string" or #token < 10 then
				return false
			end
			local expected = sessionTokens[player.UserId]
			if not expected then return false end
			return token == expected
		end,
		checkReplay = function(_self: RequestIntegrity, player: Player, requestId: string?): boolean
			if not requestId or type(requestId) ~= "string" or #requestId < 5 then
				return true -- Invalid ID, will fail elsewhere; treat as potential replay
			end
			local userId = player.UserId
			if replayHistory[userId] and replayHistory[userId][requestId] then
				return true -- Duplicate = replay attack
			end
			return false
		end,
		recordRequest = function(_self: RequestIntegrity, player: Player, requestId: string)
			if not requestId then return end
			local userId = player.UserId
			if not replayHistory[userId] then
				replayHistory[userId] = {}
				replayOrder[userId] = {}
			end
			replayHistory[userId][requestId] = true
			table.insert(replayOrder[userId], requestId)
			pruneReplayHistory(userId)
		end,
		destroy = function(_self: RequestIntegrity)
			sessionTokens = {}
			replayHistory = {}
			replayOrder = {}
		end,
	}

	Players.PlayerRemoving:Connect(function(player)
		sessionTokens[player.UserId] = nil
		replayHistory[player.UserId] = nil
		replayOrder[player.UserId] = nil
	end)

	return self
end

return RequestIntegrityModule

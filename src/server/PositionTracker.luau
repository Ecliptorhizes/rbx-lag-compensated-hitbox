--!strict
--[[
	PositionTracker: Records all player positions into the TemporalBuffer every Heartbeat.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TemporalBuffer = require(script.Parent.TemporalBuffer)
type TemporalBuffer = TemporalBuffer.TemporalBuffer

local PRUNE_INTERVAL = 1 -- seconds

local PositionTrackerModule = {}

export type PositionTracker = {
	destroy: (self: PositionTracker) -> (),
}

function PositionTrackerModule.new(buffer: TemporalBuffer): PositionTracker
	local heartbeatConnection: RBXScriptConnection?
	local lastPruneTime = tick()

	local function onHeartbeat()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then continue end

			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not rootPart then continue end

			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if not humanoid or humanoid.Health <= 0 then continue end

			buffer:add(player, rootPart.CFrame)
		end

		-- Prune old entries periodically
		local now = tick()
		if now - lastPruneTime >= PRUNE_INTERVAL then
			buffer:prune()
			lastPruneTime = now
		end
	end

	heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)

	local self: PositionTracker = {
		destroy = function(_self: PositionTracker)
			if heartbeatConnection then
				heartbeatConnection:Disconnect()
				heartbeatConnection = nil
			end
		end,
	}

	return self
end

return PositionTrackerModule

--!strict
--[[
	Server entry point: wires together the lag-compensated hitbox system.
]]

local HitboxConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("HitboxConfig")) :: any
local TemporalBuffer = require(script.Parent.TemporalBuffer)
local PositionTracker = require(script.Parent.PositionTracker)
local HitRequestHandler = require(script.Parent.HitRequestHandler)

local config = HitboxConfig

local buffer = TemporalBuffer.new(config.bufferWindowMs, config.maxEntriesPerPlayer)
local positionTracker = PositionTracker.new(buffer)
local hitRequestHandler = HitRequestHandler.new(buffer, config)

-- Cleanup on server shutdown (optional; Roblox doesn't always call this)
game:BindToClose(function()
	positionTracker:destroy()
	hitRequestHandler:destroy()
	buffer:destroy()
end)

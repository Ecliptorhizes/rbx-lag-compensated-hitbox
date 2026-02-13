--!strict
--[[
	HitboxService: Knit service that wires the lag-compensated hitbox system.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local HitboxConfig = require(ReplicatedStorage.Shared.HitboxConfig) :: any
local TemporalBuffer = require(script.Parent.Parent.TemporalBuffer)
local PositionTracker = require(script.Parent.Parent.PositionTracker)
local HitRequestHandler = require(script.Parent.Parent.HitRequestHandler)

local HitboxService = Knit.CreateService({
	Name = "HitboxService",
	Client = {},
})

function HitboxService:KnitInit()
	self._janitor = Janitor.new()

	local config = HitboxConfig
	local buffer = TemporalBuffer.new(config.bufferWindowMs, config.maxEntriesPerPlayer)
	local positionTracker = PositionTracker.new(buffer)
	local hitRequestHandler = HitRequestHandler.new(buffer, config)

	self._janitor:Add(buffer, "destroy")
	self._janitor:Add(positionTracker, "destroy")
	self._janitor:Add(hitRequestHandler, "destroy")
end

function HitboxService:KnitStart()
	-- Services are ready
end

function HitboxService:KnitDestroy()
	self._janitor:Cleanup()
end

return HitboxService

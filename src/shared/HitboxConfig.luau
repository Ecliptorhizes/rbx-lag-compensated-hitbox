--!strict
--[[
	Shared configuration for the lag-compensated hitbox system.
]]

export type HitboxConfig = {
	-- Temporal buffer
	bufferWindowMs: number,
	maxEntriesPerPlayer: number,

	-- Raycast
	maxRayDistance: number,
	minRayDistance: number,

	-- Rate limiting
	maxHitsPerSecond: number,
	rateLimitWindowMs: number,

	-- Validation
	maxPositionDelta: number, -- Max allowed difference between client origin and server position (studs)
}

local DEFAULT_CONFIG: HitboxConfig = {
	bufferWindowMs = 500,
	maxEntriesPerPlayer = 60,
	maxRayDistance = 20,
	minRayDistance = 0,
	maxHitsPerSecond = 10,
	rateLimitWindowMs = 1000,
	maxPositionDelta = 5,
}

return DEFAULT_CONFIG

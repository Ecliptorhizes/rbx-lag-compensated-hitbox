--!strict
--[[
	Shared types for the lag-compensated hitbox system.
]]

export type HitRequest = {
	timestamp: number,
	targetUserId: number,
	origin: Vector3,
	direction: Vector3,
	maxDistance: number,
}

export type HitResult = {
	valid: boolean,
	reason: string?,
}

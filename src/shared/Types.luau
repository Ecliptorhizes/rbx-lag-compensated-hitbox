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
	requestId: string?, -- For round-trip latency measurement + replay protection
	sessionToken: string?, -- Anti-exploit: server-issued token
	checksum: string?, -- Anti-exploit: hash of payload for integrity verification
}

export type HitResult = {
	valid: boolean,
	reason: string?,
	requestId: string?, -- Echoed for latency tracking
}

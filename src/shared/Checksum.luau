--!strict
--[[
	Checksum: Shared integrity hash for hit requests.
	Both client and server use the same algorithm to verify payload integrity.
	Note: This is not cryptographic - it adds friction against casual tampering.
	Server-side validation remains the authoritative defense.
]]

local ChecksumModule = {}

function ChecksumModule.compute(payload: string, token: string): string
	local combined = payload .. token
	local hash = 0
	for i = 1, #combined do
		hash = (hash * 31 + string.byte(combined, i)) % 2147483647
	end
	return tostring(hash)
end

function ChecksumModule.buildPayload(timestamp: number, targetUserId: number, origin: Vector3, direction: Vector3, maxDistance: number, requestId: string): string
	return string.format("%.6f|%d|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f|%s",
		timestamp,
		targetUserId,
		origin.X, origin.Y, origin.Z,
		direction.X, direction.Y, direction.Z,
		maxDistance,
		requestId or ""
	)
end

return ChecksumModule

--!strict
--[[
	TemporalBuffer: Circular buffer for player position history.
	Stores CFrame snapshots keyed by timestamp for 300-500ms rewind.
]]

export type Entry = {
	timestamp: number,
	position: CFrame,
}

export type TemporalBuffer = {
	add: (self: TemporalBuffer, player: Player, position: CFrame) -> (),
	getPositionAt: (self: TemporalBuffer, player: Player, timestamp: number) -> (CFrame?),
	prune: (self: TemporalBuffer) -> (),
	destroy: (self: TemporalBuffer) -> (),
}

type InternalState = {
	playerBuffers: { [number]: { entries: { Entry } } },
	maxAgeMs: number,
	maxEntriesPerPlayer: number,
}

local TemporalBufferModule = {}

local DEFAULT_MAX_AGE_MS = 500
local DEFAULT_MAX_ENTRIES = 60 -- ~500ms at 120Hz

function TemporalBufferModule.new(maxAgeMs: number?, maxEntriesPerPlayer: number?): TemporalBuffer
	local maxAge = maxAgeMs or DEFAULT_MAX_AGE_MS
	local maxEntries = maxEntriesPerPlayer or DEFAULT_MAX_ENTRIES

	local state: InternalState = {
		playerBuffers = {},
		maxAgeMs = maxAge,
		maxEntriesPerPlayer = maxEntries,
	}

	local self = {} :: TemporalBuffer & InternalState
	for k, v in state do
		(self :: any)[k] = v
	end

	function self.add(_self: TemporalBuffer, player: Player, position: CFrame)
		local userId = player.UserId
		if not _self.playerBuffers[userId] then
			(_self :: any).playerBuffers[userId] = { entries = {} }
		end

		local buffer = (_self :: any).playerBuffers[userId]
		local entries = buffer.entries
		local now = tick()

		table.insert(entries, {
			timestamp = now,
			position = position,
		})

		-- Keep only the most recent N entries
		while #entries > maxEntries do
			table.remove(entries, 1)
		end
	end

	function self.getPositionAt(_self: TemporalBuffer, player: Player, timestamp: number): CFrame?
		local buffer = (_self :: any).playerBuffers[player.UserId]
		if not buffer then return nil end

		local entries = buffer.entries
		if #entries == 0 then return nil end

		-- Clamp timestamp to our window
		local oldest = entries[1].timestamp
		local newest = entries[#entries].timestamp
		if timestamp < oldest or timestamp > newest then
			return nil
		end

		-- Linear interpolation between nearest entries
		local prev, nextEntry = entries[1], entries[1]
		for i = 1, #entries do
			if entries[i].timestamp <= timestamp then
				prev = entries[i]
			end
			if entries[i].timestamp >= timestamp then
				nextEntry = entries[i]
				break
			end
		end

		if prev.timestamp == nextEntry.timestamp then
			return prev.position
		end

		local alpha = (timestamp - prev.timestamp) / (nextEntry.timestamp - prev.timestamp)
		return prev.position:Lerp(nextEntry.position, alpha)
	end

	function self.prune(_self: TemporalBuffer)
		local cutoff = tick() - (maxAge / 1000)
		for userId, buffer in (_self :: any).playerBuffers do
			local entries = buffer.entries
			while #entries > 0 and entries[1].timestamp < cutoff do
				table.remove(entries, 1)
			end
		end
	end

	function self.destroy(_self: TemporalBuffer)
		(_self :: any).playerBuffers = {}
	end

	return self
end

return TemporalBufferModule

--!strict
--[[
	LagLogger: Tracks round-trip latency and logs to developer console when lagging behind.
]]

local LagLoggerModule = {}

export type LagLogger = {
	recordSend: (self: LagLogger, requestId: string) -> (),
	recordReceive: (self: LagLogger, requestId: string?) -> number?, -- Returns round-trip ms if matched
	logIfLagging: (self: LagLogger, roundTripMs: number, reason: string?) -> (),
	destroy: (self: LagLogger) -> (),
}

function LagLoggerModule.new(thresholdMs: number): LagLogger
	local pending: { [string]: number } = {}

	local self: LagLogger = {
		recordSend = function(_self: LagLogger, requestId: string)
			pending[requestId] = tick()
		end,
		recordReceive = function(_self: LagLogger, requestId: string?): number?
			if not requestId then return nil end
			local sendTime = pending[requestId]
			if not sendTime then return nil end
			pending[requestId] = nil
			return (tick() - sendTime) * 1000
		end,
		logIfLagging = function(_self: LagLogger, roundTripMs: number, reason: string?)
			if roundTripMs >= thresholdMs then
				local msg = string.format(
					"[Hitbox] Lag detected: %.0fms round-trip (threshold: %.0fms)",
					roundTripMs,
					thresholdMs
				)
				if reason and reason ~= "" then
					msg = msg .. " | " .. reason
				end
				warn(msg)
			end
		end,
		destroy = function(_self: LagLogger)
			pending = {}
		end,
	}

	return self
end

return LagLoggerModule

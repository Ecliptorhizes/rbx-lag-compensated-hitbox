--!strict
--[[
	Shared configuration for the lag-compensated hitbox system.
	Developers can override these values when integrating into their game.
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
	maxPositionDelta: number,
	maxAttackerTargetDistance: number, -- Reject if attacker and target are farther apart (studs)

	-- Anti-exploit
	enableReplayProtection: boolean,
	enableSessionTokens: boolean,
	maxReplayHistorySize: number,

	-- Input: choose ANY button to trigger hit (default: left-click + touch)
	-- Use UserInputType names: "MouseButton1", "MouseButton2", "Touch", "Keyboard", etc.
	-- Use KeyCode names for keyboard: "Q", "F", "E", "R", "LeftShift", etc.
	hitInputTypes: { string },
	hitKeyCodes: { string },

	-- Debug: show hurt box and hit box in real-time
	debugMode: boolean,

	-- Hurt box color (targets - where damage is received)
	hurtBoxColor: Color3,
	hurtBoxTransparency: number,

	-- Hit box color (attacker ray - attack range)
	hitBoxColor: Color3,
	hitBoxTransparency: number,

	-- Lag logging: warn in developer console when round-trip exceeds this (ms)
	lagWarningThresholdMs: number,

	-- Prediction: extrapolate player positions when server lags
	predictionEnabled: boolean,
	predictionExtrapolationMs: number, -- How far ahead to predict (based on estimated latency)
}

local DEFAULT_CONFIG: HitboxConfig = {
	bufferWindowMs = 500,
	maxEntriesPerPlayer = 60,
	maxRayDistance = 20,
	minRayDistance = 0,
	maxHitsPerSecond = 10,
	rateLimitWindowMs = 1000,
	maxPositionDelta = 5,
	maxAttackerTargetDistance = 50,

	enableReplayProtection = true,
	enableSessionTokens = true,
	maxReplayHistorySize = 128,

	hitInputTypes = { "MouseButton1", "Touch" },
	hitKeyCodes = {},

	debugMode = false,
	hurtBoxColor = Color3.fromRGB(255, 100, 100),
	hurtBoxTransparency = 0.6,
	hitBoxColor = Color3.fromRGB(100, 255, 100),
	hitBoxTransparency = 0.5,

	lagWarningThresholdMs = 150,
	predictionEnabled = true,
	predictionExtrapolationMs = 100,
}

return DEFAULT_CONFIG

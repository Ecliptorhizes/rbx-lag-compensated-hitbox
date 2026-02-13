--!strict
--[[
	HitboxAPI: Public API for developers to integrate the hitbox system into their game.
	Override config values before requiring the client, or use the returned config for customization.

	Example usage:
		local HitboxAPI = require(ReplicatedStorage.Shared.HitboxAPI)
		HitboxAPI.setConfig({
			hitInputTypes = { "MouseButton2" },  -- Right-click to attack
			hitKeyCodes = { "Q", "F" },          -- Or Q/F keys
			debugMode = true,                     -- Show hurt/hit boxes
			lagWarningThresholdMs = 100,
		})
]]

local HitboxConfig = require(script.Parent.HitboxConfig) :: any

local HitboxAPIModule = {}

local configOverrides: { [string]: any } = {}

function HitboxAPIModule.setConfig(overrides: { [string]: any })
	for k, v in overrides do
		configOverrides[k] = v
	end
end

function HitboxAPIModule.getConfig(): any
	local config = table.clone(HitboxConfig)
	for k, v in configOverrides do
		config[k] = v
	end
	return config :: any
end

return HitboxAPIModule

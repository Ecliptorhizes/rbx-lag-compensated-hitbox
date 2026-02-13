--!strict
--[[
	Client entry point: initializes the HitboxClient.

	Developers can customize before starting:
		local HitboxAPI = require(ReplicatedStorage.Shared.HitboxAPI)
		HitboxAPI.setConfig({
			hitInputTypes = { "MouseButton2" },  -- Right-click
			hitKeyCodes = { "Q", "F" },          -- Or Q/F keys
			debugMode = true,                     -- Show hurt/hit boxes in real-time
			lagWarningThresholdMs = 100,          -- Log when lagging
			predictionEnabled = true,            -- Predict movement when server lags
		})
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HitboxClient = require(script.Parent.HitboxClient)

-- Optional: customize config before starting (uncomment and modify)
-- local HitboxAPI = require(ReplicatedStorage.Shared.HitboxAPI)
-- HitboxAPI.setConfig({ debugMode = true, hitKeyCodes = { "Q" } })

local client = HitboxClient.new()

if Players.LocalPlayer.Character then
	client:start()
else
	Players.LocalPlayer.CharacterAdded:Wait()
	client:start()
end

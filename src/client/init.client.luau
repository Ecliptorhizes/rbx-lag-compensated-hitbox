--!strict
--[[
	Client entry point: initializes the HitboxClient.
]]

local HitboxClient = require(script.Parent.HitboxClient)

local client = HitboxClient.new()

-- Wait for character to exist before enabling hit detection
local Players = game:GetService("Players")
local player = Players.LocalPlayer

if player.Character then
	client:start()
else
	player.CharacterAdded:Wait()
	client:start()
end

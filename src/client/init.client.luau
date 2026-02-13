--!strict
--[[
	Client entry point: starts Knit and loads hitbox controllers.

	Developers can customize before starting:
		local HitboxAPI = require(ReplicatedStorage.Shared.HitboxAPI)
		HitboxAPI.setConfig({
			hitInputTypes = { "MouseButton2" },
			hitKeyCodes = { "Q", "F" },
			debugMode = true,
			lagWarningThresholdMs = 100,
			predictionEnabled = true,
		})

	Connect to signals after Knit starts:
		local HitboxController = Knit.GetController("HitboxController")
		HitboxController.HitResult:Connect(function(result)
			print("Hit:", result.valid, result.reason)
		end)
		HitboxController.LagDetected:Connect(function(ms, reason)
			warn("Lag:", ms, "ms", reason)
		end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- Load all controllers from the controllers folder
Knit.AddControllers(script.Parent.controllers)

Knit.Start():catch(warn):await()

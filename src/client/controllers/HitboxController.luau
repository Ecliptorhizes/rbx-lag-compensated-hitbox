--!strict
--[[
	HitboxController: Knit controller that manages the client-side hitbox.
	Exposes HitResult and LagDetected signals for developers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local HitboxClient = require(script.Parent.Parent.HitboxClient)

local HitboxController = Knit.CreateController({
	Name = "HitboxController",
})

-- Signals for developers to connect to
HitboxController.HitResult = Signal.new() :: any
HitboxController.LagDetected = Signal.new() :: any

function HitboxController:KnitInit()
	self._janitor = Janitor.new()
end

function HitboxController:KnitStart()
	local config = self:_getConfig()
	local callbacks = {
		onHitResult = function(result: { valid: boolean, reason: string? })
			HitboxController.HitResult:Fire(result)
		end,
		onLagDetected = function(roundTripMs: number, reason: string?)
			HitboxController.LagDetected:Fire(roundTripMs, reason)
		end,
	}
	self._client = HitboxClient.new(config, callbacks)
	self._janitor:Add(self._client, "destroy")

	return Promise.new(function(resolve)
		if Players.LocalPlayer.Character then
			self._client:start()
			resolve()
		else
			Players.LocalPlayer.CharacterAdded:Once(function()
				self._client:start()
				resolve()
			end)
		end
	end)
end

function HitboxController:_getConfig(): any
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local api = shared:FindFirstChild("HitboxAPI")
	if api then
		local ApiModule = require(api :: ModuleScript) :: any
		if ApiModule.getConfig then
			return ApiModule:getConfig()
		end
	end
	return require(shared.HitboxConfig) :: any
end

function HitboxController:KnitDestroy()
	self._janitor:Cleanup()
	HitboxController.HitResult:Destroy()
	HitboxController.LagDetected:Destroy()
end

return HitboxController

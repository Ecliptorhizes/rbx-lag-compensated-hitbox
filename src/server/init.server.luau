--!strict
--[[
	Server entry point: starts Knit and loads hitbox services.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- Load all services from the services folder
Knit.AddServices(script.Parent.services)

Knit.Start():catch(warn)

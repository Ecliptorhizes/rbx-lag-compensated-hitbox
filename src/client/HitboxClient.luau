--!strict
--[[
	HitboxClient: Performs raycast from character and fires hit requests to the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HitboxConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HitboxConfig")) :: any

local REMOTE_NAME = "HitboxHitRequest"
local RESULT_REMOTE_NAME = "HitboxHitResult"

local HitboxClientModule = {}

export type HitboxClient = {
	start: (self: HitboxClient) -> (),
	stop: (self: HitboxClient) -> (),
	destroy: (self: HitboxClient) -> (),
}

local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
RAYCAST_PARAMS.IgnoreWater = true

local function performRaycast(origin: Vector3, direction: Vector3, maxDistance: number): RaycastResult?
	RAYCAST_PARAMS.FilterDescendantsInstances = {}
	local result = workspace:Raycast(origin, direction.Unit * maxDistance, RAYCAST_PARAMS)
	return result
end

function HitboxClientModule.new(): HitboxClient
	local connection: RBXScriptConnection?
	local resultConnection: RBXScriptConnection?
	local remote: RemoteEvent? = ReplicatedStorage:WaitForChild(REMOTE_NAME) :: RemoteEvent?
	local resultRemote: RemoteEvent? = ReplicatedStorage:WaitForChild(RESULT_REMOTE_NAME) :: RemoteEvent?

	local function attemptHit()
		local player = Players.LocalPlayer
		local character = player.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then return end

		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if not humanoid or humanoid.Health <= 0 then return end

		-- Ray from character forward (or camera look direction for more intuitive aiming)
		local camera = workspace.CurrentCamera
		local origin = rootPart.Position
		local direction = (camera and camera.CFrame.LookVector) or rootPart.CFrame.LookVector
		local maxDistance = HitboxConfig.maxRayDistance

		-- Exclude local character from raycast
		RAYCAST_PARAMS.FilterDescendantsInstances = { character }

		local result = performRaycast(origin, direction, maxDistance)
		if not result then return end

		-- Check if we hit a player character
		local hitInstance = result.Instance
		local current = hitInstance
		while current do
			local hitPlayer = Players:GetPlayerFromCharacter(current)
			if hitPlayer and hitPlayer ~= player then
				local hitHumanoid = current:FindFirstChild("Humanoid") :: Humanoid?
				if hitHumanoid and hitHumanoid.Health > 0 then
					-- Fire hit request to server
					if remote then
						remote:FireServer({
							timestamp = tick(),
							targetUserId = hitPlayer.UserId,
							origin = origin,
							direction = direction,
							maxDistance = maxDistance,
						})
					end
					break
				end
			end
			current = current.Parent
		end
	end

	if resultRemote then
		resultConnection = resultRemote.OnClientEvent:Connect(function(result: { valid: boolean, reason: string? })
			if result.valid then
				-- Hit confirmed (extend for feedback: sound, VFX, etc.)
			else
				-- Hit rejected (extend for feedback: "Miss", etc.)
			end
		end)
	end

	local function onInputBegan(input: InputObject, gameProcessed: boolean)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			attemptHit()
		end
	end

	local self: HitboxClient = {
		start = function(_self: HitboxClient)
			if connection then return end
			connection = UserInputService.InputBegan:Connect(onInputBegan)
		end,
		stop = function(_self: HitboxClient)
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if resultConnection then
				resultConnection:Disconnect()
				resultConnection = nil
			end
		end,
		destroy = function(_self: HitboxClient)
			_self:stop()
			if resultConnection then
				resultConnection:Disconnect()
				resultConnection = nil
			end
		end,
	}

	return self
end

return HitboxClientModule

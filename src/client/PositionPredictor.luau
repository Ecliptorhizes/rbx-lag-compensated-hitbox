--!strict
--[[
	PositionPredictor: Extrapolates player positions when server lags.
	Uses velocity to predict where a player will be, reducing perceived lag for both sides.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PositionPredictorModule = {}

export type PositionPredictor = {
	getPredictedPosition: (self: PositionPredictor, character: Model, extrapolationMs: number) -> Vector3,
	getPredictedCFrame: (self: PositionPredictor, character: Model, extrapolationMs: number) -> CFrame?,
	destroy: (self: PositionPredictor) -> (),
}

type CachedState = {
	position: Vector3,
	velocity: Vector3,
	timestamp: number,
}

function PositionPredictorModule.new(): PositionPredictor
	local cache: { [Model]: CachedState } = {}
	local connection: RBXScriptConnection?

	local function updateCache()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then continue end

			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not rootPart then continue end

			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if not humanoid or humanoid.Health <= 0 then continue end

			local vel = rootPart.AssemblyLinearVelocity
			cache[character] = {
				position = rootPart.Position,
				velocity = vel,
				timestamp = tick(),
			}
		end
	end

	connection = RunService.Heartbeat:Connect(updateCache)
	updateCache()

	local self: PositionPredictor = {
		getPredictedPosition = function(_self: PositionPredictor, character: Model, extrapolationMs: number): Vector3
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not rootPart then return character:GetPivot().Position end

			local state = cache[character]
			if not state then
				return rootPart.Position
			end

			local deltaSec = extrapolationMs / 1000
			return state.position + state.velocity * deltaSec
		end,
		getPredictedCFrame = function(_self: PositionPredictor, character: Model, extrapolationMs: number): CFrame?
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not rootPart then return nil end

			local state = cache[character]
			if not state then
				return rootPart.CFrame
			end

			local deltaSec = extrapolationMs / 1000
			local predictedPos = state.position + state.velocity * deltaSec
			return CFrame.new(predictedPos) * (rootPart.CFrame - rootPart.CFrame.Position)
		end,
		destroy = function(_self: PositionPredictor)
			if connection then
				connection:Disconnect()
				connection = nil
			end
			cache = {}
		end,
	}

	return self
end

return PositionPredictorModule

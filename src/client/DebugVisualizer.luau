--!strict
--[[
	DebugVisualizer: Renders hurt boxes and hit boxes in real-time for developers.
	Hurt box = area that receives damage (target).
	Hit box = attack ray/range (attacker).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DebugVisualizerModule = {}

export type DebugVisualizer = {
	start: (self: DebugVisualizer) -> (),
	stop: (self: DebugVisualizer) -> (),
	updateHitBox: (self: DebugVisualizer, origin: Vector3, direction: Vector3, maxDistance: number) -> (),
	destroy: (self: DebugVisualizer) -> (),
}

type Config = {
	hurtBoxColor: Color3,
	hurtBoxTransparency: number,
	hitBoxColor: Color3,
	hitBoxTransparency: number,
}

local function createHurtBoxAdornment(character: Model, config: Config): BoxHandleAdornment
	local adorn = Instance.new("BoxHandleAdornment")
	adorn.Name = "HurtBoxDebug"
	adorn.Adornee = character
	adorn.Size = character:GetExtentsSize()
	adorn.CFrame = character:GetBoundingCFrame()
	adorn.Color3 = config.hurtBoxColor
	adorn.Transparency = config.hurtBoxTransparency
	adorn.AlwaysOnTop = true
	return adorn
end

local function createHitBoxPart(): Part
	local part = Instance.new("Part")
	part.Name = "HitBoxDebug"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 1)
	return part
end

local function createHitBoxBeam(part: Part): Beam
	local att0 = Instance.new("Attachment")
	att0.Parent = part
	local att1 = Instance.new("Attachment")
	att1.Parent = part
	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Color = ColorSequence.new(Color3.new(0.2, 1, 0.2))
	beam.Transparency = NumberSequence.new(0.5)
	beam.Width0 = 0.3
	beam.Width1 = 0.1
	beam.Parent = part
	return beam
end

function DebugVisualizerModule.new(config: Config?): DebugVisualizer
	local cfg = config or {
		hurtBoxColor = Color3.fromRGB(255, 100, 100),
		hurtBoxTransparency = 0.6,
		hitBoxColor = Color3.fromRGB(100, 255, 100),
		hitBoxTransparency = 0.5,
	}

	local folder = Instance.new("Folder")
	folder.Name = "HitboxDebugVisuals"
	folder.Parent = workspace

	local hurtBoxes: { [Player]: BoxHandleAdornment } = {}
	local hitBoxPart: Part? = createHitBoxPart()
	local hitBoxBeam: Beam? = nil
	if hitBoxPart then
		hitBoxPart.Parent = folder
		hitBoxBeam = createHitBoxBeam(hitBoxPart)
		hitBoxBeam.Color = ColorSequence.new(cfg.hitBoxColor)
		hitBoxBeam.Transparency = NumberSequence.new(cfg.hitBoxTransparency)
	end

	local connection: RBXScriptConnection?

	local function updateHurtBoxes()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then
				if hurtBoxes[player] then
					hurtBoxes[player]:Destroy()
					hurtBoxes[player] = nil
				end
				continue
			end

			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if not humanoid or humanoid.Health <= 0 then
				if hurtBoxes[player] then
					hurtBoxes[player]:Destroy()
					hurtBoxes[player] = nil
				end
				continue
			end

			if not hurtBoxes[player] then
				local adorn = createHurtBoxAdornment(character, cfg)
				adorn.Parent = folder
				hurtBoxes[player] = adorn
			end

			local adorn = hurtBoxes[player]
			adorn.Adornee = character
			adorn.Size = character:GetExtentsSize()
			adorn.CFrame = character:GetBoundingCFrame()
		end
	end

	local self: DebugVisualizer = {
		start = function(_self: DebugVisualizer)
			if connection then return end
			connection = RunService.RenderStepped:Connect(updateHurtBoxes)
		end,
		stop = function(_self: DebugVisualizer)
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if hitBoxPart and hitBoxPart.Parent then
				hitBoxPart.Transparency = 1
			end
		end,
		updateHitBox = function(_self: DebugVisualizer, origin: Vector3, direction: Vector3, maxDistance: number)
			if not hitBoxPart or not hitBoxBeam then return end
			local dir = direction.Unit
			local length = math.clamp(maxDistance, 1, 100)
			local endPos = origin + dir * length
			local center = (origin + endPos) / 2
			hitBoxPart.CFrame = CFrame.lookAt(center, endPos)
			hitBoxPart.Size = Vector3.new(0.2, 0.2, length)
			hitBoxPart.Transparency = 1 - cfg.hitBoxTransparency
			local attachments: { Attachment } = {}
			for _, c in hitBoxPart:GetChildren() do
				if c:IsA("Attachment") then
					table.insert(attachments, c)
				end
			end
			if #attachments >= 2 then
				attachments[1].Position = Vector3.new(0, 0, -length / 2)
				attachments[2].Position = Vector3.new(0, 0, length / 2)
			end
		end,
		destroy = function(_self: DebugVisualizer)
			_self:stop()
			for _, adorn in hurtBoxes do
				adorn:Destroy()
			end
			hurtBoxes = {}
			if hitBoxPart then
				hitBoxPart:Destroy()
				hitBoxPart = nil
			end
			folder:Destroy()
		end,
	}

	return self
end

return DebugVisualizerModule

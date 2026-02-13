--!strict
--[[
	HitboxValidator: Server-side raycast + rewind validation.
	Verifies hit requests by rewinding positions and performing server raycast.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TemporalBuffer = require(script.Parent.TemporalBuffer)
type TemporalBuffer = TemporalBuffer.TemporalBuffer

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types")) :: any
type HitRequest = Types.HitRequest
type HitResult = Types.HitResult

local HitboxValidatorModule = {}

local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
RAYCAST_PARAMS.IgnoreWater = true

function HitboxValidatorModule.validate(
	request: HitRequest,
	attacker: Player,
	buffer: TemporalBuffer,
	config: any?
): HitResult
	-- Resolve target player
	local target = Players:GetPlayerByUserId(request.targetUserId)
	if not target then
		return { valid = false, reason = "Target not found" }
	end

	local targetCharacter = target.Character
	if not targetCharacter then
		return { valid = false, reason = "Target has no character" }
	end

	local targetHumanoid = targetCharacter:FindFirstChild("Humanoid") :: Humanoid?
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return { valid = false, reason = "Target is dead or invalid" }
	end

	-- Rewind: get attacker position at timestamp
	local attackerPosition = buffer:getPositionAt(attacker, request.timestamp)
	if not attackerPosition then
		return { valid = false, reason = "Attacker position not in buffer" }
	end

	-- Rewind: get target position at timestamp
	local targetPosition = buffer:getPositionAt(target, request.timestamp)
	if not targetPosition then
		return { valid = false, reason = "Target position not in buffer" }
	end

	-- Anti-exploit: verify client origin is close to server's stored position
	local cfg = config or {}
	local maxDelta = cfg.maxPositionDelta or 5
	local originDelta = (request.origin - attackerPosition.Position).Magnitude
	if originDelta > maxDelta then
		return { valid = false, reason = "Position mismatch" }
	end

	-- Anti-exploit: reject if attacker and target are too far apart
	local maxDist = cfg.maxAttackerTargetDistance or 50
	local attackerTargetDist = (attackerPosition.Position - targetPosition.Position).Magnitude
	if attackerTargetDist > maxDist then
		return { valid = false, reason = "Target too far" }
	end

	-- Build ray origin and direction from rewound attacker position
	-- Use request direction (client saw the hit) but origin from server rewind
	local rayOrigin = attackerPosition.Position
	local rayDirection = request.direction.Unit * math.clamp(request.maxDistance, 0, 100)

	-- Exclude both attacker and target from raycast
	local filterList: { Instance } = {}
	if attacker.Character then
		table.insert(filterList, attacker.Character)
	end
	table.insert(filterList, targetCharacter)
	RAYCAST_PARAMS.FilterDescendantsInstances = filterList

	local rayResult = Workspace:Raycast(rayOrigin, rayDirection, RAYCAST_PARAMS)

	if not rayResult then
		return { valid = false, reason = "Raycast missed" }
	end

	-- Check if we hit the target's character
	local hitInstance = rayResult.Instance
	local current = hitInstance
	while current do
		if current == targetCharacter then
			return { valid = true }
		end
		current = current.Parent
	end

	return { valid = false, reason = "Raycast hit wrong target" }
end

return HitboxValidatorModule

--!strict
-- Animates every plant locally from the timestamps the server put on it:
-- grows from seedling to full size, shows a countdown, and gives ready
-- squishies a little squish-bounce. Also hides the Harvest prompt unless the
-- plant is ready and belongs to the local player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Growth = require(Shared.Growth)
local Squishies = require(Shared.Config.Squishies)

local PLANT_TAG = "SquishyPlant"
local UPDATE_INTERVAL = 1 / 20
local SEEDLING_SCALE = 0.25
-- Cylinders point along X by default; stand them upright.
local CYLINDER_UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local PlantVisuals = {}

local function update(part: BasePart, now: number, localUserId: number)
	local startedAt = part:GetAttribute("StartedAt")
	local readyAt = part:GetAttribute("ReadyAt")
	local fullSize = part:GetAttribute("FullSize")
	local anchor = part:GetAttribute("Anchor")
	if type(startedAt) ~= "number" or type(readyAt) ~= "number" or type(fullSize) ~= "number" then
		return
	end
	if typeof(anchor) ~= "Vector3" then
		return
	end

	local ready = Growth.isReady(readyAt, now)
	local progress = Growth.progress(startedAt, readyAt, now)
	local size = fullSize * (SEEDLING_SCALE + (1 - SEEDLING_SCALE) * progress)
	local scale = Vector3.one
	if ready then
		-- Squash and stretch: wider when shorter, like a squishy being pressed.
		local squish = math.sin(now * 5 + ((part:GetAttribute("TileIndex") or 0) :: number)) * 0.06
		scale = Vector3.new(1 + squish, 1 - squish, 1 + squish)
	end

	local isCylinder = (part :: Part).Shape == Enum.PartType.Cylinder
	local height = size * scale.Y
	-- A cylinder's length runs along its local X, which is world up once rotated.
	local finalSize = if isCylinder then Vector3.new(height, size * scale.X, size * scale.Z) else size * scale
	part.Size = finalSize
	part.CFrame = CFrame.new(anchor + Vector3.new(0, height / 2, 0))
		* (if isCylinder then CYLINDER_UPRIGHT else CFrame.identity)

	local label = part:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		local def = Squishies.ById[part:GetAttribute("SquishyId") :: string]
		local name = if def then def.name else "Squishy"
		label.Text = if ready then name .. " - Ready!" else `{name} {Format.duration(readyAt - now)}`
	end

	local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Enabled = ready and part:GetAttribute("OwnerUserId") == localUserId
	end
end

function PlantVisuals.Start()
	local localUserId = Players.LocalPlayer.UserId
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < UPDATE_INTERVAL then
			return
		end
		elapsed = 0
		local now = Workspace:GetServerTimeNow()
		for _, instance in CollectionService:GetTagged(PLANT_TAG) do
			if instance:IsA("BasePart") then
				update(instance, now, localUserId)
			end
		end
	end)
end

return PlantVisuals

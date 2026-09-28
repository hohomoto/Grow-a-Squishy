--!strict
-- Animates every plant locally from the attributes the server puts on it:
-- grows from seedling to full size, shows a countdown and mutation tags,
-- tints and decorates mutated squishies (Gold, Rainbow, Frozen, ...), and
-- gives ready ones a squish-bounce and sparkles. Also hides the Harvest
-- prompt unless the plant is ready and belongs to the local player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Growth = require(Shared.Growth)
local Mutations = require(Shared.Config.Mutations)
local Squishies = require(Shared.Config.Squishies)

local PLANT_TAG = "SquishyPlant"
local UPDATE_INTERVAL = 1 / 20
local SEEDLING_SCALE = 0.25

local function mutationColor(id: string): Color3
	local c = Mutations.ById[id].color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local GOLD = mutationColor("Gold")
local ICE = mutationColor("Frozen")
local SLIME = mutationColor("Slimy")
local STAR = mutationColor("Starstruck")

-- Per-plant cache so mutation effects are only rebuilt when they change.
type Effects = { raw: string, ids: { string }, has: { [string]: boolean }, tags: string }
local effects: { [BasePart]: Effects } = setmetatable({}, { __mode = "k" }) :: any

local PlantVisuals = {}

local function buildEffects(part: BasePart, raw: string): Effects
	local ids: { string } = if raw == "" then {} else string.split(raw, ",")
	local has = {}
	local tags = {}
	for _, id in ids do
		local def = Mutations.ById[id]
		if def then
			has[id] = true
			table.insert(tags, `<font color="#{mutationColor(id):ToHex()}">{def.name}</font>`)
		end
	end

	-- Replace any previous mutation particles/light.
	for _, name in { "MutationFx", "MutationLight" } do
		local old = part:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local top = Mutations.top(ids)
	if top then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "MutationFx"
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), mutationColor(top.id))
		emitter.LightEmission = 1
		emitter.Rate = 2 + #ids * 2
		emitter.Lifetime = NumberRange.new(1, 1.8)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.45, 0)
		if has.Slimy then
			-- Slime drips downward.
			emitter.Acceleration = Vector3.new(0, -8, 0)
		end
		emitter.Parent = part
		if top.multiplier >= 15 then
			local light = Instance.new("PointLight")
			light.Name = "MutationLight"
			light.Color = mutationColor(top.id)
			light.Range = 9
			light.Brightness = 1.5
			light.Parent = part
		end
	end
	part.Reflectance = if has.Gold or has.Frozen then 0.25 else 0

	local cached = { raw = raw, ids = ids, has = has, tags = table.concat(tags, " ") }
	effects[part] = cached
	return cached
end

local function displayColor(base: Color3, fx: Effects, now: number, seed: number): Color3
	local color = base
	if fx.has.Rainbow then
		color = Color3.fromHSV((now * 0.25 + seed * 0.07) % 1, 0.55, 1)
	elseif fx.has.Gold then
		color = GOLD
	end
	if fx.has.Frozen then
		color = color:Lerp(ICE, 0.55)
	end
	if fx.has.Slimy then
		color = color:Lerp(SLIME, 0.4)
	end
	if fx.has.Starstruck then
		color = color:Lerp(STAR, 0.3)
	end
	return color
end

local function update(part: BasePart, now: number, localUserId: number)
	local startedAt = part:GetAttribute("StartedAt")
	local readyAt = part:GetAttribute("ReadyAt")
	local fullSize = part:GetAttribute("FullSize")
	local anchor = part:GetAttribute("Anchor")
	local proportions = part:GetAttribute("Proportions")
	local facing = part:GetAttribute("Facing")
	local baseColor = part:GetAttribute("BaseColor")
	if type(startedAt) ~= "number" or type(readyAt) ~= "number" or type(fullSize) ~= "number" then
		return
	end
	if typeof(anchor) ~= "Vector3" or typeof(proportions) ~= "Vector3" or typeof(facing) ~= "Vector3" then
		return
	end
	local tileIndex = (part:GetAttribute("TileIndex") or 0) :: number

	local raw = part:GetAttribute("Mutations")
	raw = if type(raw) == "string" then raw else ""
	local fx = effects[part]
	if not fx or fx.raw ~= raw then
		fx = buildEffects(part, raw :: string)
	end

	local ready = Growth.isReady(readyAt, now)
	local progress = Growth.progress(startedAt, readyAt, now)
	local size = fullSize * (SEEDLING_SCALE + (1 - SEEDLING_SCALE) * progress)
	local squash = Vector3.one
	if ready then
		-- Squash and stretch: wider when shorter, like a squishy being pressed.
		local squish = math.sin(now * 5 + tileIndex) * 0.06
		squash = Vector3.new(1 + squish, 1 - squish, 1 + squish)
	end

	local finalSize = proportions * squash * size
	part.Size = finalSize
	local center = anchor + Vector3.new(0, finalSize.Y / 2, 0)
	part.CFrame = CFrame.lookAt(center, center + facing)
	if typeof(baseColor) == "Color3" then
		part.Color = displayColor(baseColor, fx, now, tileIndex)
	end

	local info = part:FindFirstChild("Info")
	local label = info and info:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		local def = Squishies.ById[part:GetAttribute("SquishyId") :: string]
		local name = if def then def.name else "Squishy"
		local status = if ready then "Ready!" else Format.duration(readyAt - now)
		local line = `{name} {status}`
		label.Text = if fx.tags ~= "" then fx.tags .. "\n" .. line else line
	end

	local sparkles = part:FindFirstChild("ReadySparkles")
	if sparkles and sparkles:IsA("ParticleEmitter") then
		sparkles.Enabled = ready
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

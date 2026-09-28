--!strict
-- Animates every plant model locally from the attributes the server puts on
-- it: grows it from seedling to full size, shows a countdown and mutation
-- tags, tints and decorates mutated plants (Gold, Rainbow, Frozen, ...),
-- scales size mutations (Mini .. Colossal), and gives ready plants a
-- squish-bounce and sparkles. Also hides the Harvest prompt unless the plant
-- is ready and belongs to the local player.
--
-- The server builds each model at full size. The first time a model shows up
-- here, we record every part's offset and size relative to its Root, then
-- rescale the whole model around Root from those records.

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
local TICK = 1 / 20
-- Plants farther than this from the camera update once a second, without bounce.
local NEAR_DISTANCE = 90
local FAR_EVERY_N_TICKS = 20
local SEEDLING_SCALE = 0.25

local function mutationColor(id: string): Color3
	local c = Mutations.ById[id].color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local GOLD = mutationColor("Gold")
local ICE = mutationColor("Frozen")
local SLIME = mutationColor("Slimy")
local STAR = mutationColor("Starstruck")

type Piece = { part: BasePart, offset: CFrame, size: Vector3, shade: number? }
type Effects = { raw: string, has: { [string]: boolean }, tags: string, scale: number, top: any }
type Plant = {
	model: Model,
	rootCFrame: CFrame,
	pieces: { Piece },
	height: number,
	body: BasePart?,
	info: BillboardGui?,
	label: TextLabel?,
	prompt: ProximityPrompt?,
	sparkles: ParticleEmitter?,
	fx: Effects?,
	lastScale: number,
	lastColorKey: string,
}

local plants: { [Model]: Plant } = setmetatable({}, { __mode = "k" }) :: any
local tickCount = 0

local PlantVisuals = {}

-- Same shading rule as the server's SquishyModels.shade.
local function shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

local function capture(model: Model): Plant?
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local pieces = {}
	local height = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= root then
			local offset = root.CFrame:ToObjectSpace(descendant.CFrame)
			local shadeValue = descendant:GetAttribute("Shade")
			table.insert(pieces, {
				part = descendant,
				offset = offset,
				size = descendant.Size,
				shade = if type(shadeValue) == "number" then shadeValue else nil,
			})
			height = math.max(height, offset.Position.Y + descendant.Size.Y / 2)
		end
	end
	local info = root:FindFirstChild("Info")
	local body = model:FindFirstChild("Body")
	local plant: Plant = {
		model = model,
		rootCFrame = root.CFrame,
		pieces = pieces,
		height = height,
		body = if body and body:IsA("BasePart") then body else nil,
		info = if info and info:IsA("BillboardGui") then info else nil,
		label = nil,
		prompt = root:FindFirstChildWhichIsA("ProximityPrompt"),
		sparkles = nil,
		fx = nil,
		lastScale = -1,
		lastColorKey = "",
	}
	local label = plant.info and plant.info:FindFirstChild("Label")
	plant.label = if label and label:IsA("TextLabel") then label else nil
	local sparkles = plant.body and plant.body:FindFirstChild("ReadySparkles")
	plant.sparkles = if sparkles and sparkles:IsA("ParticleEmitter") then sparkles else nil
	plants[model] = plant
	return plant
end

local function buildEffects(plant: Plant, raw: string): Effects
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

	-- Replace any previous mutation particles/light on the body.
	local body = plant.body
	if body then
		for _, name in { "MutationFx", "MutationLight" } do
			local old = body:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
	end
	local top = Mutations.top(ids)
	if top and body then
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
		emitter.Parent = body
		if top.multiplier >= 15 then
			local light = Instance.new("PointLight")
			light.Name = "MutationLight"
			light.Color = mutationColor(top.id)
			light.Range = 9
			light.Brightness = 1.5
			light.Parent = body
		end
	end
	local shiny = if has.Gold or has.Frozen then 0.25 else 0
	for _, piece in plant.pieces do
		if piece.shade then
			piece.part.Reflectance = shiny
		end
	end

	local fx = { raw = raw, has = has, tags = table.concat(tags, " "), scale = Mutations.scale(ids), top = top }
	plant.fx = fx
	plant.lastColorKey = ""
	plant.lastScale = -1
	return fx
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

local function update(plant: Plant, now: number, near: boolean, localUserId: number)
	local model = plant.model
	local startedAt = model:GetAttribute("StartedAt")
	local readyAt = model:GetAttribute("ReadyAt")
	if type(startedAt) ~= "number" or type(readyAt) ~= "number" then
		return
	end
	local tileIndex = (model:GetAttribute("TileIndex") or 0) :: number

	local raw = model:GetAttribute("Mutations")
	raw = if type(raw) == "string" then raw else ""
	local cached = plant.fx
	local fx: Effects = if cached and cached.raw == raw then cached else buildEffects(plant, raw :: string)

	local ready = Growth.isReady(readyAt, now)
	local progress = Growth.progress(startedAt, readyAt, now)
	-- Size mutations (Mini / Big / Huge / Colossal) change the grown size.
	local scale = fx.scale * (SEEDLING_SCALE + (1 - SEEDLING_SCALE) * progress)
	local squish = 0
	if ready and near then
		-- Squash and stretch: wider when shorter, like a squishy being pressed.
		squish = math.sin(now * 5 + tileIndex) * 0.06
	end

	-- Reposition parts only when something visibly changed.
	if squish ~= 0 or math.abs(scale - plant.lastScale) > 0.002 then
		plant.lastScale = if squish ~= 0 then -1 else scale
		local scaleVector = Vector3.new(scale * (1 + squish), scale * (1 - squish), scale * (1 + squish))
		local rootCFrame = plant.rootCFrame
		for _, piece in plant.pieces do
			local offset = piece.offset
			piece.part.Size = piece.size * scaleVector
			piece.part.CFrame = rootCFrame * CFrame.new(offset.Position * scaleVector) * offset.Rotation
		end
		if plant.info then
			plant.info.StudsOffsetWorldSpace = Vector3.new(0, plant.height * scale + 1.2, 0)
		end
	end

	-- Mutation tint on the plant's own colored parts.
	local baseColor = model:GetAttribute("BaseColor")
	if typeof(baseColor) == "Color3" then
		local colorKey = if fx.has.Rainbow and near then tostring(now) else fx.raw
		if colorKey ~= plant.lastColorKey then
			plant.lastColorKey = colorKey
			local tinted = displayColor(baseColor, fx, now, tileIndex)
			for _, piece in plant.pieces do
				if piece.shade then
					piece.part.Color = shade(tinted, piece.shade)
				end
			end
		end
	end

	if plant.label then
		local def = Squishies.ById[model:GetAttribute("SquishyId") :: string]
		local name = if def then def.name else "Squishy"
		local status = if ready then "Ready!" else Format.duration(readyAt - now)
		local line = `{name} {status}`
		plant.label.Text = if fx.tags ~= "" then fx.tags .. "\n" .. line else line
	end
	if plant.sparkles then
		plant.sparkles.Enabled = ready
	end
	if plant.prompt then
		plant.prompt.Enabled = ready and model:GetAttribute("OwnerUserId") == localUserId
	end
end

local function step(now: number, localUserId: number, full: boolean)
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for _, instance in CollectionService:GetTagged(PLANT_TAG) do
		if instance:IsA("Model") then
			local plant = plants[instance] or capture(instance)
			if plant then
				local near = (plant.rootCFrame.Position - cameraPosition).Magnitude < NEAR_DISTANCE
				if near or full then
					update(plant, now, near, localUserId)
				end
			end
		end
	end
end

function PlantVisuals.Start()
	local localUserId = Players.LocalPlayer.UserId

	-- New plants shrink to seedling size immediately, before the next tick.
	CollectionService:GetInstanceAddedSignal(PLANT_TAG):Connect(function(instance)
		if instance:IsA("Model") then
			local plant = plants[instance] or capture(instance)
			if plant then
				update(plant, Workspace:GetServerTimeNow(), true, localUserId)
			end
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < TICK then
			return
		end
		elapsed = 0
		tickCount += 1
		step(Workspace:GetServerTimeNow(), localUserId, tickCount % FAR_EVERY_N_TICKS == 0)
	end)
end

return PlantVisuals

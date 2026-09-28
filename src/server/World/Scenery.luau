--!strict
-- Everything that makes the world look nice but has no gameplay: the flat
-- cartoon meadow, hills and pond, lighting, candy trees, lollipop lamps, giant squishy statues, arches,
-- flowers and clouds. Positions come from a fixed-seed RNG, so every server
-- (and every playtest) looks the same.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Rng = require(ReplicatedStorage.Shared.Rng)
local Build = require(script.Parent.Build)
local SquishyModels = require(script.Parent.SquishyModels)

export type Layout = {
	pathWidth: number,
	pathHalfLength: number,
	-- Rectangles (center + size, XZ only) that scenery must stay out of.
	keepClear: { { center: Vector3, size: Vector3 } },
	-- Z positions along the path where plot gates are; lamps avoid them.
	gateZ: { number },
	pondCenter: Vector3,
	statueCenter: Vector3,
}

local SCENERY_SEED = 20260928
local WORLD_HALF_SIZE = 260
local POND_RADIUS = 22
local MEADOW = Color3.fromRGB(150, 220, 120)

local PASTELS = {
	Color3.fromRGB(255, 170, 210), -- pink
	Color3.fromRGB(170, 235, 200), -- mint
	Color3.fromRGB(200, 175, 255), -- lavender
	Color3.fromRGB(255, 205, 160), -- peach
	Color3.fromRGB(160, 215, 255), -- sky
	Color3.fromRGB(255, 240, 150), -- lemon
}

local Scenery = {}

local function pick<T>(rng: Rng.Rng, list: { T }): T
	return list[rng:range(1, #list)]
end

local function between(rng: Rng.Rng, min: number, max: number): number
	return min + (max - min) * rng:next()
end

local function isClear(layout: Layout, position: Vector3, margin: number): boolean
	for _, zone in layout.keepClear do
		local dx = math.abs(position.X - zone.center.X)
		local dz = math.abs(position.Z - zone.center.Z)
		if dx < zone.size.X / 2 + margin and dz < zone.size.Z / 2 + margin then
			return false
		end
	end
	local flat = Vector3.new(position.X, 0, position.Z)
	if (flat - layout.pondCenter).Magnitude < POND_RADIUS + 6 + margin then
		return false
	end
	if (flat - layout.statueCenter).Magnitude < 16 + margin then
		return false
	end
	return math.abs(position.X) < WORLD_HALF_SIZE - 20 and math.abs(position.Z) < WORLD_HALF_SIZE - 20
end

-- Tries random spots until it finds `count` clear ones.
local function scatter(rng: Rng.Rng, layout: Layout, count: number, margin: number, radius: number): { Vector3 }
	local spots: { Vector3 } = {}
	local attempts = 0
	while #spots < count and attempts < count * 40 do
		attempts += 1
		local spot = Vector3.new(between(rng, -radius, radius), 0, between(rng, -radius, radius))
		local tooClose = false
		for _, other in spots do
			if (other - spot).Magnitude < margin * 2 then
				tooClose = true
				break
			end
		end
		if not tooClose and isClear(layout, spot, margin) then
			table.insert(spots, spot)
		end
	end
	return spots
end

-- Flat, cartoon-style ground built from smooth plastic parts (terrain
-- materials always look realistic, which clashes with the art style).
local function buildGround(folder: Instance, layout: Layout)
	-- The default template's Baseplate would poke through the meadow.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local span = WORLD_HALF_SIZE * 2
	Build.part({
		Name = "Meadow",
		Size = Vector3.new(span, 2, span),
		Position = Vector3.new(0, -1, 0),
		Color = MEADOW,
		Parent = folder,
	})

	local rng = Rng.new(SCENERY_SEED + 1)

	-- Lighter and darker grass patches so the meadow isn't one flat color.
	for _ = 1, 30 do
		local spot = Vector3.new(between(rng, -230, 230), 0, between(rng, -230, 230))
		if isClear(layout, spot, 12) then
			local tone = if rng:next() < 0.5 then Build.tint(MEADOW, 0.18) else MEADOW:Lerp(Color3.new(0, 0.3, 0), 0.12)
			Build.column(folder, spot, 0.08, between(rng, 14, 34), tone, { CanCollide = false, CanQuery = false })
		end
	end

	-- Round, soft hills ringing the world.
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2 + between(rng, -0.1, 0.1)
		local distance = between(rng, 190, 230)
		local diameter = between(rng, 50, 80)
		local center = Vector3.new(math.cos(angle) * distance, -diameter * 0.28, math.sin(angle) * distance)
		local tone = MEADOW:Lerp(Color3.fromRGB(90, 190, 110), between(rng, 0, 0.5))
		Build.ball(folder, center, diameter, tone, { CanCollide = true })
	end

	-- Pond: sandy rim, water, and a few lily pads.
	local pond = layout.pondCenter
	Build.column(folder, pond, 0.3, (POND_RADIUS + 4) * 2, Color3.fromRGB(255, 225, 185))
	Build.column(folder, pond, 0.4, POND_RADIUS * 2, Color3.fromRGB(120, 205, 255), {
		Transparency = 0.1,
		Reflectance = 0.15,
	})
	for _ = 1, 7 do
		local angle = between(rng, 0, math.pi * 2)
		local distance = between(rng, 4, POND_RADIUS - 4)
		local spot = pond + Vector3.new(math.cos(angle) * distance, 0.4, math.sin(angle) * distance)
		Build.column(folder, spot, 0.1, between(rng, 2.5, 4), Color3.fromRGB(110, 200, 110))
	end
end

local function buildLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(150, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(185, 165, 185)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(255, 220, 238)
	atmosphere.Decay = Color3.fromRGB(190, 160, 225)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 248, 252)
	color.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.8
	rays.Parent = Lighting
end

local function candyTree(parent: Instance, rng: Rng.Rng, ground: Vector3)
	local model = Instance.new("Model")
	model.Name = "CandyTree"
	local height = between(rng, 7, 11)
	Build.column(model, ground, height, 1.4, Color3.fromRGB(215, 160, 120))
	local color = pick(rng, PASTELS)
	local top = ground + Vector3.new(0, height, 0)
	for i = 1, 3 do
		local offset = Vector3.new(between(rng, -2.2, 2.2), between(rng, -0.5, 2), between(rng, -2.2, 2.2))
		local tone = Build.tint(color, (i - 1) * 0.12)
		Build.ball(model, top + offset, between(rng, 6, 9), tone, { CanCollide = true })
	end
	model.Parent = parent
end

local function lollipopLamp(parent: Instance, ground: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name = "LollipopLamp"
	Build.column(model, ground, 8, 0.5, Color3.new(1, 1, 1))
	local candy = Build.ball(model, ground + Vector3.new(0, 9, 0), 2.6, color, { Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 0.8
	light.Parent = candy
	model.Parent = parent
end

local function arch(parent: Instance, z: number, width: number, facing: number)
	local model = Instance.new("Model")
	model.Name = "Arch"
	local half = width / 2 + 1.5
	for _, x in { -half, half } do
		Build.column(model, Vector3.new(x, 0, z), 14, 2.4, Color3.fromRGB(255, 255, 255))
		Build.ball(model, Vector3.new(x, 15, z), 3.4, PASTELS[1], { CanCollide = true })
	end
	-- Row of candy balls forming the arch's top.
	local count = 11
	for i = 0, count - 1 do
		local t = i / (count - 1)
		local x = -half + t * half * 2
		local lift = math.sin(t * math.pi) * 4
		Build.ball(model, Vector3.new(x, 15 + lift, z), 3, PASTELS[(i % #PASTELS) + 1])
	end
	local signAnchor = Build.decor({
		Size = Vector3.one,
		Position = Vector3.new(0, 20, z + facing),
		Transparency = 1,
		Parent = model,
	})
	Build.billboard(signAnchor, "Grow a Squishy", 0, 420)
	model.Parent = parent
end

local function cloud(parent: Instance, rng: Rng.Rng, center: Vector3)
	local model = Instance.new("Model")
	model.Name = "Cloud"
	for _ = 1, 5 do
		local offset = Vector3.new(between(rng, -14, 14), between(rng, -3, 3), between(rng, -6, 6))
		Build.ball(model, center + offset, between(rng, 14, 24), Color3.fromRGB(255, 255, 255), { CastShadow = false })
	end
	model.Parent = parent
end

local function flowerPatch(parent: Instance, rng: Rng.Rng, ground: Vector3)
	local color = pick(rng, PASTELS)
	for _ = 1, 5 do
		local offset = Vector3.new(between(rng, -2, 2), 0.4, between(rng, -2, 2))
		Build.ball(parent, ground + offset, between(rng, 0.7, 1.1), color, { CastShadow = false })
	end
	Build.ball(parent, ground + Vector3.new(0, 0.3, 0), 0.6, Color3.fromRGB(255, 230, 90), { CastShadow = false })
end

function Scenery.build(parent: Instance, layout: Layout)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = parent

	buildGround(folder, layout)
	buildLighting()
	local rng = Rng.new(SCENERY_SEED)

	-- Lollipop lamps along both sides of the path, skipping the plot gates.
	local lampZ = {}
	local step = 14
	local z = -layout.pathHalfLength + 6
	while z <= layout.pathHalfLength - 6 do
		local nearGate = false
		for _, gate in layout.gateZ do
			if math.abs(z - gate) < 8 then
				nearGate = true
			end
		end
		if not nearGate then
			table.insert(lampZ, z)
		end
		z += step
	end
	local lampX = layout.pathWidth / 2 + 1.5
	for i, lz in lampZ do
		local color = PASTELS[(i % #PASTELS) + 1]
		lollipopLamp(folder, Vector3.new(-lampX, 0, lz), color)
		lollipopLamp(folder, Vector3.new(lampX, 0, lz), color)
	end

	arch(folder, -layout.pathHalfLength, layout.pathWidth, 1)
	arch(folder, layout.pathHalfLength, layout.pathWidth, -1)

	-- A giant mochi guarding the south end, looking up the path.
	Build.part({
		Name = "StatuePedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 26, 26),
		CFrame = CFrame.new(layout.statueCenter + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 255, 255),
		Parent = folder,
	})
	SquishyModels.statue(folder, layout.statueCenter + Vector3.new(0, 3, 0), 20, PASTELS[1], Vector3.new(0, 0, 0))

	-- Smaller squishies lounging around the meadow and by the pond.
	for _, spot in scatter(rng, layout, 10, 6, 150) do
		SquishyModels.statue(folder, spot, between(rng, 4, 8), pick(rng, PASTELS), Vector3.new(0, 0, 0))
	end
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		local spot = layout.pondCenter + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (POND_RADIUS + 6)
		SquishyModels.statue(folder, spot, between(rng, 3, 5), pick(rng, PASTELS), layout.pondCenter)
	end

	for _, spot in scatter(rng, layout, 45, 7, 170) do
		candyTree(folder, rng, spot)
	end
	for _, spot in scatter(rng, layout, 40, 3, 160) do
		flowerPatch(folder, rng, spot)
	end
	for _ = 1, 14 do
		local center = Vector3.new(between(rng, -220, 220), between(rng, 90, 130), between(rng, -220, 220))
		cloud(folder, rng, center)
	end

	-- Invisible walls so nobody wanders off the edge of the world.
	local edge = WORLD_HALF_SIZE - 10
	for _, wall in
		{
			{ Vector3.new(edge, 50, 0), Vector3.new(2, 120, edge * 2) },
			{ Vector3.new(-edge, 50, 0), Vector3.new(2, 120, edge * 2) },
			{ Vector3.new(0, 50, edge), Vector3.new(edge * 2, 120, 2) },
			{ Vector3.new(0, 50, -edge), Vector3.new(edge * 2, 120, 2) },
		}
	do
		Build.part({
			Name = "Boundary",
			Position = wall[1],
			Size = wall[2],
			Transparency = 1,
			CanQuery = false,
			Parent = folder,
		})
	end
end

return Scenery

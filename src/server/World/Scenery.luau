--!strict
-- Everything that makes the world look nice but has no gameplay, in the
-- blocky style of Grow a Garden: a huge flat grass field, the default sky
-- with Roblox's dynamic clouds, voxel trees and bushes around the edges,
-- flowers, rocks and a pond. Positions come from a fixed-seed RNG, so every
-- server (and every playtest) looks the same.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Rng = require(ReplicatedStorage.Shared.Rng)
local Build = require(script.Parent.Build)

export type Layout = {
	-- Rectangles (center + size, XZ only) that scenery must stay out of.
	keepClear: { { center: Vector3, size: Vector3 } },
	pondCenter: Vector3,
}

local SCENERY_SEED = 20260928
local WORLD_HALF_SIZE = 700
local POND_RADIUS = 26

local GRASS = Color3.fromRGB(106, 190, 88)
local TRUNK = Color3.fromRGB(110, 76, 50)
local LEAVES = {
	Color3.fromRGB(60, 160, 70),
	Color3.fromRGB(80, 180, 80),
	Color3.fromRGB(50, 140, 75),
	Color3.fromRGB(100, 190, 90),
}
local FLOWERS = {
	Color3.fromRGB(255, 90, 110),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(255, 255, 255),
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
	if (flat - layout.pondCenter).Magnitude < POND_RADIUS + 8 + margin then
		return false
	end
	return math.abs(position.X) < WORLD_HALF_SIZE - 30 and math.abs(position.Z) < WORLD_HALF_SIZE - 30
end

-- Random clear spots between `minRadius` and `maxRadius` from the middle.
local function scatter(
	rng: Rng.Rng,
	layout: Layout,
	count: number,
	margin: number,
	minRadius: number,
	maxRadius: number
): { Vector3 }
	local spots: { Vector3 } = {}
	local attempts = 0
	while #spots < count and attempts < count * 60 do
		attempts += 1
		local angle = between(rng, 0, math.pi * 2)
		local distance = between(rng, minRadius, maxRadius)
		local spot = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
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

local function block(parent: Instance, center: Vector3, size: Vector3, color: Color3, collide: boolean?)
	Build.part({
		Size = size,
		Position = center,
		Color = color,
		CanCollide = collide == true,
		Parent = parent,
	})
end

-- Blocky round tree: square trunk and a stack of leafy cubes.
local function voxelTree(parent: Instance, rng: Rng.Rng, ground: Vector3)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local scale = between(rng, 0.9, 1.6)
	local trunkHeight = 7 * scale
	block(
		model,
		ground + Vector3.new(0, trunkHeight / 2, 0),
		Vector3.new(1.8, trunkHeight, 1.8) * Vector3.new(scale, 1, scale),
		TRUNK,
		true
	)
	local leaves = pick(rng, LEAVES)
	local top = ground + Vector3.new(0, trunkHeight, 0)
	block(model, top + Vector3.new(0, 1.5, 0) * scale, Vector3.new(10, 3, 10) * scale, leaves, true)
	block(
		model,
		top + Vector3.new(0, 4, 0) * scale,
		Vector3.new(7.5, 2.5, 7.5) * scale,
		leaves:Lerp(Color3.new(1, 1, 1), 0.08),
		true
	)
	block(
		model,
		top + Vector3.new(0, 6, 0) * scale,
		Vector3.new(4.5, 2, 4.5) * scale,
		leaves:Lerp(Color3.new(1, 1, 1), 0.15),
		true
	)
	-- A few loose leaf blocks so trees don't all look identical.
	for _ = 1, 3 do
		local offset = Vector3.new(between(rng, -4, 4), between(rng, 0, 3), between(rng, -4, 4)) * scale
		block(model, top + offset, Vector3.one * between(rng, 2, 3.5) * scale, leaves:Lerp(Color3.new(0, 0, 0), 0.08))
	end
	model.Parent = parent
end

-- Blocky pine tree: shrinking square layers.
local function voxelPine(parent: Instance, rng: Rng.Rng, ground: Vector3)
	local model = Instance.new("Model")
	model.Name = "Pine"
	local scale = between(rng, 0.9, 1.5)
	block(model, ground + Vector3.new(0, 2.5 * scale, 0), Vector3.new(1.4, 5, 1.4) * scale, TRUNK, true)
	local leaves = Color3.fromRGB(45, 130, 70)
	for layer = 0, 3 do
		local width = (8 - layer * 1.8) * scale
		local y = (4 + layer * 2.4) * scale
		block(
			model,
			ground + Vector3.new(0, y, 0),
			Vector3.new(width, 2.4 * scale, width),
			leaves:Lerp(Color3.new(1, 1, 1), layer * 0.05),
			true
		)
	end
	model.Parent = parent
end

local function bush(parent: Instance, rng: Rng.Rng, ground: Vector3)
	local color = pick(rng, LEAVES)
	block(parent, ground + Vector3.new(0, 1.2, 0), Vector3.new(3.4, 2.4, 3.4), color, true)
	block(
		parent,
		ground + Vector3.new(1.4, 0.9, 0.8),
		Vector3.new(2.2, 1.8, 2.2),
		color:Lerp(Color3.new(1, 1, 1), 0.08)
	)
	if rng:next() < 0.5 then
		-- Berries.
		block(parent, ground + Vector3.new(-0.6, 2.5, -1), Vector3.one * 0.6, pick(rng, FLOWERS))
	end
end

local function flower(parent: Instance, rng: Rng.Rng, ground: Vector3)
	for _ = 1, 3 do
		local spot = ground + Vector3.new(between(rng, -1.5, 1.5), 0, between(rng, -1.5, 1.5))
		local height = between(rng, 0.8, 1.4)
		block(parent, spot + Vector3.new(0, height / 2, 0), Vector3.new(0.2, height, 0.2), Color3.fromRGB(70, 150, 60))
		block(parent, spot + Vector3.new(0, height + 0.3, 0), Vector3.one * 0.7, pick(rng, FLOWERS))
	end
end

local function rock(parent: Instance, rng: Rng.Rng, ground: Vector3)
	local gray = Color3.fromRGB(135, 135, 140)
	local size = between(rng, 2, 4)
	block(parent, ground + Vector3.new(0, size * 0.35, 0), Vector3.new(size, size * 0.7, size * 0.8), gray, true)
	block(
		parent,
		ground + Vector3.new(size * 0.4, size * 0.2, 0.3),
		Vector3.new(size * 0.6, size * 0.4, size * 0.5),
		gray:Lerp(Color3.new(0, 0, 0), 0.1),
		true
	)
end

local function buildGround(folder: Instance)
	-- The default template's Baseplate would poke through the field.
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local span = WORLD_HALF_SIZE * 2
	Build.part({
		Name = "Field",
		Size = Vector3.new(span, 2, span),
		Position = Vector3.new(0, -1, 0),
		Color = GRASS,
		Parent = folder,
	})
end

local function buildPond(folder: Instance, rng: Rng.Rng, center: Vector3)
	local water = Color3.fromRGB(70, 160, 240)
	Build.column(folder, center, 0.2, POND_RADIUS * 2 + 4, Color3.fromRGB(210, 190, 140))
	Build.column(folder, center, 0.35, POND_RADIUS * 2, water, { Transparency = 0.1, Reflectance = 0.15 })
	-- Stones around the edge.
	for i = 1, 22 do
		local angle = i / 22 * math.pi * 2 + between(rng, -0.05, 0.05)
		local spot = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (POND_RADIUS + 1.5)
		local size = between(rng, 1.5, 2.6)
		block(
			folder,
			spot + Vector3.new(0, size * 0.3, 0),
			Vector3.new(size, size * 0.6, size),
			Color3.fromRGB(150, 150, 155),
			true
		)
	end
	-- Lily pads.
	for _ = 1, 8 do
		local angle = between(rng, 0, math.pi * 2)
		local distance = between(rng, 4, POND_RADIUS - 4)
		local spot = center + Vector3.new(math.cos(angle) * distance, 0.35, math.sin(angle) * distance)
		Build.column(folder, spot, 0.12, between(rng, 2.5, 4), Color3.fromRGB(80, 170, 80))
	end
end

-- Bright, natural daylight like Grow a Garden, with Roblox's dynamic clouds.
local function buildSky()
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = 0
	Lighting.Ambient = Color3.fromRGB(90, 90, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 135, 145)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(199, 215, 235)
	atmosphere.Decay = Color3.fromRGB(106, 130, 170)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.5
	atmosphere.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.12
	color.Contrast = 0.05
	color.Parent = Lighting

	-- Real volumetric clouds drifting across the default sky.
	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildWhichIsA("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.5
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = terrain
end

function Scenery.build(parent: Instance, layout: Layout)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = parent

	buildGround(folder)
	buildSky()
	local rng = Rng.new(SCENERY_SEED)
	buildPond(folder, rng, layout.pondCenter)

	-- Trees: a loose ring around the play area, thicker further out.
	for _, spot in scatter(rng, layout, 30, 9, 150, 320) do
		if rng:next() < 0.65 then
			voxelTree(folder, rng, spot)
		else
			voxelPine(folder, rng, spot)
		end
	end
	for _, spot in scatter(rng, layout, 70, 10, 320, 640) do
		if rng:next() < 0.5 then
			voxelTree(folder, rng, spot)
		else
			voxelPine(folder, rng, spot)
		end
	end
	for _, spot in scatter(rng, layout, 45, 4, 120, 400) do
		bush(folder, rng, spot)
	end
	for _, spot in scatter(rng, layout, 90, 3, 100, 400) do
		flower(folder, rng, spot)
	end
	for _, spot in scatter(rng, layout, 20, 5, 150, 500) do
		rock(folder, rng, spot)
	end

	-- Invisible walls so nobody wanders off the edge of the world.
	local edge = WORLD_HALF_SIZE - 10
	for _, wall in
		{
			{ Vector3.new(edge, 60, 0), Vector3.new(2, 140, edge * 2) },
			{ Vector3.new(-edge, 60, 0), Vector3.new(2, 140, edge * 2) },
			{ Vector3.new(0, 60, edge), Vector3.new(edge * 2, 140, 2) },
			{ Vector3.new(0, 60, -edge), Vector3.new(edge * 2, 140, 2) },
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

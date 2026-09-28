--!strict
-- Builds the map at server start, in the style of Grow a Garden: a big open
-- field with dirt farm plots fenced in brown wood, lots of grass between
-- them, the shops and a fountain plaza in the middle, and voxel trees around
-- the edges (see World/Scenery).
--
-- Layout, seen from above (plots face the middle):
--
--     [Plot1]              [Plot2]
--              Seed Shop
--     [Plot3]   Fountain   [Plot4]
--              Sell Stand
--     [Plot5]              [Plot6]
--
-- Gameplay code relies on these names and attributes, so keep them if the map
-- is ever rebuilt by hand in Studio: Plots/PlotN (OwnerUserId, Facing),
-- PlotN/Tiles/<index> (TileIndex), PlotN/Plants, PlotN/SpawnPoint,
-- PlotN/SignPost, and the two stall prompts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Build = require(script.Parent.Parent.World.Build)
local Scenery = require(script.Parent.Parent.World.Scenery)
local SquishyModels = require(script.Parent.Parent.World.SquishyModels)

local TILE_SIZE = 6
local TILE_GAP = 0.8
local TILE_STEP = TILE_SIZE + TILE_GAP
local PLOT_PADDING = 3
-- Walkway between a plot's two garden beds (where the gate leads).
local BED_GAP = 7
-- Open grass between the two columns of plots, where the shops are.
local CENTER_GAP = 110
-- Open grass between plots in the same column.
local PLOT_SPACING = 45
local GATE_WIDTH = 8
local FENCE_MARGIN = 2.5
-- Distance of each shop stall from the fountain.
local STAND_Z = 42

local BED_WIDTH = Economy.PlotColumns * TILE_STEP - TILE_GAP
local BED_DEPTH = Economy.PlotBedRows * TILE_STEP - TILE_GAP
local PLOT_WIDTH = BED_WIDTH + PLOT_PADDING * 2
local PLOT_DEPTH = BED_DEPTH * 2 + BED_GAP + PLOT_PADDING * 2

local DIRT = Color3.fromRGB(128, 88, 58)
local TILE_A = Color3.fromRGB(112, 76, 50)
local TILE_B = Color3.fromRGB(120, 82, 54)
local WALKWAY = Color3.fromRGB(150, 112, 78)
local FENCE = Color3.fromRGB(110, 76, 50)
local SIGN = Color3.fromRGB(120, 118, 122)
local WHITE = Color3.fromRGB(250, 245, 238)

local WorldService = {}

local plots: { Model } = {}
local sellPrompt: ProximityPrompt
-- Where the travel buttons drop players, keyed by destination name.
local arrivals: { [string]: CFrame } = {}

-- Post-and-rail wooden fence from `from` to `to`, both at ground level.
local function fence(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local gaps = math.max(1, math.round(length / 6))
	for i = 0, gaps do
		Build.part({
			Name = "Post",
			Size = Vector3.new(0.9, 4.2, 0.9),
			Position = from:Lerp(to, i / gaps) + Vector3.new(0, 2.1, 0),
			Color = FENCE,
			Parent = parent,
		})
	end
	for _, height in { 1.6, 3.2 } do
		local lift = Vector3.new(0, height, 0)
		Build.beam(parent, from + lift, to + lift, 0.4, 0.55, FENCE)
	end
end

local function buildPlot(parent: Instance, index: number, center: Vector3, facingCenter: number): Model
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("PlotIndex", index)
	-- Direction from the plot toward the middle of the map; plants face this way.
	plot:SetAttribute("Facing", Vector3.new(facingCenter, 0, 0))

	local base = Build.part({
		Name = "Base",
		Size = Vector3.new(PLOT_WIDTH, 1, PLOT_DEPTH),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = DIRT,
		Parent = plot,
	})
	plot.PrimaryPart = base
	local top = center + Vector3.new(0, 1, 0)

	local decor = Instance.new("Model")
	decor.Name = "Decor"
	decor.Parent = plot

	-- Lighter dirt walkway between the two beds, leading to the gate.
	Build.part({
		Name = "Walkway",
		Size = Vector3.new(PLOT_WIDTH, 0.1, BED_GAP - 1),
		Position = top + Vector3.new(0, 0.05, 0),
		Color = WALKWAY,
		Parent = decor,
	})

	local tiles = Instance.new("Folder")
	tiles.Name = "Tiles"
	tiles.Parent = plot
	local originX = center.X - BED_WIDTH / 2 + TILE_SIZE / 2
	local originZ = center.Z - PLOT_DEPTH / 2 + PLOT_PADDING + TILE_SIZE / 2
	for row = 1, Economy.PlotRows do
		local bed = if row > Economy.PlotBedRows then 1 else 0
		local rowInBed = (row - 1) % Economy.PlotBedRows
		for column = 1, Economy.PlotColumns do
			local tileIndex = (row - 1) * Economy.PlotColumns + column
			local tile = Build.part({
				Name = tostring(tileIndex),
				Size = Vector3.new(TILE_SIZE, 0.3, TILE_SIZE),
				Position = Vector3.new(
					originX + (column - 1) * TILE_STEP,
					1.15,
					originZ + rowInBed * TILE_STEP + bed * (BED_DEPTH + BED_GAP)
				),
				-- Subtle checkerboard so planting spots are easy to see.
				Color = if (row + column) % 2 == 0 then TILE_A else TILE_B,
				Parent = tiles,
			})
			tile:SetAttribute("TileIndex", tileIndex)
		end
	end

	local plants = Instance.new("Folder")
	plants.Name = "Plants"
	plants.Parent = plot

	-- Fence on the grass around the plot, with a gate facing the middle.
	local hx = PLOT_WIDTH / 2 + FENCE_MARGIN
	local hz = PLOT_DEPTH / 2 + FENCE_MARGIN
	local frontX = center.X + facingCenter * hx
	local backX = center.X - facingCenter * hx
	local gateHalf = GATE_WIDTH / 2
	fence(decor, Vector3.new(backX, 0, center.Z - hz), Vector3.new(backX, 0, center.Z + hz))
	fence(decor, Vector3.new(backX, 0, center.Z - hz), Vector3.new(frontX, 0, center.Z - hz))
	fence(decor, Vector3.new(backX, 0, center.Z + hz), Vector3.new(frontX, 0, center.Z + hz))
	fence(decor, Vector3.new(frontX, 0, center.Z - hz), Vector3.new(frontX, 0, center.Z - gateHalf))
	fence(decor, Vector3.new(frontX, 0, center.Z + gateHalf), Vector3.new(frontX, 0, center.Z + hz))

	-- Where the owner appears, just inside the gate.
	Build.part({
		Name = "SpawnPoint",
		Size = Vector3.new(2, 1, 2),
		Position = Vector3.new(center.X + facingCenter * (PLOT_WIDTH / 2 - 2), 1.5, center.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = plot,
	})

	-- Wooden name sign outside the gate. PlotService writes the owner's name.
	local signX = frontX + facingCenter * 3
	local signZ = center.Z - gateHalf - 4
	Build.part({
		Name = "SignLeg",
		Size = Vector3.new(0.6, 4, 0.6),
		Position = Vector3.new(signX, 2, signZ),
		Color = FENCE,
		Parent = decor,
	})
	local board = Build.part({
		Name = "SignPost",
		Size = Vector3.new(0.5, 2.6, 5),
		Position = Vector3.new(signX, 4.6, signZ),
		Color = SIGN,
		Parent = plot,
	})
	Build.billboard(board, "Empty Plot", 3, nil, 90)

	plot.Parent = parent
	return plot
end

-- Market stall at `position`, open toward `front` (+1 or -1 along Z).
local function buildStall(
	parent: Instance,
	name: string,
	position: Vector3,
	front: number,
	color: Color3,
	signText: string,
	actionText: string
): (Model, ProximityPrompt)
	local model = Instance.new("Model")
	model.Name = name

	local counter = Build.part({
		Name = "Counter",
		Size = Vector3.new(14, 3.5, 3.5),
		Position = position + Vector3.new(0, 1.75, 0),
		Color = FENCE,
		Parent = model,
	})
	Build.part({
		Name = "CounterTop",
		Size = Vector3.new(14.8, 0.5, 4.2),
		Position = position + Vector3.new(0, 3.75, 0),
		Color = Color3.fromRGB(150, 108, 72),
		Parent = model,
	})

	local frontZ = position.Z + front * 2
	local backZ = position.Z - front * 5
	for _, x in { -7, 7 } do
		for _, z in { frontZ, backZ } do
			Build.part({
				Name = "Post",
				Size = Vector3.new(0.9, 10, 0.9),
				Position = Vector3.new(position.X + x, 5, z),
				Color = FENCE,
				Parent = model,
			})
		end
	end
	Build.part({
		Name = "BackWall",
		Size = Vector3.new(14, 9, 0.8),
		Position = Vector3.new(position.X, 4.5, backZ),
		Color = Color3.fromRGB(150, 108, 72),
		Parent = model,
	})

	-- Striped awning sloping down toward the front.
	local stripes = 8
	local stripeWidth = 15.6 / stripes
	for i = 0, stripes - 1 do
		local x = position.X - 7.8 + stripeWidth * (i + 0.5)
		local stripeColor = if i % 2 == 0 then color else WHITE
		local back = Vector3.new(x, 11.4, backZ - front * 0.8)
		local edge = Vector3.new(x, 9.2, frontZ + front * 1.6)
		Build.beam(model, back, edge, stripeWidth, 0.4, stripeColor)
		-- Hanging flap along the front edge.
		Build.part({
			Name = "Flap",
			Size = Vector3.new(stripeWidth, 1, 0.3),
			Position = edge - Vector3.new(0, 0.6, 0),
			Color = stripeColor,
			Parent = model,
		})
	end

	Build.billboard(counter, signText, 12, 260, 160)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = signText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.Parent = parent
	return model, prompt
end

-- Two-tier fountain topped with a bao, spraying water.
local function buildFountain(parent: Instance, ground: Vector3)
	local model = Instance.new("Model")
	model.Name = "Fountain"
	local stone = Color3.fromRGB(200, 200, 205)
	local water = Color3.fromRGB(80, 170, 255)
	Build.column(model, ground, 1.6, 14, stone)
	Build.column(model, ground + Vector3.new(0, 1.6, 0), 0.1, 12.6, water, { Transparency = 0.15, Reflectance = 0.2 })
	Build.column(model, ground, 5, 1.8, stone)
	Build.column(model, ground + Vector3.new(0, 5, 0), 0.8, 6.5, stone)
	Build.column(model, ground + Vector3.new(0, 5.8, 0), 0.1, 5.6, water, { Transparency = 0.15, Reflectance = 0.2 })
	local mascot = SquishyModels.statue(
		model,
		ground + Vector3.new(0, 5.8, 0),
		3.4,
		Color3.fromRGB(255, 220, 232),
		Vector3.new(0, 6, 40)
	)

	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(190, 235, 255), Color3.fromRGB(255, 255, 255))
	spray.LightEmission = 0.4
	spray.Size = NumberSequence.new(0.4, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 0.8)
	spray.Speed = NumberRange.new(10, 13)
	spray.Acceleration = Vector3.new(0, -24, 0)
	spray.SpreadAngle = Vector2.new(22, 22)
	spray.Lifetime = NumberRange.new(0.9, 1.2)
	spray.Rate = 45
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = mascot:FindFirstChild("Body")
	model.Parent = parent
end

local function buildPlaza(map: Instance)
	-- Dirt ring with grass inside, like Grow a Garden's middle circle.
	Build.column(map, Vector3.new(0, 0, 0), 0.3, 40, DIRT)
	Build.column(map, Vector3.new(0, 0, 0), 0.4, 35, Color3.fromRGB(110, 196, 92))
	buildFountain(map, Vector3.new(0, 0.4, 0))

	-- Benches facing the fountain.
	for _, degrees in { 45, 135, 225, 315 } do
		local angle = math.rad(degrees)
		local spot = Vector3.new(math.cos(angle) * 12, 0.4, math.sin(angle) * 12)
		local facing = CFrame.lookAt(spot, Vector3.new(0, 0.4, 0))
		local pieces: { { size: Vector3, offset: CFrame } } = {
			{ size = Vector3.new(5, 0.5, 1.6), offset = CFrame.new(0, 1.3, 0) }, -- seat
			{ size = Vector3.new(5, 1.6, 0.4), offset = CFrame.new(0, 2.2, 0.7) }, -- backrest
			{ size = Vector3.new(0.4, 1.1, 1.4), offset = CFrame.new(-2, 0.55, 0) }, -- legs
			{ size = Vector3.new(0.4, 1.1, 1.4), offset = CFrame.new(2, 0.55, 0) },
		}
		for _, piece in pieces do
			Build.part({
				Name = "Bench",
				Size = piece.size,
				CFrame = facing * piece.offset,
				Color = FENCE,
				Parent = map,
			})
		end
	end

	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Size = Vector3.new(8, 0.2, 4)
		spawn.Position = Vector3.new(0, 0.5, 11)
		spawn.Transparency = 1
		spawn.Parent = map
	end
end

function WorldService.Start()
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	-- Two columns of plots facing each other across the middle.
	local rows = math.ceil(Economy.PlotCount / 2)
	local plotX = CENTER_GAP / 2 + FENCE_MARGIN + PLOT_WIDTH / 2
	local rowStep = PLOT_DEPTH + FENCE_MARGIN * 2 + PLOT_SPACING
	for index = 1, Economy.PlotCount do
		local side = if index % 2 == 1 then -1 else 1
		local row = math.ceil(index / 2)
		local z = (row - (rows + 1) / 2) * rowStep
		table.insert(plots, buildPlot(plotsFolder, index, Vector3.new(side * plotX, 0, z), -side))
	end

	buildPlaza(map)

	-- Seed Shop north of the fountain, Squishy Buyer south; both face it.
	local _, shopPrompt =
		buildStall(map, "SeedShop", Vector3.new(0, 0, -STAND_Z), 1, Color3.fromRGB(230, 70, 90), "Seed Shop", "Browse")
	-- The client opens the shop UI when this prompt fires.
	shopPrompt:SetAttribute("OpensShop", true)

	local _, prompt = buildStall(
		map,
		"SellStand",
		Vector3.new(0, 0, STAND_Z),
		-1,
		Color3.fromRGB(60, 170, 90),
		"Squishy Buyer",
		"Sell All"
	)
	sellPrompt = prompt

	-- Travel buttons drop players a few studs in front of each stall.
	local arriveZ = STAND_Z - 9
	arrivals.Shop = CFrame.lookAt(Vector3.new(0, 3, -arriveZ), Vector3.new(0, 3, -STAND_Z))
	arrivals.Sell = CFrame.lookAt(Vector3.new(0, 3, arriveZ), Vector3.new(0, 3, STAND_Z))

	-- Keep trees and decorations off the plots and the middle.
	local halfWidth = plotX + PLOT_WIDTH / 2 + FENCE_MARGIN + 8
	local halfDepth = (rows / 2) * rowStep + 8
	Scenery.build(map, {
		keepClear = {
			{ center = Vector3.zero, size = Vector3.new(halfWidth * 2, 0, halfDepth * 2) },
		},
		pondCenter = Vector3.new(0, 0, -(halfDepth + 45)),
	})
end

function WorldService.GetPlots(): { Model }
	return plots
end

function WorldService.GetSellPrompt(): ProximityPrompt
	return sellPrompt
end

function WorldService.GetArrival(destination: string): CFrame?
	return arrivals[destination]
end

return WorldService

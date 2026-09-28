--!strict
-- Builds the map at server start: the candy-colored path, player plots with
-- planter beds and picket fences, the Seed Shop and Squishy Buyer stalls, and
-- (via World/Scenery) terrain, lighting and decorations.
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

local TILE_SIZE = 6
local TILE_GAP = 1
local TILE_STEP = TILE_SIZE + TILE_GAP
local PLOT_PADDING = 3
local PATH_WIDTH = 24
local PLOT_SPACING = 12
local GATE_WIDTH = 10

local PLOT_WIDTH = Economy.PlotColumns * TILE_STEP - TILE_GAP + PLOT_PADDING * 2
local PLOT_DEPTH = Economy.PlotRows * TILE_STEP - TILE_GAP + PLOT_PADDING * 2
local PATH_HALF_LENGTH = (PLOT_DEPTH * 3 + PLOT_SPACING * 4) / 2
local STAND_Z = (PLOT_DEPTH + PLOT_SPACING) / 2

local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 205, 60)
local SOIL = Color3.fromRGB(110, 75, 55)
local PATH_COLOR = Color3.fromRGB(255, 212, 228)
-- One accent per plot, used for its fence rails, frame and sign.
local PLOT_ACCENTS = {
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(130, 220, 180),
	Color3.fromRGB(185, 160, 255),
	Color3.fromRGB(255, 190, 130),
	Color3.fromRGB(130, 195, 255),
	Color3.fromRGB(255, 225, 110),
}

local WorldService = {}

local plots: { Model } = {}
local sellPrompt: ProximityPrompt
-- Where the travel buttons drop players, keyed by destination name.
local arrivals: { [string]: CFrame } = {}

-- Picket fence from `from` to `to`, both at ground level.
local function fence(parent: Instance, from: Vector3, to: Vector3, accent: Color3)
	local length = (to - from).Magnitude
	local gaps = math.max(1, math.floor(length / 2.5))
	for i = 0, gaps do
		Build.part({
			Name = "Picket",
			Size = Vector3.new(0.5, 2.6, 0.5),
			Position = from:Lerp(to, i / gaps) + Vector3.new(0, 1.3, 0),
			Color = WHITE,
			Parent = parent,
		})
	end
	for _, height in { 0.9, 1.9 } do
		local lift = Vector3.new(0, height, 0)
		Build.beam(parent, from + lift, to + lift, 0.25, 0.3, accent)
	end
end

local function buildPlot(parent: Instance, index: number, center: Vector3, facingPath: number): Model
	local accent = PLOT_ACCENTS[(index - 1) % #PLOT_ACCENTS + 1]
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("PlotIndex", index)
	-- Direction from the plot toward the path; squishies face this way.
	plot:SetAttribute("Facing", Vector3.new(facingPath, 0, 0))

	local base = Build.part({
		Name = "Base",
		Size = Vector3.new(PLOT_WIDTH, 1, PLOT_DEPTH),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(120, 200, 105),
		Material = Enum.Material.Grass,
		Parent = plot,
	})
	plot.PrimaryPart = base
	local top = center + Vector3.new(0, 1, 0)

	local decor = Instance.new("Model")
	decor.Name = "Decor"
	decor.Parent = plot

	-- Planter bed: dark soil under the tiles with a wooden frame around it.
	local bedWidth = Economy.PlotColumns * TILE_STEP + 0.4
	local bedDepth = Economy.PlotRows * TILE_STEP + 0.4
	local frameColor = Build.tint(accent, 0.35)
	Build.part({
		Name = "Soil",
		Size = Vector3.new(bedWidth, 0.2, bedDepth),
		Position = top + Vector3.new(0, 0.1, 0),
		Color = SOIL,
		Material = Enum.Material.Ground,
		Parent = decor,
	})
	for _, side in { -1, 1 } do
		Build.part({
			Name = "Frame",
			Size = Vector3.new(bedWidth + 1.6, 0.6, 0.8),
			Position = top + Vector3.new(0, 0.3, side * (bedDepth / 2 + 0.4)),
			Color = frameColor,
			Material = Enum.Material.Wood,
			Parent = decor,
		})
		Build.part({
			Name = "Frame",
			Size = Vector3.new(0.8, 0.6, bedDepth),
			Position = top + Vector3.new(side * (bedWidth / 2 + 0.4), 0.3, 0),
			Color = frameColor,
			Material = Enum.Material.Wood,
			Parent = decor,
		})
	end

	local tiles = Instance.new("Folder")
	tiles.Name = "Tiles"
	tiles.Parent = plot
	local originX = center.X - PLOT_WIDTH / 2 + PLOT_PADDING + TILE_SIZE / 2
	local originZ = center.Z - PLOT_DEPTH / 2 + PLOT_PADDING + TILE_SIZE / 2
	for row = 1, Economy.PlotRows do
		for column = 1, Economy.PlotColumns do
			local tileIndex = (row - 1) * Economy.PlotColumns + column
			local tile = Build.part({
				Name = tostring(tileIndex),
				Size = Vector3.new(TILE_SIZE, 0.4, TILE_SIZE),
				Position = Vector3.new(originX + (column - 1) * TILE_STEP, 1.2, originZ + (row - 1) * TILE_STEP),
				-- Checkerboard shading so individual tiles are easy to see.
				Color = if (row + column) % 2 == 0 then Color3.fromRGB(150, 100, 70) else Color3.fromRGB(135, 90, 62),
				Material = Enum.Material.Ground,
				Parent = tiles,
			})
			tile:SetAttribute("TileIndex", tileIndex)
		end
	end

	local plants = Instance.new("Folder")
	plants.Name = "Plants"
	plants.Parent = plot

	-- Fence around the plot with a gate on the path side.
	local hx = PLOT_WIDTH / 2 - 0.5
	local hz = PLOT_DEPTH / 2 - 0.5
	local frontX = center.X + facingPath * hx
	local backX = center.X - facingPath * hx
	local y = top.Y
	local gateHalf = GATE_WIDTH / 2
	fence(decor, Vector3.new(backX, y, center.Z - hz), Vector3.new(backX, y, center.Z + hz), accent)
	fence(decor, Vector3.new(backX, y, center.Z - hz), Vector3.new(frontX, y, center.Z - hz), accent)
	fence(decor, Vector3.new(backX, y, center.Z + hz), Vector3.new(frontX, y, center.Z + hz), accent)
	fence(decor, Vector3.new(frontX, y, center.Z - hz), Vector3.new(frontX, y, center.Z - gateHalf), accent)
	fence(decor, Vector3.new(frontX, y, center.Z + gateHalf), Vector3.new(frontX, y, center.Z + hz), accent)
	for _, side in { -1, 1 } do
		local gatePost = Vector3.new(frontX, y, center.Z + side * gateHalf)
		Build.column(decor, gatePost, 4, 0.9, WHITE)
		Build.ball(decor, gatePost + Vector3.new(0, 4.4, 0), 1.6, accent, { CanCollide = true })
	end

	-- Bushes in the back corners.
	for _, side in { -1, 1 } do
		local corner = Vector3.new(backX + facingPath * 2.2, y, center.Z + side * (hz - 2.2))
		Build.ball(decor, corner + Vector3.new(0, 1, 0), 3.2, Color3.fromRGB(110, 190, 110), { CanCollide = true })
		Build.ball(decor, corner + Vector3.new(0.6, 1.6, 0.4), 1.2, accent)
	end

	-- Walkway from the path to the gate.
	Build.part({
		Name = "Walkway",
		Size = Vector3.new(4.4, 0.4, GATE_WIDTH),
		Position = Vector3.new(center.X + facingPath * (PLOT_WIDTH / 2 + 2), 0.2, center.Z),
		Color = PATH_COLOR,
		Material = Enum.Material.Cobblestone,
		Parent = decor,
	})

	-- Where the owner appears, just inside the gate.
	Build.part({
		Name = "SpawnPoint",
		Size = Vector3.new(2, 1, 2),
		Position = Vector3.new(frontX - facingPath * 2.5, 1.5, center.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = plot,
	})

	-- Name sign beside the gate. PlotService writes the owner's name into it.
	local signBase = Vector3.new(frontX, y, center.Z - gateHalf - 3)
	Build.column(decor, signBase, 5, 0.5, WHITE)
	local board = Build.part({
		Name = "SignPost",
		Size = Vector3.new(0.4, 2.4, 6),
		Position = signBase + Vector3.new(0, 5.6, 0),
		Color = accent,
		Material = Enum.Material.Wood,
		Parent = plot,
	})
	Build.billboard(board, "Empty Plot", 2.8)

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
		Size = Vector3.new(12, 3.5, 3),
		Position = position + Vector3.new(0, 1.75, 0),
		Color = color,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	Build.part({
		Name = "CounterTop",
		Size = Vector3.new(12.8, 0.4, 3.8),
		Position = position + Vector3.new(0, 3.7, 0),
		Color = WHITE,
		Parent = model,
	})

	local frontZ = position.Z + front * 1.8
	local backZ = position.Z - front * 4.5
	for _, x in { -6, 6 } do
		for _, z in { frontZ, backZ } do
			Build.column(model, Vector3.new(position.X + x, 0, z), 9.5, 0.7, WHITE)
		end
	end
	Build.part({
		Name = "BackWall",
		Size = Vector3.new(12, 8, 0.6),
		Position = Vector3.new(position.X, 4, backZ),
		Color = Build.tint(color, 0.55),
		Material = Enum.Material.Wood,
		Parent = model,
	})

	-- Striped awning sloping down toward the front, with a scalloped edge.
	local stripes = 8
	local stripeWidth = 13.6 / stripes
	for i = 0, stripes - 1 do
		local x = position.X - 6.8 + stripeWidth * (i + 0.5)
		local stripeColor = if i % 2 == 0 then color else WHITE
		local back = Vector3.new(x, 10.6, backZ - front * 0.6)
		local edge = Vector3.new(x, 8.6, frontZ + front * 1.4)
		Build.beam(model, back, edge, stripeWidth, 0.35, stripeColor)
		Build.ball(model, edge - Vector3.new(0, 0.3, 0), stripeWidth, stripeColor)
	end

	Build.billboard(counter, signText, 11)

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

local function buildPathAndPlaza(map: Instance)
	Build.part({
		Name = "Path",
		Size = Vector3.new(PATH_WIDTH, 0.4, PATH_HALF_LENGTH * 2),
		Position = Vector3.new(0, 0.2, 0),
		Color = PATH_COLOR,
		Material = Enum.Material.Cobblestone,
		Parent = map,
	})
	for _, side in { -1, 1 } do
		Build.part({
			Name = "Curb",
			Size = Vector3.new(0.8, 0.6, PATH_HALF_LENGTH * 2),
			Position = Vector3.new(side * (PATH_WIDTH / 2 + 0.4), 0.3, 0),
			Color = WHITE,
			Parent = map,
		})
	end

	-- Round spawn plaza in the middle of the path.
	Build.column(map, Vector3.new(0, 0.3, 0), 0.25, 17, WHITE)
	Build.column(map, Vector3.new(0, 0.3, 0), 0.35, 13, Color3.fromRGB(255, 170, 210))
	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Size = Vector3.new(8, 0.2, 8)
		spawn.Position = Vector3.new(0, 0.7, 0)
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

	-- Plots alternate left/right of the path, front to back.
	local rows = math.ceil(Economy.PlotCount / 2)
	local gateZ = {}
	for index = 1, Economy.PlotCount do
		local side = if index % 2 == 1 then -1 else 1
		local row = math.ceil(index / 2)
		local x = side * (PATH_WIDTH / 2 + PLOT_WIDTH / 2 + 4)
		local z = (row - (rows + 1) / 2) * (PLOT_DEPTH + PLOT_SPACING)
		table.insert(plots, buildPlot(plotsFolder, index, Vector3.new(x, 0, z), -side))
		table.insert(gateZ, z)
	end

	buildPathAndPlaza(map)

	-- Seed Shop north of spawn, Squishy Buyer south; both open toward spawn.
	local shop, shopPrompt = buildStall(
		map,
		"SeedShop",
		Vector3.new(0, 0, -STAND_Z),
		1,
		Color3.fromRGB(255, 130, 190),
		"Seed Shop",
		"Browse"
	)
	-- The client opens the shop UI when this prompt fires.
	shopPrompt:SetAttribute("OpensShop", true)
	-- Mascot mochi on the roof, and seed "samples" on the counter.
	Build.squishy(shop, Vector3.new(0, 10.2, -STAND_Z - 1.5), 4.5, Color3.fromRGB(255, 200, 225), Vector3.zero)
	for i, x in { -4.5, -3, 3, 4.5 } do
		Build.ball(shop, Vector3.new(x, 4.5, -STAND_Z), 1.2, PLOT_ACCENTS[i])
	end

	local sell
	sell, sellPrompt = buildStall(
		map,
		"SellStand",
		Vector3.new(0, 0, STAND_Z),
		-1,
		Color3.fromRGB(255, 195, 70),
		"Squishy Buyer",
		"Sell All"
	)
	-- Giant gold coin on the roof facing the plaza, and coin stacks on the counter.
	Build.decor({
		Name = "Coin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 5, 5),
		CFrame = CFrame.new(0, 12.5, STAND_Z + 1.5) * CFrame.Angles(0, math.pi / 2, 0),
		Color = GOLD,
		Material = Enum.Material.Foil,
		Parent = sell,
	})
	for stack, x in { -4.5, 4.5 } do
		for level = 0, stack + 1 do
			Build.column(sell, Vector3.new(x, 3.9 + level * 0.3, STAND_Z), 0.3, 1.6, GOLD)
		end
	end

	-- Travel buttons drop players a few studs in front of each stall.
	local arriveZ = STAND_Z - 8
	arrivals.Shop = CFrame.lookAt(Vector3.new(0, 3, -arriveZ), Vector3.new(0, 3, -STAND_Z))
	arrivals.Sell = CFrame.lookAt(Vector3.new(0, 3, arriveZ), Vector3.new(0, 3, STAND_Z))

	-- Keep trees and flowers off the whole play area.
	local playWidth = (PATH_WIDTH / 2 + PLOT_WIDTH + 8) * 2
	Scenery.build(map, {
		pathWidth = PATH_WIDTH,
		pathHalfLength = PATH_HALF_LENGTH,
		keepClear = {
			{ center = Vector3.zero, size = Vector3.new(playWidth, 0, PATH_HALF_LENGTH * 2 + 16) },
		},
		gateZ = gateZ,
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

--!strict
-- Builds the placeholder map at server start: ground, a central path, player
-- plots with a tile grid, the Seed Shop, and the Sell stand.
--
-- When real art arrives, build the map in Studio instead, keep the same
-- instance names and attributes (Plots/PlotN/Tiles/<index>, SpawnPoint, the
-- two stands and their prompts), and delete the build* functions here.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)

local TILE_SIZE = 6
local TILE_GAP = 1
local TILE_STEP = TILE_SIZE + TILE_GAP
local PLOT_PADDING = 3
local PATH_WIDTH = 24
local PLOT_SPACING = 12

local PLOT_WIDTH = Economy.PlotColumns * TILE_STEP - TILE_GAP + PLOT_PADDING * 2
local PLOT_DEPTH = Economy.PlotRows * TILE_STEP - TILE_GAP + PLOT_PADDING * 2

local WorldService = {}

local plots: { Model } = {}
local sellPrompt: ProximityPrompt

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function billboard(parent: Instance, text: string, height: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(240, 60)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
end

local function buildGround(parent: Instance)
	-- Reuse the Baseplate from the default Studio template if there is one.
	if not Workspace:FindFirstChild("Baseplate") then
		part({
			Name = "Ground",
			Size = Vector3.new(600, 2, 600),
			Position = Vector3.new(0, -1, 0),
			Color = Color3.fromRGB(120, 200, 120),
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end
	part({
		Name = "Path",
		Size = Vector3.new(PATH_WIDTH, 0.2, PLOT_DEPTH * 3 + PLOT_SPACING * 4),
		Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(250, 225, 235),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = Vector3.new(0, 0.5, 0)
		spawn.Color = Color3.fromRGB(255, 200, 230)
		spawn.Parent = parent
	end
end

local function buildPlot(parent: Instance, index: number, center: Vector3, facingPath: number): Model
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("PlotIndex", index)

	local base = part({
		Name = "Base",
		Size = Vector3.new(PLOT_WIDTH, 1, PLOT_DEPTH),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(95, 175, 95),
		Material = Enum.Material.Grass,
		Parent = plot,
	})
	plot.PrimaryPart = base

	local tiles = Instance.new("Folder")
	tiles.Name = "Tiles"
	tiles.Parent = plot
	local originX = center.X - PLOT_WIDTH / 2 + PLOT_PADDING + TILE_SIZE / 2
	local originZ = center.Z - PLOT_DEPTH / 2 + PLOT_PADDING + TILE_SIZE / 2
	for row = 1, Economy.PlotRows do
		for column = 1, Economy.PlotColumns do
			local tileIndex = (row - 1) * Economy.PlotColumns + column
			local tile = part({
				Name = tostring(tileIndex),
				Size = Vector3.new(TILE_SIZE, 0.4, TILE_SIZE),
				Position = Vector3.new(originX + (column - 1) * TILE_STEP, 1.2, originZ + (row - 1) * TILE_STEP),
				Color = Color3.fromRGB(125, 85, 60),
				Material = Enum.Material.Ground,
				Parent = tiles,
			})
			tile:SetAttribute("TileIndex", tileIndex)
		end
	end

	local plants = Instance.new("Folder")
	plants.Name = "Plants"
	plants.Parent = plot

	-- Edge of the plot nearest the path: where the owner spawns and the sign stands.
	local edgeX = center.X + facingPath * (PLOT_WIDTH / 2 - 1)
	part({
		Name = "SpawnPoint",
		Size = Vector3.new(2, 1, 2),
		Position = Vector3.new(edgeX, 1.5, center.Z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = plot,
	})
	local post = part({
		Name = "SignPost",
		Size = Vector3.new(1, 8, 1),
		Position = Vector3.new(edgeX, 5, center.Z - PLOT_DEPTH / 2 + 2),
		Color = Color3.fromRGB(255, 255, 255),
		Parent = plot,
	})
	billboard(post, "Empty Plot", 5)

	plot.Parent = parent
	return plot
end

local function buildStand(
	parent: Instance,
	name: string,
	position: Vector3,
	color: Color3,
	signText: string,
	actionText: string
): ProximityPrompt
	local model = Instance.new("Model")
	model.Name = name
	local counter = part({
		Name = "Counter",
		Size = Vector3.new(12, 4, 4),
		Position = position + Vector3.new(0, 2, 0),
		Color = color,
		Parent = model,
	})
	part({
		Name = "Roof",
		Size = Vector3.new(14, 1, 7),
		Position = position + Vector3.new(0, 9, -1.5),
		Color = Color3.fromRGB(255, 255, 255),
		Parent = model,
	})
	billboard(counter, signText, 9)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = signText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.Parent = parent
	return prompt
end

function WorldService.Start()
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = Workspace
	buildGround(map)

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	-- Plots alternate left/right of the path, front to back.
	local rows = math.ceil(Economy.PlotCount / 2)
	for index = 1, Economy.PlotCount do
		local side = if index % 2 == 1 then -1 else 1
		local row = math.ceil(index / 2)
		local x = side * (PATH_WIDTH / 2 + PLOT_WIDTH / 2 + 4)
		local z = (row - (rows + 1) / 2) * (PLOT_DEPTH + PLOT_SPACING)
		table.insert(plots, buildPlot(plotsFolder, index, Vector3.new(x, 0, z), -side))
	end

	local shopPrompt = buildStand(
		map,
		"SeedShop",
		Vector3.new(0, 0, -(PLOT_DEPTH + PLOT_SPACING) / 2),
		Color3.fromRGB(255, 150, 200),
		"Seed Shop",
		"Browse"
	)
	-- The client opens the shop UI when this prompt fires.
	shopPrompt:SetAttribute("OpensShop", true)

	sellPrompt = buildStand(
		map,
		"SellStand",
		Vector3.new(0, 0, (PLOT_DEPTH + PLOT_SPACING) / 2),
		Color3.fromRGB(255, 210, 90),
		"Squishy Buyer",
		"Sell All"
	)
end

function WorldService.GetPlots(): { Model }
	return plots
end

function WorldService.GetSellPrompt(): ProximityPrompt
	return sellPrompt
end

return WorldService

--!strict
-- Planting, harvesting, removing, and mutating squishies. The server is
-- authoritative: growth is just timestamps in saved data, so plants keep
-- growing while the player is offline and the client can never speed them up.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Growth = require(Shared.Growth)
local Mutations = require(Shared.Config.Mutations)
local Remotes = require(Shared.Remotes)
local Squishies = require(Shared.Config.Squishies)
local Types = require(Shared.Types)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RateLimit = require(script.Parent.Parent.RateLimit)
local SquishyModels = require(script.Parent.Parent.World.SquishyModels)
local Sync = require(script.Parent.Parent.Sync)

-- Tag the client uses to find plants to animate.
local PLANT_TAG = "SquishyPlant"
-- Full-grown width in studs.
local FULL_SIZE = 4
local TILE_COUNT = Economy.PlotColumns * Economy.PlotRows
-- Harvests worth at least this multiplier are announced to the whole server.
local ANNOUNCE_MULTIPLIER = 15

local GardenService = {}

local random = Random.new()
local plotLimit = RateLimit.new(8, 12)

local function roll(): number
	return random:NextNumber()
end

local function validTileIndex(value: unknown): number?
	if type(value) == "number" and value == math.floor(value) and value >= 1 and value <= TILE_COUNT then
		return value
	end
	return nil
end

local function plantModel(plot: Model, key: string): Model?
	return (plot :: any).Plants:FindFirstChild(key)
end

-- Copies the parts of the plant record the client needs onto its model.
local function applyPlantState(model: Model, plant: Types.Plant)
	model:SetAttribute("StartedAt", plant.startedAt)
	model:SetAttribute("ReadyAt", plant.readyAt)
	model:SetAttribute("Mutations", if plant.mutations then table.concat(plant.mutations, ",") else "")
end

-- "Gold Mochi Bao" / "Mochi Bao"
local function displayName(def: Squishies.SquishyDef, mutations: { string }?): string
	local prefix = Mutations.names(mutations)
	return if prefix == "" then def.name else prefix .. " " .. def.name
end

function GardenService.Harvest(player: Player, key: string)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	local plant = data and data.plants[key]
	if not data or not plot or not plant then
		return
	end
	local def = Squishies.ById[plant.id]
	local now = os.time()
	if not def or not Growth.isReady(plant.readyAt, now) then
		return
	end
	if #data.backpack >= Economy.BackpackCapacity then
		Sync.notify(player, "Backpack full! Sell your squishies at the Squishy Buyer.")
		Sync.sfx(player, "Error")
		return
	end

	local size = Growth.sizeFromRoll(roll())
	local mutations = plant.mutations
	table.insert(data.backpack, { id = plant.id, size = size, mutations = mutations })
	data.stats.harvested += 1

	local model = plantModel(plot, key)
	if def.regrowTime then
		-- Each regrowth is a fresh squishy with its own chance to mutate.
		plant.startedAt = now
		plant.readyAt = now + def.regrowTime
		plant.mutations = Mutations.rollBase(roll)
		if model then
			applyPlantState(model, plant)
		end
	else
		data.plants[key] = nil
		if model then
			model:Destroy()
		end
	end

	local name = displayName(def, mutations)
	Sync.notify(player, string.format("Harvested %s (%.2fx)", name, size))
	Sync.sfx(player, "Squish")
	if Mutations.multiplier(mutations) >= 5 then
		Sync.sfx(player, "Sparkle")
	end
	if Mutations.multiplier(mutations) >= ANNOUNCE_MULTIPLIER then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				Sync.notify(other, `{player.DisplayName} harvested a {name}!`)
			end
		end
	end
	Sync.push(player)
end

local function spawnPlant(player: Player, plot: Model, key: string, plant: Types.Plant)
	local def = Squishies.ById[plant.id]
	local tileIndex = tonumber(key) :: number
	local tile = PlotService.GetTile(plot, tileIndex)
	if not def or not tile then
		warn(`[GardenService] skipping unknown plant {plant.id} on tile {key}`)
		return
	end

	local anchor = tile.Position + Vector3.new(0, tile.Size.Y / 2, 0)
	local facing = plot:GetAttribute("Facing")
	local direction = if typeof(facing) == "Vector3" then facing else Vector3.new(0, 0, -1)

	-- Built at full size; each client scales it down to the current growth.
	local model = SquishyModels.create(def, tileIndex, FULL_SIZE)
	model.Name = key
	model:PivotTo(CFrame.lookAt(anchor, anchor + direction))
	model:SetAttribute("SquishyId", def.id)
	model:SetAttribute("TileIndex", tileIndex)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BaseColor", Color3.fromRGB(def.color[1], def.color[2], def.color[3]))
	applyPlantState(model, plant)
	local root = model.PrimaryPart :: BasePart
	local body = model:FindFirstChild("Body") :: BasePart

	-- Sparkles while ready; the client switches them on and off.
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "ReadySparkles"
	sparkles.Enabled = false
	sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), body.Color)
	sparkles.LightEmission = 0.8
	sparkles.Rate = 4
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(1, 2.5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(0.35, 0)
	sparkles.Parent = body

	local info = Instance.new("BillboardGui")
	info.Name = "Info"
	info.Size = UDim2.fromOffset(170, 48)
	-- The client moves this up as the plant grows.
	info.StudsOffsetWorldSpace = Vector3.new(0, FULL_SIZE + 1.5, 0)
	info.MaxDistance = 60
	info.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.RichText = true
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = def.name
	label.Parent = info
	info.Parent = root

	-- The client hides this prompt unless the plant is ready and owned by the
	-- local player; the server re-checks both on trigger regardless.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Harvest"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(who)
		if who == player then
			GardenService.Harvest(player, key)
		end
	end)
	prompt.Parent = root

	CollectionService:AddTag(model, PLANT_TAG)
	model.Parent = (plot :: any).Plants
end

-- Adds a mutation to a planted squishy. Returns true if it was new.
function GardenService.AddMutation(player: Player, key: string, mutationId: string): boolean
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	local plant = data and data.plants[key]
	if not plant or not plot then
		return false
	end
	local updated, changed = Mutations.add(plant.mutations, mutationId)
	if changed then
		plant.mutations = updated
		local model = plantModel(plot, key)
		if model then
			applyPlantState(model, plant)
		end
	end
	return changed
end

-- Calls fn for every planted squishy of every player with a plot.
function GardenService.ForEachPlant(fn: (player: Player, key: string, plant: Types.Plant, model: Model?) -> ())
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		local plot = PlotService.GetPlot(player)
		if data and plot then
			for key, plant in data.plants do
				fn(player, key, plant, plantModel(plot, key))
			end
		end
	end
end

local function onPlantSeed(player: Player, rawTile: unknown, rawId: unknown)
	if not plotLimit:allow(player) then
		return
	end
	local tileIndex = validTileIndex(rawTile)
	local def = type(rawId) == "string" and Squishies.ById[rawId] or nil
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not tileIndex or not def or not data or not plot then
		return
	end

	local key = tostring(tileIndex)
	if data.plants[key] then
		return
	end
	local owned = data.seeds[def.id] or 0
	if owned < 1 then
		Sync.notify(player, "You're out of " .. def.name .. " seeds!")
		Sync.sfx(player, "Error")
		return
	end

	if owned > 1 then
		data.seeds[def.id] = owned - 1
	else
		data.seeds[def.id] = nil
	end
	local now = os.time()
	local plant: Types.Plant = {
		id = def.id,
		startedAt = now,
		readyAt = now + def.growTime,
		mutations = Mutations.rollBase(roll),
	}
	data.plants[key] = plant
	spawnPlant(player, plot, key, plant)
	Sync.sfx(player, "Pop")
	Sync.push(player)
end

local function onRemovePlant(player: Player, rawTile: unknown)
	if not plotLimit:allow(player) then
		return
	end
	local tileIndex = validTileIndex(rawTile)
	local data = DataService.Get(player)
	local plot = PlotService.GetPlot(player)
	if not tileIndex or not data or not plot then
		return
	end
	local key = tostring(tileIndex)
	local plant = data.plants[key]
	if not plant then
		return
	end
	data.plants[key] = nil
	local model = plantModel(plot, key)
	if model then
		model:Destroy()
	end
	local def = Squishies.ById[plant.id]
	Sync.notify(player, "Dug up " .. (if def then displayName(def, plant.mutations) else "a squishy"))
	Sync.sfx(player, "Dig")
end

function GardenService.Start()
	PlotService.PlotAssigned:Connect(function(player, plot)
		local data = DataService.Get(player)
		if not data then
			return
		end
		for key, plant in data.plants do
			spawnPlant(player, plot, key, plant)
		end
		Sync.push(player)
	end)

	Remotes.PlantSeed.OnServerEvent:Connect(onPlantSeed)
	Remotes.RemovePlant.OnServerEvent:Connect(onRemovePlant)
end

return GardenService

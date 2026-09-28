--!strict
-- Planting, harvesting, and removing squishies. The server is authoritative:
-- growth is just timestamps in saved data, so plants keep growing while the
-- player is offline and the client can never speed them up.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Growth = require(Shared.Growth)
local Remotes = require(Shared.Remotes)
local Squishies = require(Shared.Config.Squishies)
local Types = require(Shared.Types)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RateLimit = require(script.Parent.Parent.RateLimit)
local Sync = require(script.Parent.Parent.Sync)

-- Tag the client uses to find plants to animate.
local PLANT_TAG = "SquishyPlant"
-- Full-grown placeholder size in studs.
local FULL_SIZE = 3.5
local TILE_COUNT = Economy.PlotColumns * Economy.PlotRows

local GardenService = {}

local sizeRandom = Random.new()
local plotLimit = RateLimit.new(8, 12)

local function validTileIndex(value: unknown): number?
	if type(value) == "number" and value == math.floor(value) and value >= 1 and value <= TILE_COUNT then
		return value
	end
	return nil
end

local function plantPart(plot: Model, key: string): BasePart?
	return (plot :: any).Plants:FindFirstChild(key)
end

local function applyTimes(part: BasePart, plant: Types.Plant)
	part:SetAttribute("StartedAt", plant.startedAt)
	part:SetAttribute("ReadyAt", plant.readyAt)
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
		return
	end

	local size = Growth.sizeFromRoll(sizeRandom:NextNumber())
	table.insert(data.backpack, { id = plant.id, size = size })
	data.stats.harvested += 1

	local part = plantPart(plot, key)
	if def.regrowTime then
		plant.startedAt = now
		plant.readyAt = now + def.regrowTime
		if part then
			applyTimes(part, plant)
		end
	else
		data.plants[key] = nil
		if part then
			part:Destroy()
		end
	end

	Sync.notify(player, string.format("Harvested %s (%.2fx)", def.name, size))
	Sync.push(player)
end

local function spawnPlant(player: Player, plot: Model, key: string, plant: Types.Plant)
	local def = Squishies.ById[plant.id]
	local tile = PlotService.GetTile(plot, tonumber(key) :: number)
	if not def or not tile then
		warn(`[GardenService] skipping unknown plant {plant.id} on tile {key}`)
		return
	end

	local anchor = tile.Position + Vector3.new(0, tile.Size.Y / 2, 0)
	local seedling = FULL_SIZE * 0.25

	local part = Instance.new("Part")
	part.Name = key
	part.Shape = (Enum.PartType :: any)[def.shape]
	part.Size = Vector3.one * seedling
	part.CFrame = CFrame.new(anchor + Vector3.new(0, seedling / 2, 0))
		-- Cylinders point along X by default; stand them upright.
		* (if def.shape == "Cylinder" then CFrame.Angles(0, 0, math.pi / 2) else CFrame.identity)
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
	part.Material = (Enum.Material :: any)[def.material]
	part:SetAttribute("SquishyId", def.id)
	part:SetAttribute("TileIndex", tonumber(key))
	part:SetAttribute("OwnerUserId", player.UserId)
	part:SetAttribute("FullSize", FULL_SIZE)
	part:SetAttribute("Anchor", anchor)
	applyTimes(part, plant)

	local info = Instance.new("BillboardGui")
	info.Name = "Info"
	info.Size = UDim2.fromOffset(150, 36)
	info.ExtentsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	info.MaxDistance = 60
	info.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = def.name
	label.Parent = info
	info.Parent = part

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
	prompt.Parent = part

	CollectionService:AddTag(part, PLANT_TAG)
	part.Parent = (plot :: any).Plants
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
		return
	end

	if owned > 1 then
		data.seeds[def.id] = owned - 1
	else
		data.seeds[def.id] = nil
	end
	local now = os.time()
	local plant: Types.Plant = { id = def.id, startedAt = now, readyAt = now + def.growTime }
	data.plants[key] = plant
	spawnPlant(player, plot, key, plant)
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
	local part = plantPart(plot, key)
	if part then
		part:Destroy()
	end
	local def = Squishies.ById[plant.id]
	Sync.notify(player, "Dug up " .. (if def then def.name else "a squishy"))
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

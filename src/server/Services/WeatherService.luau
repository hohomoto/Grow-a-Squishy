--!strict
-- Runs the global weather schedule. While an event is active, plants can
-- gain its mutation; during Starfall, shooting stars strike random plants.
--
-- Current weather is published as Workspace attributes so clients can show
-- effects: Weather (event id, or "" when clear) and WeatherEndsAt.
-- In Studio, an event runs every couple of minutes and cycles through every
-- type, so playtests don't have to wait.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Mutations = require(Shared.Config.Mutations)
local Remotes = require(Shared.Remotes)
local Squishies = require(Shared.Config.Squishies)
local Weather = require(Shared.Config.Weather)
local WeatherSchedule = require(Shared.WeatherSchedule)
local GardenService = require(script.Parent.GardenService)
local Sync = require(script.Parent.Parent.Sync)

-- Owners get a message when a plant gains a mutation worth at least this.
local NOTIFY_MULTIPLIER = 5

local WeatherService = {}

local random = Random.new()

local function scheduleOptions(): WeatherSchedule.Options
	if RunService:IsStudio() then
		return {
			interval = Weather.StudioInterval,
			eventChance = 1,
			duration = Weather.StudioDuration,
			cycle = true,
		}
	end
	return { interval = Weather.Interval, eventChance = Weather.EventChance }
end

local function notifyAll(message: string)
	for _, player in Players:GetPlayers() do
		Sync.notify(player, message)
	end
end

local function tellOwner(player: Player, plantId: string, mutationId: string)
	local def = Squishies.ById[plantId]
	local mutation = Mutations.ById[mutationId]
	if def and mutation and mutation.multiplier >= NOTIFY_MULTIPLIER then
		Sync.notify(player, `Your {def.name} turned {mutation.name} (x{mutation.multiplier})!`)
		Sync.sfx(player, "Sparkle")
	end
end

local function starfallTick(def: Weather.WeatherDef)
	if random:NextNumber() >= (def.starChancePerTick or 0) then
		return
	end
	local targets = {}
	GardenService.ForEachPlant(function(player, key, plant, part)
		if part then
			table.insert(targets, { player = player, key = key, id = plant.id, part = part })
		end
	end)
	if #targets == 0 then
		return
	end
	local target = targets[random:NextInteger(1, #targets)]
	Remotes.StarStrike:FireAllClients(target.part.Position)
	-- Land the mutation as the star arrives on screen.
	task.delay(1.2, function()
		if GardenService.AddMutation(target.player, target.key, def.mutation) then
			tellOwner(target.player, target.id, def.mutation)
		end
	end)
end

local function mutationTick(def: Weather.WeatherDef)
	GardenService.ForEachPlant(function(player, key, plant)
		if random:NextNumber() < def.chancePerTick and GardenService.AddMutation(player, key, def.mutation) then
			tellOwner(player, plant.id, def.mutation)
		end
	end)
end

function WeatherService.Start()
	local options = scheduleOptions()
	local current = ""
	Workspace:SetAttribute("Weather", "")
	Workspace:SetAttribute("WeatherEndsAt", 0)

	task.spawn(function()
		while true do
			local event = WeatherSchedule.at(os.time(), options)
			local id = if event then event.def.id else ""
			if id ~= current then
				current = id
				Workspace:SetAttribute("Weather", id)
				Workspace:SetAttribute("WeatherEndsAt", if event then event.endsAt else 0)
				if event then
					notifyAll(event.def.message)
				else
					notifyAll("The weather cleared up.")
				end
			end
			if event then
				if event.def.starChancePerTick then
					starfallTick(event.def)
				else
					mutationTick(event.def)
				end
			end
			task.wait(Weather.TickInterval)
		end
	end)
end

return WeatherService

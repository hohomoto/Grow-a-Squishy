--!strict
-- Server-wide weather events. While one is active, every plant on the server
-- has a chance each tick to gain the event's mutation. Starfall is special:
-- instead of a per-plant chance, shooting stars strike random plants.
--
-- Events follow a global schedule (Shared/WeatherSchedule), so every server
-- gets the same weather at the same time.

export type WeatherDef = {
	id: string,
	name: string,
	mutation: string,
	-- Chance per plant per tick to gain the mutation.
	chancePerTick: number,
	-- Starfall only: chance per tick that a star strikes one random plant.
	starChancePerTick: number?,
	duration: number,
	-- Relative likelihood of this event being picked.
	weight: number,
	-- Screen tint while active.
	tint: { number },
	message: string,
}

local Weather = {}

-- Seconds between weather checks on the server.
Weather.TickInterval = 5

-- Live schedule: one window every 10 minutes, 60% chance of an event in it.
Weather.Interval = 600
Weather.EventChance = 0.6
-- Studio playtests: an event every 2 minutes, cycling through every type.
Weather.StudioInterval = 120
Weather.StudioDuration = 60

Weather.List = {
	{
		id = "SlimeRain",
		name = "Slime Rain",
		mutation = "Slimy",
		chancePerTick = 0.04,
		duration = 150,
		weight = 35,
		tint = { 225, 255, 215 },
		message = "Slime Rain! Squishies may turn Slimy (x3)",
	},
	{
		id = "FreezeSnap",
		name = "Freeze Snap",
		mutation = "Frozen",
		chancePerTick = 0.03,
		duration = 120,
		weight = 30,
		tint = { 215, 235, 255 },
		message = "Freeze Snap! Squishies may turn Frozen (x5)",
	},
	{
		id = "GlitterStorm",
		name = "Glitter Storm",
		mutation = "Glitter",
		chancePerTick = 0.06,
		duration = 120,
		weight = 25,
		tint = { 255, 225, 245 },
		message = "Glitter Storm! Squishies may turn Glitter (x2)",
	},
	{
		id = "Starfall",
		name = "Starfall",
		mutation = "Starstruck",
		chancePerTick = 0,
		starChancePerTick = 0.35,
		duration = 120,
		weight = 10,
		tint = { 205, 190, 255 },
		message = "STARFALL! Shooting stars make squishies Starstruck (x60)",
	},
} :: { WeatherDef }

Weather.ById = {} :: { [string]: WeatherDef }
for _, def in Weather.List do
	Weather.ById[def.id] = def
end

return Weather

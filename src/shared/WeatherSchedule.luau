--!strict
-- Deterministic weather timetable. Time is split into fixed windows; each
-- window may hold one event at a seeded offset. The same time always gives
-- the same answer, on every server.

local Rng = require(script.Parent.Rng)
local Weather = require(script.Parent.Config.Weather)

export type Event = {
	def: Weather.WeatherDef,
	startsAt: number,
	endsAt: number,
}

export type Options = {
	interval: number,
	eventChance: number,
	-- Overrides each event's duration (Studio uses short events).
	duration: number?,
	-- Cycle through event types in order instead of by weight (Studio).
	cycle: boolean?,
}

local WeatherSchedule = {}

-- Keeps weather rolls independent of the shop's rolls for the same window.
local SALT = 7919

local function pickWeighted(u: number): Weather.WeatherDef
	local total = 0
	for _, def in Weather.List do
		total += def.weight
	end
	local target = u * total
	for _, def in Weather.List do
		target -= def.weight
		if target < 0 then
			return def
		end
	end
	return Weather.List[#Weather.List]
end

-- The event scheduled in a given window, if any.
function WeatherSchedule.eventInWindow(window: number, options: Options): Event?
	local rng = Rng.new(window * SALT + 1)
	-- Always consume the same rolls so windows stay independent of each other.
	local happens = rng:next() < options.eventChance
	local typeRoll = rng:next()
	local offsetRoll = rng:next()
	if not happens then
		return nil
	end
	local def = if options.cycle then Weather.List[window % #Weather.List + 1] else pickWeighted(typeRoll)
	local duration = options.duration or def.duration
	-- Leave a gap at the end of the window so events never overlap.
	local latestStart = math.max(0, options.interval - duration - 10)
	local startsAt = window * options.interval + math.floor(offsetRoll * latestStart)
	return { def = def, startsAt = startsAt, endsAt = startsAt + duration }
end

-- The event active at `time`, if any.
function WeatherSchedule.at(time: number, options: Options): Event?
	local window = math.floor(time / options.interval)
	local event = WeatherSchedule.eventInWindow(window, options)
	if event and time >= event.startsAt and time < event.endsAt then
		return event
	end
	return nil
end

return WeatherSchedule

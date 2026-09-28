--!strict
-- Mutations are special variants of a plant that multiply its sell value.
--
-- Where they come from:
--   * `baseChance` mutations can appear on any plant when it starts growing.
--   * The rest only come from weather (see Config/Weather.luau).
--
-- Stacking is additive, so a Gold (x15) + Frozen (x5) plant is worth
-- 1 + 14 + 4 = x19, not x75. Mutations sharing a `group` are exclusive: a
-- plant keeps only the most valuable one (Rainbow replaces Gold, Huge
-- replaces Big).

export type MutationDef = {
	id: string,
	name: string,
	multiplier: number,
	color: { number },
	baseChance: number?,
	group: string?,
	-- Visual size multiplier on the plot (size mutations only).
	scale: number?,
}

local List: { MutationDef } = {
	-- Size mutations change how big the plant grows on the plot (`scale`).
	{
		id = "Mini",
		name = "Mini",
		multiplier = 1.5,
		color = { 255, 190, 235 },
		baseChance = 0.04,
		group = "Size",
		scale = 0.65,
	},
	{
		id = "Big",
		name = "Big",
		multiplier = 2,
		color = { 255, 175, 90 },
		baseChance = 0.06,
		group = "Size",
		scale = 1.35,
	},
	{
		id = "Huge",
		name = "Huge",
		multiplier = 4,
		color = { 255, 130, 70 },
		baseChance = 0.015,
		group = "Size",
		scale = 1.75,
	},
	{
		id = "Colossal",
		name = "Colossal",
		multiplier = 10,
		color = { 255, 80, 80 },
		baseChance = 0.003,
		group = "Size",
		scale = 2.5,
	},
	-- Special mutations.
	{ id = "Glitter", name = "Glitter", multiplier = 2, color = { 255, 170, 230 }, baseChance = 0.02 },
	{ id = "Slimy", name = "Slimy", multiplier = 3, color = { 120, 230, 90 } },
	{ id = "Frozen", name = "Frozen", multiplier = 5, color = { 150, 220, 255 } },
	{ id = "Gold", name = "Gold", multiplier = 15, color = { 255, 205, 60 }, baseChance = 0.005, group = "Tint" },
	{
		id = "Rainbow",
		name = "Rainbow",
		multiplier = 40,
		color = { 255, 120, 200 },
		baseChance = 0.001,
		group = "Tint",
	},
	{ id = "Starstruck", name = "Starstruck", multiplier = 60, color = { 190, 150, 255 } },
}

local ById: { [string]: MutationDef } = {}
for _, def in List do
	assert(ById[def.id] == nil, "duplicate mutation id: " .. def.id)
	ById[def.id] = def
end

local Mutations = {}

Mutations.List = List
Mutations.ById = ById

-- Total value multiplier for a set of mutations (1 when there are none).
function Mutations.multiplier(ids: { string }?): number
	local total = 1
	if ids then
		for _, id in ids do
			local def = ById[id]
			if def then
				total += def.multiplier - 1
			end
		end
	end
	return total
end

-- Returns a new list with `id` added, respecting groups, plus whether it
-- changed. Never mutates the input.
function Mutations.add(ids: { string }?, id: string): ({ string }, boolean)
	local def = ById[id]
	local result = if ids then table.clone(ids) else {}
	if not def or table.find(result, id) then
		return result, false
	end
	if def.group then
		for i = #result, 1, -1 do
			local other = ById[result[i]]
			if other and other.group == def.group then
				if other.multiplier >= def.multiplier then
					return result, false
				end
				table.remove(result, i)
			end
		end
	end
	table.insert(result, id)
	-- Keep a stable order (cheapest first) so saves and labels are consistent.
	table.sort(result, function(a, b)
		local ma = if ById[a] then ById[a].multiplier else 0
		local mb = if ById[b] then ById[b].multiplier else 0
		return ma < mb
	end)
	return result, true
end

-- Rolls the mutations a plant starts with. `random` returns floats in [0, 1).
-- Returns nil when there are none, to keep saved data small.
function Mutations.rollBase(random: () -> number): { string }?
	local result: { string }? = nil
	for _, def in List do
		if def.baseChance and random() < def.baseChance then
			result = (Mutations.add(result, def.id))
		end
	end
	return result
end

-- "Gold Frozen" style prefix for names; empty string when there are none.
function Mutations.names(ids: { string }?): string
	local names = {}
	if ids then
		for _, id in ids do
			local def = ById[id]
			if def then
				table.insert(names, def.name)
			end
		end
	end
	return table.concat(names, " ")
end

-- How much bigger (or smaller) the plant looks on the plot.
function Mutations.scale(ids: { string }?): number
	local scale = 1
	if ids then
		for _, id in ids do
			local def = ById[id]
			if def and def.scale then
				scale *= def.scale
			end
		end
	end
	return scale
end

-- The most valuable mutation in the list, for picking a highlight color.
function Mutations.top(ids: { string }?): MutationDef?
	local best: MutationDef? = nil
	if ids then
		for _, id in ids do
			local def = ById[id]
			if def and (not best or def.multiplier > best.multiplier) then
				best = def
			end
		end
	end
	return best
end

return Mutations

--!strict
-- The squishy catalog. Every plantable item lives here; the shop, growth, and
-- selling systems all read from this table, so balancing is a data-only change.
--
-- Fields:
--   id          Stable save key. NEVER rename once the game is live.
--   seedPrice   Coins per seed in the shop.
--   growTime    Seconds from planting to first harvest.
--   regrowTime  If set, the plant stays after harvest and is ready again after
--               this many seconds (multi-harvest). If nil, harvesting removes it.
--   baseValue   Sell price of a 1.00x-size harvest.
--   stockChance Probability (0-1) the item appears in a given shop restock.
--   stock       {min, max} units per player when it does appear.
--   shape/color/material  Placeholder visuals until real models exist.

export type SquishyDef = {
	id: string,
	name: string,
	rarity: string,
	seedPrice: number,
	growTime: number,
	regrowTime: number?,
	baseValue: number,
	stockChance: number,
	stock: { number },
	shape: "Ball" | "Block" | "Cylinder",
	color: { number },
	material: string,
}

local List: { SquishyDef } = {
	{
		id = "mochi",
		name = "Mochi Squishy",
		rarity = "Common",
		seedPrice = 10,
		growTime = 30,
		baseValue = 18,
		stockChance = 1,
		stock = { 10, 25 },
		shape = "Ball",
		color = { 255, 230, 235 },
		material = "SmoothPlastic",
	},
	{
		id = "stress_ball",
		name = "Stress Ball",
		rarity = "Common",
		seedPrice = 25,
		growTime = 45,
		baseValue = 40,
		stockChance = 1,
		stock = { 5, 15 },
		shape = "Ball",
		color = { 255, 120, 90 },
		material = "SmoothPlastic",
	},
	{
		id = "foam_bun",
		name = "Foam Bread Bun",
		rarity = "Uncommon",
		seedPrice = 80,
		growTime = 90,
		regrowTime = 40,
		baseValue = 28,
		stockChance = 0.85,
		stock = { 3, 8 },
		shape = "Block",
		color = { 230, 180, 110 },
		material = "SmoothPlastic",
	},
	{
		id = "butter_slime",
		name = "Butter Slime",
		rarity = "Uncommon",
		seedPrice = 150,
		growTime = 120,
		baseValue = 260,
		stockChance = 0.7,
		stock = { 2, 6 },
		shape = "Cylinder",
		color = { 255, 235, 140 },
		material = "Glass",
	},
	{
		id = "needle_ball",
		name = "Needle Ball",
		rarity = "Rare",
		seedPrice = 450,
		growTime = 180,
		regrowTime = 60,
		baseValue = 70,
		stockChance = 0.5,
		stock = { 1, 4 },
		shape = "Ball",
		color = { 120, 200, 255 },
		material = "Glass",
	},
	{
		id = "cloud_slime",
		name = "Cloud Slime",
		rarity = "Rare",
		seedPrice = 1000,
		growTime = 300,
		baseValue = 1700,
		stockChance = 0.4,
		stock = { 1, 3 },
		shape = "Cylinder",
		color = { 240, 245, 255 },
		material = "SmoothPlastic",
	},
	{
		id = "water_bead_blob",
		name = "Water Bead Blob",
		rarity = "Epic",
		seedPrice = 2500,
		growTime = 420,
		regrowTime = 90,
		baseValue = 230,
		stockChance = 0.25,
		stock = { 1, 2 },
		shape = "Ball",
		color = { 150, 110, 255 },
		material = "Glass",
	},
	{
		id = "kitty_squishy",
		name = "Kitty Squishy",
		rarity = "Epic",
		seedPrice = 6000,
		growTime = 600,
		regrowTime = 120,
		baseValue = 520,
		stockChance = 0.18,
		stock = { 1, 2 },
		shape = "Block",
		color = { 255, 170, 210 },
		material = "SmoothPlastic",
	},
	{
		id = "galaxy_slime",
		name = "Galaxy Slime",
		rarity = "Legendary",
		seedPrice = 20000,
		growTime = 900,
		regrowTime = 180,
		baseValue = 1400,
		stockChance = 0.1,
		stock = { 1, 1 },
		shape = "Cylinder",
		color = { 60, 30, 140 },
		material = "Glass",
	},
	{
		id = "jelly_dragon",
		name = "Jelly Dragon",
		rarity = "Mythic",
		seedPrice = 75000,
		growTime = 1500,
		regrowTime = 240,
		baseValue = 4200,
		stockChance = 0.05,
		stock = { 1, 1 },
		shape = "Block",
		color = { 255, 60, 100 },
		material = "Glass",
	},
	{
		id = "starlight_mochi",
		name = "Starlight Mochi",
		rarity = "Celestial",
		seedPrice = 300000,
		growTime = 2400,
		regrowTime = 300,
		baseValue = 15000,
		stockChance = 0.02,
		stock = { 1, 1 },
		shape = "Ball",
		color = { 180, 255, 250 },
		material = "Neon",
	},
}

local ById: { [string]: SquishyDef } = {}
for _, def in List do
	assert(ById[def.id] == nil, "duplicate squishy id: " .. def.id)
	ById[def.id] = def
end

return {
	List = List,
	ById = ById,
}

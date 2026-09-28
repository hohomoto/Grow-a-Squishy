--!strict
-- The plant catalog. Four families, each with its own look:
--   bao     round steamed-bun squishies with kawaii faces
--   cube    jelly squish cubes
--   butter  squishy butter sticks with a printed label
--   keycap  ASMR keyboard keycaps (these regrow: plant a keyboard, keys keep popping up)
--
-- The shop, growth, visuals and selling all read from this table, so
-- balancing is a data-only change.
--
-- Fields:
--   id          Stable save key. NEVER rename once the game is live.
--   kind        Which family / 3D look to use (see above).
--   seedPrice   Coins per seed in the shop.
--   growTime    Seconds from planting to first harvest.
--   regrowTime  If set, the plant stays after harvest and is ready again after
--               this many seconds (multi-harvest). If nil, harvesting removes it.
--   baseValue   Sell price of a 1.00x-size harvest with no mutations.
--   stockChance Probability (0-1) the item appears in a given shop restock.
--   stock       {min, max} units per player when it does appear.
--   color       Main body color.
--   accent      Secondary color: keycap letters, butter label text.
--   label       Text printed on butter sticks.
--   material    "SmoothPlastic", "Glass" (jelly, see-through) or "Neon" (glows).

export type Kind = "bao" | "cube" | "butter" | "keycap"

export type SquishyDef = {
	id: string,
	name: string,
	rarity: string,
	kind: Kind,
	seedPrice: number,
	growTime: number,
	regrowTime: number?,
	baseValue: number,
	stockChance: number,
	stock: { number },
	color: { number },
	accent: { number }?,
	label: string?,
	material: string,
}

local List: { SquishyDef } = {
	{
		id = "mochi_bao",
		name = "Mochi Bao",
		rarity = "Common",
		kind = "bao",
		seedPrice = 10,
		growTime = 30,
		baseValue = 18,
		stockChance = 1,
		stock = { 10, 25 },
		color = { 255, 225, 235 },
		material = "SmoothPlastic",
	},
	{
		id = "butter_stick",
		name = "Butter Stick",
		rarity = "Common",
		kind = "butter",
		seedPrice = 25,
		growTime = 45,
		baseValue = 40,
		stockChance = 1,
		stock = { 5, 15 },
		color = { 255, 236, 140 },
		accent = { 40, 70, 190 },
		label = "BUTTER",
		material = "SmoothPlastic",
	},
	{
		id = "wood_keycap",
		name = "Wood Keycap",
		rarity = "Common",
		kind = "keycap",
		seedPrice = 50,
		growTime = 60,
		regrowTime = 30,
		baseValue = 12,
		stockChance = 1,
		stock = { 3, 10 },
		color = { 215, 160, 110 },
		accent = { 45, 30, 25 },
		material = "SmoothPlastic",
	},
	{
		id = "squish_cube",
		name = "Squish Cube",
		rarity = "Uncommon",
		kind = "cube",
		seedPrice = 120,
		growTime = 90,
		baseValue = 210,
		stockChance = 0.85,
		stock = { 3, 8 },
		color = { 190, 140, 255 },
		material = "Glass",
	},
	{
		id = "peach_bao",
		name = "Peach Bao",
		rarity = "Uncommon",
		kind = "bao",
		seedPrice = 200,
		growTime = 150,
		regrowTime = 60,
		baseValue = 45,
		stockChance = 0.8,
		stock = { 2, 6 },
		color = { 255, 190, 160 },
		material = "SmoothPlastic",
	},
	{
		id = "salted_butter",
		name = "Salted Butter Block",
		rarity = "Uncommon",
		kind = "butter",
		seedPrice = 350,
		growTime = 180,
		baseValue = 600,
		stockChance = 0.7,
		stock = { 2, 5 },
		color = { 255, 230, 120 },
		accent = { 200, 40, 60 },
		label = "SALTED",
		material = "SmoothPlastic",
	},
	{
		id = "clicky_keycap",
		name = "Clicky Keycap",
		rarity = "Rare",
		kind = "keycap",
		seedPrice = 700,
		growTime = 240,
		regrowTime = 60,
		baseValue = 110,
		stockChance = 0.5,
		stock = { 1, 4 },
		color = { 120, 200, 255 },
		accent = { 255, 255, 255 },
		material = "SmoothPlastic",
	},
	{
		id = "glitter_cube",
		name = "Glitter Cube",
		rarity = "Rare",
		kind = "cube",
		seedPrice = 1500,
		growTime = 360,
		baseValue = 2600,
		stockChance = 0.4,
		stock = { 1, 3 },
		color = { 255, 150, 210 },
		material = "Glass",
	},
	{
		id = "galaxy_bao",
		name = "Galaxy Bao",
		rarity = "Epic",
		kind = "bao",
		seedPrice = 4000,
		growTime = 480,
		regrowTime = 90,
		baseValue = 380,
		stockChance = 0.25,
		stock = { 1, 2 },
		color = { 110, 80, 200 },
		material = "SmoothPlastic",
	},
	{
		id = "rgb_keycap",
		name = "RGB Keycap",
		rarity = "Epic",
		kind = "keycap",
		seedPrice = 9000,
		growTime = 600,
		regrowTime = 120,
		baseValue = 700,
		stockChance = 0.18,
		stock = { 1, 2 },
		color = { 80, 255, 200 },
		accent = { 30, 30, 40 },
		material = "Neon",
	},
	{
		id = "honey_butter",
		name = "Honey Butter",
		rarity = "Legendary",
		kind = "butter",
		seedPrice = 25000,
		growTime = 900,
		regrowTime = 180,
		baseValue = 1800,
		stockChance = 0.1,
		stock = { 1, 1 },
		color = { 255, 190, 60 },
		accent = { 150, 80, 20 },
		label = "HONEY",
		material = "SmoothPlastic",
	},
	{
		id = "crystal_cube",
		name = "Crystal Cube",
		rarity = "Legendary",
		kind = "cube",
		seedPrice = 60000,
		growTime = 1200,
		regrowTime = 200,
		baseValue = 3800,
		stockChance = 0.07,
		stock = { 1, 1 },
		color = { 170, 240, 255 },
		material = "Glass",
	},
	{
		id = "artisan_keycap",
		name = "Artisan Keycap",
		rarity = "Mythic",
		kind = "keycap",
		seedPrice = 150000,
		growTime = 1800,
		regrowTime = 240,
		baseValue = 8000,
		stockChance = 0.05,
		stock = { 1, 1 },
		color = { 255, 120, 160 },
		accent = { 255, 215, 90 },
		material = "SmoothPlastic",
	},
	{
		id = "dragon_bao",
		name = "Dragon Bao",
		rarity = "Mythic",
		kind = "bao",
		seedPrice = 400000,
		growTime = 2400,
		regrowTime = 300,
		baseValue = 18000,
		stockChance = 0.03,
		stock = { 1, 1 },
		color = { 255, 90, 90 },
		material = "SmoothPlastic",
	},
	{
		id = "starlight_bao",
		name = "Starlight Bao",
		rarity = "Celestial",
		kind = "bao",
		seedPrice = 1200000,
		growTime = 3600,
		regrowTime = 360,
		baseValue = 50000,
		stockChance = 0.015,
		stock = { 1, 1 },
		color = { 190, 255, 250 },
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

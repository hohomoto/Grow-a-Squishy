--!strict
-- Rarity tiers, lowest to highest. Colors are plain RGB triples so this module
-- stays free of Roblox types and can be unit-tested outside Studio.

export type RarityInfo = {
	rank: number,
	color: { number },
}

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Celestial" }

Rarities.Info = {
	Common = { rank = 1, color = { 190, 190, 190 } },
	Uncommon = { rank = 2, color = { 110, 210, 110 } },
	Rare = { rank = 3, color = { 80, 150, 255 } },
	Epic = { rank = 4, color = { 180, 90, 255 } },
	Legendary = { rank = 5, color = { 255, 190, 40 } },
	Mythic = { rank = 6, color = { 255, 80, 120 } },
	Celestial = { rank = 7, color = { 120, 255, 240 } },
} :: { [string]: RarityInfo }

return Rarities

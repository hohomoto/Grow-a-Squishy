--!strict
-- Computes the seed shop's stock for a restock window. Deterministic: the same
-- window always yields the same stock, on every server.

local Economy = require(script.Parent.Config.Economy)
local Rng = require(script.Parent.Rng)
local Squishies = require(script.Parent.Config.Squishies)

local ShopStock = {}

function ShopStock.windowAt(time: number): number
	return math.floor(time / Economy.RestockInterval)
end

function ShopStock.nextRestockAt(window: number): number
	return (window + 1) * Economy.RestockInterval
end

-- Returns { [squishyId] = units available to each player this window }.
-- Items that did not roll into stock are absent.
function ShopStock.roll(window: number): { [string]: number }
	local rng = Rng.new(window)
	local stock = {}
	for _, def in Squishies.List do
		-- Always consume both rolls, so tuning one item's stockChance never
		-- shifts the rolls of the items after it. Append new items to the END
		-- of the catalog for the same reason.
		local appears = rng:next() < def.stockChance
		local amount = rng:range(def.stock[1], def.stock[2])
		if appears then
			stock[def.id] = amount
		end
	end
	return stock
end

return ShopStock

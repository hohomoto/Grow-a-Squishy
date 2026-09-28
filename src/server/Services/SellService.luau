--!strict
-- Sells the player's whole backpack at the Squishy Buyer stand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Growth = require(Shared.Growth)
local Squishies = require(Shared.Config.Squishies)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)
local Sync = require(script.Parent.Parent.Sync)

local SellService = {}

local function sellAll(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if #data.backpack == 0 then
		Sync.notify(player, "Nothing to sell yet. Go harvest some squishies!")
		return
	end

	local total = 0
	local count = 0
	for _, item in data.backpack do
		local def = Squishies.ById[item.id]
		if def then
			total += Growth.value(def.baseValue, item.size, item.mutations)
			count += 1
		end
	end

	data.backpack = {}
	data.coins += total
	data.stats.earned += total
	Sync.notify(player, `Sold {count} squishies for {Format.commas(total)} coins!`)
	Sync.push(player)
end

function SellService.Start()
	WorldService.GetSellPrompt().Triggered:Connect(sellAll)
end

return SellService

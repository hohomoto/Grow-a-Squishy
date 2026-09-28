--!strict
-- Seed purchases and restock announcements. Stock itself is computed in
-- Shared/ShopStock and is the same on every server for a given window.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local ShopStock = require(Shared.ShopStock)
local Squishies = require(Shared.Config.Squishies)
local DataService = require(script.Parent.DataService)
local RateLimit = require(script.Parent.Parent.RateLimit)
local Sync = require(script.Parent.Parent.Sync)

-- Restocks containing this rarity or better get a server-wide shout-out.
local ANNOUNCE_MIN_RANK = Rarities.Info.Legendary.rank

local ShopService = {}

local buyLimit = RateLimit.new(6, 10)

local function onBuySeed(player: Player, rawId: unknown)
	if not buyLimit:allow(player) then
		return
	end
	local def = type(rawId) == "string" and Squishies.ById[rawId] or nil
	local data = DataService.Get(player)
	if not def or not data then
		return
	end

	Sync.rollShopWindow(data)
	local _, stock = Sync.currentStock()
	local available = (stock[def.id] or 0) - (data.shop.bought[def.id] or 0)
	if available <= 0 then
		Sync.notify(player, def.name .. " is sold out. Check back after the restock!")
		Sync.sfx(player, "Error")
		return
	end
	if data.coins < def.seedPrice then
		Sync.notify(player, "Not enough coins for " .. def.name .. ".")
		Sync.sfx(player, "Error")
		return
	end

	data.coins -= def.seedPrice
	data.shop.bought[def.id] = (data.shop.bought[def.id] or 0) + 1
	data.seeds[def.id] = (data.seeds[def.id] or 0) + 1
	Sync.sfx(player, "Coin")
	Sync.push(player)
end

local function announceRestock(stock: { [string]: number })
	local message = "The Seed Shop restocked!"
	local best = nil
	for _, def in Squishies.List do
		local rank = Rarities.Info[def.rarity].rank
		if stock[def.id] and rank >= ANNOUNCE_MIN_RANK and (not best or rank >= Rarities.Info[best.rarity].rank) then
			best = def
		end
	end
	if best then
		message = `{best.rarity} {best.name} is in the Seed Shop!`
	end
	for _, player in Players:GetPlayers() do
		Sync.notify(player, message)
		Sync.push(player)
	end
end

function ShopService.Start()
	Remotes.BuySeed.OnServerEvent:Connect(onBuySeed)

	task.spawn(function()
		local lastWindow = ShopStock.windowAt(os.time())
		while true do
			task.wait(1)
			local window, stock = Sync.currentStock()
			if window ~= lastWindow then
				lastWindow = window
				announceRestock(stock)
			end
		end
	end)
end

return ShopService

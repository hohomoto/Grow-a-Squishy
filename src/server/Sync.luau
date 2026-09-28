--!strict
-- Builds the client-visible state from player data and sends it. Call
-- Sync.push(player) after any change the player should see.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)
local ShopStock = require(Shared.ShopStock)
local Types = require(Shared.Types)
local DataService = require(script.Parent.Services.DataService)

local Sync = {}

local cachedWindow = -1
local cachedStock: { [string]: number } = {}

-- Stock for the current restock window (cached; it only changes on restock).
function Sync.currentStock(): (number, { [string]: number })
	local window = ShopStock.windowAt(os.time())
	if window ~= cachedWindow then
		cachedWindow = window
		cachedStock = ShopStock.roll(window)
	end
	return window, cachedStock
end

-- Resets the player's per-window purchase counts when a new window starts.
function Sync.rollShopWindow(data: Types.PlayerData)
	local window = Sync.currentStock()
	if data.shop.window ~= window then
		data.shop.window = window
		data.shop.bought = {}
	end
end

-- Shows coins on the default player list.
local function updateLeaderstats(player: Player, coins: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue: NumberValue
	if leaderstats then
		coinsValue = leaderstats:FindFirstChild("Coins") :: NumberValue
	else
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		coinsValue = Instance.new("NumberValue")
		coinsValue.Name = "Coins"
		coinsValue.Parent = folder
		folder.Parent = player
	end
	coinsValue.Value = coins
end

function Sync.push(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	Sync.rollShopWindow(data)
	local window, stock = Sync.currentStock()

	local remaining = {}
	for id, amount in stock do
		remaining[id] = math.max(0, amount - (data.shop.bought[id] or 0))
	end

	local state: Types.ClientState = {
		coins = data.coins,
		seeds = data.seeds,
		backpack = data.backpack,
		backpackCapacity = Economy.BackpackCapacity,
		shop = {
			restockAt = ShopStock.nextRestockAt(window),
			remaining = remaining,
		},
	}
	updateLeaderstats(player, data.coins)
	Remotes.StateUpdated:FireClient(player, state)
end

function Sync.notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

return Sync

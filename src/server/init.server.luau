--!strict
-- Server entry point. Services start in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sync = require(script.Sync)

local Services = script.Services
local ORDER = {
	"DataService",
	"WorldService",
	"PlotService",
	"GardenService",
	"ShopService",
	"SellService",
	"TravelService",
	"WeatherService",
}

for _, name in ORDER do
	local service = require(Services:FindFirstChild(name) :: ModuleScript) :: any
	service.Start()
end

Remotes.RequestState.OnServerEvent:Connect(function(player)
	Sync.push(player)
end)

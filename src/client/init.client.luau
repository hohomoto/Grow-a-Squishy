--!strict
-- Client entry point. Controllers start in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sfx = require(script.Sfx)

-- Gameplay sounds the server asks for (harvest, plant, buy, sell, ...).
Remotes.Sfx.OnClientEvent:Connect(Sfx.play)

local Controllers = script.Controllers
local ORDER = {
	"Toasts",
	"Hud",
	"ShopUi",
	"Inventory",
	"PlotInput",
	"PlantVisuals",
	"WeatherFx",
	-- State last: it requests the first snapshot once everyone is listening.
	"State",
}

for _, name in ORDER do
	local controller = require(Controllers:FindFirstChild(name) :: ModuleScript) :: any
	controller.Start()
end

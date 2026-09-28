--!strict
-- Client entry point. Controllers start in dependency order.

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

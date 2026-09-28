--!strict
-- Quick-travel buttons: Garden (your plot), Shop, and Sell.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local RateLimit = require(script.Parent.Parent.RateLimit)
local WorldService = require(script.Parent.WorldService)

local TravelService = {}

local travelLimit = RateLimit.new(1, 3)

local function onTravel(player: Player, destination: unknown)
	if not travelLimit:allow(player) then
		return
	end
	if destination == "Garden" then
		PlotService.SendHome(player)
		return
	end
	local arrival = type(destination) == "string" and WorldService.GetArrival(destination) or nil
	local character = player.Character
	if arrival and character then
		character:PivotTo(arrival)
	end
end

function TravelService.Start()
	Remotes.Travel.OnServerEvent:Connect(onTravel)
end

return TravelService

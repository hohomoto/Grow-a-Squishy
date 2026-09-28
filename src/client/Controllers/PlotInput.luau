--!strict
-- Click or tap a tile on your own plot to plant the selected seed, or dig up
-- a squishy with the shovel (tap twice to confirm, so nobody loses a Mythic
-- to a misclick).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Squishies = require(Shared.Config.Squishies)
local State = require(script.Parent.State)
local Toasts = require(script.Parent.Toasts)

local CONFIRM_WINDOW = 3
local RAY_LENGTH = 1000

local PlotInput = {}

local localPlayer = Players.LocalPlayer
local pendingDig: { tile: number, at: number }? = nil

-- Returns the plot and tile index under a screen position, if it is on a
-- plot the local player owns.
local function tileAt(screenPosition: Vector2): (Model?, number?)
	local plots = Workspace:FindFirstChild("Plots")
	local camera = Workspace.CurrentCamera
	if not plots or not camera then
		return nil, nil
	end
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plots }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
	if not result then
		return nil, nil
	end
	-- Tiles and plants both carry TileIndex.
	local tileIndex = result.Instance:GetAttribute("TileIndex")
	local plot = result.Instance:FindFirstAncestorWhichIsA("Model")
	if type(tileIndex) ~= "number" or not plot or plot:GetAttribute("OwnerUserId") ~= localPlayer.UserId then
		return nil, nil
	end
	return plot, tileIndex
end

local function onPress(screenPosition: Vector2)
	local selected = State.selected
	if not selected then
		return
	end
	local plot, tileIndex = tileAt(screenPosition)
	if not plot or not tileIndex then
		return
	end
	local plant = (plot :: any).Plants:FindFirstChild(tostring(tileIndex))

	if selected == State.SHOVEL then
		if not plant then
			return
		end
		local pending = pendingDig
		if pending and pending.tile == tileIndex and os.clock() - pending.at < CONFIRM_WINDOW then
			pendingDig = nil
			Remotes.RemovePlant:FireServer(tileIndex)
		else
			pendingDig = { tile = tileIndex, at = os.clock() }
			local def = Squishies.ById[plant:GetAttribute("SquishyId") :: string]
			Toasts.show(`Tap again to dig up {if def then def.name else "this squishy"}`)
		end
	elseif not plant then
		Remotes.PlantSeed:FireServer(tileIndex, selected)
	end
end

function PlotInput.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			onPress(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if not processedByUI then
			onPress(position)
		end
	end)
end

return PlotInput

--!strict
-- Hands each player a free plot when their data loads, sends them to it on
-- every spawn, and frees it when they leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local PlotService = {}

-- Fires after a player owns a plot and their data is loaded.
PlotService.PlotAssigned = Signal.new() :: Signal.Signal<Player, Model>

local plotOf: { [Player]: Model } = {}

local function setSign(plot: Model, text: string)
	local post = plot:FindFirstChild("SignPost")
	local label = post and post:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function sendToPlot(player: Player)
	local plot = plotOf[player]
	local character = player.Character
	if not plot or not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root or plotOf[player] ~= plot then
		return
	end
	-- Let the default spawn placement finish before moving the character.
	task.wait()
	local spawnPoint = plot:FindFirstChild("SpawnPoint") :: BasePart
	character:PivotTo(spawnPoint.CFrame + Vector3.new(0, 3, 0))
end

local function assign(player: Player)
	if player.Parent ~= Players then
		return
	end
	for _, plot in WorldService.GetPlots() do
		if plot:GetAttribute("OwnerUserId") == nil then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plotOf[player] = plot
			setSign(plot, player.DisplayName .. "'s Squishies")
			PlotService.PlotAssigned:Fire(player, plot)
			task.spawn(sendToPlot, player)
			return
		end
	end
	-- Only reachable if Max Players is set higher than Economy.PlotCount.
	player:Kick("This server is full of squishies! Please join another server.")
end

local function unassign(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plotOf[player] = nil
	for _, plant in (plot :: any).Plants:GetChildren() do
		plant:Destroy()
	end
	plot:SetAttribute("OwnerUserId", nil)
	setSign(plot, "Empty Plot")
end

-- Teleports the player to their own plot.
function PlotService.SendHome(player: Player)
	task.spawn(sendToPlot, player)
end

function PlotService.GetPlot(player: Player): Model?
	return plotOf[player]
end

function PlotService.GetTile(plot: Model, tileIndex: number): BasePart?
	return (plot :: any).Tiles:FindFirstChild(tostring(tileIndex))
end

function PlotService.Start()
	DataService.Loaded:Connect(assign)
	Players.PlayerRemoving:Connect(unassign)

	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			sendToPlot(player)
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
end

return PlotService

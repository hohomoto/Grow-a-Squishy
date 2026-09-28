--!strict
-- Always-on HUD: coins and backpack at the top, seed hotbar at the bottom.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Rarities = require(Shared.Config.Rarities)
local Squishies = require(Shared.Config.Squishies)
local Types = require(Shared.Types)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Parent.Ui)

local SLOT_SIZE = 76

local Hud = {}

local coinsLabel: TextLabel
local backpackLabel: TextLabel
local hotbar: ScrollingFrame

local function slot(order: number, title: string, subtitle: string, color: Color3, selected: boolean, onClick: () -> ())
	local button = Ui.create("TextButton", {
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = if selected then Ui.Colors.Accent else Ui.Colors.Panel,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = order,
		Parent = hotbar,
	}, {
		Ui.corner(14),
		Ui.create("UIStroke", {
			Color = color,
			Thickness = if selected then 4 else 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Ui.create("TextLabel", {
			Size = UDim2.new(1, -8, 0.6, 0),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Font = Ui.Font,
			TextScaled = true,
			TextColor3 = Ui.Colors.Text,
			Text = title,
		}),
		Ui.create("TextLabel", {
			Size = UDim2.new(1, -8, 0.3, 0),
			Position = UDim2.new(0, 4, 0.66, 0),
			BackgroundTransparency = 1,
			Font = Ui.Font,
			TextScaled = true,
			TextColor3 = Ui.Colors.Text,
			Text = subtitle,
		}),
	})
	button.Activated:Connect(onClick)
end

local function renderHotbar()
	for _, child in hotbar:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local state = State.current
	if not state then
		return
	end

	local order = 0
	for _, def in Squishies.List do
		local count = state.seeds[def.id]
		if count and count > 0 then
			order += 1
			slot(
				order,
				def.name,
				"x" .. count,
				Ui.rgb(Rarities.Info[def.rarity].color),
				State.selected == def.id,
				function()
					State.select(def.id)
				end
			)
		end
	end
	slot(order + 1, "Shovel", "dig up", Ui.Colors.PanelDark, State.selected == State.SHOVEL, function()
		State.select(State.SHOVEL)
	end)
end

local function renderTop(state: Types.ClientState)
	coinsLabel.Text = Format.commas(state.coins) .. " coins"
	backpackLabel.Text = `Backpack {#state.backpack}/{state.backpackCapacity}`
	backpackLabel.TextColor3 = if #state.backpack >= state.backpackCapacity
		then Color3.fromRGB(220, 60, 60)
		else Ui.Colors.Text
end

function Hud.Start()
	local gui = Ui.create("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	local top = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 64),
		BackgroundColor3 = Ui.Colors.Panel,
		Parent = gui,
	}, {
		Ui.corner(14),
		Ui.create("UIStroke", { Color = Ui.Colors.Accent, Thickness = 2 }),
	})
	coinsLabel = Ui.create("TextLabel", {
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 4),
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(230, 150, 20),
		Text = "...",
		Parent = top,
	})
	backpackLabel = Ui.create("TextLabel", {
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 38),
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Ui.Colors.Text,
		Text = "",
		Parent = top,
	})

	-- Scrolls sideways when a player owns more seed types than fit on screen.
	hotbar = Ui.create("ScrollingFrame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, SLOT_SIZE + 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})

	State.Changed:Connect(function(state)
		renderTop(state)
		renderHotbar()
	end)
	State.SelectionChanged:Connect(renderHotbar)
	if State.current then
		renderTop(State.current)
	end
	renderHotbar()
end

return Hud

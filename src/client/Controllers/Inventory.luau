--!strict
-- Backpack window (press B or the Bag button). Two tabs:
--   Squishies  every harvested squishy with its size and sell value
--   Seeds      every seed you own, with an Equip button for planting

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Growth = require(Shared.Growth)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local Squishies = require(Shared.Config.Squishies)
local Types = require(Shared.Types)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Parent.Ui)
local Windows = require(script.Parent.Parent.Windows)

local WINDOW = "Inventory"
-- Harvests at least this size get a "BIG!" badge.
local BIG_SIZE = 1.5

type Tab = "Squishies" | "Seeds"

local Inventory = {}

local activeTab: Tab = "Squishies"
local tabButtons: { [Tab]: TextButton } = {}
local grid: ScrollingFrame
local emptyFrame: Frame
local emptyText: TextLabel
local emptyShopButton: TextButton

local function card(order: number, def: Squishies.SquishyDef): Frame
	return Ui.create("Frame", {
		BackgroundColor3 = Ui.Colors.White,
		LayoutOrder = order,
		Parent = grid,
	}, {
		Ui.corner(14),
		Ui.stroke(Ui.rgb(Rarities.Info[def.rarity].color), 3),
		Ui.squishyIcon(def, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(52, 52),
		}),
		Ui.label({
			Position = UDim2.fromOffset(4, 66),
			Size = UDim2.new(1, -8, 0, 18),
			Text = def.name,
		}),
	})
end

-- Shown instead of the grid when a tab has nothing in it. Lives outside the
-- grid because UIGridLayout would squeeze it into a card-sized cell.
local function showEmpty(text: string?, offerShop: boolean?)
	emptyFrame.Visible = text ~= nil
	emptyText.Text = text or ""
	emptyShopButton.Visible = offerShop == true
end

local function renderSquishies(state: Types.ClientState)
	-- Most valuable first.
	local items = {}
	for _, item in state.backpack do
		local def = Squishies.ById[item.id]
		if def then
			local value = Growth.value(def.baseValue, item.size, item.mutations)
			table.insert(items, { def = def, size = item.size, value = value, mutations = item.mutations })
		end
	end
	table.sort(items, function(a, b)
		return a.value > b.value
	end)

	if #items == 0 then
		showEmpty("Your backpack is empty. Harvest ready squishies on your plot!")
		return
	end

	for order, item in items do
		local frame = card(order, item.def)
		Ui.label({
			Position = UDim2.fromOffset(4, 86),
			Size = UDim2.new(0.5, -4, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.Text,
			TextStrokeTransparency = 1,
			Text = string.format("%.2fx", item.size),
			Parent = frame,
		})
		Ui.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 86),
			Size = UDim2.new(0.5, -4, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Ui.Colors.Coin,
			Text = "$" .. Format.short(item.value),
			Parent = frame,
		})
		local top = Mutations.top(item.mutations)
		if top then
			-- Mutated: colored border plus a tag line under the stats.
			local stroke = frame:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Color = Ui.rgb(top.color)
				stroke.Thickness = 4
			end
			local tags = {}
			for _, id in item.mutations :: { string } do
				local mutation = Mutations.ById[id]
				if mutation then
					table.insert(tags, `<font color="#{Ui.rgb(mutation.color):ToHex()}">{mutation.name}</font>`)
				end
			end
			Ui.label({
				Position = UDim2.fromOffset(4, 106),
				Size = UDim2.new(1, -8, 0, 16),
				RichText = true,
				TextStrokeTransparency = 0.5,
				Text = table.concat(tags, " "),
				Parent = frame,
			})
		end
		if item.size >= BIG_SIZE then
			Ui.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(40, 18),
				Rotation = 12,
				TextColor3 = Ui.Colors.Warn,
				Text = "BIG!",
				Parent = frame,
			})
		end
	end
end

local function renderSeeds(state: Types.ClientState)
	local owned = 0
	for _, def in Squishies.List do
		local count = state.seeds[def.id]
		if count and count > 0 then
			owned += 1
			local frame = card(owned, def)
			local equipped = State.selected == def.id
			Ui.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 4),
				Size = UDim2.fromOffset(44, 20),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Ui.Colors.Text,
				TextStrokeTransparency = 1,
				Text = "x" .. count,
				Parent = frame,
			})
			local equip = Ui.button(
				if equipped then "Equipped" else "Equip",
				if equipped then Ui.Colors.Muted else Ui.Colors.Good,
				{
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -6),
					Size = UDim2.new(1, -16, 0, 26),
					Parent = frame,
				}
			)
			equip.Activated:Connect(function()
				if State.selected ~= def.id then
					State.select(def.id)
				end
				Windows.close(WINDOW)
			end)
		end
	end

	if owned == 0 then
		showEmpty("No seeds left. Buy more at the Seed Shop!", true)
	end
end

local function render()
	local state = State.current
	if not state then
		return
	end
	for tab, button in tabButtons do
		local active = tab == activeTab
		button.BackgroundColor3 = if active then Ui.Colors.Info else Ui.Colors.Muted
	end

	Ui.clear(grid)
	showEmpty(nil)
	local layout = grid:FindFirstChildWhichIsA("UIGridLayout") :: UIGridLayout
	-- Seed cards need room for the Equip button, squishy cards for mutation tags.
	layout.CellSize = if activeTab == "Seeds" then UDim2.fromOffset(112, 140) else UDim2.fromOffset(112, 126)
	if activeTab == "Squishies" then
		renderSquishies(state)
	else
		renderSeeds(state)
	end
end

local function setTab(tab: Tab)
	activeTab = tab
	render()
end

function Inventory.Start()
	local window = Windows.create(WINDOW, "Backpack", Ui.Colors.Info, render)
	local content = window.content

	local tabs = Ui.create("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	for order, tab: Tab in { "Squishies", "Seeds" } :: { Tab } do
		local button = Ui.button(tab, Ui.Colors.Muted, {
			Size = UDim2.fromOffset(140, 40),
			LayoutOrder = order,
			Parent = tabs,
		})
		button.Activated:Connect(function()
			setTab(tab)
		end)
		tabButtons[tab] = button
	end

	grid = Ui.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = content,
	}, {
		Ui.create("UIGridLayout", {
			CellSize = UDim2.fromOffset(112, 112),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Ui.padding(4),
	})

	emptyFrame = Ui.create("Frame", {
		Position = UDim2.fromOffset(0, 64),
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = content,
	})
	emptyText = Ui.label({
		Size = UDim2.new(1, 0, 0, 50),
		TextColor3 = Ui.Colors.Muted,
		TextStrokeTransparency = 1,
		TextWrapped = true,
		Text = "",
		Parent = emptyFrame,
	})
	emptyShopButton = Ui.button("Go to Seed Shop", Ui.Colors.Accent, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(220, 44),
		Parent = emptyFrame,
	})
	emptyShopButton.Activated:Connect(function()
		Remotes.Travel:FireServer("Shop")
		Windows.close(WINDOW)
	end)

	State.Changed:Connect(function()
		if Windows.isOpen(WINDOW) then
			render()
		end
	end)
	State.SelectionChanged:Connect(function()
		if Windows.isOpen(WINDOW) and activeTab == "Seeds" then
			render()
		end
	end)
end

return Inventory

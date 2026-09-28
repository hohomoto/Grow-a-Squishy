--!strict
-- Seed Shop window. Opens from the shop stand's prompt. Lists every squishy,
-- including ones not in stock right now, so players know what to hope for.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Rarities = require(Shared.Config.Rarities)
local Remotes = require(Shared.Remotes)
local Squishies = require(Shared.Config.Squishies)
local Types = require(Shared.Types)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Parent.Ui)
local Windows = require(script.Parent.Parent.Windows)

local WINDOW = "Shop"
local ROW_HEIGHT = 84

local ShopUi = {}

type Row = { stock: TextLabel, buy: TextButton, frame: Frame }

local restockLabel: TextLabel
local rows: { [string]: Row } = {}

local function buildRow(list: ScrollingFrame, def: Squishies.SquishyDef, order: number)
	local rarityColor = Ui.rgb(Rarities.Info[def.rarity].color)
	local details = `Grows {Format.duration(def.growTime)}`
	if def.regrowTime then
		details ..= ` · Regrows {Format.duration(def.regrowTime)}`
	end
	details ..= ` · Sells ~${Format.short(def.baseValue)}`

	local frame = Ui.create("Frame", {
		Size = UDim2.new(1, -10, 0, ROW_HEIGHT),
		BackgroundColor3 = Ui.Colors.White,
		LayoutOrder = order,
		Parent = list,
	}, {
		Ui.corner(14),
		Ui.stroke(rarityColor, 3),
		Ui.squishyIcon(def, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(56, 56),
		}),
		Ui.label({
			Position = UDim2.fromOffset(80, 8),
			Size = UDim2.new(1, -220, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rarityColor,
			Text = def.name,
		}),
		Ui.label({
			Position = UDim2.fromOffset(80, 36),
			Size = UDim2.new(1, -220, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rarityColor,
			TextStrokeTransparency = 1,
			Text = def.rarity,
		}),
		Ui.label({
			Position = UDim2.fromOffset(80, 56),
			Size = UDim2.new(1, -220, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.Muted,
			TextStrokeTransparency = 1,
			Text = details,
		}),
	})

	local stock = Ui.label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(120, 22),
		TextColor3 = Ui.Colors.Text,
		TextStrokeTransparency = 1,
		Text = "",
		Parent = frame,
	})
	local buy = Ui.button("$" .. Format.short(def.seedPrice), Ui.Colors.Good, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(120, 38),
		Parent = frame,
	})
	buy.Activated:Connect(function()
		Remotes.BuySeed:FireServer(def.id)
	end)

	rows[def.id] = { stock = stock, buy = buy, frame = frame }
end

local function render(state: Types.ClientState)
	for id, row in rows do
		local left = state.shop.remaining[id]
		local def = Squishies.ById[id]
		local inStock = left ~= nil and left > 0
		if left == nil then
			row.stock.Text = "NO STOCK"
			row.stock.TextColor3 = Ui.Colors.Muted
		elseif left == 0 then
			row.stock.Text = "SOLD OUT"
			row.stock.TextColor3 = Ui.Colors.Bad
		else
			row.stock.Text = `{left} in stock`
			row.stock.TextColor3 = Ui.Colors.Good
		end
		local canBuy = inStock and state.coins >= def.seedPrice
		row.buy.BackgroundColor3 = if canBuy then Ui.Colors.Good else Ui.Colors.Muted
		row.buy.AutoButtonColor = canBuy
		-- Fade out items that aren't in stock this round.
		row.frame.BackgroundColor3 = if inStock then Ui.Colors.White else Ui.Colors.PanelAlt
	end
end

function ShopUi.open()
	Windows.open(WINDOW)
end

function ShopUi.Start()
	local window = Windows.create(WINDOW, "Seed Shop", Ui.Colors.Accent, function()
		if State.current then
			render(State.current)
		end
	end)
	local content = window.content

	restockLabel = Ui.label({
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.Text,
		TextStrokeTransparency = 1,
		Text = "",
		Parent = content,
	})

	local list = Ui.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = content,
	}, {
		Ui.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
		}),
		Ui.padding(4),
	})
	for order, def in Squishies.List do
		buildRow(list, def, order)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("OpensShop") then
			ShopUi.open()
		end
	end)
	State.Changed:Connect(function(state)
		if Windows.isOpen(WINDOW) then
			render(state)
		end
	end)

	task.spawn(function()
		while true do
			local state = State.current
			if Windows.isOpen(WINDOW) and state then
				local left = state.shop.restockAt - Workspace:GetServerTimeNow()
				restockLabel.Text = "New stock in " .. Format.duration(left)
			end
			task.wait(0.25)
		end
	end)
end

return ShopUi

--!strict
-- Seed Shop window. Opens from the shop stand's prompt. Lists every squishy,
-- including ones not in stock right now, so players know what to hope for.

local Players = game:GetService("Players")
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

local ShopUi = {}

type Row = { stock: TextLabel, buy: TextButton }

local panel: Frame
local restockLabel: TextLabel
local rows: { [string]: Row } = {}

local function buildRow(list: ScrollingFrame, def: Squishies.SquishyDef, order: number)
	local rarityColor = Ui.rgb(Rarities.Info[def.rarity].color)
	local details = `{def.rarity} · Grows {Format.duration(def.growTime)}`
	if def.regrowTime then
		details ..= ` · Regrows {Format.duration(def.regrowTime)}`
	end
	details ..= ` · Sells ~{Format.short(def.baseValue)}`

	local row = Ui.create("Frame", {
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = Ui.Colors.White,
		LayoutOrder = order,
		Parent = list,
	}, {
		Ui.corner(10),
		Ui.create("UIStroke", { Color = rarityColor, Thickness = 2 }),
		Ui.create("TextLabel", {
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -130, 0, 26),
			BackgroundTransparency = 1,
			Font = Ui.Font,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rarityColor,
			TextStrokeTransparency = 0.6,
			Text = def.name,
		}),
		Ui.create("TextLabel", {
			Position = UDim2.fromOffset(10, 34),
			Size = UDim2.new(1, -130, 0, 22),
			BackgroundTransparency = 1,
			Font = Ui.Font,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.Muted,
			Text = details,
		}),
	})

	local stock = Ui.create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 4),
		Size = UDim2.fromOffset(110, 20),
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Ui.Colors.Text,
		Text = "",
		Parent = row,
	})
	local buy = Ui.create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -6),
		Size = UDim2.fromOffset(110, 32),
		BackgroundColor3 = Ui.Colors.Good,
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Ui.Colors.White,
		Text = Format.short(def.seedPrice),
		Parent = row,
	}, { Ui.corner(8) })
	buy.Activated:Connect(function()
		Remotes.BuySeed:FireServer(def.id)
	end)

	rows[def.id] = { stock = stock, buy = buy }
end

local function render(state: Types.ClientState)
	for id, row in rows do
		local left = state.shop.remaining[id]
		local def = Squishies.ById[id]
		if left == nil then
			row.stock.Text = "Not in stock"
		elseif left == 0 then
			row.stock.Text = "Sold out"
		else
			row.stock.Text = `x{left} left`
		end
		local canBuy = left ~= nil and left > 0 and state.coins >= def.seedPrice
		row.buy.BackgroundColor3 = if canBuy then Ui.Colors.Good else Ui.Colors.Muted
		row.buy.AutoButtonColor = canBuy
	end
end

function ShopUi.open()
	panel.Visible = true
	if State.current then
		render(State.current)
	end
end

function ShopUi.close()
	panel.Visible = false
end

function ShopUi.Start()
	local gui = Ui.create("ScreenGui", {
		Name = "Shop",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	panel = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.72),
		BackgroundColor3 = Ui.Colors.Panel,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(18),
		Ui.create("UIStroke", { Color = Ui.Colors.Accent, Thickness = 3 }),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(520, 560) }),
		Ui.create("TextLabel", {
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.new(1, -80, 0, 34),
			BackgroundTransparency = 1,
			Font = Ui.Font,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Ui.Colors.Accent,
			Text = "Seed Shop",
		}),
	})
	restockLabel = Ui.create("TextLabel", {
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.new(1, -80, 0, 20),
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.Text,
		Text = "",
		Parent = panel,
	})
	local closeButton = Ui.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Ui.Colors.Accent,
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Ui.Colors.White,
		Text = "X",
		Parent = panel,
	}, { Ui.corner(10) })
	closeButton.Activated:Connect(ShopUi.close)

	local list = Ui.create("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 74),
		Size = UDim2.new(1, -24, 1, -86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		Parent = panel,
	}, {
		Ui.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
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
		if panel.Visible then
			render(state)
		end
	end)

	task.spawn(function()
		while true do
			local state = State.current
			if panel.Visible and state then
				local left = state.shop.restockAt - Workspace:GetServerTimeNow()
				restockLabel.Text = "New stock in " .. Format.duration(left)
			end
			task.wait(0.25)
		end
	end)
end

return ShopUi

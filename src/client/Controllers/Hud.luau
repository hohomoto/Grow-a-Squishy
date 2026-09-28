--!strict
-- Always-on HUD:
--   top     coins, backpack meter, shop restock timer
--   left    menu buttons (Garden / Seeds / Sell travel, Backpack window)
--   bottom  seed hotbar + shovel (number keys 1-9 select slots)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
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

local SLOT_SIZE = 78
local MENU_BUTTON_SIZE = 66

local NUMBER_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local Hud = {}

local coinsLabel: TextLabel
local bagLabel: TextLabel
local bagFill: Frame
local restockLabel: TextLabel
local statusStack: Frame
local hotbar: ScrollingFrame
-- Tool ids in hotbar order, so number keys can select them.
local slotTools: { string } = {}

local function slot(index: number, tool: string, title: string, count: string?, color: Color3, icon: Frame?)
	local selected = State.selected == tool
	local button = Ui.create("TextButton", {
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		BackgroundColor3 = if selected then Ui.Colors.Accent else Ui.Colors.Panel,
		AutoButtonColor = true,
		Text = "",
		LayoutOrder = index,
		Parent = hotbar,
	}, {
		Ui.corner(14),
		Ui.stroke(if selected then Ui.Colors.White else color, if selected then 4 else 3),
		Ui.create("UIScale", { Scale = if selected then 1.08 else 1 }),
		Ui.label({
			Name = "Title",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -3),
			Size = UDim2.new(1, -6, 0, 18),
			Text = title,
		}),
	})
	if icon then
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 8)
		icon.Size = UDim2.fromOffset(44, 44)
		icon.Parent = button
	end
	if count then
		Ui.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 2),
			Size = UDim2.fromOffset(40, 20),
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = count,
			Parent = button,
		})
	end
	if index <= 9 then
		Ui.label({
			Position = UDim2.fromOffset(5, 2),
			Size = UDim2.fromOffset(16, 18),
			TextColor3 = Ui.Colors.Muted,
			TextStrokeTransparency = 1,
			Text = tostring(index),
			Parent = button,
		})
	end
	Ui.addPressEffect(button)
	button.Activated:Connect(function()
		State.select(tool)
	end)
end

local function renderHotbar()
	Ui.clear(hotbar)
	table.clear(slotTools)
	local state = State.current
	if not state then
		return
	end

	for _, def in Squishies.List do
		local count = state.seeds[def.id]
		if count and count > 0 then
			table.insert(slotTools, def.id)
			local color = Ui.rgb(Rarities.Info[def.rarity].color)
			slot(#slotTools, def.id, def.name, "x" .. count, color, Ui.squishyIcon(def, {}))
		end
	end
	table.insert(slotTools, State.SHOVEL)
	local shovelIcon = Ui.create("Frame", { BackgroundTransparency = 1 }, {
		Ui.label({ Size = UDim2.fromScale(1, 1), Text = "DIG", TextColor3 = Ui.Colors.Warn }),
	})
	slot(#slotTools, State.SHOVEL, "Shovel", nil, Ui.Colors.Outline, shovelIcon)
end

local function renderTop(state: Types.ClientState)
	coinsLabel.Text = Format.commas(state.coins)
	local used = #state.backpack
	local full = used >= state.backpackCapacity
	bagLabel.Text = if full then "Backpack FULL - go sell!" else `Backpack {used}/{state.backpackCapacity}`
	bagFill.Size = UDim2.fromScale(math.clamp(used / state.backpackCapacity, 0, 1), 1)
	bagFill.BackgroundColor3 = if full then Ui.Colors.Bad else Ui.Colors.Info
end

-- Phones and tablets: the bottom-left corner belongs to the thumbstick.
local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function pill(order: number, height: number): Frame
	return Ui.create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Ui.Colors.Outline,
		BackgroundTransparency = 0.25,
		LayoutOrder = order,
		Parent = statusStack,
	}, { Ui.corner(height // 2) })
end

-- Status panel: weather (added by WeatherFx), restock timer, backpack meter
-- and coins, stacked in the bottom-left corner (top-left on touch screens).
local function buildStatus(gui: ScreenGui)
	local touch = isTouchOnly()
	statusStack = Ui.create("Frame", {
		Name = "Status",
		AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(0, 1),
		Position = if touch then UDim2.fromOffset(12, 8) else UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(220, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 6),
		}),
	})

	local restock = pill(1, 24)
	restockLabel = Ui.label({
		Position = UDim2.fromOffset(10, 3),
		Size = UDim2.new(1, -20, 1, -6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = restock,
	})

	local meter = Ui.create("Frame", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Ui.Colors.PanelAlt,
		ClipsDescendants = true,
		LayoutOrder = 2,
		Parent = statusStack,
	}, { Ui.corner(11), Ui.stroke(Ui.Colors.Outline, 2) })
	bagFill = Ui.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.Colors.Info,
		BorderSizePixel = 0,
		Parent = meter,
	}, { Ui.corner(11) })
	bagLabel = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 2,
		Parent = meter,
	})

	local coinPill = Ui.create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Ui.Colors.Panel,
		LayoutOrder = 3,
		Parent = statusStack,
	}, { Ui.corner(22), Ui.stroke(Ui.Colors.Outline, 3) })
	Ui.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Ui.Colors.Coin,
		Parent = coinPill,
	}, {
		Ui.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Ui.stroke(Color3.fromRGB(190, 130, 20), 2),
		Ui.label({ Size = UDim2.fromScale(1, 1), Text = "$", TextStrokeTransparency = 1 }),
	})
	coinsLabel = Ui.label({
		Position = UDim2.fromOffset(48, 5),
		Size = UDim2.new(1, -60, 1, -10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Ui.Colors.Coin,
		Text = "...",
		Parent = coinPill,
	})
end

-- The status panel, so other controllers (weather) can add rows to it.
function Hud.getStatusStack(): Frame
	return statusStack
end

local function buildMenu(gui: ScreenGui)
	local menu = Ui.create("Frame", {
		Name = "Menu",
		-- Left edge on computers; right edge on touch screens, where the
		-- status panel takes the top-left corner.
		AnchorPoint = if isTouchOnly() then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
		Position = if isTouchOnly() then UDim2.new(1, -10, 0.5, 0) else UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(MENU_BUTTON_SIZE, (MENU_BUTTON_SIZE + 8) * 4),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})

	local entries: { { text: string, color: Color3, action: () -> () } } = {
		{
			text = "Garden",
			color = Ui.Colors.Good,
			action = function()
				Remotes.Travel:FireServer("Garden")
			end,
		},
		{
			text = "Seeds",
			color = Ui.Colors.Accent,
			action = function()
				Remotes.Travel:FireServer("Shop")
			end,
		},
		{
			text = "Sell",
			color = Ui.Colors.Warn,
			action = function()
				Remotes.Travel:FireServer("Sell")
			end,
		},
		{
			text = "Bag",
			color = Ui.Colors.Info,
			action = function()
				Windows.toggle("Inventory")
			end,
		},
	}
	for order, entry in entries do
		local button = Ui.button(entry.text, entry.color, {
			Size = UDim2.fromOffset(MENU_BUTTON_SIZE, MENU_BUTTON_SIZE),
			LayoutOrder = order,
			Parent = menu,
		})
		button.Activated:Connect(entry.action)
	end
end

function Hud.Start()
	-- We use our own hotbar, so hide Roblox's default (empty) backpack bar.
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	local gui = Ui.screenGui("Hud")
	buildStatus(gui)
	buildMenu(gui)

	-- Scrolls sideways when a player owns more seed types than fit. Kept to the
	-- middle of the screen so the mobile thumbstick and jump button stay free.
	hotbar = Ui.create("ScrollingFrame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		-- Narrower on computers so it clears the bottom-left status panel.
		Size = UDim2.new(if isTouchOnly() then 0.62 else 0.5, 0, 0, SLOT_SIZE + 16),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 4,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local index = NUMBER_KEYS[input.KeyCode]
		if index and slotTools[index] then
			State.select(slotTools[index])
		elseif input.KeyCode == Enum.KeyCode.B then
			Windows.toggle("Inventory")
		end
	end)

	State.Changed:Connect(function(state)
		renderTop(state)
		renderHotbar()
	end)
	State.SelectionChanged:Connect(renderHotbar)

	task.spawn(function()
		while true do
			local state = State.current
			if state then
				local left = state.shop.restockAt - Workspace:GetServerTimeNow()
				restockLabel.Text = "New seeds in " .. Format.duration(left)
			end
			task.wait(0.25)
		end
	end)
end

return Hud

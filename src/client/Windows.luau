--!strict
-- Pop-up window manager. Every full-screen menu (Shop, Backpack, ...) is a
-- window; opening one closes the others, and each pops in with a bounce.

local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)

export type Window = {
	frame: Frame,
	content: Frame,
	onOpen: (() -> ())?,
}

local Windows = {}

local gui: ScreenGui? = nil
local windows: { [string]: Window } = {}
local openName: string? = nil

local function getGui(): ScreenGui
	if not gui then
		gui = Ui.screenGui("Windows", 5)
	end
	return gui :: ScreenGui
end

-- Builds a hidden window with a colored title bar and close button. Put the
-- window's contents inside the returned `content` frame.
function Windows.create(name: string, title: string, color: Color3, onOpen: (() -> ())?): Window
	local frame = Ui.create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.92, 0.74),
		BackgroundColor3 = Ui.Colors.Panel,
		Visible = false,
		Parent = getGui(),
	}, {
		Ui.corner(20),
		Ui.stroke(Ui.Colors.Outline, 3),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(620, 540) }),
		Ui.create("UIScale", {}),
	})

	local titleBar = Ui.create("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = color,
		Parent = frame,
	}, {
		Ui.corner(20),
		-- Square off the bar's bottom corners so it meets the body cleanly.
		Ui.create("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}),
		Ui.label({
			Position = UDim2.fromOffset(18, 8),
			Size = UDim2.new(1, -90, 0, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = title,
			ZIndex = 2,
		}),
	})

	local close = Ui.button("X", Ui.Colors.Bad, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(42, 42),
		ZIndex = 3,
		Parent = titleBar,
	})
	close.Activated:Connect(function()
		Windows.close(name)
	end)

	local content = Ui.create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(12, 66),
		Size = UDim2.new(1, -24, 1, -78),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	local window: Window = { frame = frame, content = content, onOpen = onOpen }
	windows[name] = window
	return window
end

function Windows.open(name: string)
	local window = windows[name]
	if not window then
		return
	end
	if openName and openName ~= name then
		Windows.close(openName)
	end
	openName = name
	if window.onOpen then
		window.onOpen()
	end
	local scale = window.frame:FindFirstChildWhichIsA("UIScale") :: UIScale
	scale.Scale = 0.85
	window.frame.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function Windows.close(name: string)
	local window = windows[name]
	if window then
		window.frame.Visible = false
	end
	if openName == name then
		openName = nil
	end
end

function Windows.toggle(name: string)
	if openName == name then
		Windows.close(name)
	else
		Windows.open(name)
	end
end

function Windows.isOpen(name: string): boolean
	return openName == name
end

return Windows

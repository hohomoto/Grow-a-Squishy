--!strict
-- UI kit: theme colors plus small builders for the pieces every screen uses
-- (buttons, labels, strokes, squishy icons). All UI is built in code so it
-- lives in Git; swap colors and fonts here to restyle the whole game.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Squishies = require(ReplicatedStorage.Shared.Config.Squishies)

local Ui = {}

Ui.Font = Enum.Font.FredokaOne
Ui.Colors = {
	Panel = Color3.fromRGB(255, 244, 250),
	PanelAlt = Color3.fromRGB(255, 228, 240),
	Outline = Color3.fromRGB(120, 60, 100),
	Accent = Color3.fromRGB(255, 110, 175),
	Good = Color3.fromRGB(80, 205, 120),
	Warn = Color3.fromRGB(255, 190, 60),
	Info = Color3.fromRGB(90, 170, 255),
	Bad = Color3.fromRGB(235, 80, 80),
	Muted = Color3.fromRGB(175, 160, 172),
	Text = Color3.fromRGB(80, 40, 70),
	Coin = Color3.fromRGB(255, 200, 40),
	White = Color3.new(1, 1, 1),
}

-- create("TextLabel", { Text = "hi", Parent = frame }, { Ui.corner() })
function Ui.create(className: string, props: { [string]: any }, children: { any }?): any
	local instance = Instance.new(className) :: any
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	-- Parent last so the instance renders fully configured.
	instance.Parent = parent
	return instance
end

function Ui.corner(radius: number?): Instance
	return Ui.create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Ui.stroke(color: Color3?, thickness: number?): Instance
	return Ui.create("UIStroke", {
		Color = color or Ui.Colors.Outline,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Vertical gradient that lightens the top of whatever it is applied to.
function Ui.shine(): Instance
	return Ui.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
	})
end

function Ui.padding(pixels: number): Instance
	local p = UDim.new(0, pixels)
	return Ui.create("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Ui.rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- Transparent, scaled, outlined text: the default look for game UI text.
function Ui.label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Ui.Colors.White,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Ui.Colors.Outline,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.create("TextLabel", defaults)
end

-- Squishes down while pressed, pops back on release.
function Ui.addPressEffect(button: GuiButton)
	local scale = button:FindFirstChildWhichIsA("UIScale") or Ui.create("UIScale", { Parent = button })
	local info = TweenInfo.new(0.08, Enum.EasingStyle.Quad)
	button.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			TweenService:Create(scale, info, { Scale = 0.9 }):Play()
		end
	end)
	button.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end)
end

-- Chunky candy button with a text label. Returns the button.
function Ui.button(text: string, color: Color3, props: { [string]: any }): TextButton
	local merged: { [string]: any } = { BackgroundColor3 = color, AutoButtonColor = true, Text = "" }
	for key, value in props do
		merged[key] = value
	end
	local button = Ui.create("TextButton", merged, {
		Ui.corner(10),
		Ui.stroke(Ui.Colors.Outline, 2),
		Ui.shine(),
		Ui.label({
			Name = "Label",
			Size = UDim2.new(1, -12, 1, -8),
			Position = UDim2.fromOffset(6, 4),
			Text = text,
		}),
	})
	Ui.addPressEffect(button)
	return button
end

-- Placeholder icon for a squishy: a glossy blob in its color and rough shape.
-- Replace with ImageLabels once icon art exists.
function Ui.squishyIcon(def: Squishies.SquishyDef, props: { [string]: any }): Frame
	local radius = if def.shape == "Ball" then UDim.new(0.5, 0) else UDim.new(0.25, 0)
	local merged: { [string]: any } = { BackgroundColor3 = Ui.rgb(def.color) }
	for key, value in props do
		merged[key] = value
	end
	return Ui.create("Frame", merged, {
		Ui.create("UICorner", { CornerRadius = radius }),
		Ui.stroke(Ui.Colors.Outline, 2),
		Ui.create("UIAspectRatioConstraint", {
			AspectRatio = if def.shape == "Cylinder" then 0.8 else 1,
		}),
		-- Highlight dot for a soft, shiny look.
		Ui.create("Frame", {
			Size = UDim2.fromScale(0.28, 0.2),
			Position = UDim2.fromScale(0.2, 0.16),
			BackgroundColor3 = Ui.Colors.White,
			BackgroundTransparency = if def.material == "Glass" or def.material == "Neon" then 0.2 else 0.45,
		}, { Ui.create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
	})
end

-- Removes every child except layouts, paddings and other UI modifiers.
function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

return Ui

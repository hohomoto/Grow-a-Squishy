--!strict
-- Short pop-up messages above the hotbar, from the server or local code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent.Ui)

local MAX_VISIBLE = 4
local LIFETIME = 3

local Toasts = {}

local container: Frame
local order = 0

function Toasts.show(message: string)
	order += 1
	local label = Ui.label({
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Ui.Colors.Outline,
		BackgroundTransparency = 0.15,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		Text = message,
		LayoutOrder = order,
		Parent = container,
	})
	Ui.corner(12).Parent = label
	Ui.create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = label })

	local visible = {}
	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(visible, child)
		end
	end
	table.sort(visible, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #visible - MAX_VISIBLE do
		visible[i]:Destroy()
	end

	task.delay(LIFETIME, function()
		if label.Parent then
			local tween = TweenService:Create(
				label,
				TweenInfo.new(0.4),
				{ TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 }
			)
			tween.Completed:Connect(function()
				label:Destroy()
			end)
			tween:Play()
		end
	end)
end

function Toasts.Start()
	local gui = Ui.screenGui("Toasts", 10)
	container = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.new(0.9, 0, 0, 170),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Ui.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 6),
		}),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge) }),
	})

	Remotes.Notify.OnClientEvent:Connect(Toasts.show)
end

return Toasts

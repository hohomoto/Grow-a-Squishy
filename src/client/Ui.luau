--!strict
-- Tiny helper for building placeholder UI in code, plus the shared theme.

local Ui = {}

Ui.Font = Enum.Font.FredokaOne
Ui.Colors = {
	Panel = Color3.fromRGB(255, 240, 246),
	PanelDark = Color3.fromRGB(70, 40, 60),
	Accent = Color3.fromRGB(255, 120, 180),
	Good = Color3.fromRGB(90, 200, 120),
	Muted = Color3.fromRGB(160, 150, 160),
	Text = Color3.fromRGB(60, 35, 55),
	White = Color3.new(1, 1, 1),
}

-- create("TextLabel", { Text = "hi", Parent = frame }, { create("UICorner", {}) })
function Ui.create(className: string, props: { [string]: any }, children: { Instance }?): any
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
	-- Parent last so the instance replicates/renders fully configured.
	instance.Parent = parent
	return instance
end

function Ui.corner(radius: number?): Instance
	return Ui.create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Ui.rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

return Ui

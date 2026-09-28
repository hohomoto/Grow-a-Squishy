--!strict
-- Building blocks for the procedural map. Everything is made from Roblox's
-- built-in parts, meshes and textures, so no uploaded assets are needed.

local Build = {}

local function apply(instance: Instance, props: { [string]: any }?)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
end

-- Anchored part with smooth surfaces. Parent is applied last.
function Build.part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	-- Classic Roblox plastic: flat colors with a subtle texture, like Grow a Garden.
	p.Material = Enum.Material.Plastic
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Purely decorative: no collisions, no raycast hits, no touch events.
function Build.decor(props: { [string]: any }): Part
	props.CanCollide = if props.CanCollide == nil then false else props.CanCollide
	props.CanQuery = false
	props.CanTouch = false
	return Build.part(props)
end

function Build.ball(
	parent: Instance,
	position: Vector3,
	diameter: number,
	color: Color3,
	props: { [string]: any }?
): Part
	local p = Build.decor({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		Position = position,
		Color = color,
	})
	apply(p, props)
	p.Parent = parent
	return p
end

-- A vertical cylinder standing on `base` (Roblox cylinders lie along X).
function Build.column(
	parent: Instance,
	base: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	props: { [string]: any }?
): Part
	local p = Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
	})
	apply(p, props)
	p.Parent = parent
	return p
end

-- A flat bar from `from` to `to` (used for fence rails and awning stripes).
function Build.beam(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	width: number,
	thickness: number,
	color: Color3,
	props: { [string]: any }?
): Part
	local p = Build.part({
		Size = Vector3.new(width, thickness, (to - from).Magnitude),
		CFrame = CFrame.lookAt((from + to) / 2, to),
		Color = color,
	})
	apply(p, props)
	p.Parent = parent
	return p
end

-- Floating sign. Keep maxDistance small for signs that repeat (plots), so
-- the screen doesn't fill up with far-away labels.
function Build.billboard(
	parent: Instance,
	text: string,
	height: number,
	width: number?,
	maxDistance: number?
): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(width or 240, 60)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = maxDistance or 120
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(120, 60, 100)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
end

-- Lighter version of a color, for trims and highlights.
function Build.tint(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

return Build

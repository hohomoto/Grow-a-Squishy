--!strict
-- Building blocks for the procedural map. Everything is made from Roblox's
-- built-in parts, meshes and textures, so no uploaded assets are needed.

local Build = {}

-- Roblox's classic smiley, shipped with every client (no upload needed).
local FACE_TEXTURE = "rbxasset://textures/face.png"

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
	p.Material = Enum.Material.SmoothPlastic
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

-- Puts a smiley face on the part's Front (-Z) side.
function Build.face(p: BasePart)
	local decal = Instance.new("Decal")
	decal.Name = "Face"
	decal.Face = Enum.NormalId.Front
	decal.Texture = FACE_TEXTURE
	decal.Parent = p
end

-- A soft, rounded squishy with a face, sitting on `ground` and looking at
-- `lookAt`. `proportions` stretches it (x = width, y = height, z = depth).
function Build.squishy(
	parent: Instance,
	ground: Vector3,
	size: number,
	color: Color3,
	lookAt: Vector3,
	proportions: Vector3?
): Part
	local shape = proportions or Vector3.new(1, 0.85, 1)
	local partSize = shape * size
	local center = ground + Vector3.new(0, partSize.Y / 2, 0)
	local flatTarget = Vector3.new(lookAt.X, center.Y, lookAt.Z)
	local p = Build.decor({
		Size = partSize,
		CFrame = if (flatTarget - center).Magnitude > 0.01
			then CFrame.lookAt(center, flatTarget)
			else CFrame.new(center),
		Color = color,
		CanCollide = true,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Parent = p
	Build.face(p)
	p.Parent = parent
	return p
end

function Build.billboard(parent: Instance, text: string, height: number, width: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(width or 240, 60)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 180
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

--!strict
-- Builds each plant family as a multi-part 3D model from built-in parts and
-- meshes (no uploaded assets).
--
-- Every model is built at full size, standing on the origin and facing -Z,
-- with an invisible "Root" part at ground level as its PrimaryPart. The
-- client records each part's offset from Root once, then scales the whole
-- model around Root to animate growth (see PlantVisuals).
--
-- Parts that should take on mutation colors carry a "Shade" attribute: 0 is
-- the plant's own color, positive lightens it, negative darkens it. Parts
-- without Shade (eyes, blush, rainbow bubbles) keep their color.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Squishies = require(ReplicatedStorage.Shared.Config.Squishies)

local SquishyModels = {}

-- Keycaps on a plot spell out letters in tile order.
local KEY_LETTERS = "ASMRQWERTYUIOPDFGHJKLZXCVBN"

local INK = Color3.fromRGB(40, 25, 35)
local WHITE = Color3.new(1, 1, 1)
local BLUSH = Color3.fromRGB(255, 130, 160)

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- The plant's color adjusted by a shade (-1 darkest .. 1 white).
function SquishyModels.shade(color: Color3, shade: number): Color3
	if shade >= 0 then
		return color:Lerp(WHITE, shade)
	end
	return color:Lerp(Color3.new(0, 0, 0), -shade)
end

type PartOptions = {
	shape: "Block" | "Ball" | "Sphere" | "Cylinder",
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shade: number?,
	material: Enum.Material?,
	transparency: number?,
	name: string?,
}

-- Adds one anchored, non-colliding part to the model.
local function add(model: Model, options: PartOptions): Part
	local part = Instance.new("Part")
	part.Name = options.name or "Piece"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = options.material or Enum.Material.SmoothPlastic
	part.Transparency = options.transparency or 0
	if options.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif options.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif options.shape == "Sphere" then
		-- A mesh sphere can be stretched into an ellipsoid; a Ball part can't.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Size = options.size
	part.CFrame = options.cframe
	if options.shade then
		part.Color = SquishyModels.shade(options.color, options.shade)
		part:SetAttribute("Shade", options.shade)
	else
		part.Color = options.color
	end
	part.Parent = model
	return part
end

local function newModel(): (Model, Part)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Transparency = 1
	root.Size = Vector3.new(1, 0.2, 1)
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root
	-- Stream the whole plant at once so clients never see half a model.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model, root
end

-- Kawaii face on an ellipsoid (center, radii), facing -Z: shiny eyes, a
-- little smile and rosy cheeks, all sitting on the curved surface.
local function curvedFace(model: Model, center: Vector3, radii: Vector3, scale: number)
	-- Point on the ellipsoid at yaw `yaw` and pitch `pitch` from straight ahead.
	local function surfacePoint(yaw: number, pitch: number): (Vector3, Vector3)
		local offset = Vector3.new(
			radii.X * math.cos(pitch) * math.sin(yaw),
			radii.Y * math.sin(pitch),
			-radii.Z * math.cos(pitch) * math.cos(yaw)
		)
		local normal = Vector3.new(
			offset.X / (radii.X * radii.X),
			offset.Y / (radii.Y * radii.Y),
			offset.Z / (radii.Z * radii.Z)
		).Unit
		return center + offset, normal
	end

	for _, side in { -1, 1 } do
		local eye, normal = surfacePoint(side * 0.3, 0.14)
		add(model, { shape = "Ball", size = Vector3.one * 0.12 * scale, cframe = CFrame.new(eye), color = INK })
		add(model, {
			shape = "Ball",
			size = Vector3.one * 0.045 * scale,
			cframe = CFrame.new(eye + normal * 0.045 * scale + Vector3.new(side * -0.012, 0.022, 0) * scale),
			color = WHITE,
		})

		local cheek, cheekNormal = surfacePoint(side * 0.52, 0.0)
		add(model, {
			shape = "Cylinder",
			-- Cylinders run along X; turn X to point out of the surface.
			size = Vector3.new(0.012 * scale, 0.13 * scale, 0.13 * scale),
			cframe = CFrame.lookAt(cheek + cheekNormal * 0.004 * scale, cheek + cheekNormal * 2)
				* CFrame.Angles(0, math.pi / 2, 0),
			color = BLUSH,
			transparency = 0.15,
		})
	end
	-- Smile: three small beads in an arc.
	for i, yaw in { -0.07, 0, 0.07 } do
		local pitch = if i == 2 then -0.06 else -0.03
		local point = surfacePoint(yaw, pitch)
		add(model, { shape = "Ball", size = Vector3.one * 0.04 * scale, cframe = CFrame.new(point), color = INK })
	end
end

-- Flat-front version of the face for cubes.
local function flatFace(model: Model, frontCenter: Vector3, scale: number)
	for _, side in { -1, 1 } do
		local eye = frontCenter + Vector3.new(side * 0.16, 0.06, 0) * scale
		add(model, { shape = "Ball", size = Vector3.one * 0.12 * scale, cframe = CFrame.new(eye), color = INK })
		add(model, {
			shape = "Ball",
			size = Vector3.one * 0.045 * scale,
			cframe = CFrame.new(eye + Vector3.new(side * -0.012, 0.022, -0.045) * scale),
			color = WHITE,
		})
		add(model, {
			shape = "Cylinder",
			size = Vector3.new(0.012 * scale, 0.12 * scale, 0.12 * scale),
			cframe = CFrame.lookAt(
				frontCenter + Vector3.new(side * 0.28, -0.04, -0.004) * scale,
				frontCenter + Vector3.new(side * 0.28, -0.04, -2) * scale
			) * CFrame.Angles(0, math.pi / 2, 0),
			color = BLUSH,
			transparency = 0.15,
		})
	end
	for i, x in { -0.05, 0, 0.05 } do
		local y = if i == 2 then -0.06 else -0.045
		add(model, {
			shape = "Ball",
			size = Vector3.one * 0.04 * scale,
			cframe = CFrame.new(frontCenter + Vector3.new(x, y, 0) * scale),
			color = INK,
		})
	end
end

local function surfaceText(part: BasePart, face: Enum.NormalId, canvas: Vector2, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = canvas
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.8, 0.6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

-- Steamed bun: a domed body, pleats twisting into a knob on top, and a face.
local function bao(model: Model, def: Squishies.SquishyDef, s: number, material: Enum.Material)
	local color = rgb(def.color)
	local radii = Vector3.new(0.5, 0.34, 0.5) * s
	-- Sunk slightly into the soil so it sits flat, like a real bun.
	local center = Vector3.new(0, 0.26 * s, 0)
	add(model, {
		name = "Body",
		shape = "Sphere",
		size = radii * 2,
		cframe = CFrame.new(center),
		color = color,
		shade = 0,
		material = material,
	})

	local top = center + Vector3.new(0, radii.Y - 0.02 * s, 0)
	for i = 0, 6 do
		local angle = i / 7 * math.pi * 2
		local petal = top + Vector3.new(math.cos(angle) * 0.1, -0.03, math.sin(angle) * 0.1) * s
		add(model, {
			shape = "Sphere",
			size = Vector3.new(0.07, 0.06, 0.22) * s,
			cframe = CFrame.lookAt(petal, top + Vector3.new(0, 0.07 * s, 0)),
			color = color,
			shade = -0.1,
			material = material,
		})
	end
	add(model, {
		shape = "Ball",
		size = Vector3.one * 0.11 * s,
		cframe = CFrame.new(top + Vector3.new(0, 0.03 * s, 0)),
		color = color,
		shade = 0.12,
		material = material,
	})
	curvedFace(model, center, radii, s)
end

-- Jelly squish cube with a face on the front.
local function cube(model: Model, def: Squishies.SquishyDef, s: number, material: Enum.Material)
	local side = 0.85 * s
	add(model, {
		name = "Body",
		shape = "Block",
		size = Vector3.one * side,
		cframe = CFrame.new(0, side / 2, 0),
		color = rgb(def.color),
		shade = 0,
		material = material,
		transparency = if def.material == "Glass" then 0.25 else 0,
	})
	flatFace(model, Vector3.new(0, side * 0.5, -side / 2), s)
end

-- Butter stick with a paper wrapper band and a printed label.
local function butter(model: Model, def: Squishies.SquishyDef, s: number, material: Enum.Material)
	local size = Vector3.new(1.4, 0.5, 0.65) * s
	local body = add(model, {
		name = "Body",
		shape = "Block",
		size = size,
		cframe = CFrame.new(0, size.Y / 2, 0),
		color = rgb(def.color),
		shade = 0,
		material = material,
	})
	-- Paper wrapper around the middle, printed with the label.
	local wrapper = add(model, {
		name = "Wrapper",
		shape = "Block",
		size = Vector3.new(size.X * 0.62, size.Y + 0.02 * s, size.Z + 0.02 * s),
		cframe = body.CFrame,
		color = Color3.fromRGB(250, 248, 240),
	})
	local labelColor = if def.accent then rgb(def.accent) else INK
	surfaceText(
		wrapper,
		Enum.NormalId.Front,
		Vector2.new(size.X * 0.62, size.Y) * 100,
		def.label or "BUTTER",
		labelColor
	)
end

-- Two-tier keyboard keycap with a letter on top.
local function keycap(model: Model, def: Squishies.SquishyDef, s: number, material: Enum.Material, tileIndex: number)
	local color = rgb(def.color)
	add(model, {
		name = "Body",
		shape = "Block",
		size = Vector3.new(1, 0.36, 1) * s,
		cframe = CFrame.new(0, 0.18 * s, 0),
		color = color,
		shade = -0.12,
		material = material,
		transparency = if def.material == "Glass" then 0.2 else 0,
	})
	local cap = add(model, {
		name = "Cap",
		shape = "Block",
		size = Vector3.new(0.78, 0.26, 0.78) * s,
		cframe = CFrame.new(0, 0.49 * s, 0),
		color = color,
		shade = 0.1,
		material = material,
		transparency = if def.material == "Glass" then 0.2 else 0,
	})
	local index = (tileIndex - 1) % #KEY_LETTERS + 1
	surfaceText(
		cap,
		Enum.NormalId.Top,
		Vector2.new(100, 100),
		string.sub(KEY_LETTERS, index, index),
		if def.accent then rgb(def.accent) else INK
	)
end

-- Glossy slime puddle-dome with shiny highlights.
local function slime(model: Model, def: Squishies.SquishyDef, s: number, material: Enum.Material)
	local radii = Vector3.new(0.5, 0.26, 0.5) * s
	local center = Vector3.new(0, 0.12 * s, 0)
	add(model, {
		name = "Body",
		shape = "Sphere",
		size = radii * 2,
		cframe = CFrame.new(center),
		color = rgb(def.color),
		shade = 0,
		material = material,
		transparency = if def.material == "Glass" then 0.2 else 0,
	})
	-- Little blobs oozing out around the edge.
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2 + 0.4
		add(model, {
			shape = "Sphere",
			size = Vector3.new(0.22, 0.12, 0.22) * s,
			cframe = CFrame.new(Vector3.new(math.cos(angle) * 0.42, 0.03, math.sin(angle) * 0.42) * s),
			color = rgb(def.color),
			shade = -0.05,
			material = material,
			transparency = if def.material == "Glass" then 0.2 else 0,
		})
	end
	for _, spot in { Vector3.new(-0.14, 0.34, -0.12), Vector3.new(0.1, 0.36, 0.05) } do
		add(model, { shape = "Ball", size = Vector3.one * 0.08 * s, cframe = CFrame.new(spot * s), color = WHITE })
	end
end

-- Pop-it pad with a 4x4 grid of half-sphere bubbles.
local function popit(model: Model, def: Squishies.SquishyDef, s: number, material: Enum.Material)
	local color = rgb(def.color)
	local thickness = 0.16 * s
	add(model, {
		name = "Body",
		shape = "Block",
		size = Vector3.new(1, 0.16, 1) * s,
		cframe = CFrame.new(0, thickness / 2, 0),
		color = color,
		shade = 0,
		material = material,
	})
	for row = 1, 4 do
		for column = 1, 4 do
			local position = Vector3.new(-0.36 + (column - 1) * 0.24, 0.16, -0.36 + (row - 1) * 0.24) * s
			add(model, {
				shape = "Ball",
				size = Vector3.one * 0.2 * s,
				cframe = CFrame.new(position),
				-- Rainbow pop-its keep fixed row colors; others follow the plant color.
				color = if def.rainbow then Color3.fromHSV((row - 1) / 4, 0.5, 1) else color,
				shade = if def.rainbow then nil else -0.12,
				material = material,
			})
		end
	end
end

-- Returns an unparented model of `def` at full size `s` (studs), standing on
-- the origin and facing -Z.
function SquishyModels.create(def: Squishies.SquishyDef, tileIndex: number, s: number): Model
	local model = newModel()
	local material = (Enum.Material :: any)[def.material] :: Enum.Material
	if def.kind == "bao" then
		bao(model, def, s, material)
	elseif def.kind == "cube" then
		cube(model, def, s, material)
	elseif def.kind == "butter" then
		butter(model, def, s, material)
	elseif def.kind == "keycap" then
		keycap(model, def, s, material, tileIndex)
	elseif def.kind == "slime" then
		slime(model, def, s, material)
	else
		popit(model, def, s, material)
	end
	return model
end

-- A big decorative bao (fountain topper, statues), standing on `ground` and
-- looking toward `lookAt`.
function SquishyModels.statue(parent: Instance, ground: Vector3, size: number, color: Color3, lookAt: Vector3): Model
	local model = newModel()
	model.Name = "BaoStatue"
	local fakeDef = { color = { color.R * 255, color.G * 255, color.B * 255 } } :: any
	bao(model, fakeDef, size, Enum.Material.SmoothPlastic)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
		end
	end
	local target = Vector3.new(lookAt.X, ground.Y, lookAt.Z)
	model:PivotTo(if (target - ground).Magnitude > 0.01 then CFrame.lookAt(ground, target) else CFrame.new(ground))
	model.Parent = parent
	return model
end

return SquishyModels

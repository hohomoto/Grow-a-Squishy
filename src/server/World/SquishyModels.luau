--!strict
-- Builds the 3D look of each plant family from a single part plus built-in
-- meshes and SurfaceGuis (no uploaded assets). Everything is drawn relative
-- to the part's faces, so it scales automatically as the client grows the
-- part.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Squishies = require(ReplicatedStorage.Shared.Config.Squishies)

local SquishyModels = {}

-- Width / height / depth of each family at size 1. The client multiplies
-- these by the growth size every frame.
SquishyModels.Proportions = {
	bao = Vector3.new(1, 0.8, 1),
	cube = Vector3.new(0.9, 0.9, 0.9),
	butter = Vector3.new(1.45, 0.55, 0.7),
	keycap = Vector3.new(1, 0.6, 1),
	slime = Vector3.new(1, 0.6, 1),
	popit = Vector3.new(1, 0.22, 1),
} :: { [string]: Vector3 }

-- Keycaps on a plot spell out letters in tile order.
local KEY_LETTERS = "ASMRQWERTYUIOPDFGHJKLZXCVBN"

local BLACK = Color3.fromRGB(40, 25, 35)
local BLUSH = Color3.fromRGB(255, 130, 160)

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function round(parent: Instance, frame: GuiObject, scale: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(scale or 0.5, 0)
	corner.Parent = frame
	frame.Parent = parent
end

local function dot(parent: Instance, position: UDim2, size: UDim2, color: Color3, transparency: number?): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	round(parent, frame)
	return frame
end

local function surface(part: BasePart, face: Enum.NormalId, canvas: Vector2): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	-- Canvas matches the face's aspect ratio so circles stay round.
	gui.CanvasSize = canvas
	gui.LightInfluence = 0.6
	gui.Parent = part
	return gui
end

-- Kawaii face (eyes with shine, little smile, rosy cheeks) on the Front face.
local function kawaiiFace(part: BasePart, faceWidth: number, faceHeight: number)
	local gui = surface(part, Enum.NormalId.Front, Vector2.new(faceWidth, faceHeight) * 100)
	gui.Name = "Face"
	-- Square holder in the middle so the face keeps its proportions.
	local side = math.min(faceWidth, faceHeight) * 100 * 0.8
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.55)
	holder.Size = UDim2.fromOffset(side, side)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	for _, x in { 0.3, 0.7 } do
		local eye = dot(holder, UDim2.fromScale(x, 0.42), UDim2.fromScale(0.15, 0.19), BLACK)
		dot(eye, UDim2.fromScale(0.35, 0.3), UDim2.fromScale(0.4, 0.35), Color3.new(1, 1, 1))
	end
	dot(holder, UDim2.fromScale(0.5, 0.6), UDim2.fromScale(0.14, 0.07), BLACK)
	for _, x in { 0.14, 0.86 } do
		dot(holder, UDim2.fromScale(x, 0.6), UDim2.fromScale(0.2, 0.11), BLUSH, 0.3)
	end
end

local function butterLabel(part: BasePart, def: Squishies.SquishyDef, proportions: Vector3)
	local gui = surface(part, Enum.NormalId.Front, Vector2.new(proportions.X, proportions.Y) * 100)
	gui.Name = "ButterLabel"
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	text.Size = UDim2.fromScale(0.8, 0.55)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = if def.accent then rgb(def.accent) else BLACK
	text.Text = def.label or "BUTTER"
	text.Parent = gui
end

local function keycapTop(part: BasePart, def: Squishies.SquishyDef, tileIndex: number)
	local gui = surface(part, Enum.NormalId.Top, Vector2.new(100, 100))
	gui.Name = "Keycap"
	local color = rgb(def.color)
	local dish = Instance.new("Frame")
	dish.AnchorPoint = Vector2.new(0.5, 0.5)
	dish.Position = UDim2.fromScale(0.5, 0.5)
	dish.Size = UDim2.fromScale(0.74, 0.74)
	dish.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.25)
	dish.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.25)
	stroke.Thickness = 3
	stroke.Parent = dish
	round(gui, dish, 0.18)

	local index = (tileIndex - 1) % #KEY_LETTERS + 1
	local letter = Instance.new("TextLabel")
	letter.Size = UDim2.fromScale(1, 1)
	letter.BackgroundTransparency = 1
	letter.Font = Enum.Font.FredokaOne
	letter.TextScaled = true
	letter.TextColor3 = if def.accent then rgb(def.accent) else BLACK
	letter.Text = string.sub(KEY_LETTERS, index, index)
	letter.Parent = dish
end

-- A big decorative bao with a face, sitting on `ground` and looking toward
-- `lookAt` (used for statues and the shop mascot).
function SquishyModels.statue(parent: Instance, ground: Vector3, size: number, color: Color3, lookAt: Vector3): Part
	local proportions = SquishyModels.Proportions.bao
	local partSize = proportions * size
	local center = ground + Vector3.new(0, partSize.Y / 2, 0)
	local target = Vector3.new(lookAt.X, center.Y, lookAt.Z)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = partSize
	part.CFrame = if (target - center).Magnitude > 0.01 then CFrame.lookAt(center, target) else CFrame.new(center)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanQuery = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Parent = part
	kawaiiFace(part, proportions.X, proportions.Y)
	part.Parent = parent
	return part
end

-- Glossy highlights on top of a slime blob.
local function slimeShine(part: BasePart)
	local gui = surface(part, Enum.NormalId.Top, Vector2.new(100, 100))
	gui.Name = "Shine"
	dot(gui, UDim2.fromScale(0.35, 0.32), UDim2.fromScale(0.28, 0.16), Color3.new(1, 1, 1), 0.35)
	dot(gui, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.12, 0.12), Color3.new(1, 1, 1), 0.45)
	dot(gui, UDim2.fromScale(0.3, 0.66), UDim2.fromScale(0.08, 0.08), Color3.new(1, 1, 1), 0.5)
end

-- 4x4 grid of pop-it bubbles on the top face.
local function popitBubbles(part: BasePart, def: Squishies.SquishyDef)
	local gui = surface(part, Enum.NormalId.Top, Vector2.new(100, 100))
	gui.Name = "Bubbles"
	local base = rgb(def.color)
	for row = 1, 4 do
		local rowColor = if def.rainbow then Color3.fromHSV((row - 1) / 4, 0.45, 1) else base
		for column = 1, 4 do
			local position = UDim2.fromScale(0.14 + (column - 1) * 0.24, 0.14 + (row - 1) * 0.24)
			local bubble = dot(gui, position, UDim2.fromScale(0.19, 0.19), rowColor:Lerp(Color3.new(0, 0, 0), 0.12))
			local stroke = Instance.new("UIStroke")
			stroke.Color = rowColor:Lerp(Color3.new(0, 0, 0), 0.3)
			stroke.Thickness = 2
			stroke.Parent = bubble
			dot(bubble, UDim2.fromScale(0.35, 0.3), UDim2.fromScale(0.35, 0.3), Color3.new(1, 1, 1), 0.3)
		end
	end
end

-- Returns an unparented, anchored part dressed as `def`. The caller sets its
-- size and position.
function SquishyModels.create(def: Squishies.SquishyDef, tileIndex: number): Part
	local proportions = SquishyModels.Proportions[def.kind]
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = rgb(def.color)
	part.Material = (Enum.Material :: any)[def.material]
	if def.material == "Glass" then
		-- See-through jelly.
		part.Transparency = 0.25
	end

	if def.kind == "bao" then
		-- The classic Head mesh gives a soft, rounded bun shape.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Parent = part
		kawaiiFace(part, proportions.X, proportions.Y)
	elseif def.kind == "cube" then
		kawaiiFace(part, proportions.X, proportions.Y)
	elseif def.kind == "butter" then
		butterLabel(part, def, proportions)
	elseif def.kind == "keycap" then
		keycapTop(part, def, tileIndex)
	elseif def.kind == "slime" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Parent = part
		slimeShine(part)
	elseif def.kind == "popit" then
		popitBubbles(part, def)
	end
	return part
end

return SquishyModels

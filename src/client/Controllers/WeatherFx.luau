--!strict
-- Client side of weather: announcement banner, countdown pill, falling
-- particles around the camera, a screen tint, night sky for Starfall, and
-- the shooting-star strikes. Everything here is local; the server only
-- publishes Workspace attributes (Weather, WeatherEndsAt) and StarStrike.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Weather = require(Shared.Config.Weather)
local Hud = require(script.Parent.Hud)
local Sfx = require(script.Parent.Parent.Sfx)
local Ui = require(script.Parent.Parent.Ui)

local EMITTER_HEIGHT = 45
local STAR_FALL_TIME = 1.2
local NIGHT_CLOCK = 21

local WeatherFx = {}

local banner: Frame
local bannerTitle: TextLabel
local bannerText: TextLabel
local pill: Frame
local pillLabel: TextLabel
local tint: ColorCorrectionEffect
local emitterPart: Part
local emitter: ParticleEmitter
local dayClock = Lighting.ClockTime

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- Configures the camera-following emitter for a weather type.
local function configureParticles(id: string)
	emitter.Squash = NumberSequence.new(0)
	emitter.Acceleration = Vector3.zero
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.LightEmission = 0.3
	emitter.Transparency = NumberSequence.new(0.1)
	emitter.RotSpeed = NumberRange.new(0)
	if id == "SlimeRain" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(140, 240, 100))
		emitter.Size = NumberSequence.new(0.25)
		emitter.Squash = NumberSequence.new(2.5)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Speed = NumberRange.new(60, 70)
		emitter.Lifetime = NumberRange.new(0.9, 1.1)
		emitter.Rate = 350
	elseif id == "FreezeSnap" then
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
		emitter.Size = NumberSequence.new(0.35)
		emitter.Speed = NumberRange.new(8, 12)
		emitter.Lifetime = NumberRange.new(4, 5)
		emitter.SpreadAngle = Vector2.new(35, 35)
		emitter.RotSpeed = NumberRange.new(-60, 60)
		emitter.Rate = 250
	elseif id == "GlitterStorm" then
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 150, 220), Color3.fromRGB(255, 225, 120))
		emitter.Size = NumberSequence.new(0.3, 0.1)
		emitter.Speed = NumberRange.new(10, 16)
		emitter.Lifetime = NumberRange.new(3, 4)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.LightEmission = 1
		emitter.Rate = 220
	elseif id == "Starfall" then
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 150, 255))
		emitter.Size = NumberSequence.new(0.6, 0.2)
		emitter.Squash = NumberSequence.new(3)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Speed = NumberRange.new(70, 90)
		emitter.Lifetime = NumberRange.new(1, 1.5)
		emitter.LightEmission = 1
		emitter.Rate = 10
	end
end

local function showBanner(def: Weather.WeatherDef)
	bannerTitle.Text = string.upper(def.name)
	bannerTitle.TextColor3 = rgb(def.tint)
	bannerText.Text = def.message
	local scale = banner:FindFirstChildWhichIsA("UIScale") :: UIScale
	scale.Scale = 0.3
	banner.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(4.5, function()
		local out = TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 })
		out.Completed:Connect(function()
			banner.Visible = false
		end)
		out:Play()
	end)
end

local function applyWeather()
	local id = Workspace:GetAttribute("Weather")
	local def = if type(id) == "string" then Weather.ById[id] else nil
	local fade = TweenInfo.new(2)
	if def then
		configureParticles(def.id)
		emitter.Enabled = true
		pill.Visible = true
		TweenService:Create(tint, fade, { TintColor = rgb(def.tint) }):Play()
		local clock = if def.id == "Starfall" then NIGHT_CLOCK else dayClock
		TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = clock }):Play()
		showBanner(def)
		Sfx.play("Weather")
	else
		emitter.Enabled = false
		pill.Visible = false
		TweenService:Create(tint, fade, { TintColor = Color3.new(1, 1, 1) }):Play()
		TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = dayClock }):Play()
	end
end

-- A shooting star streaks down onto `target` and bursts.
local function starStrike(target: Vector3)
	local camera = Workspace.CurrentCamera
	local star = Instance.new("Part")
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.one * 1.6
	star.Material = Enum.Material.Neon
	star.Color = Color3.fromRGB(230, 210, 255)
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.CastShadow = false
	star.Position = target + Vector3.new(-45, 140, 35)

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.7, 0)
	a0.Parent = star
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.7, 0)
	a1.Parent = star
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.45
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 120, 255))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = star

	local light = Instance.new("PointLight")
	light.Color = star.Color
	light.Range = 18
	light.Brightness = 2
	light.Parent = star
	star.Parent = camera
	Sfx.play("Star", star)

	local fall =
		TweenService:Create(star, TweenInfo.new(STAR_FALL_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = target,
		})
	fall.Completed:Connect(function()
		local burst = Instance.new("ParticleEmitter")
		burst.Color = trail.Color
		burst.LightEmission = 1
		burst.Size = NumberSequence.new(0.6, 0)
		burst.Speed = NumberRange.new(8, 18)
		burst.Lifetime = NumberRange.new(0.5, 1)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Rate = 0
		burst.Parent = star
		burst:Emit(40)
		star.Transparency = 1
		task.delay(1.2, function()
			star:Destroy()
		end)
	end)
	fall:Play()
end

local function buildUi()
	local gui = Ui.screenGui("Weather", 8)

	banner = Ui.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(460, 96),
		BackgroundColor3 = Ui.Colors.Outline,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, {
		Ui.corner(18),
		Ui.stroke(Ui.Colors.White, 3),
		Ui.create("UIScale", {}),
		Ui.create("UISizeConstraint", { MaxSize = Vector2.new(460, 96) }),
	})
	bannerTitle = Ui.label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 46),
		Text = "",
		Parent = banner,
	})
	bannerText = Ui.label({
		Position = UDim2.fromOffset(12, 58),
		Size = UDim2.new(1, -24, 0, 26),
		Text = "",
		Parent = banner,
	})

	-- Countdown row at the top of the HUD's status panel.
	pill = Ui.create("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Ui.Colors.Accent,
		BackgroundTransparency = 0.1,
		LayoutOrder = 0,
		Visible = false,
		Parent = Hud.getStatusStack(),
	}, { Ui.corner(14), Ui.stroke(Ui.Colors.Outline, 2) })
	pillLabel = Ui.label({
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		Text = "",
		Parent = pill,
	})
end

function WeatherFx.Start()
	buildUi()

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "WeatherTint"
	tint.Parent = Lighting

	emitterPart = Instance.new("Part")
	emitterPart.Name = "WeatherEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(140, 1, 140)
	emitterPart.Parent = Workspace.CurrentCamera
	emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Enabled = false
	emitter.Parent = emitterPart

	-- Keep the emitter above the camera so weather surrounds the player.
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera then
			emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, EMITTER_HEIGHT, 0))
		end
	end)

	Workspace:GetAttributeChangedSignal("Weather"):Connect(applyWeather)
	Remotes.StarStrike.OnClientEvent:Connect(starStrike)
	applyWeather()

	task.spawn(function()
		while true do
			local id = Workspace:GetAttribute("Weather")
			local endsAt = Workspace:GetAttribute("WeatherEndsAt")
			local def = if type(id) == "string" then Weather.ById[id] else nil
			if def and type(endsAt) == "number" then
				pillLabel.Text = `{def.name} · {Format.duration(endsAt - Workspace:GetServerTimeNow())}`
			end
			task.wait(0.25)
		end
	end)
end

return WeatherFx

--!strict
-- AvalancheFX: camera shake scaled by the avalanche gap, plus camera-following snowfall
-- that thickens and blows downhill as the wall closes in.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.ClientState)

local SHAKE_START = 55 -- studs; no shake beyond this gap
local MAX_SHAKE = 0.55

local AvalancheFX = {}

function AvalancheFX.init()
	local snowPart = Instance.new("Part")
	snowPart.Name = "LocalSnowfall"
	snowPart.Anchored = true
	snowPart.CanCollide = false
	snowPart.CanQuery = false
	snowPart.CanTouch = false
	snowPart.Transparency = 1
	snowPart.Size = Vector3.new(70, 1, 70)
	snowPart.Parent = Workspace

	local snow = Instance.new("ParticleEmitter")
	snow.Name = "Snow"
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	snow.Rate = 14
	snow.Lifetime = NumberRange.new(4, 6)
	snow.Speed = NumberRange.new(4, 7)
	snow.Size = NumberSequence.new(0.22)
	snow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.15),
		NumberSequenceKeypoint.new(0.85, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	snow.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
	snow.LightEmission = 0.3
	snow.RotSpeed = NumberRange.new(-90, 90)
	snow.Parent = snowPart

	RunService:BindToRenderStep("AvalancheFX", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		snowPart.CFrame = CFrame.new(camPos + Vector3.new(0, 20, -10))

		local closeness = 0
		if ClientState.inRace and ClientState.state == "Running" then
			closeness = math.clamp(1 - ClientState.gap / SHAKE_START, 0, 1)
		end
		snow.Rate = 14 + closeness * 170
		snow.Acceleration = Vector3.new(0, -1, 30 * closeness)

		if closeness > 0 then
			local amplitude = closeness * closeness * MAX_SHAKE
			local t = os.clock() * 16
			local offset = Vector3.new(math.noise(t, 0.3, 0), math.noise(0.7, t, 0), 0) * amplitude
			local roll = math.noise(0, 0, t) * amplitude * 0.04
			camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, roll)
		end
	end)
end

return AvalancheFX

--!strict
-- JuiceController: screen-feel for the big moments. Purely visual and local.
--   bigToss    slow-mo: cinematic bars, FOV zoom, punchy colour, music dips (see AudioController)
--   toss/catch small FOV pops
--   go         FOV punch + shake
--   checkpoint gold flash
--   puff       white flash + shake
--   caught     whiteout, big shake, colour drains
--   gate       gold flash + pop

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent.ClientState)
local AudioController = require(script.Parent.AudioController)

local LocalPlayer = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 209, 102)
local WHITE = Color3.fromRGB(255, 255, 255)
local BASE_FOV = 70
local BAR_HEIGHT = 0.1

local JuiceController = {}

local topBar: Frame
local bottomBar: Frame
local flash: Frame
local cc: ColorCorrectionEffect
local shakeAmount = 0
local fovToken = 0

local function tween(instance: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function camera(): Camera?
	return Workspace.CurrentCamera
end

-- Zoom the FOV to `target`, hold, then ease back to normal.
local function fovKick(target: number, inTime: number, hold: number, outTime: number)
	local cam = camera()
	if not cam then
		return
	end
	fovToken += 1
	local token = fovToken
	tween(cam, inTime, { FieldOfView = target }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(inTime + hold, function()
		if token == fovToken and camera() then
			tween(camera() :: Camera, outTime, { FieldOfView = BASE_FOV }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end
	end)
end

local function doFlash(color: Color3, startTransparency: number, fadeTime: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = startTransparency
	tween(flash, fadeTime, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

local function letterbox(show: boolean, seconds: number)
	tween(topBar, seconds, { Position = UDim2.fromScale(0, if show then 0 else -BAR_HEIGHT) })
	tween(bottomBar, seconds, { Position = UDim2.fromScale(0, if show then 1 - BAR_HEIGHT else 1) })
end

local function grade(saturation: number, contrast: number, tint: Color3, seconds: number)
	tween(cc, seconds, { Saturation = saturation, Contrast = contrast, TintColor = tint })
end

local function slowMo()
	letterbox(true, 0.15)
	fovKick(56, 0.15, 0.45, 0.35)
	grade(0.35, 0.15, Color3.fromRGB(255, 240, 220), 0.15)
	AudioController.slowmo(0.75)
	task.delay(0.65, function()
		letterbox(false, 0.3)
		grade(0, 0, WHITE, 0.35)
	end)
end

local function caught()
	doFlash(WHITE, 0.05, 0.9)
	shake(1.4)
	fovKick(60, 0.1, 0.4, 0.8)
	grade(-0.6, 0.1, Color3.fromRGB(220, 232, 255), 0.2)
	task.delay(1.6, function()
		grade(0, 0, WHITE, 1)
	end)
end

function JuiceController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "JuiceFX"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3 -- under the HUD
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local function bar(name: string, y: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
		f.Size = UDim2.fromScale(1, BAR_HEIGHT)
		f.Position = UDim2.fromScale(0, y)
		f.Parent = gui
		return f
	end
	topBar = bar("TopBar", -BAR_HEIGHT)
	bottomBar = bar("BottomBar", 1)

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.Parent = gui

	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "JuiceGrade"
	cc.Parent = Lighting

	local cam = camera()
	if cam then
		BASE_FOV = cam.FieldOfView
	end

	ClientState.Notified:Connect(function(kind: string)
		if kind == "bigToss" then
			slowMo()
		elseif kind == "toss" then
			fovKick(64, 0.12, 0.2, 0.3)
		elseif kind == "catch" then
			fovKick(66, 0.08, 0.05, 0.25)
			shake(0.25)
		elseif kind == "go" then
			local c = camera()
			if c then
				c.FieldOfView = 84
			end
			fovKick(BASE_FOV, 0.01, 0, 0.5)
			shake(0.4)
		elseif kind == "checkpoint" then
			doFlash(GOLD, 0.7, 0.5)
			fovKick(64, 0.1, 0.1, 0.4)
		elseif kind == "puff" then
			doFlash(WHITE, 0.3, 0.6)
			shake(0.7)
		elseif kind == "gate" then
			doFlash(GOLD, 0.45, 0.9)
			fovKick(62, 0.15, 0.4, 0.8)
		elseif kind == "unlock" or kind == "badge" or kind == "streak" then
			doFlash(GOLD, 0.6, 0.8)
		end
	end)

	local lastResult: any = nil
	ClientState.Changed:Connect(function()
		local info = ClientState.info
		local result = info and info.result
		if ClientState.state == "Ended" and result and result ~= lastResult then
			lastResult = result
			if result.reason == "Caught" then
				caught()
			end
		end
	end)

	-- Decaying impact shake (separate from AvalancheFX's distance rumble).
	RunService:BindToRenderStep("JuiceShake", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		if shakeAmount < 0.01 then
			shakeAmount = 0
			return
		end
		local c = camera()
		if c then
			local t = os.clock() * 30
			local offset = Vector3.new(math.noise(t, 1.7, 0), math.noise(3.1, t, 0), 0) * shakeAmount
			c.CFrame = c.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.noise(0, 0, t) * shakeAmount * 0.05)
		end
		shakeAmount *= math.exp(-dt * 5)
	end)
end

return JuiceController

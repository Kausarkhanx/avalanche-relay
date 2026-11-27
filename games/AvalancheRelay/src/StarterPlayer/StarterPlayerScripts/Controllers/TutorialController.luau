--!strict
-- TutorialController: "Pip" the penguin gives short, contextual tips during a new player's
-- first runs, so there is no separate tutorial level to sit through. Each tip shows once.
-- Tips stop after the first delivered lantern, after 3 runs, or when the player taps "Skip tips"
-- (the server saves that in PlayerData.tutorialDone).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript) :: any
local SegmentCatalog = require(Shared:WaitForChild("SegmentCatalog") :: ModuleScript) :: any
local ClientState = require(script.Parent.ClientState)
local AudioController = require(script.Parent.AudioController)

local LocalPlayer = Players.LocalPlayer

local NIGHT = Color3.fromRGB(16, 24, 38)
local ICE = Color3.fromRGB(111, 168, 220)
local GOLD = Color3.fromRGB(255, 209, 102)
local WHITE = Color3.fromRGB(245, 249, 255)

local TIPS: { [string]: string } = {
	lobby = "Hi, I'm Pip! Tap FIND SQUAD or hop on the glowing ring to start a run.",
	countdown = "That glowing thing is the Summit Lantern. Whoever carries it runs slower!",
	go = "RUN! The avalanche is right behind you. Keep an eye on the GAP meter.",
	tossAhead = "Big gap ahead! Let a friend jump across, then press E or TOSS to throw them the lantern.",
	soloAhead = "Big gap ahead! Running solo? Take the icy side route around it.",
	checkpoint = "Checkpoint! Now get the lantern down to the Village Gate.",
	caught = "So close! Pass the lantern more often: fresh legs run faster.",
	finished = "You did it! I'll stop the tips now. Have fun out there!",
}

local TutorialController = {}

local active = false
local shown: { [string]: boolean } = {}
local coach: Frame
local coachText: TextLabel
local coachScale: UIScale
local hideToken = 0
local ringArrow: BillboardGui? = nil

local function hide()
	hideToken += 1
	local token = hideToken
	TweenService:Create(coachScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.delay(0.2, function()
		if token == hideToken then
			coach.Visible = false
		end
	end)
end

local function say(id: string, force: boolean?)
	if (not active and not force) or shown[id] then
		return
	end
	shown[id] = true
	hideToken += 1
	local token = hideToken
	coachText.Text = TIPS[id]
	coach.Visible = true
	coachScale.Scale = 0.3
	TweenService:Create(coachScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	AudioController.play("SFX", "Catch", 1.5)
	task.delay(7, function()
		if token == hideToken then
			hide()
		end
	end)
end

local function finish(skipped: boolean)
	if not active then
		return
	end
	active = false
	if skipped then
		Remotes.TutorialDone():FireServer()
		hide()
	end
	if ringArrow then
		ringArrow:Destroy()
		ringArrow = nil
	end
end

local function buildCoach(gui: ScreenGui)
	coach = Instance.new("Frame")
	coach.Name = "Coach"
	-- bottom centre, above the toast and invite, clear of the results banner and the TOSS button
	coach.AnchorPoint = Vector2.new(0.5, 1)
	coach.Position = UDim2.new(0.5, 0, 1, -24)
	coach.Size = UDim2.fromOffset(560, 92)
	coach.BackgroundColor3 = NIGHT
	coach.BackgroundTransparency = 0.08
	coach.Visible = false
	coach.ZIndex = 30
	coach.Parent = gui
	coachScale = Instance.new("UIScale")
	coachScale.Parent = coach
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = coach
	local stroke = Instance.new("UIStroke")
	stroke.Color = ICE
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = coach

	local pip = Instance.new("TextLabel")
	pip.Name = "Pip"
	pip.BackgroundTransparency = 1
	pip.Position = UDim2.fromOffset(10, 0)
	pip.Size = UDim2.fromOffset(70, 92)
	pip.Text = "🐧"
	pip.TextSize = 52
	pip.ZIndex = 31
	pip.Parent = coach

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(84, 8)
	text.Size = UDim2.new(1, -96, 0, 50)
	text.Font = Enum.Font.FredokaOne
	text.TextSize = 19
	text.TextWrapped = true
	text.TextColor3 = WHITE
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.ZIndex = 31
	text.Parent = coach
	coachText = text

	local function button(name: string, label: string, x: number, color: Color3): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, x, 1, -8)
		b.Size = UDim2.fromOffset(104, 26)
		b.BackgroundColor3 = color
		b.Font = Enum.Font.FredokaOne
		b.Text = label
		b.TextSize = 15
		b.TextColor3 = NIGHT
		b.ZIndex = 31
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = b
		b.Parent = coach
		return b
	end
	button("GotIt", "GOT IT!", -12, GOLD).Activated:Connect(function()
		AudioController.click()
		hide()
	end)
	button("Skip", "Skip tips", -124, ICE).Activated:Connect(function()
		AudioController.click()
		finish(true)
	end)
end

-- A bobbing "START HERE" marker over the ring while a new player is in the lobby.
local function buildRingArrow()
	local lobby = Workspace:FindFirstChild("Lobby")
	local ring = lobby and lobby:FindFirstChild("StartRing", true)
	if not ring or not ring:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "StartHereArrow"
	gui.Adornee = ring
	gui.Size = UDim2.fromOffset(200, 90)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 300
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "START HERE\n▼"
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.TextStrokeColor3 = NIGHT
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	ringArrow = gui
end

local function nextSegmentNeedsToss(): boolean
	local info = ClientState.info
	if not info or not info.segmentNames then
		return false
	end
	local display = info.segmentNames[ClientState.segment + 1]
	if not display then
		return false
	end
	for _, seg in SegmentCatalog.Pool do
		if seg.displayName == display then
			return seg.tossRequired
		end
	end
	return false
end

function TutorialController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialFX"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 6 -- above the HUD
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	buildCoach(gui)

	local ok, info = pcall(function()
		return Remotes.GetDailyInfo():InvokeServer()
	end)
	if not ok or type(info) ~= "table" or info.tutorialDone then
		return
	end
	active = true
	buildRingArrow()
	task.delay(2, say, "lobby")

	local lastSegment = -1
	ClientState.Changed:Connect(function()
		if not active then
			return
		end
		if ringArrow then
			ringArrow.Enabled = not ClientState.inRace
		end
		if not ClientState.inRace then
			return
		end
		local state = ClientState.state
		if state == "Countdown" then
			say("countdown")
		elseif state == "Running" then
			if not shown.go then
				say("go")
			elseif ClientState.segment ~= lastSegment then
				if ClientState.segment >= 1 then
					say("checkpoint")
				end
				if nextSegmentNeedsToss() then
					local squadSize = if ClientState.info and ClientState.info.memberIds then #ClientState.info.memberIds else 1
					task.delay(if ClientState.segment >= 1 then 7.5 else 0, say, if squadSize > 1 then "tossAhead" else "soloAhead")
				end
			end
			lastSegment = ClientState.segment
		elseif state == "Ended" then
			local result = ClientState.info and ClientState.info.result
			if result then
				if result.reason == "Finished" then
					say("finished", true)
					finish(false)
				elseif result.reason == "Caught" then
					shown.caught = nil -- worth repeating once per run while learning
					say("caught")
				end
			end
		end
	end)

	-- Gentle bob on the ring arrow.
	RunService.RenderStepped:Connect(function()
		if ringArrow then
			ringArrow.StudsOffsetWorldSpace = Vector3.new(0, 9 + math.sin(os.clock() * 3) * 0.8, 0)
		end
	end)

	-- After 3 runs the server turns the tips off; check again whenever we're back in the lobby.
	ClientState.Notified:Connect(function(kind: string)
		if kind == "lobby" and active then
			task.spawn(function()
				local okInfo, latest = pcall(function()
					return Remotes.GetDailyInfo():InvokeServer()
				end)
				if okInfo and type(latest) == "table" and latest.tutorialDone then
					finish(false)
				end
			end)
		end
	end)
end

return TutorialController

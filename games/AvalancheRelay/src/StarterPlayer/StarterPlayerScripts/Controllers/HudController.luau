--!strict
-- HudController: drives the AvalancheHUD built by StarterGui/HudBuilder.
-- Progress dots, timer, gap meter, TOSS button + radial cooldown, countdown slam,
-- finish banner, toasts, daily panel, and phone-friendly UIScale.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript) :: any
local ClientState = require(script.Parent.ClientState)
local PassController = require(script.Parent.PassController)
local AudioController = require(script.Parent.AudioController)

local LocalPlayer = Players.LocalPlayer

local NIGHT = Color3.fromRGB(16, 24, 38)
local ICE = Color3.fromRGB(111, 168, 220)
local GOLD = Color3.fromRGB(255, 209, 102)
local DANGER = Color3.fromRGB(255, 107, 107)
local GREEN = Color3.fromRGB(124, 245, 140)
local WHITE = Color3.fromRGB(245, 249, 255)

local GAP_METER_MAX = 80
local DANGER_GAP = 20

local HudController = {}

local gui: ScreenGui
local ui: { [string]: any } = {}
local dailyInfo: { [string]: any }? = nil
local countdownToken = 0
local toastToken = 0
local bannerToken = 0
local lastCountdownValue = -1
local shownResultFor: any = nil

local function fmtTime(t: number): string
	t = math.max(0, t)
	local minutes = math.floor(t / 60)
	return string.format("%d:%05.2f", minutes, t - minutes * 60)
end

-- Countdown / toast / banner ---------------------------------------------------------

local function slam(text: string, color: Color3?)
	countdownToken += 1
	local token = countdownToken
	local label: TextLabel = ui.countdown
	local pop: UIScale = ui.countdownPop
	label.Text = text
	label.TextColor3 = color or GOLD
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0
	label.Visible = true
	pop.Scale = 2.6
	TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(0.8, function()
		if token ~= countdownToken then
			return
		end
		local fade = TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		if token == countdownToken then
			label.Visible = false
		end
	end)
end

local function toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	local label: TextLabel = ui.toast
	label.Text = text
	label.TextColor3 = color or WHITE
	label.Visible = true
	task.delay(2.4, function()
		if token == toastToken then
			label.Visible = false
		end
	end)
end

local function hideBanner()
	bannerToken += 1
	TweenService:Create(ui.banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0, -240),
	}):Play()
end

local function showBanner(title: string, detail: string, extra: string)
	bannerToken += 1
	local token = bannerToken
	local banner: Frame = ui.banner
	banner.AgainButton.Text = "RUN AGAIN"
	banner.AgainButton.AutoButtonColor = true
	banner.Title.Text = title
	banner.Detail.Text = detail
	banner.Extra.Text = extra
	banner.Position = UDim2.new(0.5, 0, 0, -240)
	TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 96),
	}):Play()
	task.delay(5, function()
		if token ~= bannerToken then
			return
		end
		TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -240),
		}):Play()
	end)
end

-- Daily panel ------------------------------------------------------------------------

local function renderDaily()
	local info = dailyInfo
	if not info then
		return
	end
	local panel = ui.daily
	local lines = {}
	for i, name in info.segments do
		table.insert(lines, string.format("%d. %s", i, name))
	end
	panel.Segments.Text = table.concat(lines, "\n")
	local best = info.personalBest
	panel.Best.Text = if best
		then string.format("Best today: %d/%d · %s", best.segments, info.totalSegments, fmtTime(best.time))
		else "Best today: no runs yet"
	panel.Badges.Text = string.format("Frost Badges: %d   Runs: %d", info.frostBadges, info.totalRuns)
	local streak = info.streak or 0
	if streak == 0 then
		panel.Streak.Text = "🔥 Start a streak: clear a segment today"
	elseif info.playedToday then
		panel.Streak.Text = string.format("🔥 Streak: %d day%s  (best %d)", streak, if streak == 1 then "" else "s", info.bestStreak or streak)
	else
		panel.Streak.Text = string.format("🔥 Run today to keep your %d-day streak!", streak)
	end
	panel.FlameButton.Text = "Flame: " .. tostring(info.flame)
	panel.KitButton.Text = if info.ownsKit then "Trailblazer Kit ✓" else "Get Trailblazer Kit"
	panel.KitButton.AutoButtonColor = not info.ownsKit
	local unlockedCount = 0
	for _, reward in info.rewards or {} do
		if reward.unlocked then
			unlockedCount += 1
		end
	end
	panel.RewardsButton.Text = string.format("❄  Rewards  %d/%d", unlockedCount, #(info.rewards or {}))
end

-- Rewards panel ----------------------------------------------------------------------------

local renderRewards: () -> ()

local function rewardRow(reward: { [string]: any }, order: number): Frame
	local row = Instance.new("Frame")
	row.Name = reward.id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, 56)
	row.BackgroundColor3 = if reward.unlocked then Color3.fromRGB(34, 48, 70) else Color3.fromRGB(28, 34, 46)
	row.ZIndex = 22
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = row

	local function text(name: string, value: string, x: number, width: number, size: number, color: Color3, y: number, height: number)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(x, y)
		l.Size = UDim2.new(0, width, 0, height)
		l.Font = Enum.Font.FredokaOne
		l.Text = value
		l.TextSize = size
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.ZIndex = 23
		l.Parent = row
	end
	local icon = if reward.kind == "flame" then "🔥" else "🧣"
	text("Icon", if reward.unlocked then icon else "🔒", 12, 34, 24, WHITE, 0, 56)
	text("Name", reward.name, 52, 220, 20, if reward.unlocked then WHITE else Color3.fromRGB(150, 160, 178), 6, 26)
	text("Need", string.format("❄ %d Frost Badge%s", reward.badges, if reward.badges == 1 then "" else "s"), 52, 220, 14, ICE, 30, 18)

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -10, 0.5, 0)
	button.Size = UDim2.fromOffset(110, 36)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 17
	button.ZIndex = 23
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = button
	if not reward.unlocked then
		button.Text = "LOCKED"
		button.BackgroundColor3 = Color3.fromRGB(70, 78, 92)
		button.TextColor3 = Color3.fromRGB(170, 178, 190)
		button.AutoButtonColor = false
	elseif reward.equipped then
		button.Text = if reward.kind == "flame" then "USING" else "TAKE OFF"
		button.BackgroundColor3 = GREEN
		button.TextColor3 = NIGHT
	else
		button.Text = if reward.kind == "flame" then "USE" else "WEAR"
		button.BackgroundColor3 = GOLD
		button.TextColor3 = NIGHT
	end
	button.Activated:Connect(function()
		if not reward.unlocked then
			return
		end
		AudioController.click()
		local info = dailyInfo :: any
		if reward.kind == "flame" then
			Remotes.SetFlameColor():FireServer(reward.value)
			info.flame = reward.value
			for _, r in info.rewards do
				if r.kind == "flame" then
					r.equipped = r.value == reward.value
				end
			end
		else
			reward.equipped = not reward.equipped
			Remotes.SetWearable():FireServer(reward.id, reward.equipped)
		end
		renderDaily()
		renderRewards()
	end)
	button.Parent = row
	return row
end

renderRewards = function()
	local info = dailyInfo
	local panel = ui.rewards
	if not info or not panel then
		return
	end
	for _, child in panel.List:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, reward in info.rewards or {} do
		rewardRow(reward, i).Parent = panel.List
	end
	-- progress toward the next Frost Badge
	local every = info.badgeEvery or 5
	local into = (info.segmentsCleared or 0) % every
	local nextReward
	for _, reward in info.rewards or {} do
		if not reward.unlocked then
			nextReward = reward
			break
		end
	end
	panel.Bar.Fill.Size = UDim2.fromScale(into / every, 1)
	panel.Progress.Text = if nextReward
		then string.format("Next badge: %d/%d segments  ·  next reward at ❄ %d: %s", into, every, nextReward.badges, nextReward.name)
		else string.format("Next badge: %d/%d segments  ·  everything unlocked!", into, every)
end

local remindedStreak = false

local function refreshDaily()
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.GetDailyInfo():InvokeServer()
		end)
		if ok and type(result) == "table" then
			dailyInfo = result
			renderDaily()
			-- once per session: nudge players whose streak is about to lapse
			if not remindedStreak and (result.streak or 0) > 0 and not result.playedToday then
				remindedStreak = true
				task.delay(3, toast, string.format("🔥 Run today to keep your %d-day streak!", result.streak), Color3.fromRGB(255, 160, 90))
			end
			if ui.rewards and ui.rewards.Visible then
				renderRewards()
			end
		end
	end)
end

local function onFlameClicked()
	AudioController.click()
	local info = dailyInfo
	if not info then
		return
	end
	local flames = info.flames
	if #flames <= 1 then
		toast("Earn flame colours with Frost Badges (or the Trailblazer Kit)", GOLD)
		return
	end
	local index = table.find(flames, info.flame) or 1
	local nextFlame = flames[index % #flames + 1]
	info.flame = nextFlame
	Remotes.SetFlameColor():FireServer(nextFlame)
	renderDaily()
end

local function onKitClicked()
	AudioController.click()
	local info = dailyInfo
	if info and info.ownsKit then
		return
	end
	if Config.GAMEPASS_ID == 0 then
		toast("Trailblazer Kit isn't on sale yet", GOLD)
		return
	end
	MarketplaceService:PromptGamePassPurchase(LocalPlayer, Config.GAMEPASS_ID)
end

-- Compact leaderboard (top right, lobby only) -------------------------------------------

local function statValue(player: Player, name: string): number
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	return if value and value:IsA("IntValue") then value.Value else 0
end

local function renderLeaderboard()
	local board = ui.leaderboard
	if not board then
		return
	end
	board.Visible = not ClientState.inRace
	if not board.Visible then
		return
	end
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		local ta, tb = statValue(a, "Today"), statValue(b, "Today")
		if ta ~= tb then
			return ta > tb
		end
		return statValue(a, "Badges") > statValue(b, "Badges")
	end)
	for _, child in board:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "Header" then
			child:Destroy()
		end
	end
	for i, player in players do
		if i > 8 then
			break
		end
		local row = board.Header:Clone()
		row.Name = "Row"
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 20)
		local color = if player == LocalPlayer then GOLD else WHITE
		local values = {
			PlayerName = player.DisplayName,
			Today = tostring(statValue(player, "Today")),
			Badges = tostring(statValue(player, "Badges")),
			Streak = tostring(statValue(player, "Streak")),
		}
		for column, value in values do
			local cell = row:FindFirstChild(column)
			if cell and cell:IsA("TextLabel") then
				cell.Text = value
				cell.TextColor3 = color
				cell.TextSize = 15
			end
		end
		row.Parent = board
	end
end

-- Race HUD -----------------------------------------------------------------------------

local function setRadial(progress: number)
	local degrees = math.clamp(progress, 0, 1) * 360
	ui.cooldownRight.Rotation = math.clamp(degrees, 0, 180)
	ui.cooldownLeft.Rotation = math.clamp(degrees - 180, 0, 180)
end

local function updateTossButton()
	local button = ui.toss
	local carrier = ClientState.isCarrier() and ClientState.state == "Running"
	local remaining = PassController.cooldownRemaining()
	local ready = PassController.canToss() and remaining <= 0
	button.Visible = ClientState.inRace and ClientState.state ~= "Ended"
	button.Lock.Visible = not ready
	button.Cooldown.Visible = carrier and remaining > 0
	if carrier and remaining > 0 then
		setRadial(1 - remaining / Config.TOSS_COOLDOWN)
	end
	button.Label.TextColor3 = if ready then NIGHT else Color3.fromRGB(200, 208, 220)
	button.Hint.TextColor3 = button.Label.TextColor3
end

local function onStateChanged()
	local inRace = ClientState.inRace
	ui.raceHud.Visible = inRace
	ui.daily.Visible = not inRace
	if not inRace then
		lastCountdownValue = -1
		return
	end
	local info = ClientState.info
	if not info then
		return
	end

	-- Progress dots
	local total = info.totalSegments or 5
	for i, dot in ui.dots do
		dot.Visible = i <= total
		if i <= ClientState.segment then
			dot.BackgroundColor3 = GOLD
			dot.BackgroundTransparency = 0
		else
			dot.BackgroundColor3 = ICE
			dot.BackgroundTransparency = if i == ClientState.segment + 1 then 0.15 else 0.6
		end
	end

	-- Countdown at the trailhead
	if ClientState.state == "Countdown" then
		local value = math.ceil(ClientState.time)
		if value ~= lastCountdownValue and value > 0 then
			lastCountdownValue = value
			slam(tostring(value))
			AudioController.play("SFX", "Beep", 1 + (3 - math.min(value, 3)) * 0.12)
		end
	else
		lastCountdownValue = -1
	end

	-- Carrier label
	if ClientState.isCarrier() then
		ui.carrierLabel.Text = if #info.memberIds > 1 then "You carry the lantern! Toss it across gaps" else "You carry the lantern!"
	elseif ClientState.carrierId ~= 0 then
		local carrier = Players:GetPlayerByUserId(ClientState.carrierId)
		ui.carrierLabel.Text = if carrier then carrier.DisplayName .. " has the lantern" else ""
	else
		ui.carrierLabel.Text = if info.tossing then "Lantern in the air!" else ""
	end

	-- Gap meter
	local gap = ClientState.gap
	local fill: Frame = ui.gapFill
	fill.Size = UDim2.fromScale(1, math.clamp(gap / GAP_METER_MAX, 0.04, 1))
	local danger = ClientState.state == "Running" and gap < DANGER_GAP
	fill.BackgroundColor3 = if danger then DANGER else ICE
	ui.gapValue.Text = if ClientState.state == "Running" then tostring(math.max(0, math.floor(gap))) else "--"
	ui.gapValue.TextColor3 = if danger then DANGER else WHITE

	-- Result banner (sent once with the Ended state)
	local result = info.result
	if ClientState.state == "Ended" and result and shownResultFor ~= result then
		shownResultFor = result
		local elapsed = result.elapsed or result.time
		ui.timer.Text = fmtTime(elapsed)
		local finished = result.reason == "Finished"
		local title = if finished then "LANTERN DELIVERED!" else "CAUGHT BY THE AVALANCHE"
		local detail = if finished
			then string.format("All %d segments in %s", result.totalSegments, fmtTime(result.time))
			else string.format("%d/%d segments · survived %s", result.segments, result.totalSegments, fmtTime(elapsed))
		local extras = {}
		if result.newBest and result.segments > 0 then
			table.insert(extras, "New personal best today!")
		end
		if result.badgesEarned > 0 then
			table.insert(extras, string.format("+%d Frost Badge", result.badgesEarned))
		end
		if #extras == 0 then
			table.insert(extras, if finished then "Back to the summit soon..." else "Toss earlier, outrun the snow!")
		end
		showBanner(title, detail, table.concat(extras, "  ·  "))
		if result.reason == "Caught" then
			ui.banner.Title.TextColor3 = DANGER
		else
			ui.banner.Title.TextColor3 = GOLD
		end
	end
end

local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	ui.scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.75, 1.2)
end

function HudController.init()
	-- HudBuilder only runs once the character has spawned (avatar loading can take a while),
	-- so poll quietly instead of WaitForChild's "infinite yield" warning.
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local found = playerGui:FindFirstChild("AvalancheHUD")
	while not found do
		task.wait(0.2)
		found = playerGui:FindFirstChild("AvalancheHUD")
	end
	gui = found :: ScreenGui
	local raceHud = gui:WaitForChild("RaceHud") :: any
	local tossButton = raceHud.TossButton

	ui.scale = gui:WaitForChild("Scale")
	ui.raceHud = raceHud
	ui.carrierLabel = raceHud.CarrierLabel
	ui.timer = raceHud.Timer.Text
	ui.gapFill = raceHud.GapMeter.Track.Fill
	ui.gapValue = raceHud.GapMeter.Value
	ui.toss = tossButton
	ui.cooldownRight = tossButton.Cooldown.Right.Disc.Gradient
	ui.cooldownLeft = tossButton.Cooldown.Left.Disc.Gradient
	ui.countdown = gui:WaitForChild("Countdown")
	ui.countdownPop = ui.countdown:WaitForChild("Pop")
	ui.banner = gui:WaitForChild("Banner")
	ui.toast = gui:WaitForChild("Toast")
	ui.daily = gui:WaitForChild("DailyPanel")
	ui.dots = {}
	local i = 1
	while raceHud.Progress:FindFirstChild("Dot" .. i) do
		ui.dots[i] = raceHud.Progress:FindFirstChild("Dot" .. i)
		i += 1
	end

	tossButton.Activated:Connect(function()
		PassController.tryToss()
	end)

	-- Find Squad / Join / Run Again all ask the server to put us on the Start ring.
	ui.invite = gui:WaitForChild("Invite")
	ui.daily.FindButton.Activated:Connect(function()
		AudioController.click()
		Remotes.QuickJoin():FireServer()
		ui.invite.Visible = false
	end)
	ui.invite.JoinButton.Activated:Connect(function()
		AudioController.click()
		Remotes.QuickJoin():FireServer()
		ui.invite.Visible = false
	end)
	ui.banner.AgainButton.Activated:Connect(function()
		AudioController.click()
		Remotes.QuickJoin():FireServer()
		local info = ClientState.info
		local squadSize = if info and info.memberIds then #info.memberIds else 1
		ui.banner.AgainButton.Text = if squadSize > 1 then "WAITING FOR SQUAD..." else "HERE WE GO!"
		ui.banner.AgainButton.AutoButtonColor = false
	end)
	-- Our own compact leaderboard replaces Roblox's big player list.
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	ui.leaderboard = gui:WaitForChild("Leaderboard")
	task.spawn(function()
		while gui.Parent do
			renderLeaderboard()
			task.wait(1)
		end
	end)
	ClientState.Changed:Connect(function()
		if ui.leaderboard.Visible == ClientState.inRace then
			renderLeaderboard()
		end
	end)

	ui.rewards = gui:WaitForChild("Rewards")
	ui.daily.RewardsButton.Activated:Connect(function()
		AudioController.click()
		ui.rewards.Visible = not ui.rewards.Visible
		if ui.rewards.Visible then
			renderRewards()
			refreshDaily()
		end
	end)
	ui.rewards.Close.Activated:Connect(function()
		AudioController.click()
		ui.rewards.Visible = false
	end)
	ui.daily.FlameButton.Activated:Connect(onFlameClicked)
	ui.daily.KitButton.Activated:Connect(onKitClicked)

	ClientState.Changed:Connect(onStateChanged)
	ClientState.Notified:Connect(function(kind: string, text: string, position: Vector3?)
		if kind == "countdown" then
			slam(text)
		elseif kind == "go" then
			slam("GO!", GREEN)
		elseif kind == "lobby" then
			hideBanner()
			refreshDaily()
		elseif kind == "invite" then
			ui.invite.Label.Text = text
			ui.invite.Visible = true
			AudioController.play("SFX", "Checkpoint", 1.4)
		elseif kind == "inviteClose" then
			ui.invite.Visible = false
		elseif kind == "rematchAsk" or kind == "cocoa" then
			toast(text, GOLD)
		elseif kind == "kitReady" then
			refreshDaily()
		elseif kind == "streak" then
			toast(text, Color3.fromRGB(255, 160, 90))
			refreshDaily()
		elseif kind == "unlock" then
			slam("❄", GOLD)
			toast(text .. "  Open ❄ Rewards to use it", GOLD)
			refreshDaily()
		elseif kind == "warning" then
			toast(text, DANGER)
		elseif kind == "badge" or kind == "kit" then
			toast(text, GOLD)
			refreshDaily()
		elseif kind == "info" or kind == "puff" then
			toast(text, WHITE)
		elseif position == nil and (kind == "checkpoint" or kind == "gate" or kind == "catch") then
			toast(text, GOLD)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, _passId: number, purchased: boolean)
		if player == LocalPlayer and purchased then
			task.delay(1, refreshDaily)
		end
	end)

	-- Smooth timer, pulsing current dot, and the cooldown ring every frame.
	RunService.RenderStepped:Connect(function()
		if not ClientState.inRace then
			return
		end
		if ClientState.state == "Running" then
			ui.timer.Text = fmtTime(ClientState.time + (os.clock() - ClientState.receivedAt))
		elseif ClientState.state == "Countdown" then
			ui.timer.Text = fmtTime(0)
		end
		local pulseIndex = if ClientState.state == "Running" then ClientState.segment + 1 else -1
		for index, dot in ui.dots do
			dot.Pulse.Scale = if index == pulseIndex then 1 + 0.18 * (0.5 + 0.5 * math.sin(os.clock() * 6)) else 1
		end
		updateTossButton()
	end)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
	onStateChanged()
	refreshDaily()
	-- Game pass ownership is checked async on the server; re-read once it has settled.
	task.delay(5, refreshDaily)
end

return HudController

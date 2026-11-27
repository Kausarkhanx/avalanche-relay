--!strict
-- LobbyService: the summit Start ring. Up to MAX_SQUAD_SIZE players standing on the ring when
-- the 10s countdown ends become a squad and are sent to their course. Also fills the daily
-- board and answers GetDailyInfo.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DailySeed = require(ReplicatedStorage.Shared.DailySeed)
local DataService = require(script.Parent.DataService)
local RaceService = require(script.Parent.RaceService)
local LanternService = require(script.Parent.LanternService)
local MonetizationService = require(script.Parent.MonetizationService)
local RewardService = require(script.Parent.RewardService)

local UPDATE_INTERVAL = 0.25

local LobbyService = {}

local lobby: Instance? = nil
local ring: BasePart? = nil
local spawnPart: BasePart? = nil
local onRingSince: { [Player]: number } = {}
local countdownEnd: number? = nil
local lastAnnounced = -1
local boardSeed = -1

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function setStatus(text: string)
	if not ring then
		return
	end
	local gui = ring:FindFirstChild("Status")
	local label = gui and gui:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function refreshBoard()
	local seed = DailySeed.todaySeed()
	if seed == boardSeed or not lobby then
		return
	end
	boardSeed = seed
	local board = lobby:FindFirstChild("DailyBoard", true)
	local gui = board and board:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		return
	end
	local names = DailySeed.displayNames(DailySeed.pickSegments(seed))
	local lines = {}
	for i, name in names do
		table.insert(lines, string.format("%d.  %s", i, name))
	end
	local title = gui:FindFirstChild("Title", true)
	local list = gui:FindFirstChild("List", true)
	if title and title:IsA("TextLabel") then
		local t = os.date("!*t")
		title.Text = string.format("TODAY'S MOUNTAIN  ·  %02d/%02d", t.day, t.month)
	end
	if list and list:IsA("TextLabel") then
		list.Text = table.concat(lines, "\n")
	end
end

local function playersOnRing(): { Player }
	local activeRing = ring
	if not activeRing then
		return {}
	end
	local radius = (activeRing:GetAttribute("Radius") :: number?) or 10
	local now = os.clock()
	local list = {}
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local onIt = false
		if root and humanoid and humanoid.Health > 0 and not RaceService.isRacing(player) then
			local delta = root.Position - activeRing.Position
			onIt = Vector3.new(delta.X, 0, delta.Z).Magnitude <= radius and math.abs(delta.Y) < 7
		end
		if onIt then
			onRingSince[player] = onRingSince[player] or now
			table.insert(list, player)
		else
			onRingSince[player] = nil
		end
	end
	table.sort(list, function(a, b)
		return onRingSince[a] < onRingSince[b]
	end)
	return list
end

-- Lobby players who are not racing and not on the ring (they get the Join invite).
local function idlePlayers(onRing: { Player }): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if not RaceService.isRacing(player) and not table.find(onRing, player) and getRoot(player) then
			table.insert(list, player)
		end
	end
	return list
end

local inviteOpen = false
local function closeInvite()
	if not inviteOpen then
		return
	end
	inviteOpen = false
	for _, player in Players:GetPlayers() do
		if not RaceService.isRacing(player) then
			Remotes.Notify():FireClient(player, "inviteClose", "", nil)
		end
	end
end

local function update()
	refreshBoard()
	local onRing = playersOnRing()
	if #onRing == 0 then
		countdownEnd = nil
		lastAnnounced = -1
		closeInvite()
		setStatus("Step on the ring to start a run")
		return
	end

	local now = os.clock()
	if not countdownEnd then
		local idle = idlePlayers(onRing)
		-- Alone on the ring with others around: give them time to hop in.
		local wait = if #onRing == 1 and #idle > 0 then Config.LOBBY_SOLO_WAIT_SECONDS else Config.LOBBY_COUNTDOWN_SECONDS
		countdownEnd = now + wait
		if #idle > 0 and #onRing < Config.MAX_SQUAD_SIZE then
			inviteOpen = true
			for _, player in idle do
				Remotes.Notify():FireClient(player, "invite", onRing[1].DisplayName .. " is starting a run!", nil)
			end
		end
	end
	if #onRing >= Config.MAX_SQUAD_SIZE then
		countdownEnd = math.min(countdownEnd :: number, now + Config.FULL_SQUAD_COUNTDOWN)
		closeInvite()
	end
	local remaining = math.max(0, math.ceil((countdownEnd :: number) - now))
	local squadSize = math.min(#onRing, Config.MAX_SQUAD_SIZE)
	setStatus(string.format("Squad %d/%d  ·  starting in %ds", squadSize, Config.MAX_SQUAD_SIZE, remaining))

	if remaining ~= lastAnnounced and remaining > 0 then
		lastAnnounced = remaining
		for _, player in onRing do
			Remotes.Notify():FireClient(player, "countdown", tostring(remaining), nil)
		end
	end

	if now >= (countdownEnd :: number) then
		countdownEnd = nil
		lastAnnounced = -1
		closeInvite()
		local squad = {}
		for i = 1, squadSize do
			squad[i] = onRing[i]
			onRingSince[onRing[i]] = nil
		end
		task.spawn(RaceService.startRace, squad)
	end
end

local function placeOnRing(player: Player): boolean
	local character = player.Character
	if not ring or not character or not getRoot(player) then
		return false
	end
	local angle = math.random() * math.pi * 2
	local radius = math.random() * 5
	local position = ring.Position + Vector3.new(math.cos(angle) * radius, 3, math.sin(angle) * radius)
	character:PivotTo(CFrame.lookAt(position, position + Vector3.zAxis))
	return true
end

function LobbyService.sendToLobby(player: Player, rematch: boolean?)
	local character = player.Character
	local base = if spawnPart then spawnPart.Position else Vector3.new(0, 305, -30)
	LanternService.applyMovement(player, nil)
	Remotes.Notify():FireClient(player, "lobby", "Back at the summit", nil)
	if rematch and placeOnRing(player) then
		return
	end
	if character then
		local offset = Vector3.new(math.random(-4, 4), 4, math.random(-4, 4))
		character:PivotTo(CFrame.lookAt(base + offset, base + offset + Vector3.zAxis))
	end
end

-- Find Squad (lobby) / Join (invite) / Run Again (results banner) all use this.
local lastQuickJoin: { [Player]: number } = {}
local function onQuickJoin(player: Player)
	local now = os.clock()
	if now - (lastQuickJoin[player] or 0) < 1 then
		return
	end
	lastQuickJoin[player] = now
	if RaceService.isRacing(player) then
		RaceService.requestRematch(player)
	else
		placeOnRing(player)
	end
end

-- Cozy lodge: grab a hot cocoa from the cocoa bar. Purely for fun; it goes away when a run starts.
local function removeCocoa(player: Player)
	local character = player.Character
	local mug = character and character:FindFirstChild("CocoaMug")
	if mug then
		mug:Destroy()
	end
end

local function giveCocoa(player: Player)
	local character = player.Character
	if not character or RaceService.isRacing(player) then
		return
	end
	removeCocoa(player)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local mug = Instance.new("Part")
	mug.Name = "CocoaMug"
	mug.Shape = Enum.PartType.Cylinder
	mug.Size = Vector3.new(0.75, 0.6, 0.6)
	mug.Color = Color3.fromRGB(230, 90, 90)
	mug.Material = Enum.Material.SmoothPlastic
	mug.CanCollide = false
	mug.CanTouch = false
	mug.CanQuery = false
	mug.Massless = true
	mug.CFrame = hand.CFrame * CFrame.new(0, -0.35, -0.35) * CFrame.Angles(0, 0, math.pi / 2)
	local cream = Instance.new("Part")
	cream.Name = "Cream"
	cream.Shape = Enum.PartType.Ball
	cream.Size = Vector3.new(0.45, 0.45, 0.45)
	cream.Color = Color3.fromRGB(255, 250, 240)
	cream.Material = Enum.Material.SmoothPlastic
	cream.CanCollide = false
	cream.CanTouch = false
	cream.CanQuery = false
	cream.Massless = true
	cream.CFrame = CFrame.new(mug.Position + mug.CFrame.RightVector * 0.4)
	local creamWeld = Instance.new("WeldConstraint")
	creamWeld.Part0 = mug
	creamWeld.Part1 = cream
	creamWeld.Parent = cream
	cream.Parent = mug
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Rate = 6
	steam.Lifetime = NumberRange.new(0.8, 1.4)
	steam.Speed = NumberRange.new(0.8, 1.4)
	steam.Size = NumberSequence.new(0.2, 0.7)
	steam.Transparency = NumberSequence.new(0.6, 1)
	steam.Acceleration = Vector3.new(0, 1.5, 0)
	steam.Parent = cream
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = mug
	weld.Parent = mug
	mug.Parent = character
	Remotes.Notify():FireClient(player, "cocoa", "Mmm, hot cocoa!", nil)
end

local function getDailyInfo(player: Player): { [string]: any }
	local seed = DailySeed.todaySeed()
	local names = DailySeed.pickSegments(seed)
	local data = DataService.waitForData(player, 10)
	local best = data and data.bestDaily[DailySeed.dateKey(seed)]
	return {
		seed = seed,
		segments = DailySeed.displayNames(names),
		totalSegments = #names,
		personalBest = if best then { segments = best.segments, time = best.time } else nil,
		frostBadges = if data then data.frostBadges else 0,
		totalRuns = if data then data.totalRuns else 0,
		ownsKit = MonetizationService.ownsKit(player),
		flame = MonetizationService.getEquippedFlame(player),
		flames = MonetizationService.availableFlames(player),
		gamePassId = Config.GAMEPASS_ID,
		rewards = RewardService.describe(player),
		segmentsCleared = if data then data.segmentsCleared else 0,
		tutorialDone = if data then data.tutorialDone else true,
		streak = if data then DataService.currentStreak(data) else 0,
		bestStreak = if data then data.bestStreak else 0,
		playedToday = data ~= nil and data.streakDay == DailySeed.utcDayKey(0),
		badgeEvery = Config.BADGE_EVERY_SEGMENTS,
	}
end

function LobbyService.init()
	lobby = Workspace:FindFirstChild("Lobby")
	if not lobby then
		warn("[LobbyService] Workspace.Lobby is missing. Run tools/BuildWorld.luau in Studio.")
	else
		local foundRing = lobby:FindFirstChild("StartRing", true)
		ring = if foundRing and foundRing:IsA("BasePart") then foundRing else nil
		local foundSpawn = lobby:FindFirstChildOfClass("SpawnLocation") or lobby:FindFirstChild("LobbySpawn", true)
		spawnPart = if foundSpawn and foundSpawn:IsA("BasePart") then foundSpawn else nil
	end

	RaceService.setLobbyReturn(LobbyService.sendToLobby)
	RaceService.setRaceStarting(removeCocoa)
	Remotes.QuickJoin().OnServerEvent:Connect(onQuickJoin)
	Remotes.TutorialDone().OnServerEvent:Connect(function(player: Player)
		DataService.setTutorialDone(player)
	end)

	if lobby then
		for _, d in lobby:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Name == "CocoaPrompt" then
				d.Triggered:Connect(giveCocoa)
			end
		end
	end

	-- Rate-limited: at most one fresh build per player every 0.5s; spam gets the cached copy.
	local infoCache: { [Player]: { at: number, info: { [string]: any } } } = {}
	Remotes.GetDailyInfo().OnServerInvoke = function(player: Player)
		local cached = infoCache[player]
		if cached and os.clock() - cached.at < 0.5 then
			return cached.info
		end
		local info = getDailyInfo(player)
		infoCache[player] = { at = os.clock(), info = info }
		return info
	end
	Players.PlayerRemoving:Connect(function(player)
		infoCache[player] = nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		onRingSince[player] = nil
		lastQuickJoin[player] = nil
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(update)
			if not ok then
				warn("[LobbyService] " .. tostring(err))
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return LobbyService

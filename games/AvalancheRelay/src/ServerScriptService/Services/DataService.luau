--!strict
-- DataService: load, session-lock, autosave and release player data.
--
-- Record shape in the DataStore (key "u_<UserId>"):
--   { data = PlayerData, lock = { jobId = string, time = number }? }
-- A lock younger than SESSION_LOCK_SECONDS held by another server blocks loading.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local DailySeed = require(ReplicatedStorage.Shared.DailySeed)

type PlayerData = Types.PlayerData

local STORE_NAME = "AvalancheRelay_v1"
local SCHEMA_VERSION = 5
local RETRY_DELAYS = { 1, 2, 4 }
local KICK_MESSAGE = "Your save is still loading, please rejoin"

local DataService = {}

local store: DataStore? = nil
local cache: { [Player]: PlayerData } = {}
local canSave: { [Player]: boolean } = {}
local loadedEvent = Instance.new("BindableEvent")

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

local function defaultData(): PlayerData
	return {
		schemaVersion = SCHEMA_VERSION,
		bestDaily = {},
		totalRuns = 0,
		segmentsCleared = 0,
		frostBadges = 0,
		cosmetics = {},
		equippedFlame = "Gold",
		equippedWear = {},
		tutorialDone = false,
		streak = 0,
		streakDay = "",
		bestStreak = 0,
	}
end

-- Upgrades any older or partial record to the current schema.
local function migrate(raw: any): PlayerData
	if type(raw) ~= "table" then
		return defaultData()
	end
	local data = raw
	local version = tonumber(data.schemaVersion) or 0

	if version < 1 then
		data.bestDaily = if type(data.bestDaily) == "table" then data.bestDaily else {}
		data.totalRuns = tonumber(data.totalRuns) or 0
		data.segmentsCleared = tonumber(data.segmentsCleared) or 0
		data.frostBadges = tonumber(data.frostBadges) or 0
	end
	if version < 2 then
		-- v2 added cosmetics and the equipped flame color.
		data.cosmetics = if type(data.cosmetics) == "table" then data.cosmetics else {}
		data.equippedFlame = if type(data.equippedFlame) == "string" then data.equippedFlame else "Gold"
	end
	if version < 3 then
		-- v3 added earned wearables (Frost Badge rewards).
		data.equippedWear = if type(data.equippedWear) == "table" then data.equippedWear else {}
	end
	if version < 4 then
		-- v4 added the first-run tutorial flag. Anyone who has already played skips it.
		data.tutorialDone = (tonumber(data.totalRuns) or 0) > 0
	end
	if version < 5 then
		-- v5 added the daily streak.
		data.streak = tonumber(data.streak) or 0
		data.streakDay = if type(data.streakDay) == "string" then data.streakDay else ""
		data.bestStreak = tonumber(data.bestStreak) or 0
	end

	data.schemaVersion = SCHEMA_VERSION
	return data :: PlayerData
end

-- Keep only the most recent DAILY_HISTORY_DAYS entries so records stay small.
local function pruneHistory(data: PlayerData)
	local keys = {}
	for key in data.bestDaily do
		table.insert(keys, key)
	end
	if #keys <= Config.DAILY_HISTORY_DAYS then
		return
	end
	table.sort(keys, function(a, b)
		return (tonumber(a) or 0) > (tonumber(b) or 0)
	end)
	for i = Config.DAILY_HISTORY_DAYS + 1, #keys do
		data.bestDaily[keys[i]] = nil
	end
end

-- pcall with 3 retries and 1s/2s/4s backoff.
local function withRetries(label: string, fn: () -> ()): boolean
	for attempt = 1, #RETRY_DELAYS + 1 do
		local ok, err = pcall(fn)
		if ok then
			return true
		end
		if attempt <= #RETRY_DELAYS then
			warn(string.format("[DataService] %s failed (attempt %d), retrying: %s", label, attempt, tostring(err)))
			task.wait(RETRY_DELAYS[attempt])
		else
			warn(string.format("[DataService] %s gave up: %s", label, tostring(err)))
		end
	end
	return false
end

local function lockIsForeign(lock: any): boolean
	return type(lock) == "table"
		and lock.jobId ~= game.JobId
		and type(lock.time) == "number"
		and os.time() - lock.time < Config.SESSION_LOCK_SECONDS
end

type LoadStatus = "ok" | "locked" | "error"

local function tryLoad(player: Player): (LoadStatus, PlayerData?)
	local activeStore = store
	if not activeStore then
		return "error", nil
	end
	local key = keyFor(player.UserId)
	local lockedByOther = false
	local loaded: PlayerData? = nil

	local ok = withRetries("load " .. key, function()
		lockedByOther = false
		loaded = nil
		activeStore:UpdateAsync(key, function(old: any)
			local record = if type(old) == "table" then old else {}
			if lockIsForeign(record.lock) then
				lockedByOther = true
				return nil -- cancel the write, leave the other server's lock alone
			end
			record.data = migrate(record.data)
			record.lock = { jobId = game.JobId, time = os.time() }
			loaded = record.data
			return record
		end)
	end)

	if not ok then
		return "error", nil
	end
	if lockedByOther then
		return "locked", nil
	end
	return "ok", loaded
end

local function save(player: Player, release: boolean): boolean
	local data = cache[player]
	local activeStore = store
	if not data or not canSave[player] or not activeStore then
		return false
	end
	pruneHistory(data)
	local key = keyFor(player.UserId)
	return withRetries("save " .. key, function()
		activeStore:UpdateAsync(key, function(old: any)
			local record = if type(old) == "table" then old else {}
			if lockIsForeign(record.lock) then
				return nil -- another server owns this session now; never clobber it
			end
			record.data = data
			record.lock = if release then nil else { jobId = game.JobId, time = os.time() }
			return record
		end)
	end)
end

-- Daily streak -------------------------------------------------------------------------

-- The streak still counts if the player last played today or yesterday (UTC).
function DataService.currentStreak(data: PlayerData): number
	if data.streakDay == DailySeed.utcDayKey(0) or data.streakDay == DailySeed.utcDayKey(-1) then
		return data.streak
	end
	return 0
end

local function grantBonusSegments(data: PlayerData, segments: number): number
	if segments <= 0 then
		return 0
	end
	data.segmentsCleared += segments
	local badgeTotal = math.floor(data.segmentsCleared / Config.BADGE_EVERY_SEGMENTS)
	local earned = math.max(0, badgeTotal - data.frostBadges)
	data.frostBadges = math.max(data.frostBadges, badgeTotal)
	return earned
end

-- Call after a run that cleared at least one segment. Returns
-- (streak, extendedToday, bonusSegments, badgesFromBonus).
function DataService.updateStreak(player: Player): (number, boolean, number, number)
	local data = cache[player]
	if not data then
		return 0, false, 0, 0
	end
	local today = DailySeed.utcDayKey(0)
	if data.streakDay == today then
		return data.streak, false, 0, 0
	end
	if data.streakDay == DailySeed.utcDayKey(-1) then
		data.streak += 1
	else
		data.streak = 1
	end
	data.streakDay = today
	data.bestStreak = math.max(data.bestStreak, data.streak)
	local bonus = Config.STREAK_BONUSES[data.streak] or 0
	local earned = grantBonusSegments(data, bonus)
	return data.streak, true, bonus, earned
end

local function setupLeaderstats(player: Player, data: PlayerData)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local today = Instance.new("IntValue")
	today.Name = "Today"
	local best = data.bestDaily[DailySeed.dateKey(DailySeed.todaySeed())]
	today.Value = if best then best.segments else 0
	today.Parent = folder

	local badges = Instance.new("IntValue")
	badges.Name = "Badges"
	badges.Value = data.frostBadges
	badges.Parent = folder

	local streak = Instance.new("IntValue")
	streak.Name = "Streak"
	streak.Value = DataService.currentStreak(data)
	streak.Parent = folder

	folder.Parent = player
end

local function refreshLeaderstats(player: Player)
	local data = cache[player]
	local folder = player:FindFirstChild("leaderstats")
	if not data or not folder then
		return
	end
	local today = folder:FindFirstChild("Today")
	local badges = folder:FindFirstChild("Badges")
	local best = data.bestDaily[DailySeed.dateKey(DailySeed.todaySeed())]
	if today and today:IsA("IntValue") then
		today.Value = if best then best.segments else 0
	end
	if badges and badges:IsA("IntValue") then
		badges.Value = data.frostBadges
	end
	local streak = folder:FindFirstChild("Streak")
	if streak and streak:IsA("IntValue") then
		streak.Value = DataService.currentStreak(data)
	end
end

local function finishLoad(player: Player, data: PlayerData, saveable: boolean)
	cache[player] = data
	canSave[player] = saveable
	setupLeaderstats(player, data)
	loadedEvent:Fire(player)
end

local function onPlayerAdded(player: Player)
	if not store then
		finishLoad(player, defaultData(), false)
		return
	end

	local lastStatus: LoadStatus = "error"
	for attempt = 1, #RETRY_DELAYS + 1 do
		local status, data = tryLoad(player)
		lastStatus = status
		if status == "ok" and data then
			if player.Parent == nil then
				-- Left while loading: release the lock we just took.
				cache[player] = data
				canSave[player] = true
				save(player, true)
				cache[player] = nil
				canSave[player] = nil
				return
			end
			finishLoad(player, data, true)
			return
		elseif status == "locked" and attempt <= #RETRY_DELAYS then
			task.wait(RETRY_DELAYS[attempt])
		else
			break
		end
	end

	if player.Parent == nil then
		return
	end
	if lastStatus == "locked" then
		player:Kick(KICK_MESSAGE)
	else
		-- DataStores are down: let them play, but do not overwrite their real save.
		warn("[DataService] Using temporary data for " .. player.Name)
		finishLoad(player, defaultData(), false)
	end
end

local function onPlayerRemoving(player: Player)
	if cache[player] then
		save(player, true)
	end
	cache[player] = nil
	canSave[player] = nil
end

-- Public API ---------------------------------------------------------------

function DataService.get(player: Player): PlayerData?
	return cache[player]
end

function DataService.waitForData(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 15)
	while not cache[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return cache[player]
end

-- Records a finished or failed run. Returns (isNewDailyBest, frostBadgesEarned).
function DataService.recordRun(player: Player, dateKey: string, segments: number, time: number): (boolean, number)
	local data = cache[player]
	if not data then
		return false, 0
	end
	data.totalRuns += 1
	data.segmentsCleared += segments

	local badgeTotal = math.floor(data.segmentsCleared / Config.BADGE_EVERY_SEGMENTS)
	local earned = math.max(0, badgeTotal - data.frostBadges)
	data.frostBadges = math.max(data.frostBadges, badgeTotal)

	local rounded = math.floor(time * 100 + 0.5) / 100
	local best = data.bestDaily[dateKey]
	local isBetter = best == nil or segments > best.segments or (segments == best.segments and rounded < best.time)
	if isBetter then
		data.bestDaily[dateKey] = { segments = segments, time = rounded }
	end

	-- The tips switch off after 3 runs (RaceService also switches them off on a delivery).
	if data.totalRuns >= 3 then
		data.tutorialDone = true
	end

	refreshLeaderstats(player)
	return isBetter, earned
end

function DataService.refresh(player: Player)
	refreshLeaderstats(player)
end

function DataService.setTutorialDone(player: Player)
	local data = cache[player]
	if data then
		data.tutorialDone = true
	end
end

function DataService.setCosmetic(player: Player, key: string, owned: boolean)
	local data = cache[player]
	if data then
		data.cosmetics[key] = owned
	end
end

function DataService.setWearable(player: Player, id: string, on: boolean)
	local data = cache[player]
	if data then
		data.equippedWear[id] = if on then true else nil
	end
end

function DataService.setEquippedFlame(player: Player, flame: string)
	local data = cache[player]
	if data then
		data.equippedFlame = flame
	end
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not save: " .. tostring(result))
	end

	-- In Studio, check API access once so a disabled setting doesn't cost 7s of retries per player.
	if store and RunService:IsStudio() then
		local probeOk, probeErr = pcall(function()
			(store :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			warn(
				"[DataService] Studio has no DataStore access (Game Settings > Security > Enable Studio Access to API Services). Using temporary data. "
					.. tostring(probeErr)
			)
			store = nil
		end
	end

	-- Studio-only test hook: ServerStorage.DevCommands.SetProgress:Invoke(player, segmentsCleared)
	-- sets lifetime segments and the matching badge count. Never created on live servers.
	if RunService:IsStudio() then
		local folder = Instance.new("Folder")
		folder.Name = "DevCommands"
		local setProgress = Instance.new("BindableFunction")
		setProgress.Name = "SetProgress"
		setProgress.OnInvoke = function(player: Player, segments: number)
			local data = DataService.waitForData(player, 10)
			if not data then
				return false
			end
			data.segmentsCleared = segments
			data.frostBadges = math.floor(segments / Config.BADGE_EVERY_SEGMENTS)
			refreshLeaderstats(player)
			return true
		end
		setProgress.Parent = folder
		-- SetStreak:Invoke(player, streak, daysAgo) e.g. (player, 2, 1) = a 2-day streak last played yesterday
		local setStreak = Instance.new("BindableFunction")
		setStreak.Name = "SetStreak"
		setStreak.OnInvoke = function(player: Player, streak: number, daysAgo: number)
			local data = DataService.waitForData(player, 10)
			if not data then
				return false
			end
			data.streak = streak
			data.streakDay = DailySeed.utcDayKey(-daysAgo)
			data.bestStreak = math.max(data.bestStreak, streak)
			refreshLeaderstats(player)
			return true
		end
		setStreak.Parent = folder
		folder.Parent = game:GetService("ServerStorage")
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave loop.
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_SECONDS)
			for player in cache do
				task.spawn(save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in cache do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

DataService.Loaded = loadedEvent.Event

return DataService

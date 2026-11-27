--!strict
-- RaceService: per-squad state machine (Countdown -> Running -> Ended), server clocks via
-- os.clock, checkpoint detection, falls/puffs, scoring and cleanup.
-- (Not named RunService, which would collide with the Roblox service.)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DailySeed = require(ReplicatedStorage.Shared.DailySeed)
local DataService = require(script.Parent.DataService)
local CourseService = require(script.Parent.CourseService)
local LanternService = require(script.Parent.LanternService)
local AvalancheService = require(script.Parent.AvalancheService)
local MonetizationService = require(script.Parent.MonetizationService)
local RewardService = require(script.Parent.RewardService)

type Squad = Types.Squad
type EndReason = Types.EndReason

local TICK_INTERVAL = 0.1

local RaceService = {}

local squads: { [number]: Squad } = {}
local playerSquad: { [Player]: Squad } = {}
local nextSquadId = 0
local returnToLobby: ((Player, boolean) -> ())? = nil
local onRaceStarting: ((Player) -> ())? = nil

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function notify(player: Player, kind: string, text: string, position: Vector3?)
	Remotes.Notify():FireClient(player, kind, text, position)
end

local function notifySquad(squad: Squad, kind: string, text: string, position: Vector3?)
	for _, member in squad.members do
		notify(member, kind, text, position)
	end
end

local function insidePart(part: BasePart, position: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function facingDownhill(position: Vector3): CFrame
	return CFrame.lookAt(position, position + Vector3.zAxis)
end

-- One-shot particle bursts for big moments. Kinds: "snow" (caught/puffed), "sparkle" (checkpoint/gate).
local function burst(position: Vector3, kind: string, count: number)
	local anchor = Instance.new("Part")
	anchor.Name = "Burst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(4, 4, 4)
	anchor.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.SpreadAngle = Vector2.new(180, 180)
	if kind == "snow" then
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Lifetime = NumberRange.new(0.8, 1.6)
		emitter.Speed = NumberRange.new(10, 24)
		emitter.Drag = 3
		emitter.Size = NumberSequence.new(3, 9)
		emitter.Transparency = NumberSequence.new(0.1, 1)
		emitter.Color = ColorSequence.new(Color3.fromRGB(248, 252, 255))
		emitter.Acceleration = Vector3.new(0, -8, 0)
	else
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Speed = NumberRange.new(10, 22)
		emitter.Drag = 3
		emitter.Size = NumberSequence.new(0.8, 0)
		emitter.LightEmission = 1
		emitter.Color = ColorSequence.new(MonetizationService.FLAME_COLORS.Gold, Color3.fromRGB(255, 255, 255))
		emitter.Acceleration = Vector3.new(0, -6, 0)
	end
	emitter.Parent = anchor
	anchor.Parent = workspace
	emitter:Emit(count)
	Debris:AddItem(anchor, 3)
end

local function buildInfo(squad: Squad): Types.RaceInfo
	local ids = {}
	for _, member in squad.members do
		table.insert(ids, member.UserId)
	end
	return {
		squadId = squad.id,
		totalSegments = #squad.course.checkpoints,
		memberIds = ids,
		segmentNames = DailySeed.displayNames(squad.course.segmentNames),
		cooldown = math.max(0, squad.lastPassTime + Config.TOSS_COOLDOWN - os.clock()),
		tossing = squad.tossing,
		result = nil,
	}
end

local function elapsedTime(squad: Squad): number
	if squad.state == "Countdown" then
		return math.max(0, squad.countdownEnd - os.clock())
	elseif squad.state == "Running" then
		return os.clock() - squad.startClock
	end
	return (squad.endClock or os.clock()) - squad.startClock
end

local function sendState(squad: Squad, player: Player, info: Types.RaceInfo)
	local gap = squad.lanternDistance - squad.avalancheDistance
	local carrierId = if squad.carrier then squad.carrier.UserId else 0
	Remotes.RaceStateUpdate():FireClient(player, squad.state, squad.checkpointsCleared, elapsedTime(squad), gap, carrierId, info)
end

local function broadcast(squad: Squad)
	local info = buildInfo(squad)
	for _, member in squad.members do
		sendState(squad, member, info)
	end
end

-- Respawn points ------------------------------------------------------------------

-- The last checkpoint, unless the wall has already passed it; then the first solid
-- waypoint safely ahead of the wall.
function RaceService.safePoint(squad: Squad): Vector3
	local course = squad.course
	local index = squad.checkpointsCleared
	local checkpointDist = if index > 0 then course.checkpointDistances[index] else course.startDistance
	local point = if index > 0 then course.respawnPoints[index] else course.startSpawn
	if squad.state ~= "Running" then
		return point
	end
	local minDist = squad.avalancheDistance + Config.SAFE_RESPAWN_AHEAD
	if checkpointDist >= minDist then
		return point
	end
	return CourseService.waypointAtOrAfter(course, minDist) + Vector3.new(0, 3, 0)
end

local function puff(squad: Squad, player: Player, reason: string)
	local now = os.clock()
	if (squad.immunity[player] or 0) > now then
		return
	end
	squad.immunity[player] = now + Config.PUFF_IMMUNITY_SECONDS
	local character = player.Character
	local root = getRoot(player)
	if not character or not root then
		return
	end
	local from = root.Position
	burst(from, "snow", 25)
	local target = RaceService.safePoint(squad)
	character:PivotTo(facingDownhill(target))
	root.AssemblyLinearVelocity = Vector3.zero
	local text = if reason == "fell" then "Whoops! Back on the trail" else "Puffed by the avalanche!"
	notify(player, "puff", text, nil)
	for _, member in squad.members do
		if member ~= player then
			notify(member, "puffOther", player.DisplayName .. " got puffed!", from)
		end
	end
end

-- Race flow -----------------------------------------------------------------------

local function cleanup(squad: Squad)
	if squads[squad.id] ~= squad then
		return
	end
	squads[squad.id] = nil
	for _, member in squad.members do
		if playerSquad[member] == squad then
			playerSquad[member] = nil
		end
		if member.Parent then
			LanternService.applyMovement(member, nil)
			if returnToLobby then
				-- Run Again sends them straight onto the Start ring.
				returnToLobby(member, squad.rematch[member] == true)
			end
		end
	end
	LanternService.destroy(squad)
	CourseService.destroy(squad.course)
end

local function lightGate(squad: Squad)
	local gate = squad.course.gate
	if not gate then
		return
	end
	local hook = gate:FindFirstChild("Hook", true)
	if hook and hook:IsA("BasePart") then
		LanternService.deliver(squad, hook.Position - Vector3.new(0, 1.4, 0))
	end
	for _, d in gate:GetDescendants() do
		if d.Name == "GateGlow" and d:IsA("BasePart") then
			d.Material = Enum.Material.Neon
			d.Color = MonetizationService.FLAME_COLORS.Gold
		elseif d.Name == "GateLight" and d:IsA("Light") then
			d.Enabled = true
		end
	end
	local kitOwner = false
	for _, member in squad.members do
		if MonetizationService.ownsKit(member) then
			kitOwner = true
		end
	end
	if kitOwner then
		local confetti = gate:FindFirstChild("Confetti", true)
		if confetti and confetti:IsA("ParticleEmitter") then
			confetti:Emit(160)
		end
	end
	local position = if hook and hook:IsA("BasePart") then hook.Position + Vector3.new(0, 3, 0) else nil
	if position then
		burst(position, "sparkle", 100) -- for everyone; Trailblazer Kit adds confetti on top
	end
	notifySquad(squad, "gate", "Lantern delivered!", position)
end

function RaceService.endRace(squad: Squad, reason: EndReason)
	if squad.state == "Ended" then
		return
	end
	local wasRunning = squad.state == "Running"
	squad.state = "Ended"
	squad.endReason = reason
	squad.endClock = os.clock()
	AvalancheService.stop(squad)

	if reason == "Finished" then
		lightGate(squad)
	elseif reason == "Caught" then
		if squad.lantern then
			burst(squad.lantern.Position, "snow", 70)
		end
		LanternService.park(squad)
	end

	local segments = squad.checkpointsCleared
	local time = if wasRunning then squad.lastCheckpointTime else 0
	local total = #squad.course.checkpoints
	local info = buildInfo(squad)

	for _, member in squad.members do
		LanternService.applyMovement(member, squad)
		if reason ~= "Abandoned" then
			local before = DataService.get(member)
			local badgesBefore = if before then before.frostBadges else 0
			local newBest = DataService.recordRun(member, squad.dateKey, segments, time)
			-- Daily streak: any run that clears a segment counts for today.
			if segments >= 1 then
				local streak, extended, bonus = DataService.updateStreak(member)
				if extended then
					local text = if bonus > 0
						then string.format("🔥 %d-day streak! +%d bonus segments", streak, bonus)
						else string.format("🔥 %d-day streak!", streak)
					task.delay(0.8, notify, member, "streak", text, nil)
				end
				DataService.refresh(member)
			end
			local after = DataService.get(member)
			local earned = math.max(0, (if after then after.frostBadges else 0) - badgesBefore)
			if reason == "Finished" then
				DataService.setTutorialDone(member) -- first delivery: tips are done
			end
			local data = DataService.get(member)
			local memberInfo = table.clone(info)
			memberInfo.result = {
				reason = reason,
				segments = segments,
				totalSegments = total,
				time = time,
				elapsed = if wasRunning then (squad.endClock :: number) - squad.startClock else 0,
				newBest = newBest,
				badgesEarned = earned,
				frostBadges = if data then data.frostBadges else 0,
			}
			sendState(squad, member, memberInfo)
			if earned > 0 then
				local total = memberInfo.result.frostBadges
				notify(member, "badge", string.format("Frost Badge earned! (%d total)", total), nil)
				task.delay(1.5, RewardService.announceUnlocks, member, total - earned, total)
			end
		end
	end

	task.delay(if reason == "Abandoned" then 0 else Config.POST_RACE_SECONDS, cleanup, squad)
end

function RaceService.reachCheckpoint(squad: Squad, index: number): boolean
	if squad.state ~= "Running" or index ~= squad.checkpointsCleared + 1 then
		return false
	end
	local now = os.clock()
	if now - squad.lastCheckpointClock < Config.CHECKPOINT_MIN_INTERVAL then
		return false
	end
	squad.checkpointsCleared = index
	squad.lastCheckpointClock = now
	squad.lastCheckpointTime = now - squad.startClock

	local checkpoint = squad.course.checkpoints[index]
	if index >= #squad.course.checkpoints then
		RaceService.endRace(squad, "Finished")
	else
		notifySquad(squad, "checkpoint", "+Checkpoint", checkpoint.Position + Vector3.new(0, 4, 0))
		burst(checkpoint.Position + Vector3.new(0, 4, 0), "sparkle", 40)
		local banner = checkpoint.Parent and checkpoint.Parent:FindFirstChild("BannerCloth")
		if banner and banner:IsA("BasePart") then
			banner.Color = MonetizationService.FLAME_COLORS.Gold
		end
	end
	return true
end

local function tick(squad: Squad)
	if squad.state ~= "Running" then
		if squad.state == "Countdown" then
			broadcast(squad)
		end
		return
	end
	local lantern = squad.lantern
	if lantern then
		squad.lanternDistance = CourseService.project(squad.course, lantern.Position)
		local nextIndex = squad.checkpointsCleared + 1
		local checkpoint = squad.course.checkpoints[nextIndex]
		if checkpoint and insidePart(checkpoint, lantern.Position) then
			RaceService.reachCheckpoint(squad, nextIndex)
		end
	end
	if squad.state ~= "Running" then
		return
	end
	for _, member in squad.members do
		local root = getRoot(member)
		if root and root.Position.Y < squad.course.killY then
			puff(squad, member, "fell")
		end
	end
	if lantern and squad.carrier == nil and not squad.tossing and lantern.Position.Y < squad.course.killY then
		RaceService.endRace(squad, "Caught")
		return
	end
	broadcast(squad)
end

local function beginRunning(squad: Squad)
	if squad.state ~= "Countdown" then
		return
	end
	squad.state = "Running"
	squad.startClock = os.clock()
	squad.lastCheckpointClock = squad.startClock
	for _, member in squad.members do
		LanternService.applyMovement(member, squad)
	end
	AvalancheService.start(squad, {
		onLanternCaught = function()
			RaceService.endRace(squad, "Caught")
		end,
		onPlayerCaught = function(player: Player)
			puff(squad, player, "avalanche")
		end,
	})
	notifySquad(squad, "go", "GO!", nil)
end

function RaceService.startRace(members: { Player })
	local valid = {}
	for _, member in members do
		if member.Parent and not playerSquad[member] and getRoot(member) then
			table.insert(valid, member)
		end
	end
	if #valid == 0 then
		return
	end

	nextSquadId += 1
	local seed = DailySeed.todaySeed()
	local course = CourseService.build(DailySeed.pickSegments(seed))
	local now = os.clock()
	local squad: Squad = {
		id = nextSquadId,
		members = valid,
		state = "Countdown",
		course = course,
		dateKey = DailySeed.dateKey(seed),
		lantern = nil,
		carrier = nil,
		tossing = false,
		lastPassTime = -math.huge,
		checkpointsCleared = 0,
		lastCheckpointClock = now,
		lastCheckpointTime = 0,
		countdownEnd = now + Config.RACE_COUNTDOWN_SECONDS,
		startClock = now,
		endClock = nil,
		avalancheDistance = 0,
		lanternDistance = 0,
		endReason = nil,
		immunity = {},
		rematch = {},
		slowmoUntil = 0,
	}
	squads[squad.id] = squad

	for i, member in valid do
		playerSquad[member] = squad
		if onRaceStarting then
			onRaceStarting(member)
		end
		local spot = course.startCFrame * CFrame.new((i - (#valid + 1) / 2) * 5, 3, -12)
		local character = member.Character
		if character then
			character:PivotTo(facingDownhill(spot.Position))
		end
	end

	LanternService.create(squad)
	LanternService.giveTo(squad, valid[1])
	for _, member in valid do
		LanternService.applyMovement(member, squad)
	end
	notifySquad(squad, "info", valid[1].DisplayName .. " carries the Summit Lantern!", nil)
	broadcast(squad)

	task.delay(Config.RACE_COUNTDOWN_SECONDS, beginRunning, squad)
end

function RaceService.removePlayer(player: Player)
	local squad = playerSquad[player]
	if not squad then
		return
	end
	playerSquad[player] = nil
	local index = table.find(squad.members, player)
	if index then
		table.remove(squad.members, index)
	end
	if #squad.members == 0 then
		RaceService.endRace(squad, "Abandoned")
		return
	end
	if squad.carrier == player and squad.state ~= "Ended" then
		local lantern = squad.lantern
		local heir = if lantern then LanternService.nearestAlive(squad, lantern.Position, player) else nil
		if heir then
			LanternService.giveTo(squad, heir)
			notifySquad(squad, "info", heir.DisplayName .. " grabbed the lantern!", nil)
		else
			LanternService.park(squad)
		end
	end
end

local function onDied(player: Player)
	local squad = playerSquad[player]
	if not squad or squad.state == "Ended" or squad.carrier ~= player then
		return
	end
	local lantern = squad.lantern
	local heir = if lantern then LanternService.nearestAlive(squad, lantern.Position, player) else nil
	if heir then
		LanternService.giveTo(squad, heir)
		notifySquad(squad, "info", heir.DisplayName .. " grabbed the lantern!", nil)
	else
		LanternService.park(squad)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		onDied(player)
	end)
	if not character.Parent then
		character.AncestryChanged:Wait()
	end
	task.wait() -- let the default spawn placement finish first

	local squad = playerSquad[player]
	if squad and squad.state ~= "Ended" then
		character:PivotTo(facingDownhill(RaceService.safePoint(squad)))
		if squad.carrier == nil and not squad.tossing and squad.lantern then
			LanternService.giveTo(squad, player)
		end
		LanternService.applyMovement(player, squad)
	else
		LanternService.applyMovement(player, nil)
	end
end

-- Public helpers ---------------------------------------------------------------------

function RaceService.getSquad(player: Player): Squad?
	return playerSquad[player]
end

function RaceService.isRacing(player: Player): boolean
	return playerSquad[player] ~= nil
end

function RaceService.setLobbyReturn(fn: (Player, boolean) -> ())
	returnToLobby = fn
end

function RaceService.setRaceStarting(fn: (Player) -> ())
	onRaceStarting = fn
end

-- Run Again: pressed on the results banner. When the whole squad has pressed it,
-- skip the rest of the results screen and go straight back onto the Start ring together.
function RaceService.requestRematch(player: Player): boolean
	local squad = playerSquad[player]
	if not squad or squad.state ~= "Ended" or squad.rematch[player] then
		return false
	end
	squad.rematch[player] = true
	local everyone = true
	for _, member in squad.members do
		if not squad.rematch[member] then
			everyone = false
		end
	end
	for _, member in squad.members do
		if member ~= player and not squad.rematch[member] then
			notify(member, "rematchAsk", player.DisplayName .. " wants to run again!", nil)
		end
	end
	if everyone then
		task.spawn(cleanup, squad)
	end
	return true
end

function RaceService.init()
	Remotes.RequestPass().OnServerEvent:Connect(function(player: Player, targetUserId: any)
		if type(targetUserId) ~= "number" then
			return
		end
		local squad = playerSquad[player]
		local target = Players:GetPlayerByUserId(targetUserId)
		if not squad or not target then
			return
		end
		LanternService.tryPass(squad, player, target)
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(RaceService.removePlayer)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK_INTERVAL then
			return
		end
		accumulator = 0
		for _, squad in squads do
			tick(squad)
		end
	end)
end

return RaceService

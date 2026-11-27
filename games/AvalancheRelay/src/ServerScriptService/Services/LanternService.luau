--!strict
-- LanternService: creates the Summit Lantern, welds it to the carrier, applies carrier movement,
-- and validates + animates tosses. The lantern is only ever (a) welded to a carrier's
-- HumanoidRootPart or (b) anchored and moved by the server, so it never free-falls under
-- client physics.

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MonetizationService = require(script.Parent.MonetizationService)

type Squad = Types.Squad

local LANTERN_TAG = "SummitLantern"
-- Where the lantern hangs relative to the HumanoidRootPart: just under the right hand
-- while the carrier holds their arm out (the hold pose below).
-- Measured on R15: the right-hand grip sits at about (1.05, 0.03, -1.68) in this pose; the
-- lantern's handle top is 1.55 above its center, so the handle ends up in the hand.
local CARRY_OFFSET = CFrame.new(1.05, -1.4, -1.68)

-- Roblox's default "holding a tool" arm pose, so the carrier looks like they hold the lantern out.
local HOLD_ANIMATIONS: { [Enum.HumanoidRigType]: string } = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://507768375",
	[Enum.HumanoidRigType.R6] = "rbxassetid://182393478",
}

local LanternService = {}

local holdTracks: { [Player]: AnimationTrack } = {}

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function isAlive(player: Player): boolean
	local humanoid = getHumanoid(player)
	return player.Parent ~= nil and humanoid ~= nil and humanoid.Health > 0 and getRoot(player) ~= nil
end

local function notifySquad(squad: Squad, kind: string, text: string, position: Vector3?)
	for _, member in squad.members do
		Remotes.Notify():FireClient(member, kind, text, position)
	end
end

local function decoPart(lantern: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = lantern.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = lantern
	weld.Part1 = p
	weld.Parent = p
	p.Parent = lantern
end

local function applyFlame(lantern: BasePart, player: Player?)
	local color = MonetizationService.getFlameColor(player)
	lantern.Color = color
	local light = lantern:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = color
	end
	local glow = lantern:FindFirstChild("Embers")
	if glow and glow:IsA("ParticleEmitter") then
		glow.Color = ColorSequence.new(color)
	end
end

local function setHoldPose(player: Player?, holding: boolean)
	if not player then
		return
	end
	local existing = holdTracks[player]
	if existing then
		existing:Stop(0.2)
		holdTracks[player] = nil
	end
	if not holding then
		return
	end
	local humanoid = getHumanoid(player)
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = HOLD_ANIMATIONS[humanoid.RigType] or HOLD_ANIMATIONS[Enum.HumanoidRigType.R15]
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
		holdTracks[player] = track
	end
end

local function detach(lantern: BasePart)
	local weld = lantern:FindFirstChild("CarryWeld")
	if weld then
		weld:Destroy()
	end
end

-- Movement ---------------------------------------------------------------------

-- WalkSpeed/JumpPower are only ever set here, on the server.
function LanternService.applyMovement(player: Player, squad: Squad?)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	if squad and squad.state == "Countdown" then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		return
	end
	local isCarrier = squad ~= nil and squad.state == "Running" and squad.carrier == player
	humanoid.WalkSpeed = if isCarrier then Config.CARRIER_WALKSPEED else Config.NORMAL_WALKSPEED
	humanoid.JumpPower = if isCarrier
		then Config.NORMAL_JUMPPOWER * Config.CARRIER_JUMP_MULTIPLIER
		else Config.NORMAL_JUMPPOWER
end

-- Lantern lifecycle ------------------------------------------------------------------

function LanternService.create(squad: Squad): BasePart
	local core = Instance.new("Part")
	core.Name = "SummitLantern"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1.1, 1.1, 1.1)
	core.Material = Enum.Material.Neon
	core.Color = MonetizationService.FLAME_COLORS.Gold
	core.CanCollide = false
	core.CanTouch = false
	core.Massless = true
	core.CastShadow = false
	core.Anchored = true
	core.CFrame = squad.course.startCFrame * CFrame.new(0, 4, -10)

	local frame = Color3.fromRGB(70, 52, 40)
	decoPart(core, "Cap", Vector3.new(1.5, 0.3, 1.5), CFrame.new(0, 0.85, 0), frame, Enum.Material.Metal)
	decoPart(core, "Base", Vector3.new(1.5, 0.3, 1.5), CFrame.new(0, -0.85, 0), frame, Enum.Material.Metal)
	decoPart(core, "Handle", Vector3.new(0.2, 0.6, 0.9), CFrame.new(0, 1.25, 0), frame, Enum.Material.Metal)
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		decoPart(
			core,
			"Bar",
			Vector3.new(0.15, 1.5, 0.15),
			CFrame.new(math.cos(angle) * 0.68, 0, math.sin(angle) * 0.68),
			frame,
			Enum.Material.Metal
		)
	end
	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Shape = Enum.PartType.Ball
	glass.Size = Vector3.new(1.45, 1.45, 1.45)
	glass.Transparency = 0.7
	glass.Material = Enum.Material.Glass
	glass.Color = Color3.fromRGB(255, 240, 210)
	glass.CanCollide = false
	glass.CanTouch = false
	glass.Massless = true
	glass.CastShadow = false
	glass.CFrame = core.CFrame
	local glassWeld = Instance.new("WeldConstraint")
	glassWeld.Part0 = core
	glassWeld.Part1 = glass
	glassWeld.Parent = glass
	glass.Parent = core

	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 2
	light.Shadows = true
	light.Color = core.Color
	light.Parent = core

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Rate = 10
	embers.Lifetime = NumberRange.new(0.4, 0.8)
	embers.Speed = NumberRange.new(0.5, 1.5)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Size = NumberSequence.new(0.25, 0)
	embers.LightEmission = 1
	embers.Color = ColorSequence.new(core.Color)
	embers.Parent = core

	-- Juice: a glowing streak while the lantern flies, and a sparkle pop when it's caught.
	local trailTop = Instance.new("Attachment")
	trailTop.Position = Vector3.new(0, 0.5, 0)
	trailTop.Parent = core
	local trailBottom = Instance.new("Attachment")
	trailBottom.Position = Vector3.new(0, -0.5, 0)
	trailBottom.Parent = core
	local trail = Instance.new("Trail")
	trail.Name = "TossTrail"
	trail.Attachment0 = trailTop
	trail.Attachment1 = trailBottom
	trail.Lifetime = 0.45
	trail.LightEmission = 1
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160), Color3.fromRGB(255, 160, 80))
	trail.Enabled = false
	trail.Parent = core
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "CatchBurst"
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.4, 0.8)
	burst.Speed = NumberRange.new(8, 16)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Drag = 4
	burst.Size = NumberSequence.new(0.6, 0)
	burst.LightEmission = 1
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140))
	burst.Parent = core

	core:SetAttribute("SquadId", squad.id)
	core:SetAttribute("CarrierUserId", 0)
	CollectionService:AddTag(core, LANTERN_TAG)
	core.Parent = squad.course.model
	squad.lantern = core
	return core
end

function LanternService.giveTo(squad: Squad, player: Player): boolean
	local lantern = squad.lantern
	local root = getRoot(player)
	if not lantern or not root then
		return false
	end
	detach(lantern)
	-- Unanchor before welding, otherwise the carrier would be frozen in place.
	lantern.Anchored = false
	lantern.CFrame = root.CFrame * CARRY_OFFSET
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = lantern
	weld.Parent = lantern

	local previous = squad.carrier
	squad.carrier = player
	lantern:SetAttribute("CarrierUserId", player.UserId)
	applyFlame(lantern, player)
	if previous and previous ~= player then
		setHoldPose(previous, false)
		LanternService.applyMovement(previous, squad)
	end
	setHoldPose(player, true)
	LanternService.applyMovement(player, squad)
	return true
end

-- Leaves the lantern anchored where it is (e.g. the carrier died with nobody to hand it to).
function LanternService.park(squad: Squad)
	local lantern = squad.lantern
	if not lantern then
		return
	end
	local position = lantern.Position
	detach(lantern)
	lantern.Anchored = true
	lantern.CFrame = CFrame.new(position)
	local previous = squad.carrier
	squad.carrier = nil
	lantern:SetAttribute("CarrierUserId", 0)
	setHoldPose(previous, false)
	if previous then
		LanternService.applyMovement(previous, squad)
	end
end

function LanternService.nearestAlive(squad: Squad, from: Vector3, exclude: Player?): Player?
	local best: Player? = nil
	local bestDist = math.huge
	for _, member in squad.members do
		if member ~= exclude and isAlive(member) then
			local root = getRoot(member) :: BasePart
			local d = (root.Position - from).Magnitude
			if d < bestDist then
				best, bestDist = member, d
			end
		end
	end
	return best
end

-- Tossing -----------------------------------------------------------------------------

local function hasLineOfSight(squad: Squad, fromRoot: BasePart, toRoot: BasePart): boolean
	local ignore: { Instance } = {}
	for _, member in squad.members do
		if member.Character then
			table.insert(ignore, member.Character)
		end
	end
	if squad.lantern then
		table.insert(ignore, squad.lantern)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true -- invisible triggers and the avalanche hitbox don't block
	local origin = fromRoot.Position + Vector3.new(0, 1.5, 0)
	local target = toRoot.Position + Vector3.new(0, 1.5, 0)
	return Workspace:Raycast(origin, target - origin, params) == nil
end

local function animateToss(squad: Squad, from: Player, to: Player)
	local lantern = squad.lantern :: BasePart
	squad.tossing = true
	detach(lantern)
	lantern.Anchored = true
	squad.carrier = nil
	lantern:SetAttribute("CarrierUserId", 0)
	setHoldPose(from, false)
	LanternService.applyMovement(from, squad)

	local startPos = lantern.Position

	local function targetPos(): Vector3
		local root = getRoot(to)
		return if root then (root.CFrame * CARRY_OFFSET).Position else startPos
	end
	local distance = (targetPos() - startPos).Magnitude
	local peak = math.max(Config.TOSS_ARC_HEIGHT, distance * 0.3)

	-- Big tosses get the slow-mo treatment: clients play the camera effect, and the
	-- avalanche briefly slows so the moment reads (same for every squad).
	local big = distance >= Config.BIG_TOSS_DISTANCE
	if big then
		squad.slowmoUntil = os.clock() + Config.TOSS_FLIGHT_SECONDS + 0.2
	end
	notifySquad(squad, if big then "bigToss" else "toss", if big then "Big toss!" else "Toss!", startPos + Vector3.new(0, 2, 0))
	local trail = lantern:FindFirstChild("TossTrail")
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
	end

	local driver = Instance.new("NumberValue")
	driver.Value = 0
	local connection = driver.Changed:Connect(function(t: number)
		-- Quadratic Bezier that tracks the receiver while they move.
		local finish = targetPos()
		local control = (startPos + finish) / 2 + Vector3.new(0, peak, 0)
		local a = startPos:Lerp(control, t)
		local b = control:Lerp(finish, t)
		lantern.CFrame = CFrame.new(a:Lerp(b, t)) * CFrame.Angles(0, t * math.pi * 2, 0)
	end)

	local tween = TweenService:Create(driver, TweenInfo.new(Config.TOSS_FLIGHT_SECONDS, Enum.EasingStyle.Linear), { Value = 1 })
	tween.Completed:Connect(function()
		connection:Disconnect()
		driver:Destroy()
		squad.tossing = false
		if trail and trail:IsA("Trail") then
			trail.Enabled = false
		end
		local burst = lantern:FindFirstChild("CatchBurst")
		if burst and burst:IsA("ParticleEmitter") and lantern.Parent then
			burst:Emit(if big then 40 else 20)
		end
		if squad.state ~= "Running" or squad.lantern ~= lantern or lantern.Parent == nil then
			return
		end
		local receiver: Player? = nil
		if isAlive(to) and table.find(squad.members, to) then
			receiver = to
		elseif isAlive(from) and table.find(squad.members, from) then
			receiver = from
		else
			receiver = LanternService.nearestAlive(squad, lantern.Position, nil)
		end
		if receiver then
			LanternService.giveTo(squad, receiver)
			notifySquad(squad, "catch", "Nice Toss!", lantern.Position + Vector3.new(0, 2.5, 0))
		end
	end)
	tween:Play()
end

-- Every check runs here on the server; the client only names a target.
function LanternService.tryPass(squad: Squad, from: Player, to: Player): boolean
	if squad.state ~= "Running" or squad.tossing then
		return false
	end
	if squad.carrier ~= from or from == to or not table.find(squad.members, to) then
		return false
	end
	local now = os.clock()
	if now - squad.lastPassTime < Config.TOSS_COOLDOWN then
		return false
	end
	if not isAlive(from) or not isAlive(to) then
		return false
	end
	local fromRoot = getRoot(from) :: BasePart
	local toRoot = getRoot(to) :: BasePart
	if (toRoot.Position - fromRoot.Position).Magnitude > Config.TOSS_RANGE then
		Remotes.Notify():FireClient(from, "warning", "Too far to toss!", nil)
		return false
	end
	if not hasLineOfSight(squad, fromRoot, toRoot) then
		Remotes.Notify():FireClient(from, "warning", "Something's in the way!", nil)
		return false
	end
	squad.lastPassTime = now
	animateToss(squad, from, to)
	return true
end

-- Village Gate delivery: the lantern flies onto the gate hook.
function LanternService.deliver(squad: Squad, hookPosition: Vector3)
	local lantern = squad.lantern
	if not lantern then
		return
	end
	detach(lantern)
	lantern.Anchored = true
	local previous = squad.carrier
	squad.carrier = nil
	lantern:SetAttribute("CarrierUserId", 0)
	setHoldPose(previous, false)
	if previous then
		LanternService.applyMovement(previous, squad)
	end
	TweenService:Create(
		lantern,
		TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(hookPosition) }
	):Play()
	local light = lantern:FindFirstChildOfClass("PointLight")
	if light then
		TweenService:Create(light, TweenInfo.new(1), { Range = 28, Brightness = 4 }):Play()
	end
end

function LanternService.destroy(squad: Squad)
	for _, member in squad.members do
		setHoldPose(member, false)
	end
	if squad.lantern then
		squad.lantern:Destroy()
		squad.lantern = nil
	end
end

function LanternService.init()
	-- Recolor a carried lantern when its carrier picks a new Trailblazer flame.
	MonetizationService.FlameChanged:Connect(function(player: Player)
		for _, inst in CollectionService:GetTagged(LANTERN_TAG) do
			if inst:IsA("BasePart") and inst:GetAttribute("CarrierUserId") == player.UserId then
				applyFlame(inst, player)
			end
		end
	end)
end

return LanternService

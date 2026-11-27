--!strict
-- AvalancheService: moves an anchored snow wall along each squad's waypoint path on Heartbeat,
-- ramping speed from AVALANCHE_START_SPEED to AVALANCHE_MAX_SPEED, and checks the hitbox with
-- GetPartsInPart for the lantern (run over) and players (puffed back, no damage).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local CourseService = require(script.Parent.CourseService)

type Squad = Types.Squad

export type Callbacks = {
	onLanternCaught: () -> (),
	onPlayerCaught: (Player) -> (),
}

type Active = {
	squad: Squad,
	model: Model,
	hitbox: BasePart,
	elapsed: number,
	checkTimer: number,
	callbacks: Callbacks,
	params: OverlapParams,
}

local AvalancheService = {}

local active: { [number]: Active } = {}

-- Fallback wall if ServerStorage.AvalancheWall is missing.
local function buildFallbackWall(): Model
	local model = Instance.new("Model")
	model.Name = "AvalancheWall"
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(84, 64, 14)
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.Material = Enum.Material.SmoothPlastic
	hitbox.Color = Color3.fromRGB(240, 246, 252)
	hitbox.Parent = model
	model.PrimaryPart = hitbox
	return model
end

local function makeWall(): (Model, BasePart)
	local template = ServerStorage:FindFirstChild("AvalancheWall")
	local model = if template and template:IsA("Model") then template:Clone() else buildFallbackWall()
	local hitbox = model:FindFirstChild("Hitbox")
	assert(hitbox and hitbox:IsA("BasePart"), "AvalancheWall needs a Hitbox part")
	model.PrimaryPart = hitbox
	return model, hitbox
end

local function placeWall(entry: Active)
	local squad = entry.squad
	local course = squad.course
	local point = CourseService.pointAt(course, squad.avalancheDistance)
	-- The wall rolls straight down the mountain (+Z), centered on the course;
	-- its front face sits on the current path point.
	local forward = Vector3.zAxis
	local depth = entry.hitbox.Size.Z
	local center = Vector3.new(course.centerX, point.Y + Config.AVALANCHE_VERTICAL_OFFSET, point.Z) - forward * (depth / 2)
	entry.model:PivotTo(CFrame.lookAt(center, center + forward))
end

local function checkHits(entry: Active)
	local squad = entry.squad
	local include: { Instance } = {}
	local lantern = squad.lantern
	if lantern then
		table.insert(include, lantern)
	end
	for _, member in squad.members do
		if member.Character then
			table.insert(include, member.Character)
		end
	end
	if #include == 0 then
		return
	end
	entry.params.FilterDescendantsInstances = include

	local parts = Workspace:GetPartsInPart(entry.hitbox, entry.params)
	local caught: { [Player]: boolean } = {}
	for _, part in parts do
		if lantern and (part == lantern or part:IsDescendantOf(lantern)) then
			entry.callbacks.onLanternCaught()
			return
		end
		local character = part:FindFirstAncestorOfClass("Model")
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		if player and player ~= squad.carrier then
			caught[player] = true
		end
	end
	for player in caught do
		entry.callbacks.onPlayerCaught(player)
	end
end

local function step(dt: number)
	for id, entry in active do
		local squad = entry.squad
		if squad.state ~= "Running" then
			continue
		end
		entry.elapsed += dt
		local moving = entry.elapsed - Config.AVALANCHE_GRACE_SECONDS
		if moving > 0 then
			local t = math.clamp(moving / Config.AVALANCHE_RAMP_SECONDS, 0, 1)
			local speed = Config.AVALANCHE_START_SPEED + (Config.AVALANCHE_MAX_SPEED - Config.AVALANCHE_START_SPEED) * t
			if os.clock() < (squad.slowmoUntil or 0) then
				speed *= Config.SLOWMO_AVALANCHE_FACTOR -- big-toss bullet time
			end
			squad.avalancheDistance = math.min(squad.avalancheDistance + speed * dt, squad.course.totalLength)
		end
		placeWall(entry)

		entry.checkTimer += dt
		if entry.checkTimer >= Config.AVALANCHE_CHECK_INTERVAL then
			entry.checkTimer = 0
			checkHits(entry)
		end
	end
end

function AvalancheService.start(squad: Squad, callbacks: Callbacks)
	AvalancheService.stop(squad)
	local model, hitbox = makeWall()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local entry: Active = {
		squad = squad,
		model = model,
		hitbox = hitbox,
		elapsed = 0,
		checkTimer = 0,
		callbacks = callbacks,
		params = params,
	}
	squad.avalancheDistance = 0
	placeWall(entry)
	model.Parent = squad.course.model
	active[squad.id] = entry
end

function AvalancheService.stop(squad: Squad)
	local entry = active[squad.id]
	if entry then
		active[squad.id] = nil
		-- The wall stays in place as scenery until the course is cleaned up.
		local spray = entry.model:FindFirstChild("Spray", true)
		if spray then
			for _, emitter in spray:GetChildren() do
				if emitter:IsA("ParticleEmitter") then
					emitter.Rate = emitter.Rate * 0.3
				end
			end
		end
	end
end

function AvalancheService.init()
	RunService.Heartbeat:Connect(step)
end

return AvalancheService

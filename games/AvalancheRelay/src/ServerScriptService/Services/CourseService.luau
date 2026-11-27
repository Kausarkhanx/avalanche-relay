--!strict
-- CourseService: clones segments from ServerStorage.Segments, chains each segment's Entry
-- attachment onto the previous Exit attachment, builds the avalanche waypoint path, and
-- answers path questions. Each squad gets its own slot, offset by SQUAD_OFFSET_X on X.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type Course = Types.Course

local CourseService = {}

local usedSlots: { [number]: boolean } = {}
local coursesFolder: Folder? = nil
local segmentsFolder: Instance? = nil

local function findAttachment(root: Instance, name: string): Attachment?
	for _, d in root:GetDescendants() do
		if d:IsA("Attachment") and d.Name == name then
			return d
		end
	end
	return nil
end

-- Optional intermediate path points inside a segment, named WP_1, WP_2, ...
local function waypointAttachments(root: Instance): { Attachment }
	local found: { { index: number, att: Attachment } } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Attachment") then
			local n = string.match(d.Name, "^WP_(%d+)$")
			if n then
				table.insert(found, { index = tonumber(n) :: number, att = d })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.index < b.index
	end)
	local out = {}
	for _, f in found do
		table.insert(out, f.att)
	end
	return out
end

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Snow
	p.Color = Color3.fromRGB(236, 243, 250)
	p.Parent = parent
	return p
end

-- A start pad for each course. The run begins at its front edge (local z = 0).
local function makeTrailhead(origin: CFrame): (Model, Attachment)
	local model = Instance.new("Model")
	model.Name = "Trailhead"

	local root = newPart(model, "Root", Vector3.one, origin)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	model.PrimaryPart = root

	newPart(model, "Pad", Vector3.new(36, 2, 34), origin * CFrame.new(0, -1, -17))
	local ridge = newPart(model, "Crest", Vector3.new(60, 12, 8), origin * CFrame.new(0, 5, -38))
	ridge.Color = Color3.fromRGB(205, 220, 236)

	local line = newPart(model, "StartLine", Vector3.new(36, 0.2, 1), origin * CFrame.new(0, 0.05, -1))
	line.Material = Enum.Material.Neon
	line.Color = Color3.fromRGB(255, 209, 102)
	line.CanCollide = false
	line.CanQuery = false

	local exit = Instance.new("Attachment")
	exit.Name = "Exit"
	exit.Parent = root
	return model, exit
end

local function cumulativeOf(waypoints: { Vector3 }): { number }
	local cumulative = { 0 }
	for i = 2, #waypoints do
		cumulative[i] = cumulative[i - 1] + (waypoints[i] - waypoints[i - 1]).Magnitude
	end
	return cumulative
end

local function direction(a: Vector3, b: Vector3): Vector3
	local d = b - a
	if d.Magnitude < 1e-4 then
		return Vector3.zAxis
	end
	return d.Unit
end

-- Path queries ----------------------------------------------------------------

function CourseService.pointAt(course: Course, distance: number): (Vector3, Vector3)
	local wps, cum = course.waypoints, course.cumulative
	if distance <= 0 then
		return wps[1], direction(wps[1], wps[2])
	end
	for i = 1, #wps - 1 do
		if distance <= cum[i + 1] then
			local segLen = cum[i + 1] - cum[i]
			local t = if segLen > 0 then (distance - cum[i]) / segLen else 0
			return wps[i]:Lerp(wps[i + 1], t), direction(wps[i], wps[i + 1])
		end
	end
	local n = #wps
	return wps[n], direction(wps[n - 1], wps[n])
end

-- Distance along the path of the closest point to `position`.
function CourseService.project(course: Course, position: Vector3): number
	local wps, cum = course.waypoints, course.cumulative
	local bestDist, bestAlong = math.huge, 0
	for i = 1, #wps - 1 do
		local a, b = wps[i], wps[i + 1]
		local ab = b - a
		local lenSq = ab:Dot(ab)
		local t = if lenSq > 0 then math.clamp((position - a):Dot(ab) / lenSq, 0, 1) else 0
		local d = (position - (a + ab * t)).Magnitude
		if d < bestDist then
			bestDist = d
			bestAlong = cum[i] + t * math.sqrt(lenSq)
		end
	end
	return bestAlong
end

-- First waypoint (always on solid ground) at or beyond `distance`.
function CourseService.waypointAtOrAfter(course: Course, distance: number): Vector3
	for i, d in course.cumulative do
		if i > 1 and d >= distance then
			return course.waypoints[i]
		end
	end
	return course.waypoints[#course.waypoints]
end

-- Build / destroy ----------------------------------------------------------------

function CourseService.build(segmentNames: { string }): Course
	local folder = coursesFolder :: Folder
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true

	local centerX = slot * Config.SQUAD_OFFSET_X
	local origin = CFrame.new(centerX, Config.COURSE_ORIGIN_Y, 0)

	local model = Instance.new("Model")
	model.Name = "Course_" .. slot
	model.Parent = folder

	local trailhead, trailExit = makeTrailhead(origin)
	trailhead.Parent = model

	local waypoints: { Vector3 } = {
		origin.Position + Vector3.new(0, 0, -34 - Config.AVALANCHE_START_BEHIND),
		origin.Position,
	}
	local checkpoints: { BasePart } = {}
	local respawnPoints: { Vector3 } = {}
	local builtNames: { string } = {}
	local gate: Model? = nil
	local prevExit = trailExit

	for _, name in segmentNames do
		local template = if segmentsFolder then segmentsFolder:FindFirstChild(name) else nil
		if not (template and template:IsA("Model")) then
			warn("[CourseService] Missing segment model ServerStorage.Segments." .. name)
			continue
		end
		local seg = template:Clone()
		local entry = findAttachment(seg, "Entry")
		local exit = findAttachment(seg, "Exit")
		if not entry or not exit then
			warn("[CourseService] Segment " .. name .. " needs Entry and Exit attachments")
			seg:Destroy()
			continue
		end

		-- Snap this segment's Entry onto the previous segment's Exit.
		seg:PivotTo(prevExit.WorldCFrame * entry.WorldCFrame:Inverse() * seg:GetPivot())
		seg.Parent = model

		for _, wp in waypointAttachments(seg) do
			table.insert(waypoints, wp.WorldPosition)
		end
		table.insert(waypoints, exit.WorldPosition)

		local checkpoint = seg:FindFirstChild("Checkpoint", true)
		if not (checkpoint and checkpoint:IsA("BasePart")) then
			local fallback = newPart(seg, "Checkpoint", Vector3.new(24, 12, 6), exit.WorldCFrame * CFrame.new(0, 6, -6))
			fallback.Transparency = 1
			fallback.CanCollide = false
			fallback.CanQuery = false
			fallback.CanTouch = false
			checkpoint = fallback
		end
		table.insert(checkpoints, checkpoint :: BasePart)
		table.insert(respawnPoints, exit.WorldPosition + Vector3.new(0, 3, -8))
		table.insert(builtNames, name)
		if name == "VillageGate" then
			gate = seg
		end
		prevExit = exit
	end

	local cumulative = cumulativeOf(waypoints)
	local bboxCFrame, bboxSize = model:GetBoundingBox()

	local course: Course = {
		slot = slot,
		model = model,
		segmentNames = builtNames,
		checkpoints = checkpoints,
		respawnPoints = respawnPoints,
		checkpointDistances = {},
		waypoints = waypoints,
		cumulative = cumulative,
		totalLength = cumulative[#cumulative],
		startCFrame = origin,
		startSpawn = (origin * CFrame.new(0, 3, -12)).Position,
		startDistance = 0,
		killY = bboxCFrame.Position.Y - bboxSize.Y / 2 - 25,
		centerX = centerX,
		gate = gate,
	}
	course.startDistance = CourseService.project(course, course.startSpawn)
	for i, cp in checkpoints do
		course.checkpointDistances[i] = CourseService.project(course, cp.Position)
	end
	return course
end

function CourseService.destroy(course: Course)
	course.model:Destroy()
	usedSlots[course.slot] = nil
end

function CourseService.init()
	local existing = Workspace:FindFirstChild("Courses")
	if existing and existing:IsA("Folder") then
		coursesFolder = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = "Courses"
		folder.Parent = Workspace
		coursesFolder = folder
	end
	segmentsFolder = ServerStorage:FindFirstChild("Segments")
	if not segmentsFolder then
		warn("[CourseService] ServerStorage.Segments is missing. Run tools/BuildWorld.luau in Studio.")
	end
end

return CourseService

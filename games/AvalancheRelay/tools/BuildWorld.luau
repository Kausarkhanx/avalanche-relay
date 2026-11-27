-- Avalanche Relay world builder. Run in Studio (Edit mode) from the command bar or MCP.
-- Rebuilds: Workspace.Lobby, ServerStorage.Segments (8 + Village Gate), ServerStorage.AvalancheWall,
-- Lighting, SoundService groups and StarterPlayer movement defaults. Safe to run again.
-- Parts only: no meshes, no uploaded assets.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local C = {
	Snow = Color3.fromRGB(236, 243, 250),
	SnowShade = Color3.fromRGB(205, 220, 236),
	Ice = Color3.fromRGB(160, 210, 240),
	DeepIce = Color3.fromRGB(70, 130, 200),
	Rock = Color3.fromRGB(88, 96, 112),
	Wood = Color3.fromRGB(124, 86, 58),
	DarkWood = Color3.fromRGB(86, 58, 40),
	Pine = Color3.fromRGB(46, 92, 74),
	Gold = Color3.fromRGB(255, 209, 102),
	Blue = Color3.fromRGB(111, 168, 220),
	Night = Color3.fromRGB(16, 24, 38),
}

local M = Enum.Material
local V = Vector3.new
local rng = Random.new(2026)

local function newPart(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.Snow
	p.Color = C.Snow
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function deco(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- Ground slab with its top surface at `top`, spanning z0..z1.
local function pad(m: Instance, x: number, top: number, z0: number, z1: number, width: number, color: Color3?, material: Enum.Material?): Part
	return newPart(m, {
		Name = "Ground",
		Size = V(width, 2, z1 - z0),
		CFrame = CFrame.new(x, top - 1, (z0 + z1) / 2),
		Color = color or C.Snow,
		Material = material or M.Snow,
	})
end

-- Sloped slab whose top surface runs from a to b.
local function ramp(m: Instance, a: Vector3, b: Vector3, width: number, color: Color3?, material: Enum.Material?): Part
	local mid = (a + b) / 2
	return newPart(m, {
		Name = "Ramp",
		Size = V(width, 2, (b - a).Magnitude + 1),
		CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, -1, 0),
		Color = color or C.Snow,
		Material = material or M.Snow,
	})
end

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's axis vertical

local function pine(m: Instance, base: Vector3, h: number)
	local trunkH = h * 0.28
	newPart(m, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = V(trunkH + 1, 1.4, 1.4),
		CFrame = CFrame.new(base + V(0, trunkH / 2, 0)) * UPRIGHT,
		Material = M.Wood,
		Color = C.DarkWood,
	})
	-- Branches start low (2.5 studs) so nobody can slip underneath them.
	local branchStart = math.min(trunkH, 2.5)
	for i = 1, 3 do
		local d = h * 0.6 * (1 - (i - 1) * 0.27)
		local th = h * 0.24
		local y = branchStart + (i - 1) * th * 0.8 + th / 2
		-- Needles are solid: trees are real obstacles you have to go around.
		newPart(m, {
			Name = "Needles",
			Shape = Enum.PartType.Cylinder,
			Size = V(th, d, d),
			CFrame = CFrame.new(base + V(0, y, 0)) * UPRIGHT,
			Material = M.Grass,
			Color = C.Pine,
		})
		deco(newPart(m, {
			Name = "SnowCap",
			Shape = Enum.PartType.Cylinder,
			Size = V(0.5, d * 0.8, d * 0.8),
			CFrame = CFrame.new(base + V(0, y + th / 2 + 0.2, 0)) * UPRIGHT,
		}))
	end
end

local function rock(m: Instance, pos: Vector3, size: Vector3, collide: boolean?)
	local p = newPart(m, {
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
		Material = M.Slate,
		Color = C.Rock,
	})
	if not collide then
		deco(p)
	end
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui
	gui.Parent = part
end

-- Banner and invisible Checkpoint trigger just before the segment exit.
local function checkpointBanner(m: Instance, exitPos: Vector3, width: number)
	local z = exitPos.Z - 6
	local y = exitPos.Y
	for _, side in { -1, 1 } do
		newPart(m, { Name = "BannerPost", Size = V(1.2, 13, 1.2), CFrame = CFrame.new(side * width / 2, y + 6.5, z), Material = M.Wood, Color = C.DarkWood })
		local bulb = deco(newPart(m, { Name = "BannerLamp", Shape = Enum.PartType.Ball, Size = V(1.4, 1.4, 1.4), CFrame = CFrame.new(side * width / 2, y + 13.6, z), Material = M.Neon, Color = C.Gold }))
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Color = C.Gold
		light.Parent = bulb
	end
	local cloth = deco(newPart(m, { Name = "BannerCloth", Size = V(width - 2, 3.2, 0.4), CFrame = CFrame.new(0, y + 11, z), Material = M.Fabric, Color = C.Blue }))
	surfaceText(cloth, Enum.NormalId.Front, "CHECKPOINT", Color3.new(1, 1, 1))
	surfaceText(cloth, Enum.NormalId.Back, "CHECKPOINT", Color3.new(1, 1, 1))
	newPart(m, {
		Name = "Checkpoint",
		Size = V(width, 12, 6),
		CFrame = CFrame.new(0, y + 6, z),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

local function newSegment(name: string, exit: Vector3, difficulty: number, toss: boolean): (Model, Part)
	local m = Instance.new("Model")
	m.Name = name
	local root = newPart(m, { Name = "Root", Size = V(2, 2, 2), CFrame = CFrame.new(), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	m.PrimaryPart = root
	local entry = Instance.new("Attachment")
	entry.Name = "Entry"
	entry.Parent = root
	local ex = Instance.new("Attachment")
	ex.Name = "Exit"
	ex.Position = exit
	ex.Parent = root
	m:SetAttribute("Difficulty", difficulty)
	m:SetAttribute("TossRequired", toss)
	return m, root
end

local function wp(root: Part, index: number, pos: Vector3)
	local a = Instance.new("Attachment")
	a.Name = "WP_" .. index
	a.Position = pos
	a.Parent = root
end

local function crevasse(m: Instance, z0: number, z1: number, topY: number, width: number)
	deco(newPart(m, { Name = "CrevasseGlow", Size = V(width, 1, z1 - z0), CFrame = CFrame.new(0, topY - 40, (z0 + z1) / 2), Material = M.Neon, Color = C.DeepIce }))
	for _, z in { z0 - 1, z1 + 1 } do
		deco(newPart(m, { Name = "CrevasseWall", Size = V(width, 34, 2), CFrame = CFrame.new(0, topY - 19, z), Material = M.Glacier, Color = C.Ice }))
	end
end

-- Segments (local coords: forward +Z, Entry at the origin) --------------------------

local builders: { [string]: () -> Model } = {}

builders.Switchbacks = function()
	local exit = V(0, -30, 120)
	local m, root = newSegment("Switchbacks", exit, 1, false)
	pad(m, 0, 0, 0, 16, 24)
	pad(m, -18, -8, 28, 42, 14)
	pad(m, 18, -16, 52, 66, 14)
	pad(m, -18, -24, 76, 90, 14)
	pad(m, 0, -30, 100, 120, 26)
	ramp(m, V(-6, 0, 16), V(-16, -8, 28), 10)
	ramp(m, V(-11, -8, 38), V(11, -16, 56), 8)
	ramp(m, V(11, -16, 62), V(-11, -24, 80), 8)
	ramp(m, V(-14, -24, 90), V(-4, -30, 100), 10)
	-- cliff mass and fences
	for _, spec in { { -18, -8, 35 }, { 18, -16, 59 }, { -18, -24, 83 } } do
		rock(m, V(spec[1] * 1.3, spec[2] - 9, spec[3]), V(16, 16, 16))
		newPart(m, { Name = "Fence", Size = V(0.6, 2.5, 14), CFrame = CFrame.new(spec[1] + (if spec[1] < 0 then -7 else 7), spec[2] + 1.25, spec[3]), Material = M.Wood, Color = C.Wood })
	end
	pine(m, V(9, 0, 6), 16)
	pine(m, V(-24, -8, 31), 14)
	pine(m, V(24, -16, 63), 15)
	pine(m, V(11, -30, 106), 14)
	wp(root, 1, V(-18, -8, 35))
	wp(root, 2, V(18, -16, 59))
	wp(root, 3, V(-18, -24, 83))
	checkpointBanner(m, exit, 24)
	return m
end

builders.IceBridgeGap = function()
	local exit = V(0, -18, 120)
	local m, root = newSegment("IceBridgeGap", exit, 3, true)
	pad(m, 0, 0, 0, 20, 24)
	ramp(m, V(0, 0, 20), V(0, -6, 46), 6, C.Ice, M.Ice)
	pad(m, 0, -6, 46, 54, 12, C.Ice, M.Ice)
	crevasse(m, 54, 62, -7, 40)
	pad(m, 0, -7, 62, 80, 20)
	ramp(m, V(0, -7, 80), V(0, -18, 98), 16)
	pad(m, 0, -18, 98, 120, 24)
	-- Solo detour: ice floes a carrier can hop (slower than tossing across)
	for _, f in { { 12, -6, 50 }, { 19, -6.5, 56 }, { 24, -7, 64 }, { 19, -7, 72 }, { 13, -7, 76 } } do
		local floe = pad(m, f[1], f[2], f[3] - 3, f[3] + 3, 6, C.Ice, M.Glacier)
		floe.Name = "Floe"
		floe.CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.6, 0.2)
	end
	deco(newPart(m, { Name = "GapSign", Size = V(6, 3, 0.4), CFrame = CFrame.new(-9, -3, 52), Material = M.Wood, Color = C.Wood }))
	surfaceText(m:FindFirstChild("GapSign") :: BasePart, Enum.NormalId.Front, "TOSS IT!", C.Gold)
	pine(m, V(-8, -7, 72), 14)
	pine(m, V(9, -18, 104), 15)
	rock(m, V(-16, -10, 70), V(10, 10, 10))
	wp(root, 1, V(0, -6, 50))
	wp(root, 2, V(0, -7, 71))
	checkpointBanner(m, exit, 24)
	return m
end

builders.PineSlalom = function()
	local exit = V(0, -24, 120)
	local m = newSegment("PineSlalom", exit, 1, false)
	pad(m, 0, 0, 0, 12, 30)
	ramp(m, V(0, 0, 12), V(0, -24, 108), 30)
	pad(m, 0, -24, 108, 120, 30)
	local function slopeY(z: number): number
		return -24 * (z - 12) / 96
	end
	for _, t in { { -8, 26 }, { 6, 36 }, { -11, 45 }, { -2, 52 }, { 9, 62 }, { -9, 70 }, { 3, 80 }, { 12, 86 }, { -5, 92 }, { 8, 99 } } do
		pine(m, V(t[1], slopeY(t[2]) - 0.6, t[2]), rng:NextNumber(11, 14)) -- solid, so keep weaving gaps
	end
	for _, z in { 30, 58, 88 } do
		newPart(m, { Name = "SnowMound", Shape = Enum.PartType.Ball, Size = V(5, 5, 5), CFrame = CFrame.new(rng:NextNumber(-10, 10), slopeY(z) - 1.6, z), Color = C.SnowShade })
	end
	for _, side in { -1, 1 } do
		for z = 20, 100, 20 do
			rock(m, V(side * 17, slopeY(z), z), V(5, 4, 7), true)
		end
	end
	checkpointBanner(m, exit, 30)
	return m
end

builders.FrozenWaterfallSteps = function()
	local exit = V(0, -27, 120)
	local m = newSegment("FrozenWaterfallSteps", exit, 2, false)
	pad(m, 0, 0, 0, 14, 24)
	for i = 1, 8 do
		local z0 = 16 + (i - 1) * 11
		local step = pad(m, if i % 2 == 0 then 3 else -3, -3 * i, z0, z0 + 8, 10, C.Ice, M.Glacier)
		step.Name = "IceStep"
		step.CustomPhysicalProperties = PhysicalProperties.new(0.9, 0.6, 0.2)
		-- frozen falls cascading beside each step
		deco(newPart(m, { Name = "FrozenFall", Size = V(7, 8, 11), CFrame = CFrame.new(-13, -3 * i - 3, z0 + 4), Material = M.Glass, Color = C.Ice, Transparency = 0.25, Reflectance = 0.15 }))
		local icicle = deco(newPart(m, { Name = "Icicle", Size = V(0.6, 3, 0.6), CFrame = CFrame.new(rng:NextNumber(-7, 7), -3 * i - 2.5, z0 + 8), Material = M.Glass, Color = C.Ice, Transparency = 0.2 }))
		icicle.Name = "Icicle"
	end
	pad(m, 0, -27, 104, 120, 24)
	deco(newPart(m, { Name = "FallGlow", Size = V(2, 30, 100), CFrame = CFrame.new(-17, -15, 60), Material = M.Neon, Color = C.DeepIce, Transparency = 0.5 }))
	rock(m, V(16, -14, 40), V(12, 20, 12))
	rock(m, V(16, -24, 86), V(12, 16, 12))
	checkpointBanner(m, exit, 24)
	return m
end

builders.CollapsedCabin = function()
	local exit = V(0, -14, 120)
	local m = newSegment("CollapsedCabin", exit, 2, false)
	pad(m, 0, 0, 0, 16, 24)
	ramp(m, V(0, 0, 16), V(0, -6, 30), 16)
	pad(m, 0, -6, 30, 82, 26, C.Wood, M.WoodPlanks)
	local floorY = -6
	local function wall(x: number, z0: number, z1: number, h: number)
		newPart(m, { Name = "CabinWall", Size = V(1, h, z1 - z0), CFrame = CFrame.new(x, floorY + h / 2, (z0 + z1) / 2), Material = M.WoodPlanks, Color = C.DarkWood })
	end
	wall(-13, 30, 44, 10)
	wall(-13, 52, 62, 6)
	wall(-13, 70, 82, 10)
	wall(13, 30, 40, 10)
	wall(13, 48, 82, 8)
	for _, z in { 30, 82 } do
		newPart(m, { Name = "CabinWall", Size = V(7, 10, 1), CFrame = CFrame.new(-9.5, floorY + 5, z), Material = M.WoodPlanks, Color = C.DarkWood })
		newPart(m, { Name = "CabinWall", Size = V(7, 10, 1), CFrame = CFrame.new(9.5, floorY + 5, z), Material = M.WoodPlanks, Color = C.DarkWood })
	end
	-- hop-over beams (carrier can clear 1.8 studs)
	newPart(m, { Name = "Beam", Size = V(24, 1.8, 1.6), CFrame = CFrame.new(0, floorY + 0.9, 40), Material = M.Wood, Color = C.Wood })
	newPart(m, { Name = "Beam", Size = V(24, 2, 2), CFrame = CFrame.new(0, floorY + 1.6, 50) * CFrame.Angles(0, 0, math.rad(8)), Material = M.Wood, Color = C.Wood })
	-- collapsed roof ramp up to a loft; crates block the right side
	ramp(m, V(-4, -6, 58), V(-4, -2.5, 66), 16, C.Wood, M.WoodPlanks)
	pad(m, -4, -2.5, 66, 72, 16, C.Wood, M.WoodPlanks)
	for _, z in { 62, 69 } do
		newPart(m, { Name = "Crate", Size = V(8, 5, 7), CFrame = CFrame.new(8.5, floorY + 2.5, z), Material = M.WoodPlanks, Color = C.Wood })
	end
	-- leftover roof overhead and a lamp
	deco(newPart(m, { Name = "RoofSlab", Size = V(14, 1, 18), CFrame = CFrame.new(-6, floorY + 11, 38) * CFrame.Angles(0, 0, math.rad(-25)), Material = M.Snow }))
	deco(newPart(m, { Name = "RoofSlab", Size = V(14, 1, 14), CFrame = CFrame.new(6, floorY + 10, 76) * CFrame.Angles(0, 0, math.rad(22)), Material = M.Snow }))
	local lamp = deco(newPart(m, { Name = "CabinLamp", Size = V(1, 1.4, 1), CFrame = CFrame.new(0, floorY + 8, 56), Material = M.Neon, Color = C.Gold }))
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.5
	light.Color = C.Gold
	light.Parent = lamp
	ramp(m, V(0, -6, 82), V(0, -14, 100), 16)
	pad(m, 0, -14, 100, 120, 24)
	pine(m, V(-9, -14, 108), 14)
	checkpointBanner(m, exit, 24)
	return m
end

builders.CrevassePlanks = function()
	local exit = V(0, -10, 120)
	local m, root = newSegment("CrevassePlanks", exit, 3, true)
	pad(m, 0, 0, 0, 16, 20)
	ramp(m, V(0, 0, 16), V(0, -2, 34), 3, C.Wood, M.WoodPlanks)
	pad(m, 0, -2, 34, 42, 10)
	crevasse(m, 16, 34, -2, 30)
	crevasse(m, 42, 50, -3, 30)
	pad(m, 0, -3, 50, 62, 12)
	ramp(m, V(-2.5, -3, 62), V(-2.5, -4, 90), 3, C.Wood, M.WoodPlanks)
	ramp(m, V(2.5, -3, 62), V(2.5, -4, 90), 3, C.Wood, M.WoodPlanks)
	crevasse(m, 62, 90, -4, 30)
	pad(m, 0, -4, 90, 94, 12)
	ramp(m, V(0, -4, 94), V(0, -10, 102), 12)
	pad(m, 0, -10, 102, 120, 24)
	-- Solo detour: stepping posts around the big gap
	for _, p in { { -8, -2, 38 }, { -12, -2.5, 43 }, { -12, -3, 49 }, { -8, -3, 54 } } do
		local post = pad(m, p[1], p[2], p[3] - 2, p[3] + 2, 4, C.Rock, M.Slate)
		post.Name = "Post"
		deco(newPart(m, { Name = "PostPillar", Size = V(3, 30, 3), CFrame = CFrame.new(p[1], p[2] - 17, p[3]), Material = M.Slate, Color = C.Rock }))
	end
	-- rope rails
	for _, x in { -1.8, 1.8 } do
		local a, b = V(x, 2.5, 16), V(x, 0.5, 34)
		deco(newPart(m, { Name = "Rope", Shape = Enum.PartType.Cylinder, Size = V((b - a).Magnitude, 0.2, 0.2), CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), Material = M.Fabric, Color = C.Wood }))
	end
	deco(newPart(m, { Name = "GapSign", Size = V(6, 3, 0.4), CFrame = CFrame.new(7, 0, 40), Material = M.Wood, Color = C.Wood }))
	surfaceText(m:FindFirstChild("GapSign") :: BasePart, Enum.NormalId.Front, "TOSS IT!", C.Gold)
	wp(root, 1, V(0, -2, 38))
	wp(root, 2, V(0, -3, 56))
	wp(root, 3, V(0, -4, 92))
	checkpointBanner(m, exit, 24)
	return m
end

builders.SnowTunnel = function()
	local exit = V(0, -16, 120)
	local m = newSegment("SnowTunnel", exit, 1, false)
	pad(m, 0, 0, 0, 12, 18)
	ramp(m, V(0, 0, 12), V(0, -16, 108), 16)
	pad(m, 0, -16, 108, 120, 18)
	local function slopeY(z: number): number
		return -16 * (z - 12) / 96
	end
	for s = 0, 5 do
		local zc = 24 + s * 12 + 6
		local y = slopeY(zc)
		for _, side in { -1, 1 } do
			newPart(m, { Name = "TunnelWall", Size = V(3, 15, 12.2), CFrame = CFrame.new(side * 9.5, y + 6, zc), Color = C.SnowShade })
		end
		newPart(m, { Name = "TunnelRoof", Size = V(22, 3, 12.2), CFrame = CFrame.new(0, y + 14, zc), Color = C.Snow })
		local strip = deco(newPart(m, { Name = "IceLight", Size = V(6, 0.3, 1), CFrame = CFrame.new(0, y + 12.4, zc), Material = M.Neon, Color = C.Blue }))
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Brightness = 1.4
		light.Color = C.Blue
		light.Parent = strip
		if s % 2 == 0 then
			newPart(m, { Name = "SnowMound", Size = V(6, 2, 4), CFrame = CFrame.new(if s % 4 == 0 then -4 else 4, y + 0.4, zc), Color = C.SnowShade })
		end
	end
	rock(m, V(-14, 4, 24), V(10, 14, 8))
	rock(m, V(14, 2, 26), V(10, 12, 8))
	rock(m, V(-13, -12, 96), V(9, 10, 8))
	pine(m, V(7, -16, 112), 13)
	checkpointBanner(m, exit, 18)
	return m
end

builders.IcicleRidge = function()
	local exit = V(0, -15, 120)
	local m, root = newSegment("IcicleRidge", exit, 2, false)
	pad(m, 0, 0, 0, 14, 22)
	pad(m, -8, -5, 36.5, 43.5, 7)
	pad(m, 8, -10, 62.5, 69.5, 7)
	pad(m, 0, -15, 86.5, 93.5, 7)
	pad(m, 0, -15, 94, 120, 22)
	ramp(m, V(0, 0, 14), V(-8, -5, 36.5), 5)
	ramp(m, V(-8, -5, 43.5), V(8, -10, 62.5), 5)
	ramp(m, V(8, -10, 69.5), V(0, -15, 86.5), 5)
	for _, spec in { { -4, -2.5, 25 }, { 0, -7.5, 53 }, { 4, -12.5, 78 } } do
		rock(m, V(spec[1], spec[2] - 12, spec[3]), V(10, 20, 14))
		for _, side in { -1, 1 } do
			deco(newPart(m, {
				Name = "IceSpike",
				Size = V(0.8, rng:NextNumber(4, 7), 0.8),
				CFrame = CFrame.new(spec[1] + side * 4.5, spec[2] + 1.5, spec[3] + rng:NextNumber(-3, 3)) * CFrame.Angles(0, 0, side * 0.2),
				Material = M.Glass,
				Color = C.Ice,
				Transparency = 0.15,
			}))
		end
	end
	for _, c in { { -8, -5, 40 }, { 8, -10, 66 }, { 0, -15, 90 } } do
		for i = 1, 3 do
			deco(newPart(m, { Name = "Icicle", Size = V(0.6, rng:NextNumber(2.5, 5), 0.6), CFrame = CFrame.new(c[1] + rng:NextNumber(-3, 3), c[2] - 3.5, c[3] + rng:NextNumber(-3, 3)), Material = M.Glass, Color = C.Ice, Transparency = 0.2 }))
		end
	end
	pine(m, V(8, -15, 108), 14)
	wp(root, 1, V(-8, -5, 40))
	wp(root, 2, V(8, -10, 66))
	wp(root, 3, V(0, -15, 90))
	checkpointBanner(m, exit, 22)
	return m
end

local function cabin(m: Instance, pos: Vector3, face: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, face, 0)
	newPart(m, { Name = "House", Size = V(10, 7, 10), CFrame = cf * CFrame.new(0, 3.5, 0), Material = M.WoodPlanks, Color = C.Wood })
	for _, side in { -1, 1 } do
		newPart(m, { Name = "HouseRoof", Size = V(12, 0.8, 7.2), CFrame = cf * CFrame.new(0, 9, side * 2.8) * CFrame.Angles(side * math.rad(35), 0, 0), Material = M.Snow })
	end
	local window = deco(newPart(m, { Name = "Window", Size = V(2, 2, 0.3), CFrame = cf * CFrame.new(2.5, 4, -5.05), Material = M.Neon, Color = C.Gold }))
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Color = C.Gold
	light.Parent = window
	newPart(m, { Name = "Door", Size = V(2.4, 4.4, 0.3), CFrame = cf * CFrame.new(-2, 2.2, -5.05), Material = M.Wood, Color = C.DarkWood })
end

builders.VillageGate = function()
	local exit = V(0, -8, 120)
	local m = newSegment("VillageGate", exit, 1, false)
	local y = -8
	pad(m, 0, 0, 0, 16, 24)
	ramp(m, V(0, 0, 16), V(0, -8, 40), 20)
	pad(m, 0, y, 40, 120, 70)
	cabin(m, V(-24, y, 62), math.rad(90))
	cabin(m, V(24, y, 62), math.rad(-90))
	cabin(m, V(-25, y, 114), 0)
	cabin(m, V(25, y, 114), 0)
	-- the gate arch
	local gateZ = 100
	for _, side in { -1, 1 } do
		newPart(m, { Name = "GatePost", Size = V(2.4, 14, 2.4), CFrame = CFrame.new(side * 8, y + 7, gateZ), Material = M.Wood, Color = C.DarkWood })
		newPart(m, { Name = "GateGlow", Size = V(1.6, 1.6, 1.6), CFrame = CFrame.new(side * 8, y + 14.8, gateZ), Material = M.Glass, Color = C.Night })
		newPart(m, { Name = "Palisade", Size = V(26, 5, 0.8), CFrame = CFrame.new(side * 22.2, y + 2.5, gateZ), Material = M.WoodPlanks, Color = C.Wood })
	end
	local beam = newPart(m, { Name = "GateBeam", Size = V(20, 2, 2.4), CFrame = CFrame.new(0, y + 14, gateZ), Material = M.Wood, Color = C.Wood })
	surfaceText(beam, Enum.NormalId.Front, "VILLAGE", C.Gold)
	newPart(m, { Name = "Hook", Size = V(0.4, 1.6, 0.4), CFrame = CFrame.new(0, y + 12.2, gateZ), Material = M.Metal, Color = C.DarkWood, CanCollide = false })
	local gateLight = Instance.new("PointLight")
	gateLight.Name = "GateLight"
	gateLight.Enabled = false
	gateLight.Range = 32
	gateLight.Brightness = 3
	gateLight.Color = C.Gold
	gateLight.Parent = beam
	local confetti = Instance.new("ParticleEmitter")
	confetti.Name = "Confetti"
	confetti.Enabled = false
	confetti.Rate = 0
	confetti.Lifetime = NumberRange.new(2, 3.5)
	confetti.Speed = NumberRange.new(18, 30)
	confetti.SpreadAngle = Vector2.new(60, 60)
	confetti.Acceleration = V(0, -18, 0)
	confetti.Drag = 1
	confetti.RotSpeed = NumberRange.new(-200, 200)
	confetti.Size = NumberSequence.new(0.5)
	confetti.EmissionDirection = Enum.NormalId.Top
	confetti.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.Gold),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 143, 177)),
		ColorSequenceKeypoint.new(0.66, C.Blue),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(124, 245, 192)),
	})
	confetti.Parent = beam
	-- delivery trigger under the arch (the last "checkpoint")
	newPart(m, { Name = "Checkpoint", Size = V(16, 12, 6), CFrame = CFrame.new(0, y + 6, gateZ), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	-- lamp posts and trees
	for _, z in { 50, 70, 90 } do
		for _, side in { -1, 1 } do
			newPart(m, { Name = "LampPost", Size = V(0.6, 7, 0.6), CFrame = CFrame.new(side * 11, y + 3.5, z), Material = M.Metal, Color = C.DarkWood })
			local bulb = deco(newPart(m, { Name = "LampBulb", Size = V(1.2, 1.2, 1.2), CFrame = CFrame.new(side * 11, y + 7.4, z), Material = M.Neon, Color = C.Gold }))
			local light = Instance.new("PointLight")
			light.Range = 14
			light.Color = C.Gold
			light.Parent = bulb
		end
	end
	pine(m, V(-30, y, 80), 16)
	pine(m, V(31, y, 86), 17)
	pine(m, V(-12, 0, 6), 15)
	return m
end

-- Cozy Cocoa Lodge ----------------------------------------------------------------------

local COZY = {
	Wall = Color3.fromRGB(150, 98, 64),
	WallOut = C.DarkWood,
	Stone = Color3.fromRGB(132, 120, 112),
	Rug = Color3.fromRGB(178, 64, 72),
	RugInner = Color3.fromRGB(246, 226, 196),
	ChairA = Color3.fromRGB(196, 72, 72),
	ChairB = Color3.fromRGB(232, 170, 70),
	Cocoa = Color3.fromRGB(98, 58, 36),
	Cream = Color3.fromRGB(255, 250, 240),
	Warm = Color3.fromRGB(255, 196, 120),
	Fire = Color3.fromRGB(255, 140, 50),
}

local function steam(parent: Instance, rate: number, size: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Steam"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Rate = rate
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(0.6, 1.2)
	e.Size = NumberSequence.new(size * 0.4, size)
	e.Transparency = NumberSequence.new(0.55, 1)
	e.Acceleration = V(0, 1.2, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.LightInfluence = 0.6
	e.Parent = parent
end

-- A little mug of hot cocoa with whipped cream (and sometimes marshmallows).
local function mug(m: Instance, base: Vector3, color: Color3, marshmallows: boolean?)
	local up = CFrame.Angles(0, 0, math.pi / 2)
	deco(newPart(m, { Name = "Mug", Shape = Enum.PartType.Cylinder, Size = V(1, 0.8, 0.8), CFrame = CFrame.new(base + V(0, 0.5, 0)) * up, Material = M.SmoothPlastic, Color = color }))
	deco(newPart(m, { Name = "MugHandle", Size = V(0.16, 0.5, 0.36), CFrame = CFrame.new(base + V(0.48, 0.5, 0)), Material = M.SmoothPlastic, Color = color }))
	deco(newPart(m, { Name = "Cocoa", Shape = Enum.PartType.Cylinder, Size = V(0.06, 0.7, 0.7), CFrame = CFrame.new(base + V(0, 1, 0)) * up, Material = M.SmoothPlastic, Color = COZY.Cocoa }))
	local cream = deco(newPart(m, { Name = "Cream", Shape = Enum.PartType.Ball, Size = V(0.55, 0.55, 0.55), CFrame = CFrame.new(base + V(0, 1.1, 0)), Material = M.SmoothPlastic, Color = COZY.Cream }))
	steam(cream, 2.5, 0.8)
	if marshmallows then
		for i = 0, 2 do
			local a = i * 2.1
			deco(newPart(m, { Name = "Marshmallow", Size = V(0.2, 0.2, 0.2), CFrame = CFrame.new(base + V(math.cos(a) * 0.25, 1.08, math.sin(a) * 0.25)) * CFrame.Angles(0, a, 0.3), Material = M.SmoothPlastic, Color = Color3.fromRGB(255, 236, 240) }))
		end
	end
end

-- An armchair you can sit in. `facing` is the direction a seated player looks.
local function armchair(m: Instance, position: Vector3, facing: Vector3, color: Color3)
	local cf = CFrame.lookAt(position, position + facing)
	local seat = Instance.new("Seat")
	seat.Name = "Armchair"
	seat.Anchored = true
	seat.Size = V(3.4, 1.2, 3.4)
	seat.CFrame = cf
	seat.Material = M.Fabric
	seat.Color = color
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Parent = m
	newPart(m, { Name = "ChairBack", Size = V(3.4, 3.4, 0.8), CFrame = cf * CFrame.new(0, 1.7, 1.5), Material = M.Fabric, Color = color })
	for _, side in { -1, 1 } do
		newPart(m, { Name = "ChairArm", Size = V(0.7, 1.4, 3.4), CFrame = cf * CFrame.new(side * 1.75, 0.95, 0), Material = M.Fabric, Color = color })
		newPart(m, { Name = "ChairLeg", Size = V(0.4, 0.9, 0.4), CFrame = cf * CFrame.new(side * 1.4, -1.05, 1.3), Material = M.Wood, Color = C.DarkWood })
		newPart(m, { Name = "ChairLeg", Size = V(0.4, 0.9, 0.4), CFrame = cf * CFrame.new(side * 1.4, -1.05, -1.3), Material = M.Wood, Color = C.DarkWood })
	end
	deco(newPart(m, { Name = "Cushion", Size = V(1.6, 1.2, 0.5), CFrame = cf * CFrame.new(0.6, 1.3, 1.0) * CFrame.Angles(0.2, 0, 0.2), Material = M.Fabric, Color = COZY.Cream }))
end

local function fairyLights(m: Instance, from: Vector3, to: Vector3, count: number)
	local colors = { C.Gold, Color3.fromRGB(255, 150, 190), Color3.fromRGB(140, 220, 255), Color3.fromRGB(160, 255, 170) }
	for i = 0, count - 1 do
		local t = i / math.max(count - 1, 1)
		local sag = math.sin(t * math.pi * (count / 4)) * 0.25
		local bulb = deco(newPart(m, { Name = "FairyLight", Shape = Enum.PartType.Ball, Size = V(0.45, 0.45, 0.45), CFrame = CFrame.new(from:Lerp(to, t) - V(0, math.abs(sag), 0)), Material = M.Neon, Color = colors[i % #colors + 1] }))
		if i % 4 == 0 then
			local light = Instance.new("PointLight")
			light.Range = 6
			light.Brightness = 0.6
			light.Color = bulb.Color
			light.Parent = bulb
		end
	end
end

local function buildCozyLodge(L: Instance, top: number)
	local lodge = Instance.new("Model")
	lodge.Name = "CocoaLodge"
	lodge.Parent = L
	local lx, lz = -45, -10
	local floorY = top + 1 -- walking surface inside
	local wallTop = top + 12

	-- Shell: floor, walls with a door gap on the north side, gable ends, roof.
	newPart(lodge, { Name = "LodgeFloor", Size = V(30, 1, 22), CFrame = CFrame.new(lx, top + 0.5, lz), Material = M.WoodPlanks, Color = C.Wood })
	local function wall(size: Vector3, pos: Vector3)
		newPart(lodge, { Name = "LodgeWall", Size = size, CFrame = CFrame.new(pos), Material = M.WoodPlanks, Color = COZY.WallOut })
	end
	wall(V(12, 12, 1), V(lx - 9, top + 6, lz + 11))
	wall(V(12, 12, 1), V(lx + 9, top + 6, lz + 11))
	wall(V(6, 4, 1), V(lx, top + 10, lz + 11))
	wall(V(30, 12, 1), V(lx, top + 6, lz - 11))
	wall(V(1, 12, 22), V(lx - 15, top + 6, lz))
	wall(V(1, 12, 22), V(lx + 15, top + 6, lz))
	-- warm inner paneling so the inside glows honey-brown
	for _, spec in {
		{ V(28, 11, 0.2), V(lx, top + 6.5, lz - 10.4) },
		{ V(0.2, 11, 21), V(lx - 14.4, top + 6.5, lz) },
		{ V(0.2, 11, 21), V(lx + 14.4, top + 6.5, lz) },
	} do
		deco(newPart(lodge, { Name = "Paneling", Size = spec[1], CFrame = CFrame.new(spec[2]), Material = M.WoodPlanks, Color = COZY.Wall }))
	end
	-- gable ends (the triangles under the roof)
	local gableH, gableW = 7.74, 11.06
	for _, x in { lx - 15, lx + 15 } do
		local south = Instance.new("WedgePart")
		south.Name = "Gable"
		south.Anchored = true
		south.Size = V(1, gableH, gableW)
		south.CFrame = CFrame.new(x, wallTop + gableH / 2, lz - gableW / 2)
		south.Material = M.WoodPlanks
		south.Color = COZY.WallOut
		south.Parent = lodge
		local north = south:Clone()
		north.CFrame = CFrame.new(x, wallTop + gableH / 2, lz + gableW / 2) * CFrame.Angles(0, math.pi, 0)
		north.Parent = lodge
	end
	for _, side in { -1, 1 } do
		local roofCF = CFrame.new(lx, wallTop + 3.87, lz + side * 5.53) * CFrame.Angles(side * math.rad(35), 0, 0)
		newPart(lodge, { Name = "LodgeRoof", Size = V(33, 1.2, 13.5), CFrame = roofCF, Material = M.Snow })
		-- wooden ceiling under the snowy roof
		deco(newPart(lodge, { Name = "Ceiling", Size = V(29.8, 0.3, 13.3), CFrame = roofCF * CFrame.new(0, -0.75, 0), Material = M.WoodPlanks, Color = COZY.Wall }))
	end
	for _, z in { lz - 6, lz, lz + 6 } do
		-- cross beams
		deco(newPart(lodge, { Name = "Beam", Size = V(29.8, 0.8, 0.8), CFrame = CFrame.new(lx, wallTop - 0.4, z), Material = M.Wood, Color = C.DarkWood }))
	end
	-- warm windows with wooden crosses
	for _, side in { -1, 1 } do
		local wx = lx + side * 9
		deco(newPart(lodge, { Name = "LodgeWindow", Size = V(3.4, 3.4, 0.3), CFrame = CFrame.new(wx, top + 6.5, lz + 11.6), Material = M.Neon, Color = COZY.Warm, Transparency = 0.15 }))
		deco(newPart(lodge, { Name = "WindowFrame", Size = V(0.3, 3.6, 0.4), CFrame = CFrame.new(wx, top + 6.5, lz + 11.7), Material = M.Wood, Color = C.DarkWood }))
		deco(newPart(lodge, { Name = "WindowFrame", Size = V(3.6, 0.3, 0.4), CFrame = CFrame.new(wx, top + 6.5, lz + 11.7), Material = M.Wood, Color = C.DarkWood }))
		deco(newPart(lodge, { Name = "WindowSnow", Size = V(3.8, 0.35, 0.8), CFrame = CFrame.new(wx, top + 4.6, lz + 11.8) }))
	end

	-- Outside: sign, wreath, doormat, porch lantern, fairy lights along the eaves.
	-- turned to face outward (+Z) so the text sits on its Front face
	local sign = newPart(lodge, { Name = "LodgeSign", Size = V(10, 1.8, 0.3), CFrame = CFrame.new(lx, top + 13.2, lz + 11.7) * CFrame.Angles(0, math.pi, 0), Material = M.Wood, Color = C.Wood })
	surfaceText(sign, Enum.NormalId.Front, "COCOA LODGE", C.Gold)
	deco(newPart(lodge, { Name = "Wreath", Shape = Enum.PartType.Cylinder, Size = V(0.3, 2.2, 2.2), CFrame = CFrame.new(lx, top + 10, lz + 11.7) * CFrame.Angles(0, math.pi / 2, 0), Material = M.Grass, Color = C.Pine }))
	deco(newPart(lodge, { Name = "WreathBow", Size = V(0.8, 0.5, 0.3), CFrame = CFrame.new(lx, top + 9, lz + 11.9), Material = M.Fabric, Color = COZY.Rug }))
	deco(newPart(lodge, { Name = "Doormat", Size = V(5, 0.1, 2.4), CFrame = CFrame.new(lx, top + 0.05, lz + 13), Material = M.Fabric, Color = COZY.Rug }))
	local porch = deco(newPart(lodge, { Name = "PorchLantern", Size = V(0.8, 1.2, 0.8), CFrame = CFrame.new(lx + 3.8, top + 7, lz + 11.9), Material = M.Neon, Color = COZY.Warm }))
	local porchLight = Instance.new("PointLight")
	porchLight.Range = 14
	porchLight.Brightness = 1.4
	porchLight.Color = COZY.Warm
	porchLight.Parent = porch
	fairyLights(lodge, V(lx - 16, wallTop - 0.3, lz + 12.2), V(lx + 16, wallTop - 0.3, lz + 12.2), 22)
	fairyLights(lodge, V(lx - 16, wallTop - 0.3, lz - 12.2), V(lx + 16, wallTop - 0.3, lz - 12.2), 22)

	-- Fireplace on the west wall, with a chimney that smokes.
	local fx = lx - 13
	newPart(lodge, { Name = "Fireplace", Size = V(3, 9, 9), CFrame = CFrame.new(fx, top + 5.5, lz), Material = M.Cobblestone, Color = COZY.Stone })
	deco(newPart(lodge, { Name = "Firebox", Size = V(0.4, 3.6, 4.6), CFrame = CFrame.new(fx + 1.4, floorY + 1.8, lz), Material = M.SmoothPlastic, Color = Color3.fromRGB(28, 20, 18) }))
	newPart(lodge, { Name = "Mantel", Size = V(3.8, 0.6, 10), CFrame = CFrame.new(fx + 0.4, top + 8.2, lz), Material = M.Wood, Color = C.DarkWood })
	for i, z in { -3, 0, 3 } do
		deco(newPart(lodge, { Name = "Stocking", Size = V(0.3, 1.4, 0.8), CFrame = CFrame.new(fx + 2.1, top + 7.1, lz + z), Material = M.Fabric, Color = if i == 2 then C.Pine else COZY.Rug }))
		deco(newPart(lodge, { Name = "StockingCuff", Size = V(0.32, 0.35, 0.85), CFrame = CFrame.new(fx + 2.12, top + 7.75, lz + z), Material = M.Fabric, Color = COZY.Cream }))
	end
	for _, z in { -0.6, 0.6 } do
		deco(newPart(lodge, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = V(3, 0.6, 0.6), CFrame = CFrame.new(fx + 2, floorY + 0.35, lz + z) * CFrame.Angles(0, math.pi / 2, 0), Material = M.Wood, Color = C.DarkWood }))
	end
	local flame = deco(newPart(lodge, { Name = "Flame", Size = V(0.6, 1.4, 2.2), CFrame = CFrame.new(fx + 2, floorY + 1.2, lz), Material = M.Neon, Color = COZY.Fire, Transparency = 0.25 }))
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 5
	fire.Color = COZY.Fire
	fire.SecondaryColor = C.Gold
	fire.Parent = flame
	local fireLight = Instance.new("PointLight")
	fireLight.Range = 26
	fireLight.Brightness = 2.2
	fireLight.Color = COZY.Fire
	fireLight.Shadows = true
	fireLight.Parent = flame
	-- chimney rises straight up from the fireplace through the roof
	local chimneyBottom, chimneyTop = top + 10, wallTop + 11
	local chimney = newPart(lodge, { Name = "Chimney", Size = V(2.6, chimneyTop - chimneyBottom, 3), CFrame = CFrame.new(fx - 0.2, (chimneyBottom + chimneyTop) / 2, lz), Material = M.Cobblestone, Color = COZY.Stone })
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 4
	smoke.Lifetime = NumberRange.new(4, 6)
	smoke.Speed = NumberRange.new(2, 4)
	smoke.Size = NumberSequence.new(2, 6)
	smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = chimney

	-- Rug, two armchairs facing the fire, coffee table with cocoa and cookies.
	deco(newPart(lodge, { Name = "Rug", Shape = Enum.PartType.Cylinder, Size = V(0.12, 11, 11), CFrame = CFrame.new(lx - 5, floorY + 0.06, lz) * UPRIGHT, Material = M.Fabric, Color = COZY.Rug }))
	deco(newPart(lodge, { Name = "RugInner", Shape = Enum.PartType.Cylinder, Size = V(0.13, 7, 7), CFrame = CFrame.new(lx - 5, floorY + 0.07, lz) * UPRIGHT, Material = M.Fabric, Color = COZY.RugInner }))
	armchair(lodge, V(lx - 5, floorY + 1.5, lz - 4.5), V(-1, 0, 0.35), COZY.ChairA)
	armchair(lodge, V(lx - 5, floorY + 1.5, lz + 4.5), V(-1, 0, -0.35), COZY.ChairB)
	deco(newPart(lodge, { Name = "Blanket", Size = V(2.6, 0.2, 3.2), CFrame = CFrame.new(lx - 4.2, floorY + 2.25, lz + 4.5) * CFrame.Angles(0, 0, 0.25), Material = M.Fabric, Color = Color3.fromRGB(110, 150, 210) }))
	local tableTop = floorY + 1.7
	newPart(lodge, { Name = "CoffeeTable", Size = V(3, 0.4, 5), CFrame = CFrame.new(lx - 9, tableTop - 0.2, lz), Material = M.Wood, Color = C.Wood })
	for _, o in { { -1.2, -2.1 }, { 1.2, -2.1 }, { -1.2, 2.1 }, { 1.2, 2.1 } } do
		newPart(lodge, { Name = "TableLeg", Size = V(0.35, 1.5, 0.35), CFrame = CFrame.new(lx - 9 + o[1], floorY + 0.75, lz + o[2]), Material = M.Wood, Color = C.DarkWood })
	end
	mug(lodge, V(lx - 9.4, tableTop, lz - 1.4), COZY.ChairA, true)
	mug(lodge, V(lx - 8.6, tableTop, lz + 1.5), Color3.fromRGB(120, 180, 230), false)
	deco(newPart(lodge, { Name = "Plate", Shape = Enum.PartType.Cylinder, Size = V(0.1, 1.6, 1.6), CFrame = CFrame.new(lx - 9, tableTop + 0.05, lz) * UPRIGHT, Material = M.SmoothPlastic, Color = COZY.Cream }))
	for i = 0, 3 do
		local a = i * math.pi / 2
		deco(newPart(lodge, { Name = "Cookie", Shape = Enum.PartType.Cylinder, Size = V(0.12, 0.55, 0.55), CFrame = CFrame.new(lx - 9 + math.cos(a) * 0.4, tableTop + 0.14 + i * 0.02, lz + math.sin(a) * 0.4) * UPRIGHT, Material = M.Sand, Color = Color3.fromRGB(196, 140, 80) }))
	end

	-- Cocoa bar on the east wall: grab a mug with the prompt on the pot.
	local bx = lx + 12.5
	newPart(lodge, { Name = "CocoaCounter", Size = V(3, 3.6, 12), CFrame = CFrame.new(bx, floorY + 1.8, lz), Material = M.WoodPlanks, Color = C.Wood })
	local counterTop = floorY + 3.6
	newPart(lodge, { Name = "Countertop", Size = V(3.6, 0.4, 12.6), CFrame = CFrame.new(bx - 0.2, counterTop + 0.2, lz), Material = M.Wood, Color = Color3.fromRGB(196, 140, 96) })
	local potY = counterTop + 0.4
	local pot = newPart(lodge, { Name = "CocoaPot", Shape = Enum.PartType.Cylinder, Size = V(2, 2.6, 2.6), CFrame = CFrame.new(bx, potY + 1, lz - 3) * UPRIGHT, Material = M.Metal, Color = Color3.fromRGB(180, 60, 60) })
	local potTop = deco(newPart(lodge, { Name = "CocoaSurface", Shape = Enum.PartType.Cylinder, Size = V(0.1, 2.3, 2.3), CFrame = CFrame.new(bx, potY + 1.95, lz - 3) * UPRIGHT, Material = M.SmoothPlastic, Color = COZY.Cocoa }))
	steam(potTop, 8, 2)
	deco(newPart(lodge, { Name = "Ladle", Size = V(0.2, 2.6, 0.2), CFrame = CFrame.new(bx + 0.4, potY + 2.6, lz - 3) * CFrame.Angles(0, 0, -0.4), Material = M.Metal, Color = Color3.fromRGB(200, 200, 210) }))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CocoaPrompt"
	prompt.ActionText = "Grab a hot cocoa"
	prompt.ObjectText = "Cocoa Bar"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pot
	for i, z in { 0, 1.4, 2.8, 4.2 } do
		mug(lodge, V(bx - 0.5, counterTop + 0.4, lz + z), if i % 2 == 0 then COZY.ChairB else COZY.ChairA, i % 2 == 1)
	end
	deco(newPart(lodge, { Name = "MarshmallowJar", Shape = Enum.PartType.Cylinder, Size = V(1.6, 1.1, 1.1), CFrame = CFrame.new(bx + 0.6, counterTop + 1.2, lz - 5.4) * UPRIGHT, Material = M.Glass, Color = COZY.Cream, Transparency = 0.45 }))
	-- faces into the room (-X) with the text on its Front face
	local barSign = newPart(lodge, { Name = "CocoaSign", Size = V(8, 2.4, 0.3), CFrame = CFrame.lookAt(V(lx + 14.1, top + 9, lz), V(lx, top + 9, lz)), Material = M.Wood, Color = C.DarkWood })
	surfaceText(barSign, Enum.NormalId.Front, "HOT COCOA", C.Gold)

	-- Bookshelf, hanging lamp, fairy lights inside.
	newPart(lodge, { Name = "Bookshelf", Size = V(7, 7, 1.4), CFrame = CFrame.new(lx + 1, floorY + 3.5, lz - 9.7), Material = M.Wood, Color = C.DarkWood })
	local bookColors = { COZY.Rug, C.Blue, C.Gold, C.Pine, COZY.ChairB, Color3.fromRGB(150, 110, 200) }
	for row = 0, 2 do
		for i = 0, 9 do
			local h = rng:NextNumber(1.2, 1.7)
			deco(newPart(lodge, { Name = "Book", Size = V(0.5, h, 1), CFrame = CFrame.new(lx - 1.6 + i * 0.58, floorY + 1 + row * 2.2 + h / 2, lz - 9.2), Material = M.SmoothPlastic, Color = bookColors[(i + row) % #bookColors + 1] }))
		end
	end
	deco(newPart(lodge, { Name = "LampChain", Size = V(0.15, 2.5, 0.15), CFrame = CFrame.new(lx - 2, wallTop + 0.5, lz), Material = M.Metal, Color = C.DarkWood }))
	local lamp = deco(newPart(lodge, { Name = "HangingLamp", Shape = Enum.PartType.Ball, Size = V(1.6, 1.6, 1.6), CFrame = CFrame.new(lx - 2, wallTop - 1.3, lz), Material = M.Neon, Color = COZY.Warm }))
	local lampLight = Instance.new("PointLight")
	lampLight.Range = 20
	lampLight.Brightness = 1.3
	lampLight.Color = COZY.Warm
	lampLight.Shadows = true
	lampLight.Parent = lamp
	fairyLights(lodge, V(lx - 13.8, wallTop - 0.8, lz - 9.9), V(lx + 13.8, wallTop - 0.8, lz - 9.9), 18)
	fairyLights(lodge, V(lx - 13.8, wallTop - 0.8, lz + 9.9), V(lx + 13.8, wallTop - 0.8, lz + 9.9), 18)
end

-- Lobby -------------------------------------------------------------------------------

local function buildLobby(): Model
	local L = Instance.new("Model")
	L.Name = "Lobby"
	local top = 300

	newPart(L, { Name = "Plateau", Size = V(180, 10, 180), CFrame = CFrame.new(0, top - 5, 0) })
	newPart(L, { Name = "Peak", Size = V(200, 70, 200), CFrame = CFrame.new(0, top - 45, 0) * CFrame.Angles(0, math.rad(45), 0), Material = M.Slate, Color = C.Rock })
	newPart(L, { Name = "PeakSnow", Size = V(300, 90, 300), CFrame = CFrame.new(0, top - 120, 0) * CFrame.Angles(0, math.rad(20), 0), Color = C.SnowShade })
	for _, e in { { 0, 90, 180, 1 }, { 0, -90, 180, 1 }, { 90, 0, 1, 180 }, { -90, 0, 1, 180 } } do
		newPart(L, { Name = "EdgeBarrier", Size = V(e[3], 30, e[4]), CFrame = CFrame.new(e[1], top + 15, e[2]), Transparency = 1 })
	end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		newPart(L, { Name = "SnowBank", Shape = Enum.PartType.Ball, Size = V(16, 16, 16), CFrame = CFrame.new(math.cos(a) * 86, top - 4, math.sin(a) * 86), Color = C.SnowShade })
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = V(12, 1, 12)
	spawn.CFrame = CFrame.new(0, top + 0.5, -30)
	spawn.Material = M.Snow
	spawn.Color = C.Blue
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = L

	-- Start ring
	local ring = deco(newPart(L, { Name = "StartRing", Shape = Enum.PartType.Cylinder, Size = V(0.6, 20, 20), CFrame = CFrame.new(0, top + 0.3, 20) * UPRIGHT, Material = M.Neon, Color = C.Gold }))
	ring:SetAttribute("Radius", 10)
	deco(newPart(L, { Name = "RingInner", Shape = Enum.PartType.Cylinder, Size = V(0.7, 17, 17), CFrame = CFrame.new(0, top + 0.35, 20) * UPRIGHT, Material = M.SmoothPlastic, Color = C.Night }))
	local ringLight = Instance.new("PointLight")
	ringLight.Range = 18
	ringLight.Brightness = 2
	ringLight.Color = C.Gold
	ringLight.Parent = ring
	local status = Instance.new("BillboardGui")
	status.Name = "Status"
	status.Size = UDim2.new(16, 0, 3, 0)
	status.StudsOffsetWorldSpace = V(0, 7, 0)
	status.LightInfluence = 0
	status.MaxDistance = 150
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Label"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.fromScale(1, 1)
	statusLabel.Font = Enum.Font.FredokaOne
	statusLabel.Text = "Step on the ring to start a run"
	statusLabel.TextScaled = true
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextStrokeColor3 = C.Night
	statusLabel.TextStrokeTransparency = 0.2
	statusLabel.Parent = status
	status.Parent = ring
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local pos = V(math.cos(a) * 13, top, 20 + math.sin(a) * 13)
		newPart(L, { Name = "LanternPost", Size = V(0.6, 5, 0.6), CFrame = CFrame.new(pos + V(0, 2.5, 0)), Material = M.Wood, Color = C.DarkWood })
		local bulb = deco(newPart(L, { Name = "LanternBulb", Size = V(1, 1, 1), CFrame = CFrame.new(pos + V(0, 5.4, 0)), Material = M.Neon, Color = C.Gold }))
		local light = Instance.new("PointLight")
		light.Range = 8
		light.Color = C.Gold
		light.Parent = bulb
	end

	-- Daily board (front face looks back toward the spawn)
	for _, side in { -1, 1 } do
		newPart(L, { Name = "BoardPost", Size = V(1, 14, 1), CFrame = CFrame.new(side * 9.5, top + 7, 48), Material = M.Wood, Color = C.DarkWood })
	end
	local board = newPart(L, { Name = "DailyBoard", Size = V(18, 11, 0.6), CFrame = CFrame.new(0, top + 8, 48), Material = M.Wood, Color = C.DarkWood })
	deco(newPart(L, { Name = "BoardSnow", Size = V(19, 0.8, 1.4), CFrame = CFrame.new(0, top + 13.9, 48) }))
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Front
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 40
	boardGui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.04)
	title.Size = UDim2.fromScale(0.9, 0.2)
	title.Font = Enum.Font.FredokaOne
	title.Text = "TODAY'S MOUNTAIN"
	title.TextScaled = true
	title.TextColor3 = C.Gold
	title.Parent = boardGui
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.08, 0.28)
	list.Size = UDim2.fromScale(0.84, 0.66)
	list.Font = Enum.Font.FredokaOne
	list.Text = "..."
	list.TextScaled = true
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.Parent = boardGui
	boardGui.Parent = board

	-- Cozy Cocoa Lodge (see buildCozyLodge)
	buildCozyLodge(L, top)

	for _, t in { { 40, -40 }, { 55, -10 }, { 62, 30 }, { 40, 62 }, { -30, 60 }, { -62, 34 }, { -66, -48 }, { -20, -62 }, { 20, -66 }, { 70, 64 } } do
		pine(L, V(t[1], top, t[2]), rng:NextNumber(16, 22))
	end
	for _, r in { { 30, 10 }, { -20, 30 }, { 60, -55 } } do
		rock(L, V(r[1], top + 1, r[2]), V(6, 4, 5), true)
	end
	return L
end

-- Avalanche wall template ------------------------------------------------------------------

local function buildAvalanche(): Model
	local wall = Instance.new("Model")
	wall.Name = "AvalancheWall"
	local hitbox = newPart(wall, { Name = "Hitbox", Size = V(84, 64, 14), CFrame = CFrame.new(), Transparency = 1, CanCollide = false, CanQuery = true, CanTouch = false })
	wall.PrimaryPart = hitbox
	for ix = 0, 7 do
		for iy = 0, 4 do
			local s = rng:NextNumber(12, 17)
			local shade = C.Snow:Lerp(C.SnowShade, rng:NextNumber())
			deco(newPart(wall, {
				Name = "Chunk",
				Size = V(s, s * rng:NextNumber(0.8, 1.1), s),
				CFrame = CFrame.new(-36.75 + ix * 10.5 + rng:NextNumber(-2, 2), -26 + iy * 12.5 + rng:NextNumber(-2, 2), rng:NextNumber(-4, 4) - (if iy == 0 then 2 else 0))
					* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
				Material = M.SmoothPlastic,
				Color = shade,
			}))
		end
	end
	local spray = deco(newPart(wall, { Name = "Spray", Size = V(84, 50, 1), CFrame = CFrame.new(0, -6, -8), Transparency = 1 }))
	local puffs = Instance.new("ParticleEmitter")
	puffs.Name = "Puffs"
	puffs.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puffs.EmissionDirection = Enum.NormalId.Front
	puffs.Rate = 70
	puffs.Lifetime = NumberRange.new(1.2, 2.2)
	puffs.Speed = NumberRange.new(6, 16)
	puffs.SpreadAngle = Vector2.new(25, 25)
	puffs.Acceleration = V(0, -4, 0)
	puffs.Drag = 1.5
	puffs.RotSpeed = NumberRange.new(-40, 40)
	puffs.Size = NumberSequence.new(6, 16)
	puffs.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.5), NumberSequenceKeypoint.new(1, 1) })
	puffs.Color = ColorSequence.new(Color3.fromRGB(245, 250, 255))
	puffs.LightInfluence = 0.8
	puffs.Parent = spray
	local powder = puffs:Clone()
	powder.Name = "Powder"
	powder.Rate = 40
	powder.Size = NumberSequence.new(3, 8)
	powder.Speed = NumberRange.new(14, 24)
	powder.Parent = spray
	return wall
end

-- Lighting, audio, player defaults ------------------------------------------------------------

local function setupLighting()
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
	Lighting.ClockTime = 7
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(35, 45, 65)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 125, 150)
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromHex("DDEBF7")
	atmosphere.Decay = Color3.fromHex("6FA8DC")
	atmosphere.Glare = 0.6
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.05
	cc.Contrast = 0.08
	cc.TintColor = Color3.fromRGB(255, 248, 235)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 30
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.12
	rays.Spread = 0.6
	rays.Parent = Lighting
end

-- Audio ids are free Creator Store audio: music courtesy of APM Music (Roblox-licensed),
-- effects from Pro Sound Effects and Daily Sounds. "rbxassetid://0" = still TODO.
local function setupAudio()
	local spec = {
		Music = {
			{ "LobbyMusic", true, 0.35, "rbxassetid://1839878694" }, -- "Happy Feet (b)", APM
			{ "RaceMusic", true, 0.4, "rbxassetid://9045803411" }, -- "High Five Happy (c)", APM
		},
		Ambience = {
			{ "Wind", true, 0.5, "rbxassetid://0" }, -- TODO: a licensed soft wind loop
			{ "Rumble", true, 0.7, "rbxassetid://9112775181" }, -- Earthquake Rumble 2, Pro Sound Effects
		},
		SFX = {
			{ "Toss", false, 0.6, "rbxassetid://9126047581" }, -- Synth Air Whoosh, Pro Sound Effects
			{ "Catch", false, 0.8, "rbxassetid://106984966606682" }, -- Cartoon Pop, Daily Sounds
			{ "Checkpoint", false, 0.6, "rbxassetid://130378474223829" }, -- Coin Pickup, Daily Sounds
			{ "Beep", false, 0.5, "rbxassetid://138309872562566" }, -- Retro Coin Collect, Daily Sounds
			{ "Heartbeat", true, 0.6, "rbxassetid://132163421525060" }, -- Fast Heartbeat, Daily Sounds
			{ "Bell", false, 0.7, "rbxassetid://132377870366381" }, -- Clear Bell Ding, Daily Sounds
			{ "Caught", false, 0.6, "rbxassetid://96795857757261" }, -- Power Down, Daily Sounds
		},
		UI = {
			{ "Click", false, 0.5, "rbxassetid://106984966606682" }, -- Cartoon Pop, Daily Sounds
		},
	}
	for groupName, sounds in spec do
		local old = SoundService:FindFirstChild(groupName)
		if old then
			old:Destroy()
		end
		local group = Instance.new("SoundGroup")
		group.Name = groupName
		group.Volume = 1
		for _, s in sounds do
			local sound = Instance.new("Sound")
			sound.Name = s[1]
			sound.Looped = s[2]
			sound.Volume = s[3]
			if s[4] == "rbxassetid://0" then
				-- Left empty: an id of 0 makes Roblox log a load error. AudioController skips empty sounds.
				sound.SoundId = ""
				sound:SetAttribute("TODO", "Set SoundId to a Roblox-licensed audio id")
			else
				sound.SoundId = s[4]
			end
			sound.SoundGroup = group
			sound.Parent = group
		end
		group.Parent = SoundService
	end
end

local function setupPlayers()
	StarterPlayer.CharacterUseJumpPower = true
	StarterPlayer.CharacterJumpPower = 50
	StarterPlayer.CharacterWalkSpeed = 20
	pcall(function()
		Players.RespawnTime = 2
	end)
	pcall(function()
		Workspace.StreamingEnabled = false -- courses are small and the client reads the lantern via tags
	end)
end

-- Run -------------------------------------------------------------------------------------

local function replace(parent: Instance, name: string)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- Remove the Baseplate template's floor and spawn so falls and spawns use the summit.
for _, name in { "Baseplate", "SpawnLocation" } do
	local inst = Workspace:FindFirstChild(name)
	if inst and inst:IsA("BasePart") then
		inst:Destroy()
	end
end

setupLighting()
setupAudio()
setupPlayers()
task.wait()

replace(Workspace, "Lobby")
buildLobby().Parent = Workspace
task.wait()

replace(ServerStorage, "Segments")
local segments = Instance.new("Folder")
segments.Name = "Segments"
segments.Parent = ServerStorage
local built = {}
for _, name in { "Switchbacks", "IceBridgeGap", "PineSlalom", "FrozenWaterfallSteps", "CollapsedCabin", "CrevassePlanks", "SnowTunnel", "IcicleRidge", "VillageGate" } do
	local model = builders[name]()
	model.Parent = segments
	table.insert(built, name)
	task.wait()
end

replace(ServerStorage, "AvalancheWall")
buildAvalanche().Parent = ServerStorage

return "Built lobby, " .. #built .. " segments, avalanche wall, lighting, audio"

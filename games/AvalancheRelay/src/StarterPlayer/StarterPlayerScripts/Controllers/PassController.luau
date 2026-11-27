--!strict
-- PassController: E key / gamepad X / the HUD TOSS button. Picks the nearest valid squadmate
-- and asks the server to pass; the server re-checks everything. Also draws the local
-- BillboardGuis: a bobbing arrow over the squad's lantern and green rings over squadmates
-- in toss range.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript) :: any
local ClientState = require(script.Parent.ClientState)

local LocalPlayer = Players.LocalPlayer
local RING_COLOR = Color3.fromRGB(124, 245, 140)
local ARROW_COLOR = Color3.fromRGB(255, 209, 102)

local PassController = {}

local rings: { [Player]: BillboardGui } = {}
local arrow: BillboardGui? = nil
local cachedLantern: BasePart? = nil
local lastLanternLookup = 0
local lastRequest = 0

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function squadmates(): { Player }
	local list = {}
	local info = ClientState.info
	if not info or not info.memberIds then
		return list
	end
	for _, id in info.memberIds do
		if id ~= LocalPlayer.UserId then
			local player = Players:GetPlayerByUserId(id)
			if player then
				table.insert(list, player)
			end
		end
	end
	return list
end

local function getLantern(): BasePart?
	local now = os.clock()
	if cachedLantern and cachedLantern.Parent and now - lastLanternLookup < 1 then
		return cachedLantern
	end
	lastLanternLookup = now
	cachedLantern = nil
	local info = ClientState.info
	if not info then
		return nil
	end
	for _, inst in CollectionService:GetTagged("SummitLantern") do
		if inst:IsA("BasePart") and inst:GetAttribute("SquadId") == info.squadId then
			cachedLantern = inst
			break
		end
	end
	return cachedLantern
end

local function canReach(myRoot: BasePart, target: Player): (boolean, number)
	local root = getRoot(target)
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, math.huge
	end
	local distance = (root.Position - myRoot.Position).Magnitude
	if distance > Config.TOSS_RANGE then
		return false, distance
	end
	local ignore: { Instance } = {}
	if LocalPlayer.Character then
		table.insert(ignore, LocalPlayer.Character)
	end
	for _, mate in squadmates() do
		if mate.Character then
			table.insert(ignore, mate.Character)
		end
	end
	local lantern = getLantern()
	if lantern then
		table.insert(ignore, lantern)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local origin = myRoot.Position + Vector3.new(0, 1.5, 0)
	local goal = root.Position + Vector3.new(0, 1.5, 0)
	return Workspace:Raycast(origin, goal - origin, params) == nil, distance
end

function PassController.findTarget(): Player?
	if not ClientState.isCarrier() or ClientState.state ~= "Running" then
		return nil
	end
	local myRoot = getRoot(LocalPlayer)
	if not myRoot then
		return nil
	end
	local best: Player? = nil
	local bestDist = math.huge
	for _, mate in squadmates() do
		local ok, distance = canReach(myRoot, mate)
		if ok and distance < bestDist then
			best, bestDist = mate, distance
		end
	end
	return best
end

function PassController.cooldownRemaining(): number
	local info = ClientState.info
	if not info then
		return 0
	end
	return math.max(0, (info.cooldown or 0) - (os.clock() - ClientState.receivedAt))
end

function PassController.canToss(): boolean
	local info = ClientState.info
	return ClientState.isCarrier()
		and ClientState.state == "Running"
		and info ~= nil
		and not info.tossing
		and #squadmates() > 0
end

function PassController.tryToss()
	if not ClientState.isCarrier() or ClientState.state ~= "Running" then
		return
	end
	if #squadmates() == 0 then
		ClientState.localNotify("warning", "Solo run: just keep carrying!")
		return
	end
	if PassController.cooldownRemaining() > 0 or os.clock() - lastRequest < 0.3 then
		return
	end
	local target = PassController.findTarget()
	if target then
		lastRequest = os.clock()
		Remotes.RequestPass():FireServer(target.UserId)
	else
		ClientState.localNotify("warning", "No squadmate in range")
	end
end

-- Local billboards -----------------------------------------------------------------

local function makeRing(target: Player): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "TossRing_" .. target.UserId
	gui.Size = UDim2.fromOffset(46, 46)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local circle = Instance.new("Frame")
	circle.Name = "Ring"
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundTransparency = 1
	circle.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle
	local stroke = Instance.new("UIStroke")
	stroke.Color = RING_COLOR
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = circle
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function clearRings()
	for player, gui in rings do
		gui:Destroy()
		rings[player] = nil
	end
end

local function updateBillboards()
	if not ClientState.inRace then
		clearRings()
		if arrow then
			arrow.Enabled = false
		end
		return
	end

	-- Bobbing arrow over our lantern.
	local lantern = getLantern()
	if lantern then
		if not arrow then
			local gui = Instance.new("BillboardGui")
			gui.Name = "LanternArrow"
			gui.Size = UDim2.fromOffset(40, 40)
			gui.AlwaysOnTop = true
			gui.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.FredokaOne
			label.Text = "▼"
			label.TextScaled = true
			label.TextColor3 = ARROW_COLOR
			label.TextStrokeColor3 = Color3.fromRGB(16, 24, 38)
			label.TextStrokeTransparency = 0.3
			label.Parent = gui
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
			arrow = gui
		end
		local activeArrow = arrow :: BillboardGui
		activeArrow.Adornee = lantern
		activeArrow.Enabled = true
		activeArrow.StudsOffset = Vector3.new(0, 2.8 + math.sin(os.clock() * 4) * 0.35, 0)
	elseif arrow then
		arrow.Enabled = false
	end

	-- Green rings over squadmates we could toss to right now.
	local myRoot = getRoot(LocalPlayer)
	local showRings = ClientState.isCarrier() and ClientState.state == "Running" and myRoot ~= nil
	local best = if showRings then PassController.findTarget() else nil
	local seen: { [Player]: boolean } = {}
	if showRings and myRoot then
		for _, mate in squadmates() do
			local ok = canReach(myRoot, mate)
			local head = mate.Character and mate.Character:FindFirstChild("Head")
			if ok and head then
				seen[mate] = true
				local gui = rings[mate] or makeRing(mate)
				rings[mate] = gui
				gui.Adornee = head
				local ring = gui:FindFirstChild("Ring")
				local stroke = ring and ring:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Thickness = if mate == best then 6 else 3
				end
			end
		end
	end
	for player, gui in rings do
		if not seen[player] then
			gui:Destroy()
			rings[player] = nil
		end
	end
end

function PassController.init()
	ContextActionService:BindAction("AvalancheToss", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			PassController.tryToss()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if arrow and arrow.Enabled then
			arrow.StudsOffset = Vector3.new(0, 2.8 + math.sin(os.clock() * 4) * 0.35, 0)
		end
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		updateBillboards()
	end)
end

return PassController

--!strict
-- RewardService: free cosmetics unlocked by lifetime Frost Badges (see Shared/Rewards).
-- Announces new unlocks after a run, and builds the earned wearables (beanie, scarf,
-- earmuffs) from parts on the character. Never affects speed, jumps or tossing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local DataService = require(script.Parent.DataService)

local WEAR_FOLDER = "Wearables"

local RewardService = {}

local function badgesOf(player: Player): number
	local data = DataService.get(player)
	return if data then data.frostBadges else 0
end

function RewardService.isUnlocked(player: Player, rewardId: string): boolean
	local reward = Rewards.get(rewardId)
	return reward ~= nil and badgesOf(player) >= reward.badges
end

-- Whether the player has earned this flame (Gold is always free; kit flames are checked elsewhere).
function RewardService.flameEarned(player: Player, flame: string): boolean
	if flame == "Gold" then
		return true
	end
	local need = Rewards.flameRequirement(flame)
	return need ~= nil and badgesOf(player) >= need
end

-- Wearables ---------------------------------------------------------------------------

local function wearPart(folder: Instance, attach: BasePart, name: string, props: { [string]: any }, offset: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	if props.Shape then
		p.Shape = props.Shape
	end
	for k, v in props do
		if k ~= "Shape" then
			(p :: any)[k] = v
		end
	end
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = attach.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = attach
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local builders: { [string]: (Instance, Model) -> () } = {}

builders.Beanie = function(folder, character)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local w = math.max(head.Size.X, head.Size.Z) * 1.08
	local h = head.Size.Y
	wearPart(folder, head, "BeanieCap", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.55, w, w), Color = Color3.fromRGB(214, 70, 80), Material = Enum.Material.Fabric }, CFrame.new(0, h * 0.42, 0) * UPRIGHT)
	wearPart(folder, head, "BeanieBrim", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h * 0.2, w * 1.06, w * 1.06), Color = Color3.fromRGB(250, 244, 236), Material = Enum.Material.Fabric }, CFrame.new(0, h * 0.18, 0) * UPRIGHT)
	wearPart(folder, head, "BeaniePom", { Shape = Enum.PartType.Ball, Size = Vector3.new(w * 0.38, w * 0.38, w * 0.38), Color = Color3.fromRGB(250, 244, 236), Material = Enum.Material.Fabric }, CFrame.new(0, h * 0.78, 0))
end

builders.Scarf = function(folder, character)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local s = torso.Size
	wearPart(folder, torso, "ScarfWrap", { Size = Vector3.new(s.X * 0.72, 0.42, s.Z * 1.25), Color = Color3.fromRGB(90, 200, 190), Material = Enum.Material.Fabric }, CFrame.new(0, s.Y / 2 - 0.05, 0))
	wearPart(folder, torso, "ScarfStripe", { Size = Vector3.new(s.X * 0.74, 0.14, s.Z * 1.27), Color = Color3.fromRGB(250, 244, 236), Material = Enum.Material.Fabric }, CFrame.new(0, s.Y / 2 - 0.05, 0))
	wearPart(folder, torso, "ScarfTail", { Size = Vector3.new(0.38, s.Y * 0.55, 0.12), Color = Color3.fromRGB(90, 200, 190), Material = Enum.Material.Fabric }, CFrame.new(-s.X * 0.22, s.Y * 0.18, -s.Z / 2 - 0.12) * CFrame.Angles(0, 0, 0.12))
end

builders.Earmuffs = function(folder, character)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local s = head.Size
	for _, side in { -1, 1 } do
		wearPart(folder, head, "Muff", { Shape = Enum.PartType.Ball, Size = Vector3.new(s.Y * 0.5, s.Y * 0.5, s.Y * 0.5), Color = Color3.fromRGB(255, 170, 205), Material = Enum.Material.Fabric }, CFrame.new(side * (s.X / 2 + 0.08), 0, 0))
	end
	wearPart(folder, head, "MuffBand", { Size = Vector3.new(s.X * 1.15, 0.14, 0.22), Color = Color3.fromRGB(250, 244, 236) }, CFrame.new(0, s.Y * 0.55, 0))
end

function RewardService.applyWearables(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild(WEAR_FOLDER)
	if old then
		old:Destroy()
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = WEAR_FOLDER
	folder.Parent = character
	for _, reward in Rewards.LIST do
		if reward.kind == "wear" and data.equippedWear[reward.value] and badgesOf(player) >= reward.badges then
			local build = builders[reward.value]
			if build then
				build(folder, character)
			end
		end
	end
end

-- Called after a run with the badge count before and after it.
function RewardService.announceUnlocks(player: Player, before: number, after: number)
	local unlocked = Rewards.newlyUnlocked(before, after)
	for i, reward in unlocked do
		if reward.kind == "wear" then
			DataService.setWearable(player, reward.value, true) -- wear it straight away
		end
		task.delay((i - 1) * 2.6, function()
			if player.Parent then
				Remotes.Notify():FireClient(player, "unlock", "Unlocked: " .. reward.name .. "!", nil)
			end
		end)
	end
	if #unlocked > 0 then
		RewardService.applyWearables(player)
	end
end

-- For GetDailyInfo: every reward with its state.
function RewardService.describe(player: Player): { { [string]: any } }
	local data = DataService.get(player)
	local out = {}
	for _, reward in Rewards.LIST do
		local unlocked = badgesOf(player) >= reward.badges
		table.insert(out, {
			id = reward.id,
			name = reward.name,
			kind = reward.kind,
			value = reward.value,
			badges = reward.badges,
			unlocked = unlocked,
			equipped = if reward.kind == "wear"
				then data ~= nil and data.equippedWear[reward.value] == true
				else data ~= nil and data.equippedFlame == reward.value,
		})
	end
	return out
end

function RewardService.init()
	Remotes.SetWearable().OnServerEvent:Connect(function(player: Player, id: any, on: any)
		if type(id) ~= "string" or type(on) ~= "boolean" then
			return
		end
		local reward = Rewards.get(id)
		if not reward or reward.kind ~= "wear" or not RewardService.isUnlocked(player, id) then
			return
		end
		DataService.setWearable(player, reward.value, on)
		RewardService.applyWearables(player)
	end)

	local function onPlayer(player: Player)
		player.CharacterAppearanceLoaded:Connect(function()
			RewardService.applyWearables(player)
		end)
		DataService.waitForData(player, 15)
		if player.Character then
			RewardService.applyWearables(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return RewardService

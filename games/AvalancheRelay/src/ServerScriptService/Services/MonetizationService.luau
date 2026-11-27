--!strict
-- MonetizationService: Trailblazer Kit game pass (cosmetic only) and the ProcessReceipt stub.
-- Nothing here touches carrier speed, toss range or avalanche speed.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local Rewards = require(ReplicatedStorage.Shared.Rewards)

local KIT_KEY = "TrailblazerKit"

local MonetizationService = {}

MonetizationService.FLAME_ORDER = { "Gold", "Frost", "Aurora", "Rose", "Ember" }
MonetizationService.FLAME_COLORS = {
	Gold = Color3.fromRGB(255, 209, 102),
	Frost = Color3.fromRGB(143, 211, 255),
	Aurora = Color3.fromRGB(124, 245, 192),
	Rose = Color3.fromRGB(255, 143, 177),
	Ember = Color3.fromRGB(255, 140, 66),
} :: { [string]: Color3 }

local flameChanged = Instance.new("BindableEvent")
MonetizationService.FlameChanged = flameChanged.Event

local owners: { [Player]: boolean } = {}

local function addTrail(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") or root:FindFirstChild("TrailblazerTrail") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, 0.6, 0.4)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -2.4, 0.4)
	a1.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "TrailblazerTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.55
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255), Color3.fromRGB(111, 168, 220))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = root

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "TrailblazerSparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 14
	sparkle.Lifetime = NumberRange.new(0.5, 0.9)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.Size = NumberSequence.new(0.35, 0)
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	sparkle.Parent = a1
end

local function applyCosmetics(player: Player)
	if owners[player] and player.Character then
		task.spawn(addTrail, player, player.Character)
	end
end

local function checkOwnership(player: Player)
	DataService.waitForData(player, 15)
	if Config.GAMEPASS_ID == 0 then
		owners[player] = Config.STUDIO_GRANT_KIT and RunService:IsStudio()
	else
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.GAMEPASS_ID)
		end)
		if ok then
			owners[player] = owns
		else
			warn("[MonetizationService] Ownership check failed, using saved flag: " .. tostring(owns))
			local data = DataService.get(player)
			owners[player] = data ~= nil and data.cosmetics[KIT_KEY] == true
		end
	end
	if owners[player] then
		DataService.setCosmetic(player, KIT_KEY, true)
		-- The HUD may have loaded before this check finished; tell it to refresh.
		Remotes.Notify():FireClient(player, "kitReady", "", nil)
	end
	applyCosmetics(player)
	flameChanged:Fire(player)
end

function MonetizationService.ownsKit(player: Player): boolean
	return owners[player] == true
end

-- Trailblazer Kit owners can use every flame; anyone can use the ones they've earned
-- with Frost Badges. Ember stays kit-only.
function MonetizationService.canUseFlame(player: Player, flame: string): boolean
	if not MonetizationService.FLAME_COLORS[flame] then
		return false
	end
	if owners[player] then
		return true
	end
	return not Rewards.KIT_ONLY_FLAMES[flame] and RewardService.flameEarned(player, flame)
end

function MonetizationService.availableFlames(player: Player): { string }
	local out = {}
	for _, flame in MonetizationService.FLAME_ORDER do
		if MonetizationService.canUseFlame(player, flame) then
			table.insert(out, flame)
		end
	end
	return out
end

function MonetizationService.getEquippedFlame(player: Player): string
	local data = DataService.get(player)
	local flame = if data then data.equippedFlame else "Gold"
	return if MonetizationService.canUseFlame(player, flame) then flame else "Gold"
end

function MonetizationService.getFlameColor(player: Player?): Color3
	if not player then
		return MonetizationService.FLAME_COLORS.Gold
	end
	return MonetizationService.FLAME_COLORS[MonetizationService.getEquippedFlame(player)]
end

-- Developer products. The MVP sells none, so every receipt is unknown.
-- When you add a product:
--   1. Register a handler below by ProductId.
--   2. Idempotency: Roblox can call ProcessReceipt more than once for the same purchase.
--      Store receiptInfo.PurchaseId (in the player's data or a separate "Receipts" DataStore)
--      and skip granting if it is already stored.
--   3. Save first, then return PurchaseGranted. Return NotProcessedYet on any failure so Roblox retries.
local productHandlers: { [number]: (Player, any) -> boolean } = {}

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local handler = productHandlers[receiptInfo.ProductId]
	if not handler then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(handler, player, receiptInfo)
	if ok and granted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if purchased and passId == Config.GAMEPASS_ID and Config.GAMEPASS_ID ~= 0 then
			owners[player] = true
			DataService.setCosmetic(player, KIT_KEY, true)
			applyCosmetics(player)
			flameChanged:Fire(player)
			Remotes.Notify():FireClient(player, "kit", "Trailblazer Kit unlocked! Pick a flame color.", nil)
		end
	end)

	Remotes.SetFlameColor().OnServerEvent:Connect(function(player: Player, flame: any)
		if type(flame) ~= "string" or not MonetizationService.canUseFlame(player, flame) then
			return
		end
		DataService.setEquippedFlame(player, flame)
		flameChanged:Fire(player)
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			applyCosmetics(player)
		end)
		task.spawn(checkOwnership, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owners[player] = nil
	end)
end

return MonetizationService

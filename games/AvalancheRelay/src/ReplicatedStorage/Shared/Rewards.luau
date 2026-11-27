--!strict
-- Free rewards unlocked by lifetime Frost Badges (1 badge per 5 segments cleared).
-- All cosmetic. Trailblazer Kit owners get every flame straight away plus the Ember flame,
-- sparkle trail and gate confetti; wearables are earn-only.

export type Reward = {
	id: string,
	name: string,
	kind: "flame" | "wear",
	value: string, -- flame name, or wearable id
	badges: number, -- Frost Badges needed
}

local Rewards = {}

Rewards.LIST = {
	{ id = "FlameFrost", name = "Frost Flame", kind = "flame", value = "Frost", badges = 1 },
	{ id = "Beanie", name = "Cozy Beanie", kind = "wear", value = "Beanie", badges = 2 },
	{ id = "FlameAurora", name = "Aurora Flame", kind = "flame", value = "Aurora", badges = 3 },
	{ id = "Scarf", name = "Candy Scarf", kind = "wear", value = "Scarf", badges = 5 },
	{ id = "FlameRose", name = "Rose Flame", kind = "flame", value = "Rose", badges = 8 },
	{ id = "Earmuffs", name = "Fluffy Earmuffs", kind = "wear", value = "Earmuffs", badges = 12 },
} :: { Reward }

Rewards.KIT_ONLY_FLAMES = { Ember = true } :: { [string]: boolean }

local byId: { [string]: Reward } = {}
for _, reward in Rewards.LIST do
	byId[reward.id] = reward
end

function Rewards.get(id: string): Reward?
	return byId[id]
end

-- Rewards whose badge requirement lies in (before, after].
function Rewards.newlyUnlocked(before: number, after: number): { Reward }
	local out = {}
	for _, reward in Rewards.LIST do
		if reward.badges > before and reward.badges <= after then
			table.insert(out, reward)
		end
	end
	return out
end

function Rewards.nextReward(badges: number): Reward?
	for _, reward in Rewards.LIST do
		if reward.badges > badges then
			return reward
		end
	end
	return nil
end

-- The badge requirement for earning `flame` (nil if it is Gold or kit-only).
function Rewards.flameRequirement(flame: string): number?
	for _, reward in Rewards.LIST do
		if reward.kind == "flame" and reward.value == flame then
			return reward.badges
		end
	end
	return nil
end

return Rewards

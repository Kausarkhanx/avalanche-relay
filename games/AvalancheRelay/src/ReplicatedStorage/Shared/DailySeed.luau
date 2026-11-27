--!strict
-- Daily course selection. Every server computes the same seed from the UTC date,
-- so every server runs the same mountain on the same day.

local Config = require(script.Parent.Config)
local SegmentCatalog = require(script.Parent.SegmentCatalog)

local DailySeed = {}

function DailySeed.todaySeed(): number
	local override = Config.SEED_OVERRIDE
	if override then
		return override
	end
	local t = os.date("!*t")
	return t.year * 10000 + t.month * 100 + t.day
end

function DailySeed.dateKey(seed: number): string
	return tostring(seed)
end

-- Real UTC calendar day as "YYYYMMDD", ignoring SEED_OVERRIDE (used for streaks).
-- offsetDays = -1 gives yesterday.
function DailySeed.utcDayKey(offsetDays: number?): string
	local t = os.date("!*t", os.time() + (offsetDays or 0) * 86400)
	return tostring(t.year * 10000 + t.month * 100 + t.day)
end

-- Returns segment model names in run order; the Village Gate is always last.
-- FNV-1a over the seed's digits. Consecutive dates are near-identical numbers, and feeding
-- them straight into Random.new gave neighbouring days very similar shuffles.
local function mix(seed: number): number
	local hash = 2166136261
	for i = 1, #tostring(seed) do
		hash = bit32.bxor(hash, string.byte(tostring(seed), i))
		hash = (hash * 16777619) % 4294967296
	end
	return hash
end

function DailySeed.pickSegments(seed: number): { string }
	local rng = Random.new(mix(seed))
	local pool = table.clone(SegmentCatalog.Pool)

	-- Fisher-Yates shuffle with the seeded generator.
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local count = math.min(Config.SEGMENTS_PER_RUN, #pool)
	local picked = {}
	local hasToss = false
	for i = 1, count do
		picked[i] = pool[i]
		if pool[i].tossRequired then
			hasToss = true
		end
	end

	-- Guarantee at least one toss moment per day (still deterministic).
	if not hasToss then
		for i = count + 1, #pool do
			if pool[i].tossRequired then
				picked[count] = pool[i]
				break
			end
		end
	end

	local names = {}
	for _, info in picked do
		table.insert(names, info.name)
	end
	table.insert(names, SegmentCatalog.Finish.name)
	return names
end

function DailySeed.displayNames(names: { string }): { string }
	local out = {}
	for _, name in names do
		table.insert(out, SegmentCatalog.displayName(name))
	end
	return out
end

return DailySeed

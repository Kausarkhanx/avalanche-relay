--!strict
-- The hand-built course segments. Model names must match ServerStorage.Segments.

export type SegmentInfo = {
	name: string,
	displayName: string,
	difficulty: number, -- 1 easy .. 3 hard
	tossRequired: boolean, -- has a gap the carrier cannot jump (solo players take the detour)
}

local SegmentCatalog = {}

SegmentCatalog.Pool = {
	{ name = "Switchbacks", displayName = "Switchbacks", difficulty = 1, tossRequired = false },
	{ name = "IceBridgeGap", displayName = "Ice Bridge Gap", difficulty = 3, tossRequired = true },
	{ name = "PineSlalom", displayName = "Pine Slalom", difficulty = 1, tossRequired = false },
	{ name = "FrozenWaterfallSteps", displayName = "Frozen Waterfall Steps", difficulty = 2, tossRequired = false },
	{ name = "CollapsedCabin", displayName = "Collapsed Cabin", difficulty = 2, tossRequired = false },
	{ name = "CrevassePlanks", displayName = "Crevasse Planks", difficulty = 3, tossRequired = true },
	{ name = "SnowTunnel", displayName = "Snow Tunnel", difficulty = 1, tossRequired = false },
	{ name = "IcicleRidge", displayName = "Icicle Ridge", difficulty = 2, tossRequired = false },
} :: { SegmentInfo }

SegmentCatalog.Finish = {
	name = "VillageGate",
	displayName = "Village Gate",
	difficulty = 1,
	tossRequired = false,
} :: SegmentInfo

local byName: { [string]: SegmentInfo } = {}
for _, info in SegmentCatalog.Pool do
	byName[info.name] = info
end
byName[SegmentCatalog.Finish.name] = SegmentCatalog.Finish

function SegmentCatalog.get(name: string): SegmentInfo?
	return byName[name]
end

function SegmentCatalog.displayName(name: string): string
	local info = byName[name]
	return if info then info.displayName else name
end

return SegmentCatalog

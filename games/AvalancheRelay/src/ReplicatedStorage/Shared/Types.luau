--!strict
-- Shared type definitions for Avalanche Relay.

export type RaceState = "Countdown" | "Running" | "Ended"

export type EndReason = "Finished" | "Caught" | "Abandoned"

export type DailyBest = {
	segments: number,
	time: number,
}

export type PlayerData = {
	schemaVersion: number,
	bestDaily: { [string]: DailyBest }, -- keyed by date seed, e.g. "20261126"
	totalRuns: number,
	segmentsCleared: number, -- lifetime, drives Frost Badges
	frostBadges: number,
	cosmetics: { [string]: boolean },
	equippedFlame: string,
	equippedWear: { [string]: boolean }, -- earned wearables switched on (v3)
	tutorialDone: boolean, -- first-run tips finished or skipped (v4)
	streak: number, -- consecutive UTC days with at least one segment cleared (v5)
	streakDay: string, -- last day ("YYYYMMDD") that counted toward the streak
	bestStreak: number,
}

export type Course = {
	slot: number,
	model: Model,
	segmentNames: { string },
	checkpoints: { BasePart }, -- one per segment, in order; the last one is the Village Gate
	respawnPoints: { Vector3 }, -- where a player reappears after checkpoint i
	checkpointDistances: { number }, -- distance along the avalanche path of each checkpoint
	waypoints: { Vector3 }, -- avalanche path
	cumulative: { number }, -- distance along the path at each waypoint
	totalLength: number,
	startCFrame: CFrame,
	startSpawn: Vector3,
	startDistance: number,
	killY: number,
	centerX: number,
	gate: Model?,
}

export type Squad = {
	id: number,
	members: { Player },
	state: RaceState,
	course: Course,
	dateKey: string,
	lantern: BasePart?,
	carrier: Player?,
	tossing: boolean,
	lastPassTime: number,
	checkpointsCleared: number,
	lastCheckpointClock: number,
	lastCheckpointTime: number, -- seconds from GO to the latest checkpoint (score tiebreak)
	countdownEnd: number,
	startClock: number,
	endClock: number?,
	avalancheDistance: number,
	lanternDistance: number,
	endReason: EndReason?,
	immunity: { [Player]: number },
	rematch: { [Player]: boolean }, -- pressed Run Again after the run ended
	slowmoUntil: number, -- os.clock() until which the avalanche runs in slow-mo (big toss)
}

export type RaceResult = {
	reason: EndReason,
	segments: number,
	totalSegments: number,
	time: number, -- time of the last checkpoint (score tiebreak)
	elapsed: number, -- total run time, for display
	newBest: boolean,
	badgesEarned: number,
	frostBadges: number,
}

-- Sixth argument of RaceStateUpdate.
export type RaceInfo = {
	squadId: number,
	totalSegments: number,
	memberIds: { number },
	segmentNames: { string },
	cooldown: number,
	tossing: boolean,
	result: RaceResult?,
}

return {}

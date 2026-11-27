--!strict
-- Tunable numbers for Avalanche Relay. Server and client both read this module.

local Config = {
	-- Monetization
	GAMEPASS_ID = 2099167575, -- Trailblazer Kit (99 Robux), created 27 Nov 2026

	-- Movement (applied on the server only)
	NORMAL_WALKSPEED = 20,
	CARRIER_WALKSPEED = 14,
	NORMAL_JUMPPOWER = 50,
	CARRIER_JUMP_MULTIPLIER = 0.8, -- carrier jumps 20% lower

	-- Lantern toss
	TOSS_RANGE = 24,
	TOSS_COOLDOWN = 1.5,
	TOSS_FLIGHT_SECONDS = 0.6,
	TOSS_ARC_HEIGHT = 7,
	BIG_TOSS_DISTANCE = 12, -- tosses this long get slow-mo
	SLOWMO_AVALANCHE_FACTOR = 0.35, -- avalanche speed multiplier during a big toss

	-- Avalanche
	AVALANCHE_START_SPEED = 12,
	AVALANCHE_MAX_SPEED = 19,
	AVALANCHE_RAMP_SECONDS = 40, -- time to go from start speed to max speed (short, punchy runs)
	AVALANCHE_GRACE_SECONDS = 1.5, -- after GO, before the wall starts moving
	AVALANCHE_START_BEHIND = 40, -- studs behind the trailhead pad
	AVALANCHE_VERTICAL_OFFSET = 18,
	AVALANCHE_CHECK_INTERVAL = 0.1,

	-- Race flow
	LOBBY_COUNTDOWN_SECONDS = 5,
	LOBBY_SOLO_WAIT_SECONDS = 10, -- one player on the ring and others idle: wait longer so they can join
	FULL_SQUAD_COUNTDOWN = 3, -- squad is full: start sooner
	RACE_COUNTDOWN_SECONDS = 3,
	POST_RACE_SECONDS = 6, -- results screen; pressing RUN AGAIN as a squad skips the rest
	MAX_SQUAD_SIZE = 4,
	SEGMENTS_PER_RUN = 3, -- plus the Village Gate, always last (~60-90s runs)
	CHECKPOINT_MIN_INTERVAL = 3,
	PUFF_IMMUNITY_SECONDS = 2,
	SAFE_RESPAWN_AHEAD = 20, -- puffed players reappear at least this far ahead of the wall

	-- Course layout
	SQUAD_OFFSET_X = 600,
	COURSE_ORIGIN_Y = 250,

	-- Progression and saving
	BADGE_EVERY_SEGMENTS = 5,
	AUTOSAVE_SECONDS = 120,
	SESSION_LOCK_SECONDS = 180,
	DAILY_HISTORY_DAYS = 30,
	-- Daily streak: clear at least one segment each UTC day. Milestones add bonus
	-- segments toward Frost Badges (cosmetic rewards only).
	STREAK_BONUSES = { [3] = 2, [7] = 5, [14] = 5, [30] = 10 } :: { [number]: number },

	-- Testing
	SEED_OVERRIDE = nil :: number?, -- e.g. 20261127 to preview another day's course
	STUDIO_GRANT_KIT = false, -- true lets you try the Trailblazer Kit in Studio while GAMEPASS_ID is 0
}

return Config

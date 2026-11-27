# Avalanche Relay

An all-ages co-op parkour race. A squad of 1–4 players carries one glowing **Summit Lantern** from the peak to the village gate while a slow, relentless avalanche wall chases them. The carrier is slower and jumps lower, so squads win by tossing the lantern to each other across gaps.

## Controls

| Action | Keyboard | Gamepad | Touch |
| --- | --- | --- | --- |
| Move / jump | WASD / Space | Left stick / A | Thumbstick / jump button |
| Toss lantern to nearest squadmate in range | **E** | **X** | **TOSS** button (bottom right) |

Green rings show which squadmates are in toss range (24 studs, clear line of sight). The thickest ring is the one you'll throw to.

## How a run works

1. Step on the glowing **Start ring** at the summit. A 5 s countdown starts; up to 4 players on the ring when it ends become a squad.
2. The squad is teleported to its own course (each squad's course is offset 600 studs on X so they never overlap). After 3-2-1-GO, the avalanche waits 1.5 s and then follows the course, ramping from 12 to 19 studs/s over 40 s.
3. Carry the lantern through each **checkpoint banner**. The carrier has WalkSpeed 14 and 20% lower jumps; everyone else has WalkSpeed 20.
4. Two segments (Ice Bridge Gap, Crevasse Planks) have a gap the carrier can't jump: a squadmate jumps across and you toss them the lantern. Solo players take a slower detour route.
5. If the avalanche touches a non-carrier, they're puffed back to the last checkpoint, or just ahead of the wall if it has already passed that checkpoint. If it touches the **lantern**, the run ends.
6. Deliver the lantern through the **Village Gate** arch to light it up. Score = segments cleared (out of 4), with the time you reached your last checkpoint as the tiebreak.

## Daily seed

`seed = year*10000 + month*100 + day` from `os.date("!*t")` (UTC). The seed is mixed with an FNV-1a hash (so neighbouring days differ), then `Random.new` shuffles the 8 hand-built segments and picks 3, guaranteeing at least one toss segment. The Village Gate is always added last. Every server computes the same seed, so everyone runs the same mountain each day. To preview another day, set `Config.SEED_OVERRIDE = 20261127`.

Segments: Switchbacks, Ice Bridge Gap (toss), Pine Slalom, Frozen Waterfall Steps, Collapsed Cabin, Crevasse Planks (toss), Snow Tunnel, Icicle Ridge. Finish: Village Gate.

## Progression and saving

- DataStore `AvalancheRelay_v1`, key `u_<UserId>`, record `{ data, lock }`.
- Saves the best Daily result per date (last 30 days), total runs, lifetime segments, Frost Badges (1 per 5 segments cleared), cosmetics, and the equipped flame.
- Session lock via `UpdateAsync` (`{jobId, time}`). A foreign lock younger than 180 s causes retries, then a kick with "Your save is still loading, please rejoin".
- Every call uses pcall with 3 retries (1 s, 2 s, 4 s). Autosave runs every 120 s, data is saved and released on leave, and `BindToClose` saves everyone within 25 s. `schemaVersion` with migration (currently v2).
- The server leaderboard (`leaderstats`) shows **Today** (best segments today) and **Badges**.
- In Studio, enable *Game Settings → Security → Enable Studio Access to API Services* to test saving. Without it the game runs on temporary data and prints one warning.

## Monetization (cosmetic only)

- **Game Pass: Trailblazer Kit**: lantern flame colors (Gold, Frost, Aurora, Rose, Ember), a sparkly snow trail, and a confetti burst when your squad lights the village gate. Create the pass on the Creator Dashboard and paste its id into `Config.GAMEPASS_ID`. Carrier speed, toss range and avalanche speed are identical for everyone. To try it in Studio before the pass exists, set `Config.STUDIO_GRANT_KIT = true`.
- **Private Servers**: enable them in *Game Settings → Monetization → Private Servers*. A private server runs the same daily course with the same rewards; it just keeps randoms out.
- `ProcessReceipt` is a stub that returns `NotProcessedYet` for unknown product ids. The comments in `MonetizationService` explain how to make grants idempotent (record each `PurchaseId` before granting).

## Remotes

| Remote | Type | Direction | Payload |
| --- | --- | --- | --- |
| `RequestPass` | RemoteEvent | client → server | `targetUserId` |
| `RaceStateUpdate` | RemoteEvent | server → client | `state, segment, time, avalancheGap, carrierId, info` (`info` = squadId, totalSegments, memberIds, segmentNames, cooldown, tossing, result?) |
| `Notify` | RemoteEvent | server → client | `kind, text, worldPosition?` |
| `GetDailyInfo` | RemoteFunction | client → server | returns seed, segments, personal best, badges, runs, kit ownership, flame |
| `SetFlameColor` | RemoteEvent | client → server | `flameName` (validated against kit ownership) |
| `QuickJoin` | RemoteEvent | client → server | none: Find Squad / Join in the lobby, Run Again after a run (rate-limited to 1/s) |
| `SetWearable` | RemoteEvent | client → server | `rewardId, on` (only earned wearables) |

## Server authority

- `RequestPass` is honored only if the sender is the current carrier, the target is alive in the same squad, the distance is ≤ 24, a raycast between them is clear, the 1.5 s cooldown has passed, and the race state is Running.
- WalkSpeed and JumpPower are set only on the server (`LanternService.applyMovement`) and re-applied on CharacterAdded.
- Checkpoints are detected by the server from the lantern's position. The index must be the last index + 1, and at least 3 s must have passed since the previous checkpoint.
- All times come from server `os.clock`. Clients only display.
- Known limit: character physics is client-owned on Roblox, so an exploiter could still teleport their own character. A follow-up could add server-side speed sanity checks on the carrier.

## Layout

```
games/AvalancheRelay/
  default.project.json           Rojo project (optional; maps src/ to the services below)
  tools/BuildWorld.luau          Builds the lobby, segments, avalanche, lighting, audio in Studio
  src/
    ReplicatedStorage/Shared/    Types, Config, SegmentCatalog, DailySeed, Remotes
    ServerScriptService/         GameServer.server.luau
      Services/                  DataService, MonetizationService, CourseService, LanternService,
                                 AvalancheService, RaceService, LobbyService
    StarterPlayer/StarterPlayerScripts/
      ClientMain.client.luau
      Controllers/               ClientState, AudioController, FloatingText, AvalancheFX,
                                 PassController, HudController, JuiceController, TutorialController
    StarterGui/HudBuilder.client.luau
```

## Squads, rematches and the lodge

- **Find Squad** (lobby panel) puts you on the Start ring. If you're alone on the ring and others are idle in the lobby, the countdown waits 10 s and they get a "X is starting a run! JOIN!" pop-up. A full squad of 4 starts after 3 s.
- **Run Again** (results banner) puts you straight back on the ring. In a squad, teammates see "X wants to run again!", and once everyone has pressed it the squad goes back together without waiting out the results screen.
- **Cocoa Lodge**: fireplace, armchairs you can sit in, a hot cocoa bar (a ProximityPrompt gives you a mug to hold until your next run), fairy lights, and a bookshelf.

## Daily streak

- Clear at least one segment on a UTC day to keep your 🔥 streak going. Missing a day resets it to 1 on your next run.
- Milestones give bonus segments toward Frost Badges (cosmetic only): day 3 gives +2, day 7 +5, day 14 +5, and day 30 +10 (`Config.STREAK_BONUSES`).
- The lobby panel shows your streak (or "Run today to keep your N-day streak!"), and you get a reminder toast on join. Extending the streak gives a 🔥 toast, a chime and a gold flash.
- Saved data is schema v5 (`streak`, `streakDay`, `bestStreak`). Streak days use the real UTC date and ignore `SEED_OVERRIDE`.
- Studio-only test hook: `ServerStorage.DevCommands.SetStreak:Invoke(player, streak, daysAgo)`.

## Leaderboard

Roblox's default player list is turned off. Instead, a compact leaderboard sits in the top-right corner of the lobby (it hides during runs, where the timer goes). It shows up to 8 players with **Today** (best segments), **❄** badges and **🔥** streak. Your own row is gold. It reads the `leaderstats` values (Today, Badges, Streak).

## First-run tips ("Pip")

New players don't get a separate tutorial level. Pip the penguin pops up with short tips at the moment each one matters:

- **Lobby**: how to start, plus a bobbing "START HERE" marker over the Start ring.
- **Countdown**: what the lantern is. **GO**: run, and watch the GAP meter.
- **Checkpoint**: head for the Village Gate.
- **Before a toss segment**: in a squad, how to toss; solo, take the side route.
- **Caught**: pass the lantern more often.

Each tip shows once, hides after 7 s, and has GOT IT / Skip tips buttons. The tips stop after the first delivered lantern, after 3 runs, or on Skip. That's saved as `tutorialDone` (schema v4), and anyone who had already played before v4 skips the tips. Code: `TutorialController`, remote `TutorialDone`.

## Frost Badge rewards (free, cosmetic)

You earn 1 Frost Badge for every 5 segments cleared (lifetime). Each badge milestone unlocks a free reward, and it's announced with a chime and a gold flash after the run. Wearables go on automatically when they unlock.

| Badges | Reward |
| --- | --- |
| 1 | Frost Flame |
| 2 | Cozy Beanie (wearable) |
| 3 | Aurora Flame |
| 5 | Candy Scarf (wearable) |
| 8 | Rose Flame |
| 12 | Fluffy Earmuffs (wearable) |

- Open **❄ Rewards** in the lobby panel to see your progress and to USE flames or WEAR / TAKE OFF wearables. The ladder lives in `Shared/Rewards.luau`.
- Trailblazer Kit owners can use every flame right away. **Ember** stays kit-only, and the wearables can only be earned.
- The server validates every equip (`SetFlameColor`, `SetWearable`). Saved data is now schema v3 (`equippedWear`).
- Studio-only test hook: `ServerStorage.DevCommands.SetProgress:Invoke(player, segmentsCleared)`. It isn't created on live servers.

## Juice

- **Big toss (≥ 12 studs)**: slow-mo with cinematic bars, a camera zoom, a colour punch and a music pitch dip. The avalanche also runs at 35% speed for the flight time (`SLOWMO_AVALANCHE_FACTOR`), which is the same for every squad. The lantern leaves a glowing trail and pops sparkles on the catch.
- **Checkpoint**: gold flash and a sparkle burst. **Gate**: gold flash and a sparkle burst for everyone; Trailblazer Kit owners also get confetti.
- **Puffed**: white flash, shake and a snow burst. **Caught**: whiteout, big shake, colour drains, and a snow explosion.
- **GO!**: an FOV punch and a shake.
- Everything except the bullet-time is client-side (`JuiceController`).

## Pacing

Runs are short on purpose: 3 segments + the Village Gate (~60–90 s), a 5 s lobby countdown, a 1.5 s avalanche head start, and the wall reaches top speed in 40 s. Tune these in `Config`.

## Audio

All free Creator Store audio, set in `tools/BuildWorld.luau`:

- **Music** (APM Music, licensed by Roblox): lobby "Happy Feet (b)" `1839878694`, race "High Five Happy (c)" `9045803411`. They crossfade, and the race track speeds up slightly as the avalanche closes in.
- **SFX**: Toss whoosh `9126047581`, and Earthquake Rumble `9112775181` (Pro Sound Effects). Catch pop `106984966606682`, Checkpoint coin `130378474223829`, countdown Beep `138309872562566`, Heartbeat (gap < 15 studs) `132163421525060`, gate Bell `132377870366381`, Caught `96795857757261`, UI Click (Daily Sounds).
- **TODO**: `Ambience/Wind` has an empty SoundId; add a licensed wind loop if you want one.

## Carrying pose

The carrier plays Roblox's default "holding a tool" arm animation (R15 `507768375`, R6 `182393478`), and the lantern is welded so its handle sits in the right hand.

# Publishing Avalanche Relay

> **Status (27 Nov 2026): published and public.** Place id `76654692240887`, universe `10779364379`. Roblox currently shows it to players **ages 16+**. Opening it to younger players is the "Expand your audience" step in the Creator Hub. Team Create is on, Studio API access is on, and DataStore saving was verified with a reload. The icon and the 3 detail-page thumbnails (toss → lodge → summit) are uploaded and waiting for Roblox moderation. The Trailblazer Kit game pass (id `2099167575`, 99 Robux, on sale) is live: it's set in `Config.GAMEPASS_ID`, its ownership check was verified in Studio, and the update was published. Private servers are enabled at 50 Robux/month (Creator Hub → Publish settings / Advanced settings → Private servers; Roblox only allows a price change once every 60 days). Under-16s: the content rating questionnaire is submitted (rated **Minimal**, Violence Occasional/Mild) and game details are complete. The last gate (Creator Hub → Audience → Manage audience) is either reaching 100 highly engaged players or paying the refundable 1,000 Robux Kids & Select fee. Optionally, also add the thumbnails on the Creator Hub "Home Page" tab (the rotating discovery images).

Everything in this guide is checked and ready, except the steps that need your Roblox account (they're marked **You**).

## 1. Store page copy

**Name:** Avalanche Relay

**Description** (paste into the experience description):

> ❄ Carry the glowing Summit Lantern down the mountain, with an avalanche right behind you!
>
> Whoever holds the lantern runs slower, so team up with up to 3 friends and TOSS it across gaps, ledges and crevasses. Big tosses go into slow-mo. Don't drop it!
>
> 🏔 A NEW MOUNTAIN EVERY DAY: the course changes daily and is the same for everyone. Beat your squad's best time.
> 🔥 DAILY STREAKS: run every day for bonus rewards.
> ❄ FROST BADGES: unlock free flames, a cozy beanie, a candy scarf and fluffy earmuffs.
> ☕ COCOA LODGE: warm up by the fire with hot cocoa between runs.
>
> Runs take about a minute. Hit RUN AGAIN and go!

**Genre:** Obby & Platformer (or Adventure).

**Icon and thumbnails** (`store/`):
- `icon-512.png` (512×512)
- `thumbnail-1-toss.png`, `thumbnail-2-cocoa-lodge.png`, `thumbnail-3-summit.png` (1920×1080, upload in this order)

The thumbnails are upscaled about 12% from Studio captures. They're fine for launch, but you could recapture them later at a bigger window size.

## 2. Maturity & Compliance questionnaire (suggested answers)

Answer honestly in the Creator Dashboard; these are suggestions from what's in the game:
- **Violence / blood:** none. Getting caught "puffs" you back with no damage, no weapons and no injuries.
- **Fear:** at most mild. It's a cartoon avalanche chase with no horror.
- **Crude humour, strong language, romance:** none.
- **Alcohol / drugs:** none. Hot cocoa only.
- **Gambling:** none. There are no paid random items.
- **Social:** Roblox's own text chat (default settings). No voice-chat features are added by the game.
- **Free-form user creation:** none.
- **Paid items:** one cosmetic-only game pass (Trailblazer Kit). Private servers are optional.

This should come out as the lowest maturity label, but Roblox decides that from your answers.

## 3. Step-by-step

1. **You:** in Studio, **File → Publish to Roblox**. Create a new experience called "Avalanche Relay" and keep it Private for now.
2. **You:** **Game Settings → Security → Enable Studio Access to API Services**, so saving works in Studio playtests too.
3. **You:** in the Creator Dashboard, open the experience → **Monetization → Passes → Create a Pass**: "Trailblazer Kit", using the icon or a lantern image. Describe it as "Lantern flame colours, sparkly snow trail, and confetti when your squad lights the village gate. Cosmetic only." Pick a price (for example 99 Robux).
4. Paste the pass id into `src/ReplicatedStorage/Shared/Config.luau` → `GAMEPASS_ID`. Then sync it into Studio (Claude can do this) and publish again.
5. **You:** **Monetization → Private Servers → Enable** (free or a small price).
6. **You:** **Places / Experience → Icon & Thumbnails**: upload the files from `store/`.
7. **You:** **Audience → Maturity & Compliance questionnaire**: fill it in (see section 2).
8. **You:** play the published game once with a friend (or two accounts): toss, check that the daily course shows, and rejoin to see that saves restore.
9. **You:** set the experience to **Public**.

## 4. What's verified, and what isn't

**Verified in Studio:**
- Solo runs: delivering the lantern, getting caught, checkpoints and the gate.
- Run Again, Find Squad and hot cocoa.
- Rewards and wearables, streaks, the tutorial and the compact leaderboard.
- **2-player Server & Clients test:**
  - A big toss lands on the teammate, with the trail and slow-mo.
  - The avalanche slows during the flight (1.7 vs 12.2 studs/s).
  - Walk speeds swap between the two players.
  - Throwing through a wall is rejected, in both directions and right after a catch.
  - A 32-stud toss is rejected, and a non-carrier's request is ignored.
- Output has no errors. The only warning is the expected "DataStore unavailable" in an unpublished place.

**Not verified until published:**
- DataStore saving and loading, including session locking across servers.
- The game pass purchase flow and ownership checks.
- Phone layout on a real device (the Studio device emulator is a good first check).
- Squad rematch and the "JOIN!" invite with real players.

## 5. Studio note

The Studio test-mode dropdown (top left, next to ▶) is set to **Server & Clients** with 2 players after the 2-player test. To go back to normal solo playtesting, set it back to **Test**.

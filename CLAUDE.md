# AD Bot: working notes

AutoHotkey v2 farming bot for the Roblox game **Anime Dimensions Simulator**. It only reads the screen and sends mouse and
keyboard input. Forked from Samogub/AD-bot; `origin` = Bijankc/AD-bot, `upstream` = Samogub. Work on branch
`device-2560x1440-150`. Facts below were observed on this PC in Nov 2026 unless marked otherwise. The game updates, so
check anything that stops matching.

## This PC

- 2560x1440, Windows scale 150% (DPI 144), Windows 11, AutoHotkey v2 at `C:\Program Files\AutoHotkey\v2\AutoHotkey.exe`.
- The user sometimes plays on an external monitor. The bot reads the DPI of Roblox's window each tick (`GameGeometry()`).
- The private server link is in `raid.ini` as `serverLink`. `raid.ini` is gitignored; never commit the link. The fork is public.
- `raid.ini` is UTF-16 (IniWrite), so plain `grep` finds nothing in it. Read it with PowerShell `Get-Content`.

## Game modes

| Mode | When | Length | Notes |
|---|---|---|---|
| Raid (Divine Guardian) | hourly | about 7:50 | Opens at **:45:00 on this user's private server**. The time differs per server. Only one per hour. Observed 100-250 tokens, 24-56 gems. A "2X raid token" banner was showing in the raid world on 7 Nov. |
| Speed Raid | every 30 min, one character each | 1:10-2:30 | Each character can be used once per week; used ones are dimmed. Weekly reset. A run can drag on if the boss is too strong (20+ min once), so `SPEED_MAX` (12 min) restarts Roblox. Observed 10-26 gems, 31-78 tokens. |
| Infinity | between the others | until the team falls or the bot leaves | On the game's Auto a run lasted 31:16 before the team fell. Never ends by itself otherwise. |

Game behaviour worth knowing:

- **Raid picker** (10 Nov, ported from upstream 0.3.5): `raidName` in `raid.ini` picks one of the 10 raids in `RAIDS`. Every raid
  except Divine is found in the Create list by name (OCR, `PickRaidByName`). As of 10 Nov only Divine has been tested on this server.
  If a raid is missing from the list 3 times, the bot skips that hour's raid.
- **Group Finder entry** (`raidEntry=gf`, user's choice on 10 Nov because grouping with other players deals more damage): `EnterRaidGF` queues
  through the Group Finder tab, as upstream 0.3.5 does. If the bot is not teleported `GF_FALLBACK` (120 s) after the raid opens, or the
  name is missing from the list 3 times, it cancels the queue and creates the raid itself for that hour, **open to others** (Friends Only
  off, short PARTY wait `startDelay`). `GF_TAB_DX` and `GF_BANNER` were measured upstream at 100% and are not yet checked at 150%.
  Fight handling is unchanged (game's Auto, kept on).
- **The raid can only be created in about the first 10 minutes after it opens** (from a code comment).
- **The raid world has no menu route back to the lobby** in the bot's logic, so it restarts Roblox to get out.
  PLAY in the raid world opens the raid list, not the modes menu.
- The private server link can land in the lobby; PLAY there goes to the modes menu (Dimension / Speed Raid / RAID card).
- The RAID card in the modes menu shows "Raid Opens in: MM:SS". The raid-world banner shows "Raid opens in N Minutes N Second".
- **Auto** button (the game's auto-battle) is at 738,852 on the bot's layout. It stays on after a death inside a run and turns
  off after a teleport or new run. So the bot presses it once at the start of each run.
- Infinity's results screen has RETRY / LEAVE and **AUTO RETRY IN 5**: if LEAVE is not pressed in time a new run starts.
- Leaving Infinity early: Esc, R, Enter resets the character until the run ends, then LEAVE on the results screen.
- Loadouts in the Bag: 1 = raid, 2 = Infinity, 3 = Speed Raid (setting `loadouts=1`).

## How the bot decides (`PickTarget`)

Priority is raid > Speed Raid > Infinity. Times below are "raid hour" (`SecOfHour()` = real time minus `raidOfs`, 0 = the raid opens):

- `infStop` 57:30 = leave Infinity (real time :42:30 here). `createFrom` 59:30 = start pressing Create (real :44:30).
- `RAID_SOON` 360 s: in the lobby this close to `infStop`, go and wait for the raid instead of starting Infinity.
- No Speed Raid is started after `SPEED_LAST_MIN` of the raid hour.
- `raidOfs` is learned by OCR. A changed value is accepted only when two readings agree within 30 s (OCR once read 41:28 as 4:28).

**The game's Auto plays every mode, at the user's explicit request** ("they are better than our macro"): `bossAuto=1` (Raid and
Speed Raid) and `infFullAuto=1` (Infinity). The bot only keeps Auto on. Do not bring back the bot's own skill pressing as a default.

## Files

- `RaidBot.ahk`: main loop (`Tick` → `Step`), goals, menus, restarts, `FindImg`. LF line endings with BOM; many comments are Ukrainian.
- `auto_boss.ahk`: Auto handling, `FightHud`, `LobbyPlay`, `LetterBox`.
- `ui.ahk`: window and settings pages. `rewards.ahk`: reward reading. `ocr.ps1`: Windows OCR server.
- `device_check.ahk`: checks the window and image match, writes `device_check.txt` and `shots\device_check.png`.
- `img/`: templates. `shots/`: screenshots named by time and reason, the first thing to look at when debugging.
- `raid.log`: live log, lines start `dd.MM HH:mm:ss.mmm`. Older days go to `logs/`. Daily totals are in `raid.ini` `[stats]`.

## Screen and DPI rules (the source of most bugs)

- Everything is matched against the top-left 1920x1080 (`SCR_W`, `SCR_H`), never `A_ScreenWidth`.
- Roblox is per-monitor DPI aware. Its top bar grows with the scale (58 px → 87 px) and the game sizes its UI from client height
  minus the top bar. So the client is 1920x(1017+extra) at y = 23-extra: **1920x1046 at (0,-6) at 150%**. The title bar above the
  screen is deliberate.
- Fixed-size button text is enlarged at 150%, so some templates need a screen-specific version. `FindImg` tries `name.png`, then
  `name_2.png`, then `name_3.png`. Cut new ones from a `shots/` screenshot at the position the author's template sat, so click
  offsets still work. `*40` tolerance, FF00FF = transparent. ImageSearch returns the first hit in scan order.
- `Gui -DPIScale`, and `WinGetPos` rather than `Gui.GetPos`, which returns DPI-divided sizes.

## Hard-won fixes: do not undo

- **White flashes and bright floors** matched PLAY and the AUTO letters, giving false "lobby" and LEAVE mid-fight. Hence `FightHud`
  (AUTO letters plus non-white pixels around them), `LobbyPlay` (PLAY without HUD on 3 ticks in a row) and tight `LetterBox` search boxes.
- **AUTO letters:** OFF at 714,840, ON at 706,842. OFF diamond can be dark as well as red. Never treat ON as off, or a click turns Auto off.
- **Focus:** if another window is in front, Windows blocks focus stealing and the bot would read and click that window (missed the
  11:45 raid on 7 Nov). Roblox is always-on-top while running, cleared in `Stop`; while it is not active the bot waits.
- **Not Responding** (10 Nov): Windows covers a hung Roblox with a ghost window owned by dwm.exe, so the focus check above
  would wait forever. `Tick` checks `IsHungAppWindow` first and restarts Roblox after `HUNG_MAX` (60 s), or `HUNG_RAID` (20 s) in a
  raid fight. The raid is lost anyway, and the user's rule is to leave at once and start a new one.
  `raidDoneKey` is set when a raid fight *starts*, so `RestartRoblox` clears it for a raid cut off within `RAID_WINDOW`
  (10 min); the bot then creates a new raid (in Group Finder mode it falls back to Create, since the raid is already open).
  **The game allows one raid an hour, and a raid can finish before minute 10**: no retry once `raidEndSeen` (end screen or
  rewards) is set, and at most one retry per raid hour (`raidRetryHour`).
- **Preventive restart:** Roblox froze after 3.5 h mid-raid. In the lobby, 10-50 min into the raid hour, a Roblox running
  `ROBLOX_MAX_AGE` (120 min) or longer is restarted (`RobloxAgeMin` reads the process start time through WMI).
- **Group Finder queue:** pressing Easy closes the Join/Create window, and an open window dims the queue banner so OCR reads
  nothing. While queued the bot must not press PLAY (`GfWaiting`). Reopening the window and clicking Easy again restarted the queue (10 Nov).
  When the raid opens, the banner changes to "Group found! / 8/8 Starting..." with no CANCEL or Time, and the teleport follows
  about 20 s later. `GfBannerShown` accepts both forms. A click 5:48 before opening gave no queue, while 4:02 before worked.
  A Halloween group teleport worked on 10 Nov (16:45).
- The `menuOk` guard: mode cards count only while PLAY is dimmed, otherwise the lobby false-matches them.

## Operating it

- Start: open Roblox, wait in the lobby, run `RaidBot.ahk`. **F1** start, **F2** stop, **F3** reload. The user must press F2 before using the PC.
- Restart from a shell (replaces the running copy, leaves Roblox alone):
  `Start-Process "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" -ArgumentList '"RaidBot.ahk"','start' -WorkingDirectory <repo>`
- Syntax check: `"/c/Program Files/AutoHotkey/v2/AutoHotkey.exe" //ErrorStdOut //validate RaidBot.ahk` from Git Bash.
- Keep live template tests to a small region: a full-screen ImageSearch with several templates takes over a minute.
- Do not close or disturb Roblox while the user is playing manually.
- Useful log grep: `restarting Roblox|ERROR|WARNING|ended by itself|pressing LEAVE|not recognised for|tokens|gems|raid clock`.
  "waiting (screen not recognised)" for a moment during loading is normal.
- Some harmless oddities: "matched a blob of letter colour", and "scroll bar not found - scrolling with the mouse wheel" in Speed Raid.

## Titan farming (`titan.ahk`, added 8 Nov)

- "Titan" = **Giant Dimension** in the Dimension list. Settings in `raid.ini` `[raid]`: `titan=1`, `titanDiff=Easy|Hard|Nightmare`, `titanHard=1` (Hardcore: 3 lives, Esc-R-Enter costs one, **never click REVIVE: 50 gems**). Takes Infinity's slot in `PickTarget`. Uses loadout 2.
- **The route must run to the end.** `TITAN_LEGS` is walked with Shift Lock on (skills otherwise turn the character and bend the route), stopping after each leg until the enemy count is steady for 12 s (the game spawns late). The boss bar appears at leg 5 of 17, the boss dies around leg 6, the next stage appears on the same spot and the later legs lead on through it. Cutting the route short at the bar caused the earlier stuck runs and wasted lives.
- **Dimensions have no AUTO button**, so the bot plays them: opening legs from `Guts4.txt`, then reset (Esc-R-Enter) and walk-and-attack steps. The game moves the respawn point forward as the run progresses.
- Stages: waves down to one big titan near the canal, then 9-13 more, 5 at the top of the stairs, boss with a purple HP bar (Plated Giant; Monstrous Giant on Easy), then more stages.
- Observed: Easy A rank 6:58, 10 gems, 2 auto-sold cards. Nightmare Hardcore with the full route: S rank 4:45, 11 gems, 3 cards (+1,920 gold); best 4:38; a final boss can stretch a run to 7:30. Titan rewards show no raid tokens directly: its **accessories sell for raid tokens** (user, 8 Nov).
- `TITAN_COUNTS` maps `EnemiesSig` to the number on screen (12 and 13 share a print). 0 held for `TITAN_ZERO_WAIT` ends a stop early; the next wave came about 4 s after a 0 once. A reset is only spent after `TitanClear` finds enemies left and not coming.
- No basic attacks on the route, and `TitanRevive` blocks clicks and Enter while the Revive screen shows.
- The basic attack clicks at the mouse position. Parked on the title bar it double-clicks and maximizes Roblox, so `TitanMouse` keeps it over the game.
- `TitanHud` tests for the neutral grey Time diamond; dimmed menus are darker or tinted. The distance pill overlaps the boss name and cannot be read, so full boss HP means "not in reach yet".
- RETRY works (8 Nov), and LEAVE is pressed when the raid is next. Results are found by OCR while the red count is dimmed; `leave.png` is Infinity's picture and does not match here. The results screen can still be missed, then the game teleports to the lobby and the bot re-enters from there.
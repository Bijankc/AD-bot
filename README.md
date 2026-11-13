# AD Bot (fork): bigger screens, 150% scale and Dimension farming

A fork of [Samogub/AD-bot](https://github.com/Samogub/AD-bot), the farming bot for **Anime Dimensions Simulator** (Roblox).
The bot only reads the screen and presses keys and the mouse, like a player would.

This fork is built from upstream **0.2.7** with parts of **0.3.5** brought in by hand (raid picker, Group Finder). It is
**not** merged with upstream 0.4.0 and later, and both sides have moved on, so each has features the other lacks.
The work is on the branch **`device-2560x1440-150`**.

> Automating Roblox games may break the rules of Roblox or the game. **Use at your own risk.**

## What this fork adds

### Screens bigger than 1920x1080, Windows scale above 100%

Upstream is tuned for a 1920x1080 screen at 100% scale and warns about anything else. This fork runs on **2560x1440 at
150%**, and the same approach should work at other sizes and scales.

- Roblox's own top bar grows with the Windows scale (58 px at 100%, 87 px at 150%), and the game shrinks its interface to
  fit. The bot makes the window taller by that amount and moves it up, so the game's buttons sit on exactly the pixels the
  images were captured at. At 150% the window is 1920x1046 at y = -6, with its **title bar above the screen on purpose**.
- Only the 1920x1080 area in the top left is read. The rest of the screen is free (the status strip sits below the game).
- The scale is read from the monitor Roblox is on, every tick, so moving the game to another monitor is noticed.
- Text that the game draws at a fixed size looks different at 150%. Those images have extra versions (`name_2.png`,
  `name_3.png`) that the bot tries in turn.
- `device_check.ahk` checks a new PC: wait in the lobby, run it, and it sets the window, saves `shots\device_check.png`
  and says whether the images match.

### Giant Dimension played live, not from a recording

Upstream plays the Giant Dimension by replaying a recorded run. This fork plays it from a built-in route and **watches
the fight while it walks**.

- The route is cut into legs. After each leg the bot stands and fights until the **ENEMIES LEFT** count stops changing,
  because the game often spawns the next group late. The count is read from the screen, and an unknown way of drawing a
  number is read once by OCR and remembered.
- **Shift Lock** is kept on, so skills that turn the character cannot bend the route.
- **Hardcore** (3 lives, more rewards): a life is only spent on a reset when enemies are left and none are coming.
  **REVIVE (50 gems) is never clicked.**
- **Stuck runs are noticed.** In some runs the character ends a leg against a wall and the group of 8 on the bridge never
  comes. The bot then steps toward the stairs and tries again. If the count still has not moved by leg 4, it ends the run
  at once and presses RETRY, instead of losing 10 minutes on a run that cannot be won.
- **Watchdog:** results without "Best Time" count as a failed run. After 3 failures in a row the bot farms Infinity for an
  hour instead, then tries the Dimension again.
- **RETRY** keeps farming without going back to the lobby. A run still going when the raid is due is ended, so the raid is
  never missed.
- Results screen: rank, time and accessory pity go to the log.
- A route for the **Curse Dimension** exists too. It is experimental and was paused in favour of Giant.

Seen on this PC: Nightmare Hardcore clears in about 4 to 4.5 minutes, S rank, 11 gems a run.

### Raids

- **Raid clock read from the game.** The hourly raid does not open at the same minute on every server. The bot reads the
  countdown ("Raid Opens in: MM:SS") and plans the hour around it. A new time is only accepted when two readings agree, so
  a misread digit cannot move the raid. Upstream has a fixed minute setting instead.
- **Group Finder with a fallback.** If no group has teleported the bot 2 minutes after the raid opens, it cancels the queue
  and creates the raid itself, open to other players.
- **Raid cut off by a freeze:** the bot creates a new raid, but never after the raid has really ended, and at most once an
  hour (the game allows one raid an hour).
- **AUTO button redrawn (13 Nov):** the game changed the AUTO button's font. New images match it. If no AUTO button is seen
  25 s into a raid, the log says so and screenshots are saved, so a future redraw does not go unnoticed.
- **Never scrolls the mouse wheel in a fight.** A group teleport during the raid list search once zoomed the camera into
  first person, and the AUTO clicks missed.

### Keeping Roblox alive

- **Roblox frozen ("Not Responding"):** Windows covers a hung window with a ghost copy. The bot looks for that first and
  restarts Roblox after 60 s (20 s in a raid fight).
- **Preventive restart:** Roblox froze after hours of running, so a Roblox that has run for 2 hours is restarted in the
  lobby at a safe point in the hour.
- **Focus:** Roblox stays on top while the bot runs. Otherwise a window in front of it gets the clicks, and Windows blocks
  the bot from taking the focus back.

## Upstream features this fork does not have

Upstream 0.4.0 and later add a new interface (HUD 2.0), Safe mode, auto rejoin, Recorder 2.0 and shared runs, Extreme,
Halloween and Death Dimensions from recordings, Discord reports and more. See the
[upstream README](https://github.com/Samogub/AD-bot). If you are on a 1920x1080 screen at 100%, upstream is the better
choice.

## What you need

- Windows 10 / 11 and [AutoHotkey v2](https://www.autohotkey.com/)
- Roblox desktop app in a normal window (not F11 fullscreen). The bot sets the window size itself.
- Screen 1920x1080 or larger. Tested at 2560x1440, Windows scale 150%.
- Screen lock and screensaver off. English OCR language pack in Windows (Settings > Time & Language > Language).
- Loadouts in the Bag: **1** = raid, **2** = Infinity and Dimension, **3** = Speed Raid (then turn on **Switch loadout**).

## How to start

1. Download this branch (`device-2560x1440-150`), not `main`.
2. Open Roblox, join the game and wait in the lobby. On a new PC, run `device_check.ahk` once.
3. Run `RaidBot.ahk`, pick the raid and modes, and turn on the Dimension page for Giant.
4. **F1** starts, **F2** stops, **F3** reloads. The bot uses the mouse and keyboard all the time, so press **F2** before
   using the PC.

Settings live in `raid.ini`. To come back to your own private server after a restart, put `serverLink=<your link>` under
`[raid]`. `raid.ini` is ignored by git, so the link is never committed.

## Good to know

- Tested on one PC and one account. Other screens can still break image matching. `device_check.ahk` shows where.
- The game changes its drawing now and then (text in Nov 2026, the AUTO button on 13 Nov). When something stops
  matching, `shots\` and `raid.log` show it first.
- `raid.log` is the live log; older days go to `logs\`. Useful search:
  `restarting Roblox|ERROR|WARNING|Titan results|fight lasted|gems|tokens`.

Credit for the bot goes to [Samogub](https://github.com/Samogub/AD-bot). This fork only adds the parts above.

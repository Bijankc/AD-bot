# AD Bot

**Farming bot for Anime Dimensions Simulator (Roblox) that keeps going when Roblox itself fails.**

> Roblox disconnects, freezes on a teleport, loops a retry screen or just closes? AD Bot was made first of all for players for whom this happens **all the time**. It notices the problem, restarts the game, joins again and carries on, so your night run does not end at the first crash.

**Version 0.2.7 · stable** · Windows · by Samogub

![Dashboard](docs/dashboard.png)

![Modes](docs/modes.png)

## What it does when Roblox breaks

- **Disconnected / Error 279:** closes Roblox and joins again.
- **Roblox crashed or closed:** starts the game again.
- **Stuck on "Teleporting":** presses LEAVE, and restarts the game if that does not help.
- **Infinity keeps restarting by itself (Auto Retry):** presses LEAVE on the results screen, so the bot does not get stuck in endless Infinity.
- **Unknown screen or stuck menu:** tries Esc and closing windows, then restarts the game.
- **Wrong window size, fullscreen or keyboard layout:** fixes it before it starts.
- **Every restart** saves a screenshot and a log line with the reason. If something still goes wrong, run `Send_Report.bat` and send the zip to the author.

## What it farms

- **Raid:** every hour. The bot enters the raid and presses the game's **Auto** button, then reads the gems and tokens from the results.
- **Speed Raid:** every 30 minutes with the next unused character, also with Auto.
- **Infinity:** between raids. The character stands still and uses the big AOE skills.
- A short summary (raids, gems, tokens, Infinity runs, Roblox restarts) is written to the log when you stop the bot.

## What you need

- Windows 10 / 11 and [AutoHotkey v2](https://www.autohotkey.com/)
- Roblox desktop app in a normal window (not F11 fullscreen). The bot sets the window size itself.
- Screen **1920x1080**, Windows scale **100%**, taskbar at the bottom
- Screen lock and screensaver turned off
- English OCR language pack in Windows (Settings > Time & Language > Language)
- In Roblox (Optional): lowest graphics
- Optional: loadout 1 = raid, 2 = Infinity, 3 = Speed Raid, then turn on **Switch loadout**

## How to start

1. Download the repository (Code > Download ZIP) and unpack it!
2. Open Roblox, join the game and wait in the lobby.
3. Run `RaidBot.ahk`. On the first start press **Check now**, fix what it shows, then **Continue**.
4. Pick the raid and modes.
5. **F1** starts, **F2** stops, **F3** reloads the bot.

After a restart the bot returns to the author's private server by default. To use your own, put `serverLink=<your link>` under `[raid]` in `raid.ini`.

## Good to know

- Tested on one setup (1920x1080, one account). Other settings can break image matching.
- The bot uses your mouse and keyboard all the time, so you cannot use the PC while it runs.
- A disconnect is noticed after about 1.5 minutes, so each failure costs a few minutes.
- Automating Roblox games may break the rules of Roblox or the game. **Use at your own risk.**

Found a problem? Run `Send_Report.bat` and send the zip to the author, or open an issue here.

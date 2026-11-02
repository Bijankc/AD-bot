# AD Bot (public build, work in progress)

Unattended farming for Anime Dimensions Simulator (Roblox): hourly raid, Speed Raid, Infinity between raids.
Meant to run while you are away (night / work). It controls the real mouse and keyboard, so you cannot use the PC meanwhile.

## Requirements
- Windows 10/11, [AutoHotkey v2](https://www.autohotkey.com/) (or compile the script to .exe)
- Screen **1920x1080**, Windows taskbar **at the bottom**, Roblox in a normal window on the main monitor (not F11 fullscreen) - the bot sets the window size itself, please do not resize or maximise it
- Windows must not lock the screen (the bot keeps the PC awake, but disable the lock screen / screensaver password)
- English keyboard layout while the bot runs (other layouts can break the skill keys)
- Windows OCR language pack for English (Settings > Time & Language > Language)
- Optional: Loadout 1 = raid team, 2 = Infinity team, 3 = Speed Raid team, then turn on "Switch loadout"

## Use
1. Start `RaidBot.ahk`, pick the raid, switch the modes you want, open the game.
2. **F1** starts, **F2** stops. While running only a thin strip (hotbar) is shown at the top of the screen.
3. Left menu: Dashboard, Modes, Skills (turn skills off, choose the combo trigger/hold key), Statistics, Appearance (colour themes, files). Fonts: Sora / Inter / JetBrains Mono if installed (or put .ttf files in a `fonts` folder), otherwise Segoe UI / Consolas.
4. Everything else: `raid.ini` (gear icon). Colours: `[theme]` section (`preset=sakura|midnight|aurora|metallic|ember|author`, or `bg=`, `card=`, `acc=` ... as 6-digit hex).

## Status
- Translated UI/logs to English; code comments are still Ukrainian.
- Calibrated on one setup only (1920x1080, one account). Other colours / settings may break image matching.
- Character recommendation is not implemented yet.
- Automating Roblox games may violate the Roblox / game rules. Use at your own risk.

## Card selling (optional, on by default)
Modes > Card selling. The bot sells only cards that look like your own pictures: open the Bag > Mass sell tab, hold the mouse over the middle of a card you want to sell and press **F6** (add each card type once, also one from the left column). Then turn on Sell cards and set when and how much to sell. Use **Test mode** first: it selects the cards but does not press Sell.

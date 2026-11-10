#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir
CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"
SendMode "Event"
SetKeyDelay 30, 30
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")   ; щоб координати не з'їжджали при масштабі Windows != 100%

; ======================= НАЛАШТУВАННЯ =======================
GAME     := "ahk_exe RobloxPlayerBeta.exe"
INI      := A_ScriptDir "\raid.ini"
LOGFILE  := A_ScriptDir "\raid.log"                  ; "" = без логу

; Точка на кожному ромбі скіла (під текстом). Готовий скіл = кольоровий, перезарядка = сірий.
; Координати для вікна Roblox на весь екран 1920x1080.
SKILL_POS := Map(
    "1", [739, 1010],
    "2", [887, 1010],
    "3", [1035, 1010],
    "4", [1184, 1010],
    "5", [960, 920],
    "e", [1348, 975],
    "r", [1400, 1025],
    "z", [1456, 958],      ; ближче до центру ромба: у RDP (дрібніший інтерфейс) точка 975 вилазила за ромб
    "x", [1512, 1025])
SKILL_KEYS := ["1", "2", "3", "4", "5", "e", "r", "z", "x"]
SKILL_BAR := [730, 900, 800, 135]        ; ділянка панелі скілів (x, y, w, h) - усі точки SKILL_POS всередині (див. SkillColor)
IMGDIR    := A_ScriptDir "\img\"
TOLERANCE := 40
; Roblox scales its interface with the window, and the images only match at the size they were captured at
; (1.11 on another PC: client 1920x1009 and 1920x1057 - PLAY was "not recognised" for minutes). So the bot sizes the window itself.
; 1.11 22:00 raid at client height 1027: the "Respawn in N" countdown was not seen at all and BossAhead scored 0.13 instead of 0.00 -
; the detectors were calibrated at 1017 (taskbar 40 px), so that is the one size we use, +-2 px.
GAME_W := 1920, GAME_H := 1017
; Device port (2560x1440 at 150%): every coordinate in this file is measured on the author's 1920x1080 screen with the
; Roblox client area at (0, 23). On a bigger screen the bot keeps Roblox at exactly that place and size and treats
; this 1920x1080 rectangle as "the screen" - searches, screenshots and checks never look at the desktop around it.
; Measured 6.11 on 2560x1440 at 150%: Roblox scales its own top bar with Windows (58 px -> 87 px), and Anime Dimensions
; sizes its interface from the client height MINUS that bar - at 1920x1017 PLAY was 156x39 instead of the template's
; 164x41 and never matched. So the client is made taller by the extra bar height and moved up by the same amount:
; 1920x1046 at (0, -6) -> the game's area below the bar is (0, 81)-(1920, 1040), exactly the author's, and PLAY
; measured 162x41 (3692 white px vs 3682 in play.png). The title bar is then above the screen - that is expected.
; At 100% the extra is 0 and everything is the author's original 1920x1017 at (0, 23).
GAME_BAR_EXTRA := Round(58 * A_ScreenDPI / 96) - 58   ; 0 at 100%, 29 at 150%
GAME_H += GAME_BAR_EXTRA
SCR_W := 1920, SCR_H := 1080             ; the "screen" all coordinates are measured on
GAME_X := 0, GAME_Y := 23 - GAME_BAR_EXTRA   ; where the top left corner of the Roblox client area must be
AUTO_BTN := [738, 852]                   ; кнопка AUTO над скілами в бою (автобій гри); FightHud / AutoBox

; The scale that matters is the one of the monitor Roblox is on (6.11: the bot was started while an external 100% monitor
; was the screen, set Roblox to 1017, then the laptop's 150% screen came back - the bar and the window no longer matched).
; Roblox is per-monitor DPI aware, so the DPI of its window is exactly what its top bar is scaled by. Called every tick.
GameGeometry() {
    global GAME_BAR_EXTRA, GAME_H, GAME_Y
    if !(hwnd := WinExist(GAME))
        return
    dpi := 0
    try dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
    if dpi < 96
        return
    extra := Round(58 * dpi / 96) - 58
    if extra = GAME_BAR_EXTRA
        return
    GAME_BAR_EXTRA := extra, GAME_H := 1017 + extra, GAME_Y := 23 - extra
    Log("Roblox is on a " Round(dpi / 96 * 100) "% screen: the window will be " GAME_W "x" GAME_H " at " GAME_X "," GAME_Y)
}
ENEMIES_BOX := [1700, 780, 1920, 900]    ; де шукати напис ENEMIES LEFT (є лише в бою)
; де напис стоїть зазвичай (лівий верхній кут). Спершу шукаємо лише тут: у широкій рамці ImageSearch
; бере перший збіг, а рожева стіна (178,106,94) з допуском *80 теж "схожа" на літери - її відкидає
; BorderOk, і до справжнього напису правіше пошук так і не доходить (бот вирішує, що бою немає)
ENEMIES_HOME := [1840, 819]
; рейди на вибір: еталон напису в списку, зсув від його лівого верхнього кута до кнопки Create, назва,
; шаблон назви для OCR. Без еталона ("") рейд шукається в списку за назвою (OCR, з прокручуванням) -
; так новий рейд додається одним рядком. Порядок у вікні бота - за ключем.
RAIDS := Map(
    "halloween", ["halloween.png", [113, 95], "Halloween Raid", "i)Hallow"],
    "divine",    ["divine.png",    [107, 92], "Divine Guardian Raid", "i)Divine"],
    "shiro",     ["", 0, "Infinity Shiro Raid", "i)Shiro"],
    "onehero",   ["", 0, "One Hero 100 Raid", "i)One\s*Hero"],
    "saiya",     ["", 0, "Saiya Ultra Instinct Raid", "i)Saiya|Instinct"],
    "sungomi",   ["", 0, "Sun Gomi Raid", "i)Gomi"],
    "tiger",     ["", 0, "Tiger Raid", "i)Tiger"],
    "dual",      ["", 0, "Dual Wielder Raid", "i)Wielder"],
    "monke",     ["", 0, "Monke Raid", "i)Monke"],
    "cursed",    ["", 0, "Cursed Sage Raid", "i)Cursed|Sage"])   ; 10.11: from upstream 0.3.5
KNOCKBACK_RAIDS := " divine "            ; лише тут бос відкидає: пошук боса й поворот камери після смерті
RAID_LIST     := [1040, 340, 220, 570]   ; стовпчик назв і кнопок Create in the list рейдів (x, y, w, h)
RAID_CREATE_X := 1175                    ; x кнопки Create in the list (the queue button of the Group Finder list sits there too)
; Group Finder (from upstream 0.3.5, measured there at 100% scale - check on the 150% screen)
GF_TAB_DX     := 145                     ; Group Finder tab: centre is this far right of the Create tab centre
GF_BTN        := "i)Eas|Ea.y|E.sy|Join|Queue|Find|Enter"   ; the button under a raid name in the Group Finder list (upstream: "Easy")
; queue banner at the top: "Divine Guardian Raid / Easy / 114/12 Raid opens in 1:51", "Time: 00:06", CANCEL - seen at
; x 825-1085, y 98-148 (10.11). Not below y 150: the raid world's own "Raid opens in N Minutes" banner starts there.
; Readable only with the Join/Create window closed - the open window dims it and OCR reads nothing (10.11 15:43).
GF_BANNER     := [760, 92, 400, 58]
GF_FALLBACK   := 120                     ; s after the raid opens: still not teleported - cancel the queue and create the raid
; loadout: рейд - 1, Infinity - 2. Bag -> кнопка "Loadout N" угорі -> рядок списку. Поточний читаємо OCR з кнопки.
BAG_BTN      := [1850, 700]              ; BAG праворуч (у лобі і в світі рейду)
LOADOUT_BOX  := [880, 192, 230, 50]      ; кнопка "Loadout N ▼" у вікні Bag
LOADOUT_ROWS := [[1085, 290], [1085, 394], [1085, 497]]
BAG_CLOSE    := [1455, 219]
; Speed Raid (28.10): меню режимів -> картка SPEED RAID -> вікно з Start -> вибір персонажа -> Start.
; Кожен персонаж - раз на тиждень (використані затемнені), режим - раз на 30 min.
SPEED_LAST_MIN  := 52                    ; після цієї minилини не починаємо (рейд о :00; бос гине за 1-2 min)
SPEED_EVERY     := 30 * 60               ; с між забігами
RAID_MAX        := 15 * 60000            ; a raid still a fight after this long restarts Roblox (10.11: 5 h stuck behind a Disconnected dialog)
DC_EVERY        := 20000                 ; read the screen centre for Roblox's Disconnected dialog this often, in any state
SPEED_MAX       := 12 * 60000            ; a Speed Raid still on after this long is left (restart) - see Step
SPEED_READY_BOX := [920, 872, 200, 32]   ; "Ready to enter" / "Ready in 00:01:13" над карткою в меню режимів
MODES_CLOSE     := [1490, 200]           ; хрестик меню режимів
SPEED_TITLE_BOX := [400, 200, 520, 65]   ; заголовок вікна: "Speed Raid" / "Select a Character"
SPEED_RESET_BOX := [400, 264, 640, 40]       ; "Weekly Reset in: 8 Hours 26 Minutes" під заголовком вікна Speed Raid
SPEED_START     := [1319, 684]           ; Start у вікні Speed Raid
SPEED_GO        := [951, 847]            ; Start під списком персонажів
SPEED_CLOSE     := [1451, 235]           ; хрестик вікон Speed Raid
SPEED_GRID      := [422, 313, 1028, 462] ; список персонажів (x, y, w, h)
SPEED_COLS      := [521, 728, 935, 1143, 1350]
SPEED_BAR_X     := 1477                  ; смуга прокрутки списку (орієнтир: точний X бот шукає сам, FindBarX)
speedBarX       := SPEED_BAR_X           ; знайдений X повзунка
SPEED_ORDER     := "5 4 3 2 1"           ; порядок скілів у Speed Raid (комбо немає; 5 є не в усіх - порожній слот не готовий, пропуск)
INF_OFFSET    := [109, 95]               ; те саме для напису "Infinite Mode"
RAID_SOON     := 360                     ; s before infStop: in the lobby, go for the raid instead of starting Infinity
RAID_WINDOW   := 10                     ; перші N minилин години пробуємо зайти в рейд (якщо цієї години ще не були; пізніше рейд не створити)
RESET_EVERY   := 5000                    ; як часто робити Esc-R-Enter, коли виходимо з Infinity
CREATE_RETRY  := 5000                    ; як часто тиснути Create, поки рейд закритий
PATROL_ROUTE := ["w", "d", "s", "s", "a", "a", "w", "w", "d"]   ; маршрут патруля в Infinity (див. Patrol)
TURN_TAP  := 150                       ; скільки ms тримати клавішу руху, щоб лише розвернутись
; Еталони з самих літер (решта прозора) збігаються з будь-якою суцільною плямою кольору літер
; (білий спалах, червоний ефект). Тому після збігу дивимось на точки довкола літер: на справжній
; кнопці там фон, на плямі - той самий колір. Точки пораховані з еталонів (зсув від лівого верхнього кута).
BORDER := Map(
    "play.png", ["white", [[5,5],[53,5],[125,5],[173,5],[5,11],[44,14],[95,17],[92,20],[5,26],[65,29],[140,32],[35,38],[158,41],[5,47],[47,50],[83,50]]],
    ; raid_mode.png = letter cores of raid_mode_2.png (same box): the cards pulse, the full letters matched only at one size (3.11 23:57)
    "raid_mode.png", ["white", [[2,2],[131,2],[50,5],[5,8],[5,11],[8,14],[80,17],[119,20],[143,23],[8,29],[2,35],[2,38],[137,38],[23,41],[56,41],[89,41]]],
    ; the modes cards pulse: dimension_2 / speed_mode_2 = letter cores (2 px of every edge cut), same box as the full template (4.11)
    "speed_mode.png", ["white", [[2,2],[86,2],[170,2],[254,2],[56,5],[140,5],[224,5],[158,8],[281,11],[161,20],[257,26],[278,35],[140,41],[32,44],[116,44],[200,44]]],
    "dimension.png", ["white", [[5,8],[86,8],[152,8],[221,8],[95,11],[125,14],[188,17],[188,20],[26,26],[116,29],[140,32],[236,35],[209,38],[56,41],[128,41],[197,41]]],
    "enemies_left.png", ["red", [[12,2],[51,11],[14,12],[27,12],[40,12],[3,13],[16,13],[29,13],[42,13],[17,14],[16,16],[11,18],[16,19],[34,20],[32,22],[18,23]]])
; хрестики відомих вікон гри: Update Logs, вікно Join/Create, меню режимів (PLAY)
CLOSE_XS := [[1506, 321], [1227, 261], [1496, 201], [BAG_CLOSE[1], BAG_CLOSE[2]]]
UPDATE_LOGS_X := [1114, 13]              ; від лівого верхнього кута напису "UPDATE LOGS" до хрестика вікна
; вікно Roblox "Disconnected / Leave / Reconnect": читаємо текст у центрі екрана (OCR), бо фон під вікном будь-який
DISCONNECT_BOX := [560, 280, 800, 520]
; no bare "retry": the RETRY button of Dimension / Infinity results is inside DISCONNECT_BOX (planner 5.11)
DISCONNECT_RE  := "i)disconnect|reconnect|lost connection|error code|connection"
; браузер зі сторінкою гри на roblox.com (вкладка Servers): перезаходимо кнопкою Join першого приватного сервера
BROWSER    := "Anime Dimensions ahk_class Chrome_WidgetWin_1"
JOIN_COLOR := 0x1D3570          ; темно-синя кнопка Join (сіра Create поруч не підходить)
JOIN_BOX   := [1370, 130, 1400, 1040]   ; вузька смуга всередині кнопок Join - перший збіг згори = перша кнопка
RESTART_GAP    := 600000   ; перезапускати Roblox не частіше, ніж раз на 10 min
SERVER_LINK    := "https://www.roblox.com/share?code=8d0a163e5397b8478b09f95c5cd09c88&type=Server"   ; приватний сервер автора (raid.ini serverLink - свій)
HUNG_MAX       := 60000    ; Roblox "Not Responding" this long - restart it (10.11)
HUNG_RAID      := 20000    ; ... in a raid fight: leave at once and try a new raid while it can still be created (user, 10.11)
ROBLOX_MAX_AGE := 120      ; min: Roblox running this long is restarted in the lobby between raids (10.11: it froze after 3.5 h mid-raid)
RESTART_GAP_DC := 60000   ; а при обриві з'єднання (Error 279) - одразу, лише не частіше раз на minилину
UNKNOWN_ESC := 90000    ; якщо screen not recognised for стільки ms - раз тиснемо Esc (закрити застряглі меню)
LOG_MAX     := 20000000  ; якщо за день лог виріс понад 20 МБ - відкладаємо його в logs\ і починаємо новий
LOGDIR      := A_ScriptDir "\logs\"   ; логи минулих днів: raid_РРРРММДД.log
LOG_DAYS    := 14        ; скільки днів їх тримати
SHOTDIR     := A_ScriptDir "\shots\"   ; скріншоти, коли бій в Infinity обривається сам
SHOT_MAX    := 100       ; скільки останніх скріншотів тримати (старіші видаляються)
READY_SAT := 50       ; насиченість кольору, вище якої скіл вважається готовим (земля під порожнім слотом 5 ~45, готові скіли 55+)
; У персонажа без скіла (наприклад, без 5) слот порожній, і крізь нього видно мапу - на кольоровій землі
; він "готовий" завжди, бот тисне його кожен тік і до інших скілів черга не доходить.
; Тому скіл, що SKILL_FAILS разів поспіль не пішов на перезарядку, пропускаємо SKILL_SKIP ms.
SKILL_FAILS := 3
SKILL_SKIP  := 20000
SKILL_SKIP_SHORT := 3000                 ; для 1-4 (порожнім буває лише слот 5)
; ============================================================

running    := false
busy       := false
comboUntil := 0          ; до якого моменту спамимо скіл комбо
partySince := 0          ; коли з'явився екран PARTY (0 = не видно)
lastCreate := 0          ; коли востаннє тиснули Create на екрані налаштувань
lastFight  := 0          ; коли востаннє бачили напис ENEMIES LEFT
fightSince := 0          ; коли почався поточний бій (0 = не в бою)
infDrop    := false      ; бій в Infinity ended сам - чекаємо лобі, щоб його теж зняти
; лічильник нагород праворуч ("Rewards: 24") читаємо вбудованим OCR Windows (ocr.ps1) у фоні, раз на 5 с
REWARD_BOX := [1560, 640, 360, 120]       ; ділянка з лічильником (з запасом - в RDP інтерфейс дрібніший)
OCR_IN     := A_Temp "\adbot_ocr.png"
OCR_OUT    := A_Temp "\adbot_ocr.txt"
ocrPending := 0          ; коли запущено розпізнавання (0 = не чекаємо)
lastOcr    := 0
runTokens  := 0          ; найбільше прочитане значення лічильника за поточний забіг
runKind    := ""         ; "raid" / "infinity" - до чого додати runTokens, коли забіг скінчиться
infLootDone := true      ; токени з екрана результатів Infinity вже прочитані (скидається на Start)
raidShotDone := true     ; екран нагород рейду вже знято (скидається на Start)
lastDmg    := ""         ; останнє прочитане "Damage Until Next Reward"
dmgChanged := A_TickCount ; коли це число востаннє змінилось (= удари влучають у боса)
lastSearch := 0          ; коли востаннє повертали камеру в пошуках боса
farPress   := 0          ; Divine: коли спрацював скіл 1 чи 2 - за 2.5 с має з'явитись Combo, інакше бос далеко
searchTurns := 0         ; скільки поворотів поспіль без влучань
friendsDone := false     ; Friends Only на цьому екрані налаштувань уже перевірено
raidEndSeen := false     ; this raid fight reached its end (end screen or rewards) - a restart then must not retry the raid
raidRetryHour := ""      ; the raid hour in which a cut-off raid was already retried (once per hour)
gfQueuedAt := 0          ; Group Finder: tick of the click that put us in the queue (0 = not queued)
gfOffHour := ""          ; Group Finder failed in this raid hour (RaidHourKey) - the raid is created instead
gfMiss := 0, gfMissHour := ""   ; Group Finder: the raid name not found in its list (per raid hour)
sameReads  := 0          ; скільки свіжих читань поспіль показали ту саму шкоду (доказ, що не влучаємо)
; лише для діагностики (на runTokens і статистику не впливають); скидаються на Start
rewardRaw    := ""       ; останнє сире читання лічильника Rewards (до 3 цифр)
rewardReads  := 0        ; скільки таких читань за забіг
rewardRepeat := 0        ; останнє значення, що повторилось двічі поспіль
charIdx      := 1        ; який по порядку персонаж зараз у рейді (1 після старту й ресету, +1 на кожну смерть)
rdChanges    := 0        ; зміни портрета (смерті разом з ресетами) за забіг
rdResetNo5   := 0        ; ресетів без скіла 5 за забіг
rdResetCombo := 0        ; ресетів без Combo за забіг
lastNo5Reset := 0        ; коли востаннє ресетили персонажа без скіла 5
no5Pending   := false    ; портрет змінився після респавну, вже обробленого по відліку: скіли нового персонажа ще треба перевірити
lastLoadoutWarn := 0     ; коли востаннє писали УВАГА про рейд без loadout 1
sessStart := 0           ; tick of the bot start (for the session length in the RUN SUMMARY line)
pickFails := 0, pickFailHour := "", pickMissAt := 0   ; PickRaidByName: misses of this hour's raid (reset in Start)
sess := Map("raids", 0, "raidGems", 0, "raidTokens", 0, "speedRuns", 0, "speedGems", 0, "speedTokens", 0, "infRuns", 0, "restarts", 0)   ; підсумок поточного запуску бота
FIGHT_STICKY := 15000    ; скільки ms після цього ще битися, якщо екран не розпізнано
hudSeen    := false      ; this tick the game's AUTO button was on screen (= a fight, see FightHud)
tickNo     := 0          ; Step calls, so a check made twice in one tick counts once (LobbyPlay)
lastReset  := 0          ; коли востаннє робили Esc-R-Enter
lastTurn   := 0          ; коли востаннє розвертались
lastPatrol := A_TickCount ; коли востаннє йшли патрулем
patrolIdx  := 0          ; котрий напрямок патруля наступний
unknownSince := 0        ; відколи екран поспіль не розпізнається (0 = розпізнається)
watchStep  := 0          ; скільки разів поспіль спрацював сторож
raidWalkDue := true      ; на початку бою в рейді ще треба підійти до боса
portraitSig := ""        ; "відбиток" портрета персонажа (лівий верхній кут) - змінюється, коли персонаж гине і виходить наступний
portraitNew := ""        ; новий відбиток, що ще перевіряється на стабільність
portraitSince := 0
lastRestart := 0         ; коли востаннє перезапускали Roblox
noGameSince := 0         ; відколи вікна Roblox немає (0 = є)
wasDead    := false      ; рейд: на екрані відлік "Respawn in N" (персонаж мертвий)
lastRespawnAt := 0       ; коли відлік скінчився (новий персонаж уже на точці появи)
camYaw     := 0          ; на скільки px миші бот повернув камеру від респавну (щоб знати, де знайшовся бос)
afterRespawn := false    ; після респавну Combo ще не було - перший Combo запишемо в лог з кутом
comboSeen  := false      ; у цьому рейді вже бачили напис "N Combo!" (значить, його розпізнавання працює)
lastCombo  := 0          ; коли востаннє бачили "Combo!" (= удари влучають)
lastComboCheck := 0
learnLeft  := 0          ; скільки ще навчальних знімків зробити в цьому рейді (raid.ini [raid] learnShots=1)
lastLearn  := 0
walkAt     := 0          ; коли після респавну йти вперед до боса (0 = не треба)
; точки всередині ромба-портрета (підходять і для звичайного екрана, і для дрібнішого RDP-інтерфейсу)
PORTRAIT_PTS := [[74, 115], [86, 127], [98, 139], [86, 108], [86, 146], [74, 139], [98, 115]]
lockUntil  := 0          ; до якого моменту персонаж не може рухатись (анімація скілів 4, 5)
turnIdx    := 0          ; котрий напрямок наступний, якщо ворогів не видно
skillFails := Map()      ; скіл -> скільки разів поспіль натиснули без перезарядки
skillSkip  := Map()      ; скіл -> до якого моменту його пропускаємо
castAt     := Map()      ; скіл -> коли пішов на перезарядку (поки знову не готовий)
castExact  := Map()      ; скіл -> castAt точний (натискання бачили), а не оцінка
skillCd    := Map()      ; скіл -> вивчена перезарядка, ms (найменша виміряна)
spreadUsed := Map()      ; Infinity: коли востаннє спрацював кожен скіл зі spread (черга - хто довше чекав)
spreadTry  := 0          ; Infinity: скільки разів поспіль помічник зі spread "не вийшов" (іконка не посіріла)
spreadNext := 0          ; коли можна тиснути наступний скіл зі spread
lastCast   := 0          ; коли востаннє основний скіл справді спрацював (персонаж ще в анімації)
curLoadout := 0          ; який loadout зараз стоїть (0 = невідомо, перевіримо в Bag)
loadoutChecked := false  ; loadout вже прочитано після Start (коли перемикання вимкнене)
OCR2_IN    := A_Temp "\adbot_ocr2.png"   ; окремі файли для синхронного OCR (асинхронний OCR нагород не заважає)
OCR2_OUT   := A_Temp "\adbot_ocr2.txt"
OCRQ       := A_Temp "\adbot_ocrq\"     ; черга запитів до OCR-сервера (див. OcrCall)
ocrPid     := 0                          ; процес OCR-сервера (0 = не запущений)

; ---------------- налаштування з raid.ini (змінюються у вікні й зберігаються одразу) ----------------
cfg := Map(
    "order",      IniRead(INI, "raid", "order", "5 4 3 2 1 e r z x"),   ; спершу баффи (5, 4), потім комбо 3 -> 1
    "comboKey",   IniRead(INI, "raid", "comboKey", "3"),
    "comboSpam",  IniRead(INI, "raid", "comboSpam", "1"),
    "comboMs",    IniRead(INI, "raid", "comboMs", "3000"),
    "combo",      IniRead(INI, "raid", "combo", "1"),
    "m1",         IniRead(INI, "raid", "m1", "1"),
    "turn",       IniRead(INI, "raid", "turn", "1"),          ; розвертатись до ворогів в Infinity
    "turnMs",     IniRead(INI, "raid", "turnMs", "2500"),
    "patrol",     IniRead(INI, "raid", "patrol", "1"),        ; час від часу йти вперед в Infinity
    "patrolMs",   IniRead(INI, "raid", "patrolMs", "9000"),   ; як часто
    "patrolWalk", IniRead(INI, "raid", "patrolWalk", "1000"), ; скільки ms іти
    "raidWalk",   IniRead(INI, "raid", "raidWalk", "3000"), ; на початку рейду пройти вперед до боса, ms
    "lockSkills", IniRead(INI, "raid", "lockSkills", "4 5"),  ; скіли, після яких персонаж якийсь час не рухається
    "lockMs",     IniRead(INI, "raid", "lockMs", "2500"),     ; скільки після них не ходити й не розвертатись
    "assists",    IniRead(INI, "raid", "assists", "e r z x"), ; помічники: тиснуться одразу, як готові
    "spread",     IniRead(INI, "raid", "spread", "5 4 e r x"),  ; Infinity: великі AOE по черзі, з паузою, поки попередній діє (решта - як готові)
    "spreadMs",   IniRead(INI, "raid", "spreadMs", "7000"),       ; скільки діє скіл зі spread - до того не тиснемо наступний, ms
    "spreadDur",  IniRead(INI, "raid", "spreadDur", "5:10"),      ; винятки "клавіша:секунди" (5 діє 10 s left)
    "infStand",   IniRead(INI, "raid", "infStand", "1"),          ; Infinity: стояти на місці (без патруля й розворотів)
    "infBossBurst", IniRead(INI, "raid", "infBossBurst", "0"),    ; Infinity: бос minилі - великі AOE одразу, без пауз
    "infSmall",   IniRead(INI, "raid", "infSmall", "3 z"),        ; Infinity: малі AOE - лише коли великі (spread) на перезарядці і none не діє
    "seekDash",   IniRead(INI, "raid", "seekDash", "1"),          ; Divine: відкинуло -> вперед з Q 3 рази через 0.5 с
    "respawnDash", IniRead(INI, "raid", "respawnDash", "1"),      ; Divine: після респавну до боса теж ривками Q
    "resetThird", IniRead(INI, "raid", "resetThird", "0"),        ; рейд: вийшов 3-й персонаж - ресет (навіть зі скілом 5)
    "resetNo5",   IniRead(INI, "raid", "resetNo5", "0"),        ; рейд: вийшов персонаж без скіла 5 - ресет (Esc-R-Enter)
    ; 29.10 00:00: з ухиленням 3 смерті (як і без), а пауз без влучань 184 с замість ~110 - ухилення вимкнене,
    ; і очі разом з ним (без ухилення їм нема що робити, а в бою з босом вони беруть ~0.8 ядра)
    "raidName",   IniRead(INI, "raid", "raidName", "divine"), ; який рейд створювати: halloween / divine
    "respawnWait", IniRead(INI, "raid", "respawnWait", "3000"), ; після зміни персонажа (смерть) чекати респавн, ms
    ; (29.10 пробував 6000: о 02:02 поворот після респавну вийшов не туди, і бот за 6 с забіг до краю арени -
    ; 161 с без ударів. З 3000 така помилка коштує менше, тож лишаємо 3000)
    "respawnWalk", IniRead(INI, "raid", "respawnWalk", "3000"), ; потім іти вперед до боса, ms (0 = не йти)
    "respawnTurn", IniRead(INI, "raid", "respawnTurn", "95"),   ; якщо бос не прямо попереду - повернути камеру, градусів (+ вправо)
    "bossAuto",   IniRead(INI, "raid", "bossAuto", "1"),         ; Raid / Speed Raid: the game's Auto fights, the bot only keeps it on (0 = old fight logic)
    "speedWalk",  IniRead(INI, "raid", "speedWalk", "2000"),    ; Speed Raid: walk to the boss at the start, ms
    "respawnWalkOther", IniRead(INI, "raid", "respawnWalkOther", "0"),   ; raids without knockback: walk after respawn, ms
    "noComboReset", IniRead(INI, "raid", "noComboReset", "12000"),       ; Divine: no Combo this long -> reset, ms (0 = off)
    "farWalk",    IniRead(INI, "raid", "farWalk", "2500"),      ; Divine: після 1/2 немає Combo -> вперед стільки ms with Q x3 (0 = вимк.)
    "soloRaid",   IniRead(INI, "raid", "soloRaid", "1"),        ; рейд: вмикати Friends Only (соло, без інших гравців)
    "raidEntry",  IniRead(INI, "raid", "raidEntry", "create"),  ; create = create the raid; gf = queue through Group Finder (Create as fallback)
    "loadouts",   IniRead(INI, "raid", "loadouts", "0"),     ; міняти loadout: рейд - 1, Infinity - 2, Speed Raid - 3
    "speed",      IniRead(INI, "raid", "speed", "1"),          ; Speed Raid раз на 30 min (пріоритет: рейд > speed > Infinity)
    "seekAfter",  IniRead(INI, "raid", "seekAfter", "5000"),    ; скільки ms без влучань, щоб почати пошук
    "camSens",    IniRead(INI, "raid", "camSens", "36"),          ; чутливість миші в грі x100 (0.36 -> 36): від неї залежить, на скільки px вести мишу для повороту камери
    "autoAfter",  IniRead(INI, "raid", "autoAfter", "0"),         ; рейд: стільки ms без Combo -> Auto (за замовчуванням вимкнено; детектор Combo бачить і AOE здалека)
    "infFullAuto", IniRead(INI, "raid", "infFullAuto", "1"),      ; Infinity: the game's Auto plays the whole run, the bot only keeps it on (0 = the bot presses skills)
    "infAuto",    IniRead(INI, "raid", "infAuto", "15000"),       ; Infinity: число ENEMIES LEFT не змінюється стільки ms -> натиснути Auto (через 5 с ще раз, вимкнути); 0 = вимк.
    "seekWalk",   IniRead(INI, "raid", "seekWalk", "3000"),     ; після повороту пройти вперед, ms
    "skillsOff",  IniRead(INI, "raid", "skillsOff", ""),      ; вимкнені скіли через пробіл
    "interval",   IniRead(INI, "raid", "interval", "120"),
    "startDelay", IniRead(INI, "raid", "startDelay", "10"),
    "startBonus", IniRead(INI, "raid", "startBonus", "110"),    ; PARTY: бонус команди з якого % стартувати, не чекаючи startDelay
    "raid",       IniRead(INI, "raid", "raid", "1"),
    "infinity",   IniRead(INI, "raid", "infinity", "1"),
    "titan",      IniRead(INI, "raid", "titan", "0"),            ; Giant (Titan) Dimension instead of Infinity, see titan.ahk
    "titanDiff",  IniRead(INI, "raid", "titanDiff", "Nightmare"),  ; Easy, Hard or Nightmare
    "titanDim",   IniRead(INI, "raid", "titanDim", "Giant"),     ; which dimension: Giant or Curse (routes in titan.ahk)
    "titanHard",  IniRead(INI, "raid", "titanHard", "1"),        ; Hardcore toggle of the dimension: 3 lives, +1 reward
    "sfx",        IniRead(INI, "raid", "sfx", "1"),                 ; короткі звуки кнопок
    "infStop",    IniRead(INI, "raid", "infStop", "57:30"),      ; о котрій (хв:с) виходити з Infinity
    "createFrom", IniRead(INI, "raid", "createFrom", "59:30"),    ; з котрої (хв:с) тиснути Create у рейді
    "fightOnly",  "0")                                            ; тест: лише скіли (не зберігається)
; що бот востаннє створив ("raid" / "infinity") і в яку годину був рейд - щоб пам'ятати після перезапуску
lastEntered := IniRead(INI, "state", "lastEntered", "")
if !InStr(" raid infinity speed titan ", " " lastEntered " ")      ; an old raid.ini may hold the removed "dungeon"
    lastEntered := ""
speedDue := IniRead(INI, "state", "speedDue", "")
try DateDiff(speedDue, A_Now, "Seconds")                  ; a corrupt value would throw on every tick
catch
    speedDue := ""         ; коли Speed Raid знову доступний (yyyyMMddHHmmss)
speedFails := 0                                           ; невдалих спроб Speed Raid поспіль
SPEED_WEEK_MAX := 50                                      ; runs per week with special rewards
raidDoneKey := IniRead(INI, "state", "raidDoneKey", "")
; Raid clock: second of the real hour at which THIS server's raid opens (0 = on the hour, as the bot was written for).
; 6.11: the raid timer runs per server - at 13:35 the menu said "Raid Opens in: 24:37" (opens at :00), but after a Roblox
; restart at 19:10 the fresh private server opened its raid at :45 ("Raid opens in 35 Minutes" at 20:10), and the bot pressed
; Create from 59:30 to :10 every hour for nothing. So the bot reads the game's countdown (RaidClockLearn) and the whole hourly
; plan (infStop, createFrom, the 10 min window, Speed Raid cut-off, "raid done this hour") runs on the shifted hour.
raidOfs := Mod(IntOr0(IniRead(INI, "state", "raidOfs", "0")), 3600)
raidCand := -1           ; a raid time read once, waiting for a second reading that agrees (RaidClockLearn)

if A_Args.Length && A_Args[1] = "fight"                 ; тест бою: лише скіли
    cfg["fightOnly"] := "1"

; ------------------------- Interface (see ui.ahk) -------------------------
#Include ui.ahk
#Include auto_boss.ahk
#Include rewards.ahk
#Include titan.ahk

; "start" or "fight" - start without F1. Not right here: the rest of this file (screen points such as AUTO_BTN once lived
; below) must run first - 7.11 00:17 a "start" launch called "lobby" 2 s in, mid-fight, the first ticks ran on a half-set bot
if A_Args.Length
    SetTimer(Start, -2000)

F1:: Start()
F2:: Stop()
F3:: RestartBot()

SkillOn(key) => true                       ; v0.3: усі скіли завжди активні (skillsOff ігнорується)

RaidTitle() => RAIDS.Has(cfg["raidName"]) ? RAIDS[cfg["raidName"]][3] : "raid"

; чи відкидає бос обраного рейду (тоді потрібні пошук боса і поворот камери після смерті)
Knockback() => lastEntered = "raid" && InStr(KNOCKBACK_RAIDS, " " cfg["raidName"] " ")
; Group Finder is the way in this raid hour (it falls back to Create for the rest of the hour after a failure)
GfActive() => cfg["raidEntry"] = "gf" && gfOffHour != RaidHourKey()
; Friends Only when creating: only in Create mode. In Group Finder mode a created raid is the fallback - open to others
SoloNow() => cfg["soloRaid"] = "1" && cfg["raidEntry"] != "gf"

; бій з одним босом: рейд або Speed Raid (підхід до боса на старті, Combo, респавн)
BossFight() => lastEntered = "raid" || lastEntered = "speed"

; лічильники в raid.ini [stats]: за сьогодні (обнуляються з новою датою) і за весь час
; a corrupt value in raid.ini must never stop the bot: anything that is not an integer counts as 0
IntOr0(v) => IsInteger(Trim(v)) ? Integer(Trim(v)) : 0

Stat(name, n := 1) {
    today := FormatTime(, "yyyyMMdd")
    if IniRead(INI, "stats", "day", "") != today {
        IniWrite today, INI, "stats", "day"
        for k in ["infRuns", "raids", "deaths", "raidGems", "raidTokens", "restarts", "speedRuns", "speedGems", "speedTokens"]
            IniWrite 0, INI, "stats", k
    }
    IniWrite IntOr0(IniRead(INI, "stats", name, "0")) + n, INI, "stats", name
    IniWrite IntOr0(IniRead(INI, "stats", name "Total", "0")) + n, INI, "stats", name "Total"
    if sess.Has(name)
        sess[name] += n
}

StatDay(name) => IniRead(INI, "stats", "day", "") = FormatTime(, "yyyyMMdd") ? IniRead(INI, "stats", name, "0") : "0"


; Читання лічильника нагород: знімаємо ділянку у файл і запускаємо ocr.ps1 у фоні (не чекаючи),
; результат забираємо на наступних тіках. Беремо найбільше правдоподібне значення за забіг.
PollRewards() {
    global ocrPending, lastOcr, runTokens, runKind, lastDmg, dmgChanged, searchTurns, sameReads
    global rewardRaw, rewardReads, rewardRepeat, tokFromScreen
    if runKind = ""
        runKind := lastEntered
    if tokFromScreen {                                   ; tokens already read from the results: a late answer must not set them again
        if ocrPending {
            try FileDelete OCR_OUT
            ocrPending := 0
        }
        return
    }
    if ocrPending {
        if FileExist(OCR_OUT) {
            txt := ""
            try txt := FileRead(OCR_OUT, "UTF-8")
            try FileDelete OCR_OUT
            ocrPending := 0
            if RegExMatch(txt, "i)(?:rewards?|tokens?)\W{0,3}(\d[\d,]*)", &m) {
                v := Integer(StrReplace(m[1], ","))
                ; лічильник росте поступово: відкидаємо явні помилки розпізнавання (стрибок понад 300)
                if v > runTokens && v - runTokens <= 300
                    runTokens := v
            }
            ; діагностика: лише рядок "Rewards N" (до 3 цифр, далі не '.', ',' і не літера); рядки з "Next Reward" відкидаємо окремо
            for ln in StrSplit(txt, "`n", "`r") {
                if RegExMatch(ln, "i)n[e3]xt|until|damage")
                    continue
                if RegExMatch(ln, "i)(?<![a-z])rewards\W{0,3}(\d{1,3})(?![\d.,a-z]|[ \t]+[kmbt]\b)", &r) {
                    if r[1] = rewardRaw
                        rewardRepeat := Integer(r[1])
                    rewardRaw := r[1], rewardReads++
                    break
                }
            }
            ; "Damage Until Next Reward: 225.89M" - якщо це число змінюється, удари влучають у боса
            if RegExMatch(txt, "i)reward:?\s*\R?\s*([\d.,]+\s*[kmbt]?)\s*$", &d) {
                if d[1] != lastDmg
                    lastDmg := d[1], dmgChanged := A_TickCount, searchTurns := 0, sameReads := 0
                else
                    sameReads++
            }
        } else if A_TickCount - ocrPending > 20000 {
            ocrPending := 0                           ; розпізнавання зависло - пробуємо знову
            OcrServerKill()
        }
        return
    }
    if A_TickCount - lastOcr < 1500                     ; у рейді частіше: швидше помічаємо, що не влучаємо
        return
    lastOcr := A_TickCount
    try FileDelete OCR_OUT
    b := REWARD_BOX
    if SaveRegion(OCR_IN, b[1], b[2], b[3], b[4]) = 0 {
        OcrCall(OCR_IN, OCR_OUT, "", false)
        ocrPending := A_TickCount
    }
}

; Які нагороди читати з екрана результатів: [іконка, лічильник у статистиці, назва в лозі]
LOOT := Map(
    "raid", [["raid_gem_icon.png", "raidGems", "gems"], ["raid_token_icon.png", "raidTokens", "tokens"]])

; Екран результатів ("REWARDS"): потрібні нагороди - наприкінці списку. Шукаємо кожну іконку, прокручуючи
; список донизу, і читаємо білу цифру під нею (ocr.ps1 -White лишає тільки білий текст).
ReadLoot(kind) {
    global runTokens, tokFromScreen
    SetStatus("results: reading rewards")
    ParkMouse()
    Sleep 1500                                           ; іконки нагород з'являються по черзі - даємо домалюватись
    todo := []
    for it in LOOT[kind]
        if FileExist(IMGDIR it[1])
            todo.Push(it)
    Loop 4 {                                             ; кілька спроб: іконка ще анімувалась або число не прочиталось
        if A_Index > 1
            Sleep 1200
        i := todo.Length
        while i >= 1 {
            it := todo[i]
            if FindImg(it[1], &tx, &ty, 1200, 300, 1620, 480, "*110") {   ; іконки нагород мерехтять - допуск більший
                n := ReadLootNumber(tx - 18, ty + 62)   ; число - під іконкою зліва
                if n > 0 {
                    Stat(it[2], n)
                    Log(RaidTitle() ": " it[3] " " n)
                    if it[2] = "raidTokens"
                        runTokens := 0, tokFromScreen := true   ; токени рейду вже пораховані з екрана - лічильник з бою не додаємо
                    todo.RemoveAt(i)
                }
            }
            i--
        }
        if !todo.Length
            break
    }
    for it in todo
        Log("  " it[3] ": could not read (icon not found or number not recognised)")
}

; біла цифра під іконкою нагороди (92x30 px від лівого нижнього краю іконки)
; Білий поріг 215; не прочиталось (число трохи сіре чи світиться, 28.10 15:08) - ще раз з м'якшим порогом 175.
; Окремі файли OCR2: асинхронне читання лічильника (OCR_IN/OCR_OUT) може бути ще в черзі.
ReadLootNumber(x, y) {
    if SaveRegion(OCR2_IN, x, y, 92, 32) != 0
        return 0
    for opts in ["-White", "-White -Thresh 175"] {
        OcrCall(OCR2_IN, OCR2_OUT, opts)
        txt := ""
        try txt := FileRead(OCR2_OUT, "UTF-8")
        try FileDelete OCR2_OUT
        if RegExMatch(txt, "\d[\d,]*", &m) && (n := Integer(StrReplace(m[0], ","))) > 0 && n < 1000000 {
            if A_Index > 1
                Log("  number read with a softer threshold: " n)
            return n
        }
    }
    return 0
}

; поворот камери: права кнопка миші затиснута, мишу ведемо на px по горизонталі (мінус - вліво)
RotateCam(px) {
    global camYaw
    camYaw += px
    MouseMove SCR_W // 2, SCR_H // 2 + 150, 0
    Send "{RButton down}"
    Sleep 60
    n := Max(1, Abs(px) // 60)                           ; дрібними кроками - Roblox краще сприймає
    Loop n {
        DllCall("mouse_event", "uint", 1, "int", px // n, "int", 0, "uint", 0, "ptr", 0)   ; відносний рух
        Sleep 15
    }
    Sleep 60
    Send "{RButton up}"
}

; Friends Only вимкнено: ліва частина перемикача - світлий "повзунок", права - темно-червона доріжка.
; (x, y) - лівий верхній кут кнопки Create; зсуви підходять і для звичайного, і для RDP-масштабу.
FriendsOff(x, y) {
    k := Integer(PixelGetColor(x - 124, y + 25)), t := Integer(PixelGetColor(x - 58, y + 25))
    kr := k >> 16 & 0xFF, kg := k >> 8 & 0xFF, kb := k & 0xFF
    tr := t >> 16 & 0xFF, tg := t >> 8 & 0xFF, tb := t & 0xFF
    return kr > 200 && kg > 110 && kb > 110 && tr > 150 && tg < 110 && tb < 110
}

; Вперед ривками: тримаючи W, Q 3 рази через 0.5 с, решту з ms - звичайним кроком
DashWalk(ms) {
    t0 := A_TickCount
    Send "{w down}"
    Loop 3 {
        if A_Index > 1
            Sleep 500
        Send "{q}"
    }
    Sleep Max(0, ms - (A_TickCount - t0))
    Send "{w up}"
}

; "відбиток" числа під ENEMIES LEFT: кількість, межі й центр червоних пікселів цифри (мерехтіння фону не міняє його);
; "" - число не видно. Число змінилось (вбили ворога) -> відбиток інший.
EnemiesSig() {
    b := ENEMIES_NUM, w := b[3], h := b[4]
    px := GrabPixels(b[1], b[2], w, h)
    n := 0, x0 := w, x1 := -1, sx := 0, sy := 0
    Loop h {
        y := A_Index - 1
        Loop w {
            x := A_Index - 1
            c := NumGet(px, (y * w + x) * 4, "uint")
            if (c >> 16 & 0xFF) > 180 && (c >> 8 & 0xFF) < 130 {
                n++, x0 := Min(x0, x), x1 := Max(x1, x), sx += x, sy += y
            }
        }
    }
    return n < 30 ? "" : (n // 4) "," x0 "," x1 "," (sx // n) "," (sy // n)
}
; Скільки px вести мишу на 45° камери. У грі 0.36 (RDP автора) це 205 px; кут пропорційний чутливості, тож px = 205 * 36 / чутливість x100:
; 0.05 (основний ПК) - 1476 px, 0.52 (тестувальник) - 142 px.
CamPx() => Min(8000, Max(20, Round(205 * 36 / Max(1, Num("camSens", 36)))))

; Напис "N Combo!" (рожеві літери з чорним контуром) - лише поки удари влучають. Точки літер і контуру взяті
; зі знімка 26.10 19:02 (лівий верхній кут слова ~(400, 540)); напис "підстрибує", тому пробуємо зсуви ±12 px.
; На 30 знімках рейду: є Combo - збіг 0.32..1.0, немає - 0 (огляд арени, Infinity - теж 0). Поріг 0.25.
COMBO_ORG := [400, 540]
; AUTO_BTN is defined at the top (with the other screen points): FightHud needs it from the first tick
; ENEMIES LEFT: число червоне на темно-червоному, OCR його не читає - порівнюємо відбиток цифри (EnemiesSig)
ENEMIES_NUM := [1842, 846, 48, 36]
lastAuto := 0, autoOffAt := 0                              ; коли тиснули Auto / коли його вимкнути вдруге
COMBO_L := "105,6 100,11 118,12 110,13 108,14 95,15 106,15 49,16 89,16 105,16 43,17 85,17 99,17 110,17 74,18 86,18 96,18 107,18 120,18 66,19 77,19 88,19 98,19 109,19 38,20 56,20 67,20 77,20 88,20 99,20 108,20 32,21 45,21 57,21 69,21 84,21 95,21 102,21 116,21 35,22 46,22 57,22 68,22 79,22 86,22 97,22 104,22 36,23 53,23 65,23 75,23 82,23 9,24 36,24 48,24 64,24 74,24 81,24 21,25 32,25 44,25 55,25 67,25 7,26 25,26 35,26 46,26 57,26 8,27 27,27 34,27 46,27 8,28 15,28 26,28 33,28 7,29 14,29 25,29 9,30"
COMBO_D := "73,0 104,0 83,1 112,1 23,2 93,2 21,3 69,3 21,4 59,4 123,4 44,5 114,5 32,6 104,6 30,7 125,7 83,8 17,9 113,9 42,10 12,11 72,11 14,12 81,12 17,13 92,13 20,14 103,14 16,15 102,15 12,16 72,16 121,16 50,17 115,17 30,18 111,18 17,19 101,19 31,20 122,20 62,21 15,22 92,22 13,23 91,23 119,23 50,24 102,24 121,24 41,25 91,25 110,25 16,26 74,26 93,26 116,26 58,27 77,27 96,27 40,28 63,28 82,28 37,29 56,29 75,29 23,30 42,30 61,30 3,31 30,31 49,31 5,32 24,32 43,32 9,33 28,33 10,34 29,34 19,35"
ComboVisible() {
    static L := ParsePts(COMBO_L), D := ParsePts(COMBO_D)
    w := 160, h := 50
    px := GrabPixels(COMBO_ORG[1] - 14, COMBO_ORG[2] - 6, w, h)
    dy := 0
    while dy <= 10 {                                     ; зсуви -6..+4 від еталона (з запасом ±2 px)
        dx := 2
        while dx <= 26 {                                 ; -12..+12
            if PtsHit(px, w, L, dx, dy, true) && PtsHit(px, w, D, dx, dy, false)
                return true
            dx += 2
        }
        dy += 2
    }
    return false
}

; чи хоча б чверть точок мають колір літер (letter) або контуру; рахуємо з раннім виходом
PtsHit(px, w, pts, ox, oy, letter) {
    need := pts.Length // 4, miss := pts.Length - need
    for p in pts {
        c := NumGet(px, ((p[2] + oy) * w + p[1] + ox) * 4, "uint")
        r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
        if letter ? (r > 190 && g < 110 && b < 120) : (r < 60 && g < 40 && b < 50) {
            if --need <= 0
                return true
        } else if --miss < 0
            return false
    }
    return false
}

ParsePts(str) {
    pts := []
    for s in StrSplit(str, " ")
        pts.Push(StrSplit(s, ","))
    return pts
}

; ділянка екрана -> пікселі в пам'яті (BGRA, рядки зверху вниз, w*4 байти на рядок) - у рази швидше за PixelGetColor
GrabPixels(sx, sy, w, h) {
    sdc := DllCall("GetDC", "ptr", 0, "ptr")
    mdc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    hbm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", w, "int", h, "ptr")
    old := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
    DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", sdc, "int", sx, "int", sy, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", mdc, "ptr", old)
    bi := Buffer(40, 0)                                   ; BITMAPINFOHEADER, висота з мінусом = рядки зверху вниз
    NumPut("uint", 40, "int", w, "int", -h, "ushort", 1, "ushort", 32, bi)
    px := Buffer(w * h * 4)
    DllCall("GetDIBits", "ptr", mdc, "ptr", hbm, "uint", 0, "uint", h, "ptr", px, "ptr", bi, "uint", 0)
    DllCall("DeleteObject", "ptr", hbm)
    DllCall("DeleteDC", "ptr", mdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
    return px
}

; Бос прямо попереду? Ядро боса (вертикальна золота "капсула") з точки респавну видно рівно по центру
; під смугою HP: x ~955, y 215..265, а обабіч нього - темне. Перевіряємо центри 900..1025: золота в
; смузі 50 px навколо центру > 25%, а в смугах 35..60 px обабіч < 8%. Знімки 26.10: вид з респавну на боса - 0.32,
; ядро зблизька - 1.0, камера повз боса - збігів немає.
; Поріг середини 0.08 (був 0.25): 28-29.10 після респавну "не попереду" було завжди рівно 0.00 (12 разів),
; "попереду" - 0.39..0.63, а 29.10 02:02 бос був попереду з 0.14 - бот повернув камеру і 161 с шукав боса.
; Зблизька ядро широке і заходить на бічні смуги: 29.10 04:08 0.51/0.08 - бос попереду, а бот відвернувся.
; Тож при сильній середині (>= 0.3) бічні смуги можуть бути до чверті від неї.
BossAhead(&score, &cx) {
    x0 := 840, y0 := 215, w := 250, h := 50             ; центри 900..1025 +- 60 px
    px := GrabPixels(x0, y0, w, h)
    col := []                                            ; скільки "золотих" пікселів у кожному стовпчику
    Loop w {
        x := A_Index - 1, n := 0
        Loop h {
            c := NumGet(px, ((A_Index - 1) * w + x) * 4, "uint")
            r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
            if r > 150 && g > 60 && g < 210 && b < 70 && r - g > 40
                n++
        }
        col.Push(n)
    }
    Sum(a, b) {                                          ; частка золота в стовпчиках [a, b) (from x0)
        t := 0
        Loop b - a
            t += col[a + A_Index]
        return t / ((b - a) * h)
    }
    best := -1, score := 0, cx := 0, ok := false
    c := 900
    while c <= 1025 {
        k := c - x0
        mid := Sum(k - 25, k + 25), side := Max(Sum(k - 60, k - 35), Sum(k + 35, k + 60))
        if mid - 2 * side > best
            best := mid - 2 * side, score := Round(mid, 2) "/" Round(side, 2), cx := c
                , ok := mid > 0.08 && (side < 0.08 || mid >= 0.3 && side <= mid / 4)
        c += 5
    }
    ; the core is a solid upright capsule: some column is gold over most of the strip. 3.11 23:00 the orange hex wall
    ; behind the arena gave 0.15/0.04 (> 0.08) with at most 13 of 50 px per column, the core 39..44 - the bot walked off sideways
    k := cx - x0, top := 0
    Loop 50
        top := Max(top, col[k - 25 + A_Index])
    score .= " col " top
    return ok && top >= 20
}

; забіг скінчився: додаємо прочитані нагороди до сум
FlushRun() {
    global runTokens, runKind, tokFromScreen
    if runKind = "raid" && runTokens > 0 && !tokFromScreen        ; "Rewards: N" counts reward drops, not tokens: log only
        Log("raid: in-fight Rewards counter " runTokens " (not counted as tokens)")
    runTokens := 0, runKind := "", tokFromScreen := false
}

; The setup checks, used by the "Setup check" screen (deep := true also tests the OCR language) and logged at every start.
; Returns [{name, state: "ok"|"warn"|"fail", fix}]. "fail" = the bot cannot work like this; "warn" = may cause trouble.
SetupChecks(deep := false) {
    r := []
    Add := (name, state, fix := "") => r.Push({name: name, state: state, fix: fix})
    ; device port: any screen at least 1920x1080 works - Roblox is kept at 1920x1017 in the top left corner
    if A_ScreenWidth >= SCR_W && A_ScreenHeight >= SCR_H
        Add("Screen resolution " A_ScreenWidth "x" A_ScreenHeight " (game area " SCR_W "x" SCR_H ")", "ok")
    else
        Add("Screen resolution is " A_ScreenWidth "x" A_ScreenHeight, "fail", "Right-click the desktop > Display settings > Display resolution: at least 1920 x 1080.")
    ; Windows scale does not matter: the bot works in real pixels and Roblox draws in real pixels
    Add("Windows display scale " Round(A_ScreenDPI / 96 * 100) "%", "ok")
    MonitorGetWorkArea(MonitorGetPrimary(), &wl, &wt, &wr, &wb)
    if wl = 0 && wt = 0 && wr = A_ScreenWidth && wb >= GAME_Y + GAME_H
        Add("Taskbar at the bottom, below the game area", "ok")
    else
        Add("Taskbar is not at the bottom (or covers the game area)", "warn", "Right-click the taskbar > Taskbar settings > Taskbar location on screen: Bottom.")
    if FileExist(A_ScriptDir "\ocr.ps1") && FileExist(IMGDIR "start.png")
        Add("Bot files (ocr.ps1, img folder)", "ok")
    else
        Add("Bot files are missing", "fail", "Unpack the whole archive into one folder: ocr.ps1 and the img folder must lie next to RaidBot.ahk.")
    if deep {
        ; the real ocr.ps1 on a sample image: the same way the bot reads text, so the result is what the bot will get
        out := A_Temp "\adbot_ocr_test.txt", text := ""
        try FileDelete(out)
        try RunWait('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' A_ScriptDir '\ocr.ps1" "' IMGDIR 'start.png" "' out '" -Scale 1', , "Hide")
        try text := FileRead(out)
        if text != "" && !InStr(text, "ERROR")
            Add("Text recognition (OCR) works", "ok")
        else if text = ""
            Add("Text recognition (OCR) gave no result", "warn", "Windows Settings > Time & Language > Language & region: add English (United States), restart the PC.")
        else
            Add("Text recognition (OCR) failed", "fail", "Windows Settings > Time & Language > Language & region: add English (United States), restart the PC.")
    }
    if hwnd := WinExist(GAME) {
        GameGeometry()
        WinGetClientPos &cx, &cy, &cw, &ch, GAME
        Log("  setup: Roblox client area " cw "x" ch " at " cx "," cy)
        if WinGetMinMax(GAME) = -1
            Add("Roblox is minimised", "fail", "Click the Roblox icon on the taskbar to open it, then maximise the window.")
        else if !(WinGetStyle(GAME) & 0xC00000)
            Add("Roblox is in fullscreen (F11)", "fail", "Press F11 in Roblox to leave fullscreen, then double-click the window title bar to maximise it.")
        else if GameSizeOk(cw, ch) && GamePosOk(cx, cy)
            Add("Roblox window size is right (" cw "x" ch " at " cx "," cy ")", "ok")
        else if FitGameWindow()                           ; the bot sets the size itself
            Add("Roblox window was set to " GAME_W "x" GAME_H, "ok")
        else
            Add("Roblox window is " cw "x" ch, "fail", "Close Roblox, open it again and press Check again. The bot sets the window size itself.")
        tid := DllCall("GetWindowThreadProcessId", "ptr", hwnd, "uint*", 0, "uint")
        hkl := DllCall("GetKeyboardLayout", "uint", tid, "ptr") & 0xFFFF
        Log("  setup: keyboard layout in Roblox 0x" Format("{:04X}", hkl))
        if (hkl & 0x3FF) != 9 {                           ; ask Roblox to switch to English (US) itself
            PostMessage(0x50, 0, 0x04090409, , "ahk_id " hwnd)
            Sleep 300
            hkl := DllCall("GetKeyboardLayout", "uint", tid, "ptr") & 0xFFFF
            Log("  setup: layout after switch request 0x" Format("{:04X}", hkl))
        }
        if (hkl & 0x3FF) = 9
            Add("Keyboard layout in Roblox is English", "ok")
        else
            Add("Roblox keyboard layout is " Format("{:04X}", hkl), "warn", "Click inside Roblox, press Win+Space until the language shows ENG, then press Check again.")
    } else
        Add("Roblox is not running", "warn", "Start Roblox and open the game, wait in the lobby, then press Check again.")
    return r
}

; every start: the same checks go to the log (nothing here stops the bot)
StartupChecks() {
    for it in SetupChecks()
        if it.state != "ok"
            Log("WARNING: " it.name (it.fix != "" ? " - " it.fix : ""))
}

Start() {
    global running, fightSince, infDrop, curLoadout, loadoutChecked, pickFails, pickFailHour, pickMissAt, sessStart
    pickFails := 0, pickFailHour := "", pickMissAt := 0
    if !setupDone {
        Log("Run the Setup check first (press Check in the window)")
        return
    }
    loadoutChecked := false
    fightSince := 0, infDrop := false                 ; бій до зупинки не рахуємо обривом
    curLoadout := 0                                      ; поки бот стояв, loadout могли змінити вручну
    for k in sess                                         ; новий запуск - новий підсумок
        sess[k] := 0
    sessStart := A_TickCount
    Log("start v" APP_VERSION ", order: " cfg["order"] (cfg["skillsOff"] != "" ? ", disabled: " cfg["skillsOff"] : "")
        . ", loadouts=" cfg["loadouts"] ", raid=" cfg["raid"] ", infinity=" cfg["infinity"] ", speed=" cfg["speed"]
        . ", raidEntry=" cfg["raidEntry"] ", soloRaid=" cfg["soloRaid"] ", resetNo5=" cfg["resetNo5"] ", infStop=" cfg["infStop"] ", bossAuto=" cfg["bossAuto"])
    StartupChecks()
    PlaceId()                                             ; поки гра запущена - запам'ятовуємо, куди перезаходити
    OcrServer()                                         ; OCR-сервер вантажиться заздалегідь
    if !TitanHud()                                      ; a Shift Lock left on holds the cursor: menus could not be clicked
        TitanLock(false)
    running := true
    PaintRun()
    Layout()
    ; поки бот працює, Windows не засинає і не гасить/не блокує екран (інакше бот бачить чорний екран)
    DllCall("SetThreadExecutionState", "uint", 0x80000003)
    SetTimer(Tick, Max(50, Num("interval", 120)))
}

Stop() {
    global running, sessStart
    was := running
    running := false
    SetTimer(Tick, 0)
    ReleaseKeys()
    FlushRun()
    if was
        Log(SessLogLine())
    sessStart := 0
    DllCall("SetThreadExecutionState", "uint", 0x80000000)
    try WinSetAlwaysOnTop 0, GAME                         ; Tick keeps Roblox on top only while the bot runs
    PaintRun()
    SetStatus("stopped")
    Layout()
}

; one line with this run's totals (the sess counters are reset in Start)
SessLogLine() {
    m := sessStart ? (A_TickCount - sessStart) // 60000 : 0
    return "RUN SUMMARY: raid " sess["raids"] " (gems " sess["raidGems"] ", tokens " sess["raidTokens"] ")"
        . ", speed " sess["speedRuns"] " (gems " sess["speedGems"] ", tokens " sess["speedTokens"] ")"
        . ", Infinity " sess["infRuns"] ", Roblox restarts " sess["restarts"]
        . ", session " (m // 60) "h " Format("{:02}", Mod(m, 60)) "m"
}

; відпускаємо клавіші руху (на випадок зупинки посеред патруля чи повороту)
ReleaseKeys() {
    for k in ["w", "a", "s", "d"]
        if GetKeyState(k)
            Send "{" k " up}"
}

; будь-яка помилка - у лог, без вікна помилки (вікно зупинило б бота до ранку)
OnError(LogError)
LogError(e, mode) {
    Log("ERROR: " e.Message " (" e.What ", line " e.Line ")")
    return 1
}

OnExit(BeforeExit)
BeforeExit(*) {
    ReleaseKeys()
    OcrServerKill()
    DllCall("SetThreadExecutionState", "uint", 0x80000000)
    return 0                                 ; 0 = дозволити вихід (ненульове значення скасувало б вихід)
}

; kind != "" - дрібниця бою (скіл, розворот, патруль...): в Infinity не пишемо в лог по рядку,
; лише рахуємо (див. FightCount); у рейді й Speed Raid пишемо все, як і раніше
SetStatus(text, kind := "") {
    global lastStatus
    quiet := kind != "" && lastEntered = "infinity"
    if quiet
        FightCount(kind)
    if lastStatus = text
        return
    lastStatus := text
    UiSetStatus(text)
    MiniUpdate()
    if !quiet
        Log(text)
}

; Hotbar (the thin strip at the top of the screen while the bot runs): status, time to the hourly raid,
; Speed Raid state and this run's counters. Refreshed on every status change and twice a second.
MiniUpdate() {
    left := 3600 - SecOfHour()
    sLeft := speedDue ? DateDiff(speedDue, A_Now, "Seconds") : 0
    s := (running ? "●  " : "○  ") lastStatus
    if running {
        if cfg["raid"] = "1"
            s .= "   │   Raid " Format("{:02}:{:02}", left // 60, Mod(left, 60))
        if cfg["speed"] = "1"
            s .= "   │   Speed " (sLeft <= 0 ? "ready" : Format("{:02}:{:02}", Min(sLeft, 5999) // 60, Mod(sLeft, 60)))
    }
    s .= "   │   F2 stop   │   F3 restart"
    if miniTxt.Text != s
        miniTxt.Text := s
}

FightLog(kind, text) {
    if lastEntered = "infinity"
        FightCount(kind)
    else
        Log(text)
}

; Infinity: дрібниці бою - раз на minилину одним рядком ("скіл 3 12, розворот 9, ...").
; Без kind - записати накопичене одразу (кінець бою, вихід з Infinity).
FightCount(kind := "") {
    static n := Map(), since := 0
    if kind != "" {
        n[kind] := n.Get(kind, 0) + 1
        if !since
            since := A_TickCount
        if A_TickCount - since < 60000
            return
    }
    s := ""
    for k, v in n
        s .= ", " k " " v
    if s != ""
        Log("Infinity in " (A_TickCount - since) // 1000 " s: " SubStr(s, 3))
    n := Map(), since := 0
}

; Лог за кожен день окремо: щойно настає новий день, учорашній raid.log переїжджає в logs\raid_РРРРММДД.log
; (старші за LOG_DAYS днів видаляються). Якщо за день лог виріс понад LOG_MAX - теж відкладаємо його в logs.
Log(text) {
    static lines := 0, day := ""
    if LOGFILE = ""
        return
    today := FormatTime(, "yyyyMMdd")
    if day != today || Mod(++lines, 2000) = 0 {
        try {
            if FileExist(LOGFILE) {
                fileDay := SubStr(FileGetTime(LOGFILE), 1, 8)
                if fileDay != today || FileGetSize(LOGFILE) > LOG_MAX {
                    DirCreate LOGDIR
                    FileMove LOGFILE, LOGDIR "raid_" fileDay (fileDay = today ? "_" FormatTime(, "HHmm") : "") ".log", 1
                    Loop Files LOGDIR "raid_*.log"
                        if DateDiff(A_Now, A_LoopFileTimeModified, "Days") > LOG_DAYS
                            FileDelete A_LoopFileFullPath
                }
            }
        }
        day := today
    }
    UiLogPush(text)
    try FileAppend FormatTime(, "dd.MM HH:mm:ss") "." Format("{:03}", A_MSec) "  " text "`n", LOGFILE, "UTF-8"
}

WinTitleSafe() {
    try return WinGetProcessName("A") " - " SubStr(WinGetTitle("A"), 1, 60)
    return "?"
}

; ----------------------- Головний цикл -----------------------
Tick() {
    global busy, noGameSince
    if !running || busy
        return
    busy := true
    try {
        if !WinExist(GAME) {
            if !noGameSince
                noGameSince := A_TickCount
            SetStatus("Roblox not found")
            if A_TickCount - noGameSince > 60000            ; гра закрилась/впала - запускаємо знову
                RestartRoblox("no Roblox window for 60 s")
            return
        }
        noGameSince := 0
        ; Roblox "Not Responding" (10.11, user): Windows puts a grey ghost copy of the window (dwm.exe) on top, so Roblox is
        ; "not the active window" below and the bot would wait there forever. Hung for HUNG_MAX - restart it. Short freezes
        ; (loading, teleports) are shorter than that.
        static hungSince := 0
        if DllCall("IsHungAppWindow", "ptr", WinExist(GAME)) {
            ; in a raid fight the raid is lost anyway - leave fast, a new one may still be created (RestartRoblox)
            lim := lastEntered = "raid" && fightSince ? HUNG_RAID : HUNG_MAX
            if !hungSince {
                hungSince := A_TickCount
                Log("Roblox is not responding - restarting it if this lasts " lim // 1000 " s")
            }
            SetStatus("Roblox is not responding (" (A_TickCount - hungSince) // 1000 " s)")
            if A_TickCount - hungSince > lim && RestartRoblox("not responding for " lim // 1000 " s", , 60000)
                hungSince := 0
            return
        }
        if hungSince {
            Log("  Roblox responds again after " (A_TickCount - hungSince) // 1000 " s")
            hungSince := 0
        }
        GameGeometry()                                    ; the monitor (and its scale) may have changed
        ; 7.11 11:40: the user typed in VS Code over the game - Windows does not let a background program take the foreground,
        ; the bot read VS Code as "screen not recognised", pressed Esc and clicked "window crosses" into it for 12 min,
        ; restarted Roblox and missed the 11:45 raid. Roblox now stays on top while the bot runs (Stop clears it), and
        ; when it still is not the active window the bot waits: keys would go to the other program.
        try if !(WinGetExStyle(GAME) & 0x8)
            WinSetAlwaysOnTop 1, GAME
        if !WinActive(GAME) {
            WinActivate GAME
            Sleep 300
        }
        if !WinActive(GAME) {
            try DllCall("SwitchToThisWindow", "ptr", WinExist(GAME), "int", 1)
            Sleep 300
        }
        static coveredLog := 0
        if !WinActive(GAME) {
            global unknownSince
            if unknownSince                               ; the wait is not "screen not recognised" (no Esc, no restart)
                unknownSince := A_TickCount
            SetStatus("Roblox is not the active window - waiting (another program has the focus)")
            if A_TickCount - coveredLog > 60000 {
                coveredLog := A_TickCount
                Log("WARNING: Roblox is not the active window (focus: " WinTitleSafe() ") - waiting")
            }
            return
        }
        ; усі координати розраховані на Roblox на весь основний монітор; якщо вікно переїхало
        ; (наприклад, після вимкнення/ввімкнення монітора) - повертаємо його
        WinGetClientPos &cx, &cy, &cw, &ch, GAME
        static fixTries := 0
        if GameSizeOk(cw, ch)
            fixTries := 0
        else if fixTries < 6 {                                ; the same size as the images were captured at
            fixTries++
            SetStatus("fixing the Roblox window size (" cw "x" ch " -> " GAME_W "x" GAME_H ")")
            FixGameWindow()
            return
        } else if fixTries = 6 {
            fixTries++
            Log("WARNING: the Roblox window could not be set to " GAME_W "x" GAME_H " (now " cw "x" ch ") - screens may not be recognised")
        }
        ; device port: the screen is wider than the game, so check the client position itself (x = 0, y = 23)
        if cx != GAME_X || Abs(cy - GAME_Y) > 2 || cw != GAME_W {
            static badPos := 0, badSince := 0
            if A_TickCount - badSince > 60000
                badPos := 0
            badPos++, badSince := A_TickCount
            if badPos > 4 {                                   ; taskbar on the left/right or a second monitor: moving does not help
                Log("ERROR: the Roblox window cannot be placed at " GAME_X "," GAME_Y " (client " cx "," cy ", w=" cw "). Put the taskbar at the bottom.")
                Stop()
                MsgBox "Roblox cannot be placed correctly (client " cx "," cy ", width=" cw ").`n`nPut the Windows taskbar at the bottom of the screen and start the bot again.", "AD Bot", "Icon! T30"
                return
            }
            SetStatus("moving Roblox back to the main monitor")
            FitGameWindow()
            return
        }
        Step()
    } finally {
        busy := false
    }
}

; "хв:с" -> секунди від початку години (якщо введено щось не те - def)
MinSec(text, def := 0) {
    try {
        p := StrSplit(Trim(text), ":")
        return Integer(p[1]) * 60 + (p.Length > 1 && p[2] != "" ? Integer(p[2]) : 0)
    } catch
        return def
}

; seconds since this server's raid opened (0..3599) - "the raid hour"; with raidOfs 0 it is the real minute:second
SecOfHour() {
    return Mod(Integer(A_Min) * 60 + Integer(A_Sec) - raidOfs + 3600, 3600)
}

RaidMin() => SecOfHour() // 60

; which raid hour it is (yyyyMMddHH of the moment this raid hour began) - for "raid done this hour"
RaidHourKey() => FormatTime(DateAdd(A_Now, -raidOfs, "Seconds"), "yyyyMMddHH")

; The game's raid countdown -> raidOfs. Modes menu card: "Raid Opens in: 24:37"; raid world banner: "Raid opens in
; 35 Minutes 0 Second". Returns true if a countdown was read. A change of more than 30 s is logged and saved.
RaidClockLearn(txt) {
    global raidOfs, raidCand
    txt := StrReplace(StrReplace(txt, "`n", " "), "`r", " ")
    txt := RegExReplace(txt, "i)\bo(?=\s*(sec|min))", "0")          ; OCR reads "0 Second" as "O Second"
    if RegExMatch(txt, "i)opens?\W*in\W*(\d{1,2})\s*[:.]\s*(\d\d)", &m)
        left := Integer(m[1]) * 60 + Integer(m[2])
    else if RegExMatch(txt, "i)opens?\W*in\W*(\d{1,2})\s*min\w*\W*(\d{1,2})\s*sec", &m)
        left := Integer(m[1]) * 60 + Integer(m[2])
    else if RegExMatch(txt, "i)opens?\W*in\W*(\d{1,2})\s*min", &m)
        left := Integer(m[1]) * 60
    else
        return false
    if left >= 3600
        return false
    ofs := Mod(Integer(A_Min) * 60 + Integer(A_Sec) + left, 3600)
    Near(a, b) => Min(Abs(a - b), 3600 - Abs(a - b)) <= 30
    if Near(ofs, raidOfs) {
        raidCand := -1                                    ; the time in use is confirmed - a stray earlier reading is dropped
        return true
    }
    ; a new time only when two readings agree: 6.11 22:03 OCR read "Raid Opens in: 41:28" as "4:28", the bot took the raid
    ; for 22:08, left Infinity for it and the next read said :45 again
    static candAt := 0
    if raidCand < 0 || !Near(ofs, raidCand) || A_TickCount - candAt > 20 * 60000 {
        raidCand := ofs, candAt := A_TickCount
        Log("  raid clock: read '" Trim(SubStr(txt, 1, 60)) "' (opens at :" Format("{:02}:{:02}", ofs // 60, Mod(ofs, 60)) ") - waiting for a second reading")
        return true
    }
    raidCand := -1
    if true {
        Log("raid clock: this server's raid opens at :" Format("{:02}:{:02}", ofs // 60, Mod(ofs, 60))
            . " (read '" Trim(SubStr(txt, 1, 60)) "', was :" Format("{:02}:{:02}", raidOfs // 60, Mod(raidOfs, 60)) ")")
        raidOfs := ofs
        IniWrite raidOfs, INI, "state", "raidOfs"
    }
    return true
}

; Куди зараз треба (пріоритет: рейд > Speed Raid > Infinity):
; "raid" (перші minилини години, якщо цієї години рейду ще не було, і з infStop - підготовка),
; "speed" (Speed Raid знову доступний - раз на 30 min), "infinity" (решта часу) або "none" (режими вимкнені - лише бій).
Target() {
    static last := ""
    t := PickTarget(&why)
    if t != last {                                        ; every change of the goal is explained in the log
        last := t
        Log("goal: " t " (" why ")")
    }
    return t
}

PickTarget(&why) {
    raidOn := cfg["raid"] = "1"
    infOn := cfg["infinity"] = "1"
    if raidOn && SecOfHour() >= MinSec(cfg["infStop"], 57 * 60 + 30) {
        why := "the hour is ending, going for the raid"
        return "raid"
    }
    ; 6.11 22:03: the raid clock said the raid opens in 4:28 and the bot still went into Infinity, only to leave it again at
    ; infStop. Outside a fight with the raid this close, go to the raid world and wait at its Create screen instead.
    if raidOn && !fightSince && MinSec(cfg["infStop"], 57 * 60 + 30) - SecOfHour() <= RAID_SOON
            && MinSec(cfg["infStop"], 57 * 60 + 30) - SecOfHour() > 0 {
        why := "the raid opens in under " (RAID_SOON + 150) // 60 " min - not starting Infinity"
        return "raid"
    }
    if raidOn && RaidMin() < RAID_WINDOW && raidDoneKey != RaidHourKey() {
        why := "no raid yet this hour"
        return "raid"
    }
    if SpeedReady() {
        why := "Speed Raid is available"
        return "speed"
    }
    speedWhy := cfg["speed"] != "1" ? "Speed Raid is off"
        : speedDue && DateDiff(A_Now, speedDue, "Seconds") < 0 ? "next Speed Raid at " FormatTime(speedDue, "HH:mm")
        : "Speed Raid is not started after minute " SPEED_LAST_MIN " while the raid is on"
    if cfg["titan"] = "1" {
        why := speedWhy
        return "titan"
    }
    if infOn {
        why := speedWhy
        return "infinity"
    }
    why := speedWhy
    return raidOn ? "raid" : "none"
}

; Speed Raid можна починати: увімкнено, минуло 30 min від минулого, і до рейду встигнемо
; (забіг до 10 min + вхід - після 46-ї minилини не починаємо, якщо рейд увімкнено)
SpeedReady() {
    if cfg["speed"] != "1" || (speedDue && DateDiff(A_Now, speedDue, "Seconds") < 0)
        return false
    return cfg["raid"] != "1" || RaidMin() < SPEED_LAST_MIN
}

; Speed Raid став доступний, а ми в Infinity: вихід з Infinity і повернення коштують ~2.5 min бою.
; Якщо в лобі й так скоро будемо - чекаємо й робимо Speed Raid тоді:
;  - рейд за <= 10 min (з Infinity вийдемо о infStop, Speed Raid - одразу після рейду);
;  - забіг Infinity іде вже 30+ min (сам закінчується на ~38-41 min).
; Довше ніж на 12 min Speed Raid не відкладаємо.
SpeedWait() {
    static noted := "-"
    if speedDue && DateDiff(A_Now, speedDue, "Seconds") > 12 * 60
        return false
    if cfg["raid"] = "1" && MinSec(cfg["infStop"], 57 * 60 + 30) - SecOfHour() <= 10 * 60
        why := "raid is near - will do it when in the lobby anyway"
    else if fightSince && A_TickCount - fightSince > 30 * 60000
        why := "Infinity ends soon by itself - will do it in the lobby"
    else
        return false
    if noted != speedDue
        noted := speedDue, Log("Speed Raid is available, but " why)
    return true
}

SetEntered(what) {
    global lastEntered
    lastEntered := what
    IniWrite what, INI, "state", "lastEntered"
}

; Кожен тік визначаємо, що на екрані, і робимо один відповідний крок.
Step() {
    global partySince, lastCreate, lastFight, lastReset, raidDoneKey, unknownSince, watchStep, raidWalkDue, patrolIdx, friendsDone
    global fightSince, infDrop, portraitSig, walkAt, infLootDone, lastDmg, dmgChanged, searchTurns, raidShotDone, sameReads, learnLeft, comboSeen, lastCombo, lastComboCheck, camYaw, afterRespawn, wasDead, lastRespawnAt, farPress, lastSearch, lastAuto, autoOffAt
    global autoOffAt, charIdx, rewardRaw, rewardReads, rewardRepeat, rdChanges, rdResetNo5, rdResetCombo, lastNo5Reset, lastLoadoutWarn, no5Pending, raidEndSeen
    prevUnknown := unknownSince              ; скидається на кожному тіку, де екран розпізнано
    unknownSince := 0
    if !prevUnknown
        watchStep := 0
    if cfg["fightOnly"] = "1" {
        Fight()
        return
    }
    goal := Target()
    ; 10.11 01:53-07:13: Roblox showed "Disconnected (Error Code: 285)" for 5 h after a raid. The blurred screen behind it kept
    ; the raid a "fight" (ENEMIES LEFT / Auto matches), so the bossAuto check (no sign for 10 s) never ran and the raid has no
    ; time limit. The dialog is now read every DC_EVERY in any state; two hits in a row restart Roblox.
    static lastDcCheck := 0, dcHits := 0
    if A_TickCount - lastDcCheck >= DC_EVERY {
        lastDcCheck := A_TickCount
        dcHits := DisconnectDialog() ? dcHits + 1 : 0
        if dcHits >= 2 {
            dcHits := 0
            Screenshot("disconnected")
            RestartRoblox("connection lost (Disconnected dialog)", , RESTART_GAP_DC)
            return
        }
    }
    b := ENEMIES_BOX
    ; бій: шукаємо лише червоні літери ENEMIES LEFT (фон ромба напівпрозорий, тому він "прозорий" у картинці)
    ; в еталоні лише насичено-червоні пікселі літер: краї літер змішуються з фоном і різняться від мапи до мапи
    h := ENEMIES_HOME
    inFight := FindImg("enemies_left.png", &x, &y, h[1] - 12, h[2] - 12, h[1] + 66, h[2] + 38, "*80 *TransFF00FF")
        || FindImg("enemies_left.png", &x, &y, b[1], b[2], b[3], b[4], "*80 *TransFF00FF")
    ; the game's AUTO button is a fight too (see FightHud): ENEMIES LEFT misses on bright floors, and with it on screen
    ; a PLAY match is a white AOE flash, not the lobby
    global hudSeen := FightHud(), tickNo
    tickNo++
    inFight := inFight || hudSeen
    ; виходимо з Infinity на рейд, а ми вже в лобі (видно PLAY): це не бій. 29.10 22:00 і 23:00 бот після LEAVE
    ; у лобі 12 min тиснув Esc-R-Enter - на меню Esc хибно "бачив" ENEMIES LEFT, "липкий" бій не закінчувався
    ; 4.11 22:34: start in the lobby with goal infinity and lastEntered=infinity from the ini: the pink lobby matched ENEMIES LEFT,
    ; the bot "fought" in the lobby. But 4.11 22:51 play.png also matched the bright floor at Infinity wave 40, so without the
    ; goal condition PLAY counts only in the first 20 s of a "fight" (a lobby false fight is caught on its first ticks).
    if !hudSeen && (lastEntered = "infinity" && goal != "infinity" || cfg["bossAuto"] = "1" && BossFight()
            || !fightSince || A_TickCount - fightSince < 20000)
            && (inFight || A_TickCount - lastFight < FIGHT_STICKY)
            && LobbyPlay() {
        if inFight || A_TickCount - lastFight < FIGHT_STICKY - 1000 {
            SetStatus("lobby (PLAY visible) - not a fight, not pressing Esc-R-Enter")
            Log("  lobby check: hudSeen " hudSeen ", FightHud now " FightHud() " (" FightHudWhy() ")")
        }
        inFight := false
        lastFight := A_TickCount - FIGHT_STICKY
    }
    inFight := AutoRunOn(inFight)                         ; bossAuto: the raid / Speed Raid run stays one fight
    ; Titan: no AUTO button in Dimensions, the whole run is played by titan.ahk. PLAY on screen = a false "fight" in the lobby
    if lastEntered = "titan" {
        global titanArmed
        if titanArmed && A_TickCount - titanArmed > 90000
            titanArmed := 0
        if (inFight || TitanHud()) && !FindImg("play.png", &px, &py, 1500, 800, 1920, 1060) {
            TitanRun(titanArmed != 0)
            return
        }
    }
    if inFight {
        partySince := 0
        lastFight := A_TickCount
        if !fightSince {
            fightSince := A_TickCount
            AutoReset()                                       ; Auto is off again after a teleport / new run
            raidEndSeen := false                              ; a new fight: its end not seen yet
        }
        infDrop := false
        if lastEntered = "raid" && raidDoneKey != RaidHourKey() {
            raidDoneKey := RaidHourKey()                          ; цієї години рейд уже є
            IniWrite raidDoneKey, INI, "state", "raidDoneKey"
        }
    }
    ; екран результатів Infinity ("REWARDS"): токени - останній пункт списку, читаємо їх один раз
    ; inFight can still be true here: the dim "ENEMIES LEFT" HUD shows under the results (1.11 22:08: gems and tokens were
    ; not read, the bot took 83 tokens from the in-fight counter instead of 274), so the results are searched during the fight too, once a second
    static lastRes := 0
    if !infLootDone && lastEntered = "raid" && A_TickCount - lastRes >= (inFight ? 1000 : 0) {
        lastRes := A_TickCount
        if FindImg("raid_results.png", &x, &y, 300, 120, 900, 260) {
            infLootDone := true
            ReadLoot("raid")
            return
        }
    }
    ; ще до "липкого" бою (FIGHT_STICKY 15 s left): гра сама телепортує саме через ~15 с, тож пізніше LEAVE вже не встигнути
    ; і навіть коли ENEMIES LEFT "видно" (тьмяний HUD під екраном результатів): інакше Esc-R-Enter виходу на рейд
    ; тисне Enter = RETRY (29.10 21:57: після LEAVE новий забіг, 12 min у Infinity і пропущений рейд 22:00)
    if lastEntered = "infinity" && LeaveInfinity()
        return
    if inFight || A_TickCount - lastFight < FIGHT_STICKY {
        if inFight && BossFight() {
            if lastEntered = "raid"
                PollRewards()                        ; лічильник праворуч: нагороди й шкода по босу
            ; "N Combo!" зліва від центру - миттєвий знак, що удари влучають (OCR шкоди повільний, 5+ с на читання)
            if A_TickCount - lastComboCheck >= 500 && cfg["bossAuto"] != "1" {
                lastComboCheck := A_TickCount
                if ComboVisible() {
                    if A_TickCount - lastCombo > 3000
                        Log("  Combo: hitting" (lastCombo ? " (none for " (A_TickCount - lastCombo) // 1000 " s left)" : ""))
                    if afterRespawn {                            ; для підбору respawnTurn: де після респавну був бос
                        afterRespawn := false
                        Log("  boss found after respawn: camera " Round(camYaw / CamPx() * 45) "° from respawn")
                    }
                    comboSeen := true, lastCombo := A_TickCount
                    dmgChanged := A_TickCount, searchTurns := 0, sameReads := 0
                }
            }
        }
        ; рейд скінчився (ENEMIES LEFT зник на 3+ s left) - знімаємо екран нагород у папку shots
        if !inFight && !raidShotDone && BossFight() && fightSince && A_TickCount - lastFight > 3000 {
            raidShotDone := true, raidEndSeen := true
            Screenshot(lastEntered = "speed" ? "speed_end" : "raid_rewards")
        }
        ; bossAuto: the game's Auto fights; no skills, combo, walks, turns, resets - only keep Auto on and wait for the end
        if cfg["bossAuto"] = "1" && BossFight() {
            static lastCard := 0, lastDc := 0
            if A_TickCount - autoSeen > 10000 && A_TickCount - lastDc >= 10000 {    ; no sign of the run for 10 s: lost connection?
                lastDc := A_TickCount
                if Disconnected() {
                    RestartRoblox("connection lost", , RESTART_GAP_DC)
                    return
                }
            }
            if !infLootDone && A_TickCount - lastCard >= 1000 {       ; REWARDS panel: gems and tokens
                lastCard := A_TickCount
                if RewardCards(lastEntered) {
                    infLootDone := true, raidEndSeen := true
                    return
                }
            }
            if !raidShotDone && autoBtnAt && A_TickCount - autoBtnAt > 3000 {    ; the Auto button is gone: the end screen is up
                raidShotDone := true, raidEndSeen := true
                Screenshot(lastEntered = "speed" ? "speed_end" : "raid_end")
            }
            ; 6.11 22:12: a Speed Raid boss (Shadow Yomiichi, 584M HP) ran 20+ min - the character kept dying - and would have
            ; run through the raid; a run has no exit but closing the game
            if lastEntered = "speed" && fightSince && (A_TickCount - fightSince > SPEED_MAX
                    || goal = "raid" && A_TickCount - fightSince > 180000) {          ; the hourly raid is worth more
                Log("Speed Raid: still fighting after " (A_TickCount - fightSince) // 60000 " min"
                    . (goal = "raid" ? " and the raid is due" : "") " - leaving it (restart)")
                Screenshot("speed_long")
                RestartRoblox("Speed Raid takes too long", , 60000)
                return
            }
            if lastEntered = "raid" && fightSince && A_TickCount - fightSince > RAID_MAX {
                Log("raid: still a fight after " (A_TickCount - fightSince) // 60000 " min - restarting Roblox")
                Screenshot("raid_long")
                RestartRoblox("raid takes too long", , 60000)
                return
            }
            if inFight && RespawnScreen()
                SetStatus("death: waiting for respawn (Auto stays on)")
            else {
                if A_TickCount - fightSince > 2000
                    AutoEnsure()
                SetStatus((lastEntered = "speed" ? "Speed Raid" : "raid") ": Auto, waiting for the end")
            }
            return
        }
        ; час іти в рейд (чи в Speed Raid), а ми в Infinity -> скидаємо персонажів (Esc, R, Enter), поки данж не закінчиться
        if lastEntered = "infinity" && (goal = "raid" || goal = "titan" || goal = "speed" && !SpeedWait()) {
            FightCount()
            if A_TickCount - lastReset >= RESET_EVERY {
                SetStatus("leaving Infinity (" (goal = "speed" ? "Speed Raid" : "raid") "): Esc-R-Enter")
                ; Roblox пропускає надто короткі натискання, поки меню анімується -> тримаємо кожну клавішу довше
                HoldKey("Esc")
                Sleep 1000
                HoldKey("r")
                Sleep 800
                HoldKey("Enter")
                lastReset := A_TickCount
            }
            return
        }
        ; Infinity on the game's Auto (infFullAuto, user 7.11: "pressing Auto more than the bot's own moves"): no skills,
        ; the game's Auto walks and fights; the bot only turns Auto back on when it is seen off (after a death or a wave)
        if cfg["infFullAuto"] = "1" && lastEntered = "infinity" {
            autoOffAt := 0                                  ; never the old "Auto for 5 s, then off"
            if inFight && A_TickCount - fightSince > 2000
                AutoEnsure()
            SetStatus("Infinity: the game's Auto plays")
            return
        }
        ; Відлік "Respawn in N": персонаж мертвий - Combo немає, але це не промах. Камеру не крутимо, скілів не тиснемо.
        ; Відлік скінчився -> новий персонаж на точці появи: одразу перевірка напрямку й підхід до боса.
        if BossFight() {
            if RespawnScreen() {
                if !wasDead {
                    Log("death: Respawn countdown")
                    charIdx++                       ; 02.11 06:05: дві смерті за 5 с дали одну зміну портрета - 3-й персонаж бився без ресету
                }
                wasDead := true, dmgChanged := A_TickCount, sameReads := 0, walkAt := 0
                SetStatus("death: waiting for respawn, not pressing skills")
                return
            }
            if wasDead {
                wasDead := false, lastRespawnAt := A_TickCount
                walkAt := A_TickCount + 1500                ; дати персонажу з'явитись
            }
        }
        ; смерть: гра виводить наступного персонажа на точку появи -> після респавну знову йдемо до боса
        if inFight
            CheckRespawn()
        ; 31.10 16:03: перевірка після відліку Respawn йде через 1.5 с, а панель скілів ще від попереднього персонажа
        ; (скіл 5 є) - третій без скіла 5 не ресетився і бився до кінця. Портрет змінюється через ~4 с - тоді перевіряємо ще раз.
        if no5Pending {
            no5Pending := false
            if inFight && lastEntered = "raid" && NeedReset() {
                ResetNo5()
                return
            }
        }
        ; після смерті скілів не тиснемо, поки не повернулись до боса й не підійшли (інакше б'ємо в порожнечу)
        if inFight && walkAt && A_TickCount < walkAt {
            SetStatus("death: waiting for respawn, not pressing skills")
            return
        }
        if inFight && walkAt && A_TickCount >= walkAt {
            walkAt := 0
            ; третій персонаж (без скіла 5) у рейді б'є слабко - одразу ресет (Esc-R-Enter), знову вийде перший
            ; (кожен ресет коштує ~23 с без шкоди: відлік смерті + шлях до боса; resetNo5=0 - не ресетити)
            if lastEntered = "raid" && NeedReset() {   ; у Speed Raid персонаж один - ресет не допоможе
                ResetNo5()
                return
            }
            ; Divine (відкидає) - поворот і respawnWalk. Інші: гра після смерті розвертає камеру від боса,
            ; тож не ходимо - стоїмо й б'ємо скілами (28.10, Shiro)
            ms := Min(Knockback() ? Num("respawnWalk", 3000) : Num("respawnWalkOther", 0), 10000)
            if ms > 0 {
                camYaw := 0, afterRespawn := true
                ; після респавну камера або дивиться прямо на боса, або ~95° лівіше (26.10) - перевіряємо по ядру боса
                if !Knockback() {                           ; інші рейди: бос прямо перед точкою появи
                    deg := 0
                } else if BossAhead(&sc, &cx) {
                    deg := 0
                    Log("  boss straight ahead after respawn (core x=" cx ", " sc ")")
                } else if deg := Num("respawnTurn", 95) {
                    Log("  boss not ahead after respawn (best " sc ") - turning camera")
                    RotateCam(Round(deg / 45 * CamPx()))
                }
                SetStatus("after respawn: camera " (deg > 0 ? "+" : "") deg "°, walking to the boss " ms " ms")
                ; Divine: від точки появи до боса далеко - звичайним кроком перший Combo був лише через ~11 с
                ; після респавну (29.10 00:00), тож теж ривками Q, як після відкидання
                if Knockback() && cfg["respawnDash"] = "1"
                    DashWalk(ms)
                else
                    HoldKey("w", ms)
                return
            }
        }
        ; бос у рейді стоїть за кілька метрів попереду -> на початку бою підходимо до нього
        if inFight && raidWalkDue && BossFight() {
            raidWalkDue := false
            ms := Min(lastEntered = "speed" ? Num("speedWalk", 2000) : Num("raidWalk", 3000), 10000)
            if ms > 0 {
                SetStatus((lastEntered = "speed" ? "Speed Raid" : "raid") ": walking to the boss " ms " ms")
                HoldKey("w", ms)
            }
            if lastEntered = "speed" {                       ; Speed Raid: одразу після підходу - уся серія
                SpeedOpener()
                return
            }
            return
        }
        ; Divine: скіл 1 чи 2 спрацював, а Combo за 2.5 с так і не з'явився (до 0.8 с після натискання - ще
        ; старий напис) -> відкинуло від боса: вперед з Q x3 (користувач, 29.10). Коротко (farWalk 1500): 3 с з ривками
        ; проносили крізь боса (29.10 16:04). Давніше 4 с (смерть) - не рахуємо.
        if inFight && farPress && A_TickCount - farPress >= 2500 {
            p := farPress, farPress := 0
            if lastEntered = "raid" && Knockback() && (ms := Num("farWalk", 1500)) > 0 && A_TickCount - p < 4000
                    && lastCombo < p + 800 && A_TickCount - lastSearch > 3000 {
                SetStatus("skill 1/2 without Combo - knocked back, forward with Q")
                Log("  skill 1/2 without Combo - forward " ms " ms with Q x3")
                DashWalk(Min(ms, 10000))
                lastSearch := A_TickCount
                return
            }
        }
        ; Auto (the game's own auto-battle): no Combo for autoAfter ms (knocked away from the boss) -> press AUTO,
        ; 5 s later press it again to turn it off. The screenshot shows where the boss was.
        if inFight && autoOffAt && A_TickCount >= autoOffAt {
            autoOffAt := 0
            Log("  Auto: off")
            ClickXY(AUTO_BTN[1], AUTO_BTN[2])
            ParkMouse()
        }
        if inFight && lastEntered = "raid" && Knockback() && comboSeen && !autoOffAt && (ms := Num("autoAfter", 20000)) > 0
                && A_TickCount - Max(lastCombo, fightSince, lastRespawnAt) > ms && A_TickCount - lastAuto > ms {
            lastAuto := A_TickCount, autoOffAt := A_TickCount + 5000
            Log("  no Combo for " (A_TickCount - Max(lastCombo, fightSince, lastRespawnAt)) // 1000 " s - Auto on for 5 s")
            SetStatus("no Combo - Auto for 5 s")
            Screenshot("no_combo")
            ClickXY(AUTO_BTN[1], AUTO_BTN[2])
            ParkMouse()
            return
        }
        ; Infinity: a far enemy stands still, so the ENEMIES LEFT number does not change for infAuto ms (any count) ->
        ; press AUTO (the game walks to the enemies), 5 s later press AUTO again to turn it off.
        static lastEn := 0, sameSince := 0, lastSig := ""
        if !inFight || lastEntered != "infinity"
            sameSince := 0, lastSig := ""
        else if (ms := Num("infAuto", 15000)) > 0 && !autoOffAt {
            if A_TickCount - lastEn >= 1000 {
                lastEn := A_TickCount
                sig := EnemiesSig()
                if sig != "" && sig != lastSig
                    lastSig := sig, sameSince := A_TickCount
            }
            if sameSince && A_TickCount - sameSince >= ms && A_TickCount - lastAuto > ms {
                lastAuto := A_TickCount, autoOffAt := A_TickCount + 5000, sameSince := 0, lastSig := ""
                Log("  Infinity: ENEMIES LEFT did not change for " ms // 1000 " s - Auto on for 5 s")
                SetStatus("enemies are not dying - Auto for 5 s")
                ClickXY(AUTO_BTN[1], AUTO_BTN[2])
                ParkMouse()
                return
            }
        }
        ; Divine: Combo немає noComboReset ms (from останнього Combo, старту бою чи респавну) - бос загубився.
        ; Не шукаємо (біг уперед і повороти камери проносили крізь боса і до краю арени, 29.10 16:04 - 100 с
        ; без шкоди), а ресет (Esc-R-Enter): після респавну бот сам іде до боса (користувач, 29.10)
        if inFight && lastEntered = "raid" && Knockback() && comboSeen && (ms := Num("noComboReset", 12000)) > 0
                && A_TickCount - Max(lastCombo, fightSince, lastRespawnAt) > ms {
            Log("  no Combo for " (A_TickCount - Max(lastCombo, fightSince, lastRespawnAt)) // 1000 " s - resetting character")
            SetStatus("no Combo - reset: Esc-R-Enter")
            Screenshot("no_combo_reset")                  ; where the character was when it lost the boss
            rdResetCombo++, charIdx := 0
            HoldKey("Esc")
            Sleep 1000
            HoldKey("r")
            Sleep 800
            HoldKey("Enter")
            lastRespawnAt := A_TickCount                  ; поки гра покаже відлік - не ресетити вдруге
            return
        }
        ; у бою (або щойно, поки спалах ховає напис) меню не шукаємо: на спалахах можливі хибні збіги кнопок
        Fight()
        return
    }
    ; бій щойно скінчився. В Infinity сам він не закінчується, тож якщо ми не виходили через
    ; Esc-R-Enter - команда загинула або гра викинула: пишемо в лог і знімаємо екран (поразка, дисконект)
    if fightSince {
        if lastEntered = "infinity" && A_TickCount - lastReset > 60000 {
            s := (lastFight - fightSince) // 1000
            Log("Infinity ended by itself: fight lasted " s // 60 ":" Format("{:02}", Mod(s, 60))
                . ", ENEMIES LEFT gone " (A_TickCount - lastFight) // 1000 " s ago")
            Screenshot("inf_end")
            infDrop := true
        }
        if BossFight() && lastFight > fightSince {            ; скільки тривав бій з босом - видно, чи зміни допомагають
            s := (lastFight - fightSince) // 1000
            Log((lastEntered = "speed" ? "Speed Raid" : RaidTitle()) ": fight lasted " s // 60 ":" Format("{:02}", Mod(s, 60)))
            if lastEntered = "raid"
                Log("  Rewards " (rewardRepeat ? rewardRepeat : "?") " (raw " (rewardRaw != "" ? rewardRaw : "?") ", reads " rewardReads "), loadout " curLoadout
                    . ", deaths+resets " rdChanges ", resets " (rdResetNo5 + rdResetCombo) " (no 5: " rdResetNo5 ", no Combo: " rdResetCombo ")")
            ; відлік наступного Speed Raid гра починає з перемоги (lastFight - останній кадр бою), а не зі старту
            if lastEntered = "speed" {
                SpeedLater(SPEED_EVERY + 15 - SinceFight() // 1000)
                Log("  next Speed Raid at " FormatTime(speedDue, "HH:mm:ss"))
            }
        }
        FlushRun()
        FightCount()
        fightSince := 0
    }
    if goal = "none" {                                                    ; режими вимкнені: меню не чіпаємо
        SetStatus("modes disabled, waiting for a fight")
        return
    }
    if FindImg("update_logs.png", &x, &y, 200, 150, 900, 520) {                               ; вікно "UPDATE LOGS" після оновлення гри
        SetStatus("closing UPDATE LOGS window")
        ClickXY(x + UPDATE_LOGS_X[1], y + UPDATE_LOGS_X[2])
        ParkMouse()
        Sleep 1000
        return
    }
    if FindImg("start.png", &x, &y) {                                     ; екран PARTY
        if !partySince
            partySince := A_TickCount
        delay := lastEntered = "raid" && !SoloNow() ? Num("startDelay", 10) * 1000 : 0    ; solo mode (Friends Only on): nobody can join - start at once
        left := delay - (A_TickCount - partySince)
        ; гравці вже набрались ("Team Damage Bonus: + 110%" - максимум) - далі чекати нема чого
        if left > 0 && PartyBonus() >= Num("startBonus", 110) {
            Log("  PARTY: team bonus +" PartyBonus() "% - Start now (" Ceil(left / 1000) " s left)")
            left := 0
        }
        if left > 0 {
            SetStatus("PARTY, Start in " Ceil(left / 1000) " s")
            return
        }
        SetStatus("pressing Start")
        FlushRun()                                                        ; попередній забіг - у суми
        infLootDone := false, raidShotDone := false
        lastDmg := "", dmgChanged := A_TickCount, searchTurns := 0, sameReads := 0   ; новий бій - шкоду рахуємо заново
        if lastEntered = "titan"
            titanArmed := A_TickCount
        Stat(lastEntered = "raid" ? "raids" : lastEntered = "titan" ? "titanRuns" : "infRuns")                ; ще один забіг у статистику
        raidWalkDue := true                                              ; у новому бою знову підійдемо до боса
        AutoReset()
        learnLeft := 30, comboSeen := false, lastCombo := 0
        portraitSig := "", walkAt := 0                                    ; новий бій - портрет запам'ятаємо заново
        patrolIdx := 0                                                    ; новий забіг - персонаж знову в центрі
        rewardRaw := "", rewardReads := 0, rewardRepeat := 0              ; діагностичні лічильники рейду - заново
        charIdx := 1, autoOffAt := 0, rdChanges := 0, rdResetNo5 := 0, rdResetCombo := 0, lastNo5Reset := 0, no5Pending := false
        ClickImg("start.png", x, y)
        ParkMouse()
        partySince := 0
        Sleep 3000
        return
    }
    partySince := 0
    if FindImg("create_final.png", &x, &y) {                              ; налаштування рейду / данжу
        if goal = "titan" && lastEntered = "titan" {
            TitanCreate(x, y)
            return
        }
        ; соло-рейд: toggle Friends Only - ліворуч від кнопки Create, у тому ж рядку
        ; Group Finder mode: this is the fallback raid - Friends Only must be OFF so other players can join (user, 10.11)
        if lastEntered = "raid" && (SoloNow() || cfg["raidEntry"] = "gf") && !friendsDone {
            friendsDone := true
            want := SoloNow() ? 1 : 0, word := want ? "enable" : "disable"
            if (FriendsOff(x, y) ? 1 : 0) = want {                  ; off and solo wanted, or on and open wanted
                SetStatus((want ? "enabling Friends Only (solo)" : "disabling Friends Only (open raid)"))
                ClickXY(x - 90, y + 25)
                ParkMouse()
                Sleep 700
                Log((FriendsOff(x, y) ? 1 : 0) = want ? "  Friends Only: could not " word : "  Friends Only " word "d")
            } else
                Log("  Friends Only already " word "d")
            return
        }
        ; raid world: the banner over the window says when this server's raid opens ("Raid opens in 35 Minutes 0 Second").
        ; Read it before deciding anything (at most every 30 s): if the clock was wrong, the goal below is recomputed from it
        static bannerAt := 0
        if lastEntered = "raid" && cfg["raid"] = "1" && A_TickCount - bannerAt > 30000 {
            bannerAt := A_TickCount
            RaidClockLearn(OcrRegion([560, 150, 800, 50]))
            goal := Target()
        }
        ; час рейду минув (рейд можна створити лише 10 min після початку години, 29.10 18:12 бот
        ; тиснув Create до 18:30 і чекав до 59:30) - з світу рейду в лобі шляху нема, перезапуск гри
        if lastEntered = "raid" && goal != "raid" {
            if RestartRoblox("raid time is over and the bot is in the Create window", , 60000)
                Log("  cannot create this hour's raid - going to " goal)
            return
        }
        ; рейд відкривається на початку години: до createFrom (наприклад 59:30) Create не тиснемо
        s := SecOfHour()
        if lastEntered = "raid" && s >= 30 * 60 && s < MinSec(cfg["createFrom"], 59 * 60 + 30) {
            SetStatus("waiting until " cfg["createFrom"] ", then Create")
            return
        }
        ; останні 5 с перед відкриттям і перші 30 с години тиснемо щосекунди - щоб створити рейд одним з перших
        rush := s >= 3595 || s < 30
        if A_TickCount - lastCreate < (rush ? 1000 : CREATE_RETRY) {
            SetStatus("raid still closed, waiting")
            return
        }
        SetStatus("pressing Create (" lastEntered ")")
        ClickImg("create_final.png", x, y)
        ParkMouse()
        lastCreate := A_TickCount
        Sleep 1000
        return
    }
    ; списки данжів і рейдів. Після оновлення Halloween Raid є і в списку данжів головного лобі,
    ; тож спершу обираємо те, що треба зараз, і лише потім вирішуємо, що робити з іншим
    rd := RAIDS.Has(cfg["raidName"]) ? RAIDS[cfg["raidName"]] : RAIDS["halloween"]   ; обраний рейд
    ; Group Finder (upstream 0.3.5): the Join/Create window of the raid world - queue for the raid, the game teleports us in
    if goal = "raid" && GfActive() && FindImg("create_tab.png", &gx, &gy) {
        if EnterRaidGF(rd, gx, gy) {
            SetEntered("raid")
            friendsDone := false
        }
        return
    }
    hasRaid := rd[1] != "" && FindImg(rd[1], &rx, &ry)
    hasHal := hasRaid || FindImg("halloween.png", &hx, &hy)               ; Halloween є в усіх списках рейдів
    ; Group Finder wanted, but the raid list shows no Create tab to start from - it is created instead (logged once an hour)
    static gfNoTabHour := ""
    if hasHal && goal = "raid" && GfActive() && gfNoTabHour != RaidHourKey() {
        gfNoTabHour := RaidHourKey()
        Log("  Group Finder: the raid list shows no Create tab (create_tab.png) - creating the raid instead")
        Screenshot("gf_notab")
    }
    hasInf := FindImg("infinite.png", &ix, &iy)
    if goal = "titan" && lastEntered = "titan" && (hasInf || hasHal) {
        if PickTitan()
            Sleep 1500
        return
    }
    if hasRaid && goal = "raid" {
        SetStatus("selecting " rd[3])
        SetEntered("raid")
        friendsDone := false                                              ; новий екран налаштувань
        ClickXY(rx + rd[2][1], ry + rd[2][2])
        ParkMouse()
        Sleep 1500
        return
    }
    if hasHal && goal = "raid" && !hasRaid {                            ; рейд без еталона - шукаємо за назвою
        ; Group Finder fallback: the window may open on the Group Finder tab (buttons say Easy) - the Create tab first
        if cfg["raidEntry"] = "gf" && FindImg("create_tab.png", &tx, &ty) {
            ClickImg("create_tab.png", tx, ty)
            ParkMouse()
            Sleep 2000
        }
        if PickRaidByName(rd) {
            SetEntered("raid")
            friendsDone := false
            Sleep 1500
        }
        return
    }
    if hasInf && goal = "infinity" {
        SetStatus("selecting Infinite Mode")
        SetEntered("infinity")
        ClickXY(ix + INF_OFFSET[1], iy + INF_OFFSET[2])
        ParkMouse()
        Sleep 1500
        return
    }
    if hasInf {                                                           ; список данжів, але час рейду
        SetStatus("closing the Infinite Mode list (raid time)")
        ClickXY(1227, 261)                                                ; хрестик вікна
        ParkMouse()
        Sleep 1000
        return
    }
    if hasHal {                                                           ; світ рейду, але рейд уже був
        static halIdle := 0
        if !halIdle || A_TickCount - halIdle > 600000
            halIdle := A_TickCount
        SetStatus("in the raid world, this hour's raid is already done")
        ; з світу рейду в лобі шляху нема - не чекаємо кіка за AFK (20 min), перезапускаємо гру
        if A_TickCount - halIdle > 90000 && RestartRoblox("in the raid world without a raid", , 60000)
            halIdle := 0
        return
    }
    if FindImg("create_tab.png", &x, &y) {                                ; вікно Join/Create
        ; 4.11 00:04: Create tab pressed for 2 min and the raid was never found in the list - no shot of it
        static tabSince := 0, tabLast := 0, tabShot := 0
        if A_TickCount - tabLast > 15000
            tabSince := A_TickCount
        tabLast := A_TickCount
        if A_TickCount - tabSince > 20000 && A_TickCount - tabShot > 300000 {
            tabShot := A_TickCount
            Log("  Create tab for 20 s: the " (goal = "infinity" ? "Infinite Mode" : rd[3]) " card is not found in the list")
            Screenshot("list_nomatch")
        }
        SetStatus("Create tab")
        ClickImg("create_tab.png", x, y)
        ParkMouse()
        Sleep 2000                                                        ; список підвантажується
        ; рейд без еталона: Halloween колись зникне зі списку, тож не чекаємо його - шукаємо одразу
        ; 4.11 15:03: after the game update divine.png no longer matched its card - the name (OCR) is the fallback for every raid
        if goal = "raid" && PickRaidByName(rd) {
            SetEntered("raid")
            friendsDone := false
            Sleep 1500
        }
        ; 4.11: the Halloween Dimension event card pushed Infinite Mode down and infinite.png stopped matching - pick it by name
        if goal = "titan" && PickTitan() {
            SetEntered("titan")                                    ; 9.11: the list can open without the DIMENSION card click, and the run was treated as Infinity
            Sleep 1500
            return
        }
        if goal = "infinity" && PickInfinity() {
            SetEntered("infinity")
            friendsDone := false
            Sleep 1500
        }
        return
    }
    ; modes menu: the RAID card shows this server's countdown just above its title ("Raid Opens in: 24:37") - learn the raid
    ; clock from it (at most every 2 min); a new goal from it applies on the next tick
    ; The modes menu dims everything under it, PLAY included: PLAY still bright = the lobby, so a "card" seen now is a false
    ; match (7.11 02:53: raid_mode.png matched the lobby's skill-bar text / a white orb, the bot "saw" the menu without
    ; SPEED RAID and put the Speed Raid off for 10 min; 01:45 it clicked such a "card" in the lobby)
    menuOk := !FindImg("play.png", &lx, &ly, 1500, 800, 1920, 1060)
    static clockAt := 0
    if menuOk && cfg["raid"] = "1" && A_TickCount - clockAt > (raidCand >= 0 ? 4000 : 120000) && FindImg("raid_mode.png", &x, &y, 0, 860, SCR_W, 1000) {
        clockAt := A_TickCount
        if RaidClockLearn(OcrRegion([x - 60, y - 30, 300, 30])) {
            ; a new time needs a second reading: take it now, the menu is usually gone by the next tick (after a Roblox
            ; restart the server - and its raid time - is new, and the next menu visit may come after the raid)
            if raidCand >= 0 {
                Sleep 1500
                RaidClockLearn(OcrRegion([x - 60, y - 30, 300, 30]))
            }
            return
        }
    }
    if menuOk && (goal = "infinity" || goal = "titan") && FindImg("dimension.png", &x, &y, 260, 880, 620, 990) {   ; меню режимів: у данжі (лише білі літери DIMENSION)
        if MenuLoadoutWrong(2)
            return
        SetStatus("entering Dimension")
        if goal = "titan"
            SetEntered("titan")
        ClickXY(x + 130, y - 400)                                ; 9.11: the chat panel covers the DIMENSION letters and takes the click; the card art is clear
        ParkMouse()
        Sleep 1500
        return
    }
    if menuOk && goal = "speed" && FindImg("speed_mode.png", &x, &y, 700, 860, 1300, 1000) {  ; меню режимів: Speed Raid
        if MenuLoadoutWrong(3)
            return
        SpeedEnter(x, y)
        return
    }
    if menuOk && FindImg("raid_mode.png", &x, &y, 0, 860, SCR_W, 1000) {                       ; меню режимів: у світ рейду
        if goal = "speed" {                                               ; картки SPEED RAID не впізнали
            Log("  modes menu: SPEED RAID not visible - postponing 10 min")
            Screenshot("speed_menu")
            SpeedLater(600)
            return
        }
        if goal != "raid" {                                               ; поза часом рейду у світ рейду не йдемо
            SetStatus("modes menu: DIMENSION not visible, waiting")
            return
        }
        if MenuLoadoutWrong(1)
            return
        SetStatus("teleporting to the raid world")
        Screenshot("raid_world")                          ; 3.11 23:00 this matched inside the raid: shows what was clicked
        ClickImg("raid_mode.png", x, y)
        ParkMouse()
        WaitLoaded()
        return
    }
    if FindImg("play.png", &x, &y, 1500, 800, 1920, 1060) {               ; лише білі літери PLAY праворуч унизу (фон анімований)
        if goal = "raid" && GfWaiting()                                   ; queued through Group Finder: PLAY would reopen the window
            return
        ; preventive restart (user, 10.11): Roblox froze after 3.5 h in the middle of a raid and the tokens were lost. In the
        ; lobby, 10-50 min after the raid opened (the raid is over, the next is far), a Roblox running 2+ h is restarted
        s := SecOfHour()
        if goal != "raid" && s >= 600 && s < 3000 && (age := RobloxAgeMin()) >= ROBLOX_MAX_AGE {
            RestartRoblox("preventive, it has been running " age // 60 " h " Mod(age, 60) " min")
            return
        }
        if infDrop {
            infDrop := false
            Log("lobby after Infinity was cut off")
            Screenshot("inf_lobby")
        }
        if goal = "raid" || goal = "infinity" || goal = "speed" || goal = "titan" {   ; перед входом - потрібний loadout (рейд 1, Infinity 2, Speed 3)
            if cfg["loadouts"] != "1"
                CheckLoadoutOnce()                                        ; перемикання вимкнене - лише читаємо, що стоїть
            EnsureLoadout(goal = "raid" ? 1 : goal = "speed" ? 3 : 2)
            if !running
                return
            ; рейд з чужим loadout - не частіше разу на годину
            if goal = "raid" && (cfg["loadouts"] != "1" || curLoadout != 1) && (!lastLoadoutWarn || A_TickCount - lastLoadoutWarn > 3600000) {
                lastLoadoutWarn := A_TickCount
                Log("WARNING: raid without loadout 1 (current " curLoadout ", toggle " cfg["loadouts"] ")")
                SetStatus("WARNING: raid without loadout 1")
            }
        }
        SetStatus("pressing PLAY")
        ClickImg("play.png", x, y)
        ParkMouse()
        Sleep 1500
        return
    }
    ; сторож: екран довго не розпізнається (застрягле меню Esc, невідоме вікно гри).
    ; Перші 2 рази тиснемо Esc, далі по черзі хрестики відомих вікон гри (Esc їх не закриває).
    unknownSince := prevUnknown ? prevUnknown : A_TickCount
    if A_TickCount - unknownSince > UNKNOWN_ESC {
        watchStep += 1
        if watchStep = 1 {
            ; щоб потім знати, на чому застрягли, - знімок і перевірка на чорний екран
            Screenshot("stuck")
            if BlackScreen()
                Log("  screen is black: the game window may be minimised or the screen locked")
        }
        ; connection lost (25.10 бот так простояв 6 год: Retry не допомагає) - лише перезапуск гри.
        ; Якщо ж screen not recognised for 12+ min - теж перезапуск, як крайній захід.
        dc := Disconnected()
        ; результати Infinity з "Teleporting in 0": телепорт гри завис (29.10 17:58 - 14 min і пропущений рейд).
        ; Раз тиснемо LEAVE, не допомогло - одразу перезапуск гри, не чекаючи 12 min
        if !dc && InStr(OcrRegion([860, 805, 340, 105]), "Teleport") {     ; 10.11 12:14 Curse: the text sat at y 825-850, above the old box
            if watchStep = 1 {
                Log("  teleport stuck (Teleporting in 0) - pressing LEAVE")
                ClickXY(1215, 762)
                ParkMouse()
                unknownSince := A_TickCount
                return
            }
            unknownSince := A_TickCount
            if RestartRoblox("teleport stuck (Teleporting in 0)", , 60000)
                watchStep := 0
            return
        }
        if dc || watchStep >= 8 {
            unknownSince := A_TickCount
            if RestartRoblox(dc ? "connection lost" : "screen not recognised for " watchStep * UNKNOWN_ESC // 60000 " min", , dc ? RESTART_GAP_DC : RESTART_GAP)
                watchStep := 0
            return
        }
        if watchStep <= 2 {
            SetStatus("screen not recognised for " UNKNOWN_ESC // 1000 " s, pressing Esc")
            HoldKey("Esc")
        } else {
            p := CLOSE_XS[Mod(watchStep - 3, CLOSE_XS.Length) + 1]
            SetStatus("screen not recognised, clicking window close (" p[1] ", " p[2] ")")
            ClickXY(p[1], p[2])
            ParkMouse()
        }
        unknownSince := A_TickCount
        return
    }
    SetStatus("waiting (screen not recognised), goal: " goal)
}

; Результати Infinity (RETRY / LEAVE): одразу LEAVE, не чекаючи відліку телепорту (29.10 17:58 він завис
; на "Teleporting in 0"). Шаблон перевірено на 3310 кадрах: збіги лише на екранах результатів.
; 3 натискання не допомогли - перезапуск гри
LeaveInfinity() {
    global lastReset, lastFight
    static leaveAt := 0, leaveN := 0, shotAt := 0
    ; 7.11 00:07-00:16: "pressing LEAVE" six times in the middle of Infinity fights (the fight went on each time; 3 within
    ; a minute would have restarted Roblox). On the real results screen the overlay hides the AUTO button (checked on the
    ; 6.11 results shot: 0 of 205 letter pixels), in a fight it is always there - so no LEAVE while it shows
    if hudSeen
        return false
    if !FindImg("leave.png", &x, &y, 1000, 680, 1450, 840) && !FindImg("leave.png", &x, &y, 1000, 680, 1450, 840, "*110 *TransFF00FF") {
        ; the button is translucent, so its colour depends on the scene behind (3.11: the template missed it and the game's
        ; AUTO RETRY looped Infinity for hours). Fallback: the light REWARDS panel, confirmed by OCR, then click the fixed LEAVE spot
        static panelAt := 0
        if A_TickCount - panelAt < 2500
            return false
        panelAt := A_TickCount
        light := 0
        for p in [[1200, 330], [1400, 400], [1100, 650], [900, 430]] {
            c := PixelGetColor(p[1], p[2])
            if Min((c >> 16) & 255, (c >> 8) & 255, c & 255) > 200
                light++
        }
        if light < 4 || !RegExMatch(OcrRegion([560, 230, 1000, 700]), "i)rewards|auto retry|retry|leave")
            return false
        Log("  Infinity results found by OCR (LEAVE picture did not match) - pressing LEAVE")
        Screenshot("leave_nomatch")
        x := 1260, y := 771
    }
    ; поки йде телепорт - ні "липкого" бою, ні Esc-R-Enter (30 s left)
    lastFight := A_TickCount - FIGHT_STICKY
    lastReset := A_TickCount + 30000 - RESET_EVERY
    if A_TickCount - leaveAt > 60000
        leaveN := 0
    if A_TickCount - leaveAt > 4000 {
        if ++leaveN > 3 {
            leaveN := 0
            RestartRoblox("LEAVE after Infinity does not work", , 60000)
            return true
        }
        leaveAt := A_TickCount
        ReleaseKeys()
        if A_TickCount - shotAt > 600000 {                ; what the LEAVE match saw (at most every 10 min) - to check it later
            shotAt := A_TickCount
            Screenshot("leave")
            Log("  LEAVE at " x "," y ": hudSeen " hudSeen ", FightHud now " FightHud() " (" FightHudWhy() ")")
        }
        SetStatus("Infinity results: pressing LEAVE")
        ClickXY(x + 90, y + 24)
        ParkMouse()
        Sleep 1500
    }
    return true
}

; ------------------------ Допоміжні функції ------------------------
; знімок основного екрана в SHOTDIR (PNG через GDI+); понад SHOT_MAX найстаріші знімки видаляємо
Screenshot(tag, sx := 0, sy := 0, w := SCR_W, h := SCR_H) {
    try {
        DirCreate SHOTDIR
        file := SHOTDIR FormatTime(, "yyyyMMdd_HHmmss") "_" tag ".png"
        res := SaveRegion(file, sx, sy, w, h)
        Log(res = 0 ? "  screenshot: " file : "  screenshot not saved (GDI+ code " res ")")
        list := ""
        Loop Files SHOTDIR "*.png"
            list .= A_LoopFileFullPath "`n"
        arr := StrSplit(Sort(RTrim(list, "`n")), "`n")        ; імена з датою -> за алфавітом = за часом
        Loop arr.Length - SHOT_MAX
            FileDelete arr[A_Index]
        return file
    } catch as e
        Log("  screenshot failed: " e.Message)
    return ""
}

; ділянка екрана -> PNG-файл (GDI + GDI+); повертає 0, якщо збережено
SaveRegion(file, sx, sy, w, h) {
    try {
        sdc := DllCall("GetDC", "ptr", 0, "ptr")
        mdc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
        hbm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", w, "int", h, "ptr")
        old := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
        DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", sdc, "int", sx, "int", sy, "uint", 0x40CC0020)  ; SRCCOPY | CAPTUREBLT
        DllCall("SelectObject", "ptr", mdc, "ptr", old)
        DllCall("DeleteDC", "ptr", mdc)
        DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
        if !DllCall("GetModuleHandle", "str", "gdiplus", "ptr")
            DllCall("LoadLibrary", "str", "gdiplus")
        si := Buffer(24, 0)
        NumPut("uint", 1, si)                                 ; GdiplusStartupInput.GdiplusVersion
        DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0)
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &bmp := 0)
        clsid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid)   ; PNG
        res := DllCall("gdiplus\GdipSaveImageToFile", "ptr", bmp, "wstr", file, "ptr", clsid, "ptr", 0)
        DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
        DllCall("gdiplus\GdiplusShutdown", "ptr", token)
        DllCall("DeleteObject", "ptr", hbm)
        return res
    }
    return -1
}

FindImg(name, &x, &y, x1 := 0, y1 := 0, x2 := SCR_W, y2 := SCR_H, opts := "") {
    x := 0
    y := 0
    file := IMGDIR name
    if !FileExist(file)
        return false
    if opts = ""
        opts := "*" TOLERANCE " *TransFF00FF"          ; FF00FF у еталоні = прозорий фон (play.png, enemies_left.png)
    try
        found := ImageSearch(&x, &y, x1, y1, x2, y2, opts " " file)
    catch
        return false
    ; запасний еталон "назва_2.png" - той самий напис у дещо іншому масштабі (наприклад, гра в RDP-сесії)
    ; play_2.png: only the letter cores (2 px of every edge cut) - PLAY pulses, and 3.11 the full letters matched only at one size
    ; enemies_left_2.png: the same letters on a bright map (a bright desert map, 4.11) - lighter red, 31 of 350 px were off at *80
    alt := IMGDIR StrReplace(name, ".png", "_2.png")
    if !found && FileExist(alt)
        try found := ImageSearch(&x, &y, x1, y1, x2, y2, opts " " alt)
    ; "_3": a second variant (7.11: card_gem_2.png was already taken, the 150% screen needed one more)
    alt := IMGDIR StrReplace(name, ".png", "_3.png")
    if !found && FileExist(alt)
        try found := ImageSearch(&x, &y, x1, y1, x2, y2, opts " " alt)
    if found && BORDER.Has(name) && !BorderOk(name, x, y) {
        Log("  " name ": matched a blob of letter colour, ignoring")
        return false
    }
    return found
}

; true, якщо довкола літер справді фон, а не той самий колір (менше 12 з 16 точок кольору літер).
; З великим допуском ImageSearch може знайти збіг на 1-2 px зміщеним, тож пробуємо і зсуви до ±2 px:
; справжній напис пройде хоча б з одним, а суцільна пляма - ні з жодним.
BorderOk(name, x, y) {
    kind := BORDER[name][1]
    for off in [[0,0],[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1],[2,0],[-2,0],[0,2],[0,-2]] {
        same := 0
        for p in BORDER[name][2] {
            c := Integer(PixelGetColor(x + off[1] + p[1], y + off[2] + p[2]))
            r := c >> 16 & 0xFF, gg := c >> 8 & 0xFF, b := c & 0xFF
            if kind = "white" ? (r > 200 && gg > 200 && b > 200) : (r > 170 && gg < 110 && b < 120)
                same += 1
        }
        if same < 12
            return true
    }
    return false
}

; число з налаштувань; якщо там щось не те (порожньо, букви) - значення за замовчуванням
Num(key, def) {
    try
        return Integer(cfg[key])
    catch
        return def
}

ClickImg(name, x, y) {
    size := PngSize(IMGDIR name)
    ClickXY(x + size[1] // 2, y + size[2] // 2)
}

ClickXY(cx, cy) {
    if !running                                           ; після F2 кліків більше нема
        return
    MouseMove cx + 3, cy + 3, 0
    Sleep 60
    MouseMove cx, cy, 0
    Sleep 80
    if !running                                           ; за ці 140 ms могли зупинити
        return
    Click
}

; Після телепорту чекаємо не фіксований час, а поки лобі справді завантажиться: з'явиться кнопка PLAY
; (перші 3 с не дивимось - старе лобі ще може бути на екрані). Найдовше 60 с.
WaitLoaded() {
    t0 := A_TickCount
    Sleep 3000
    while A_TickCount - t0 < 60000 && running {
        if FindImg("play.png", &x, &y, 1500, 800, 1920, 1060) {
            Log("  lobby loaded in " Round((A_TickCount - t0) / 1000, 1) " s")
            Sleep 500                            ; дати інтерфейсу домалюватись
            return
        }
        ; 3.11 23:00: raid_mode.png matched in the raid itself and the bot stood here 60 s while the fight went on
        h := ENEMIES_HOME
        if FindImg("enemies_left.png", &x, &y, h[1] - 12, h[2] - 12, h[1] + 66, h[2] + 38, "*80 *TransFF00FF") {
            Log("  already in a fight (ENEMIES LEFT) after " Round((A_TickCount - t0) / 1000, 1) " s - not waiting for the lobby")
            return
        }
        Sleep 500
    }
    Log("  lobby did not load in 60 s")
    Screenshot("no_lobby")
}

; вікно обриву з'єднання Roblox: текст у центрі екрана містить Disconnected / Reconnect / Retry / Error Code
Disconnected() {
    txt := OcrRegion(DISCONNECT_BOX)
    if RegExMatch(txt, DISCONNECT_RE) {
        Log("  connection lost, on screen: " StrReplace(Trim(txt), "`n", " | "))
        return true
    }
    return false
}

; синхронний OCR ділянки екрана (x, y, w, h); lines - кожен рядок як [y від верху ділянки, текст]
OcrRegion(b, lines := false) {
    txt := ""
    try FileDelete OCR2_OUT
    if SaveRegion(OCR2_IN, b[1], b[2], b[3], b[4]) = 0 {
        OcrCall(OCR2_IN, OCR2_OUT, "-Scale 2" (lines ? " -Lines" : ""))
        try txt := FileRead(OCR2_OUT, "UTF-8")
        try FileDelete OCR2_OUT
    }
    if !lines
        return txt
    out := []
    for ln in StrSplit(txt, "`n", "`r")
        if RegExMatch(ln, "^(\d+)\t(.*)$", &m)
            out.Push([Integer(m[1]), m[2]])
    return out
}

; OCR через сервер (ocr.ps1 -Serve): PowerShell запущений один раз, читання ~0.15 с замість ~1 с (28.10).
; Сервер не запущений або не відповів за 8 с - старий спосіб (окремий PowerShell на це читання).
; wait = false - лише поставити в чергу (результат забирає PollRewards на наступних тіках).
OcrCall(img, out, opts := "", wait := true) {
    try FileDelete out
    if OcrServer() {
        req := OCRQ A_TickCount "_" Random(1000, 9999)
        try {
            FileAppend img "`n" out "`n" opts, req ".tmp", "UTF-8-RAW"
            FileMove req ".tmp", req ".req"              ; сервер бере лише готові *.req
            if !wait
                return
            t0 := A_TickCount
            while A_TickCount - t0 < 8000 {
                if FileExist(out)
                    return
                Sleep 30
            }
            try FileDelete req ".req"
        }
        Log("  OCR server did not answer - restarting it, this read uses the old way")
        OcrServerKill()
    }
    cmd := 'powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' A_ScriptDir '\ocr.ps1" "' img '" "' out '" ' opts
    try wait ? RunWait(cmd, , "Hide") : Run(cmd, , "Hide")
}

; true - сервер працює. Не працює - запускаємо (не частіше раз на minилину); щойно запущений ще
; вантажиться ~1 с, тож цього разу false. Сервер сам закривається, коли закривається бот (-Parent).
OcrServer() {
    global ocrPid
    static lastTry := 0
    if ocrPid && ProcessExist(ocrPid)
        return true
    ocrPid := 0
    if lastTry && A_TickCount - lastTry < 60000
        return false
    lastTry := A_TickCount
    try {
        DirCreate OCRQ
        Loop Files OCRQ "*.*"
            try FileDelete A_LoopFileFullPath
        Run('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' A_ScriptDir '\ocr.ps1" -Serve "'
            RTrim(OCRQ, "\") '" -Parent ' DllCall("GetCurrentProcessId"), , "Hide", &pid)
        ocrPid := pid
        Log("  OCR server started")
    }
    return false
}

OcrServerKill() {
    global ocrPid
    if ocrPid
        try ProcessClose ocrPid
    ocrPid := 0
}

; Екран PARTY рейду: "Team Damage Bonus: + N%" праворуч від списку гравців (кадри 29.10: "+ 0%", "+ 110%").
; Читаємо OCR не частіше раз на секунду; -1 - не прочитали.
PartyBonus() {
    static at := 0, val := -1, box := [1060, 585, 200, 65]
    if A_TickCount - at < 1000
        return val
    at := A_TickCount
    val := -1
    ; Windows OCR то читає "+ 110%", то "+ 1100/0" (% -> 0/0) і зовсім по-різному на різних масштабах (31.10: за все
    ; життя жодного "Start одразу" - читання не збігалось із шаблоном), тож пробуємо масштаби 2, 1, 3
    for sc in [2, 1, 3] {
        try FileDelete OCR2_OUT
        if SaveRegion(OCR2_IN, box[1], box[2], box[3], box[4]) != 0
            continue
        OcrCall(OCR2_IN, OCR2_OUT, "-Scale " sc)
        txt := ""
        try txt := FileRead(OCR2_OUT, "UTF-8")
        try FileDelete OCR2_OUT
        if RegExMatch(txt, "\+\s*(\d{1,3})\s*%", &m) || RegExMatch(txt, "\+\s*(\d{1,3}?)\s*0\s*/\s*0", &m) {
            val := Integer(m[1])
            break
        }
        static lastRaw := 0
        if A_TickCount - lastRaw > 15000 {
            lastRaw := A_TickCount
            Log("  PARTY: bonus not read (scale " sc "): '" Trim(StrReplace(txt, "`n", " | ")) "'")
        }
    }
    return val
}

; Infinite Mode in the Create list by name; after a miss, waits a minute before searching again
PickInfinity() {
    static retryAt := 0
    if A_TickCount < retryAt
        return false
    if PickRaidByName(["", 0, "Infinite Mode", "i)Infinite"], false)
        return true
    retryAt := A_TickCount + 60000
    return false
}

; Рейд без еталона: шукаємо його назву в списку рейдів (OCR), гортаючи колесом від початку,
; і тиснемо Create під назвою. true - натиснули.
; Raid entry through Group Finder (upstream 0.3.5, 7.11): open its tab, find the raid by name, press the button under it -
; the bot queues and the game teleports into the raid when it opens. While queued the window is not touched (upstream: a
; second click leaves the queue). Not teleported GF_FALLBACK s after the raid opened, or the raid not in the list 3 times:
; cancel the queue and create the raid for the rest of this hour (user, 10.11). true - just queued.
EnterRaidGF(rd, x, y) {
    global gfQueuedAt, gfMiss, gfMissHour
    if gfQueuedAt && A_TickCount - gfQueuedAt > 900000      ; a queue from an earlier hour means nothing now
        gfQueuedAt := 0
    s := SecOfHour()
    if s >= GF_FALLBACK && s < 1800 {                        ; the raid is open and we are still at this window
        GfFallback((gfQueuedAt ? "no teleport " : "not queued ") s " s after the raid opened")
        return false
    }
    ; queued, but the window is open again: it dims the queue banner (unreadable) and a click on Easy would restart the
    ; queue (10.11 15:43) - close it and wait in the raid world (GfWaiting)
    if gfQueuedAt {
        SetStatus("Group Finder: queued - closing the window")
        ClickXY(1227, 261)                                ; хрестик вікна
        ParkMouse()
        Sleep 800
        return false
    }
    SetStatus("Group Finder tab")
    size := PngSize(IMGDIR "create_tab.png")
    ClickXY(x + size[1] // 2 + GF_TAB_DX, y + size[2] // 2)
    ParkMouse()
    Sleep 2000                                            ; the list loads
    if PickRaidByName(rd, false, GF_BTN) {
        gfQueuedAt := A_TickCount
        Sleep 1500                                        ; the game closes the window after the click - the banner is bright
        shown := GfBannerShown()
        Log("  Group Finder: queued for " rd[3] (shown ? "" : " - but no queue banner seen, see the shot"))
        if !shown
            Screenshot("gf_banner")
        return true
    }
    hour := RaidHourKey()
    if gfMissHour != hour
        gfMiss := 0, gfMissHour := hour
    if ++gfMiss >= 3
        GfFallback(rd[3] " not found in the Group Finder list 3 times")
    return false
}

GfBannerShown() => RegExMatch(OcrRegion(GF_BANNER), "i)opens|cancel|Time")

; Queued through Group Finder and back in the raid world (the game closes the window after Easy): wait here instead of
; pressing PLAY - PLAY reopens the window, which dims the banner. true = wait. The banner gone for 90 s after the click
; (cancelled, failed) - false, PLAY is pressed and the bot queues again. The raid open GF_FALLBACK s and no teleport -
; cancel the queue and create the raid (false: PLAY opens the window for it).
GfWaiting() {
    global gfQueuedAt
    static chkAt := 0, shown := true
    if !gfQueuedAt || !GfActive()
        return false
    if A_TickCount - gfQueuedAt > 900000 {
        gfQueuedAt := 0
        return false
    }
    s := SecOfHour()
    if s >= GF_FALLBACK && s < 1800 {
        GfFallback("no teleport " s " s after the raid opened")
        return false
    }
    if A_TickCount - chkAt > 1500 {
        chkAt := A_TickCount
        shown := GfBannerShown()
    }
    if shown || A_TickCount - gfQueuedAt < 90000 {
        SetStatus("Group Finder: queued, waiting for the raid")
        return true
    }
    Log("  Group Finder: the queue banner is gone - queueing again")
    Screenshot("gf_gone")
    gfQueuedAt := 0
    return false
}

; Group Finder did not work this hour: cancel the queue - the raid is created (open to others) for the rest of the hour.
; The window is closed first: it dims the banner and its CANCEL cannot be read.
GfFallback(why) {
    global gfQueuedAt, gfOffHour
    Log("  Group Finder: " why " - creating the raid instead (open to others)")
    Screenshot("gf_fallback")
    if FindImg("create_tab.png", &tx, &ty) {
        ClickXY(1227, 261)                                ; хрестик вікна
        ParkMouse()
        Sleep 800
    }
    if gfQueuedAt
        GfCancel()
    gfQueuedAt := 0
    gfOffHour := RaidHourKey()
}

; CANCEL on the queue banner. The OCR gives no x, so the banner is read in overlapping slices; the click goes to the
; middle of the slices that hold the word.
GfCancel() {
    b := GF_BANNER, w := 120, step := 60, sum := 0, n := 0
    sx := b[1]
    while sx + w <= b[1] + b[3] {
        if RegExMatch(OcrRegion([sx, b[2], w, b[4]]), "i)canc|ancel")
            sum += sx + w // 2, n++
        sx += step
    }
    if !n {
        Log("  Group Finder: CANCEL not found on the queue banner")
        return false
    }
    ClickXY(sum // n, b[2] + b[4] // 2)
    ParkMouse()
    Sleep 1000
    Log("  Group Finder: queue cancelled" (GfBannerShown() ? " - but the banner is still there" : ""))
    return true
}

PickRaidByName(rd, isRaid := true, btn := "i)reate") {
    global raidDoneKey, pickFails, pickFailHour, pickMissAt
    b := RAID_LIST
    SetStatus("looking for " rd[3] " in the list")
    ListWheel("Up", 80)                                   ; на початок списку (private server: more raids above the Infinite Mode)
    Sleep 1500                                            ; 4.11: the list keeps sliding after the wheel - OCR read an empty moving list
    prev := "-", empty := 0
    Loop 80 {
        lines := OcrRegion(b, true)
        if !lines.Length && ++empty <= 4 {                 ; nothing read: the list is still moving - read again, do not scroll
            Sleep 700
            continue
        }
        all := "", titleY := 0
        for ln in lines {
            all .= ln[1] ":" ln[2] "|"                   ; with y: small steps may show the same rows, only shifted
            if !titleY && RegExMatch(ln[2], rd[4])
                titleY := ln[1]
            else if titleY && RegExMatch(ln[2], btn) && ln[1] > titleY && ln[1] - titleY < 130 {
                SetStatus("selecting " rd[3])
                ClickXY(RAID_CREATE_X, b[2] + ln[1])
                ParkMouse()
                if isRaid
                    pickFails := 0
                return true
            }
        }
        if all = prev                                     ; список уже не гортається - кінець
            break
        prev := all
        ; 4 notches (~half a row): with 10 the title at the bottom edge (its Create still hidden) jumped off the top
        ; on the next step - 4.11 a raid on the private server was skipped this way
        ListWheel("Down", 2, 200)                         ; 4.11 user: down slowly and a little at a time
        Sleep 500                                         ; let the list stop before the next read
    }
    hour := RaidHourKey()
    if isRaid {                                           ; a miss within 60 s of the last counted one does not count (list still scrolling)
        if pickFailHour != hour
            pickFails := 0, pickMissAt := 0
        pickFailHour := hour
        if !pickMissAt || A_TickCount - pickMissAt > 60000
            pickFails++, pickMissAt := A_TickCount
        Log("  " rd[3] ": not found in the raid list (" pickFails "/3)")
    } else
        Log("  " rd[3] ": not found in the list")
    Screenshot("raid_list")
    ListWheel("Up", 80)                                   ; do not stay at the bottom of the list
    if !isRaid
        return false
    if pickFails >= 3 {                                       ; рейд зник з гри (limited) - не шукаємо до кінця години
        Log("  skipping this hour's raid: " rd[3] " is not in the list, pick another raid")
        raidDoneKey := hour
        IniWrite raidDoneKey, INI, "state", "raidDoneKey"
        ClickXY(1227, 261)                                ; хрестик вікна
        ParkMouse()
    }
    return false
}

; Гортає список рейдів колесом. Roblox ловить колесо лише над списком після руху миші,
; тому спершу ворушимо мишу, а оберти шлемо по одному.
ListWheel(dir, n, gap := 25) {
    b := RAID_LIST
    cx := b[1] + 60, cy := b[2] + b[4] // 2
    MouseMove cx + 8, cy + 8, 0
    Sleep 80
    MouseMove cx, cy, 0
    Sleep 150
    Loop n {
        Send "{Wheel" dir "}"
        Sleep gap
    }
    Sleep 700
}

; поточний loadout з кнопки "Loadout N" у відкритому Bag (0 - не прочитали: Bag не відкритий)
ReadLoadout() => RegExMatch(OcrRegion(LOADOUT_BOX), "i)Load\w*\s*(\d)", &m) ? Integer(m[1]) : 0

; Поставити loadout n (Bag -> список угорі -> рядок). Стан пам'ятаємо, тож Bag відкриваємо лише при зміні;
; якщо не вийшло - пауза (щоб не застрягти в лобі): Bag did not open (телепорт, вікно гри) - 1 min,
; Bag відкрився, але loadout не перемкнувся - 10 min.
; Loadout switching is off: read once after Start which loadout is active, so the log, the Dashboard and the
; "raid without loadout 1" warning show the real number.
CheckLoadoutOnce() {
    global curLoadout, loadoutChecked
    if loadoutChecked
        return
    loadoutChecked := true
    SetStatus("checking the current loadout")
    cur := 0
    Loop 2 {
        if !running
            return
        ClickXY(BAG_BTN[1], BAG_BTN[2])
        Sleep 1800
        if cur := ReadLoadout()
            break
        Sleep 1000
        if cur := ReadLoadout()
            break
    }
    if cur {
        curLoadout := cur
        ClickXY(BAG_CLOSE[1], BAG_CLOSE[2])
    }
    ParkMouse()
    Sleep 800
    Log("  current loadout: " (cur ? cur : "could not be read"))
}

EnsureLoadout(n, onlyCheck := false) {
    global curLoadout
    static failAt := 0, failWait := 0, failN := 0
    ; пауза після невдачі - лише для того самого loadout (28.10 21:40: невдача з 3 не має блокувати повернення на 2)
    if cfg["loadouts"] != "1" || curLoadout = n || (failAt && failN = n && A_TickCount - failAt < failWait)
        return false
    if onlyCheck                                          ; лише питаємо: чи треба міняти loadout
        return true
    SetStatus("loadout " n ": opening Bag")
    ; одразу після телепорту лобі ще довантажується і клік по Bag губиться (28.10 16:03: рейд пішов
    ; з loadout 2) - до 3 спроб; перш ніж клікати знову, ще раз читаємо (Bag міг відкритись пізніше)
    cur := 0
    Loop 3 {
        if !running
            return false
        if A_Index > 1 {
            Log("  loadout " n ": Bag did not open - attempt " A_Index)
            Sleep 1500
        }
        ClickXY(BAG_BTN[1], BAG_BTN[2])
        Sleep 1800
        if cur := ReadLoadout()
            break
        Sleep 1000
        if cur := ReadLoadout()
            break
    }
    bagOpen := cur != 0
    if !running
        return false
    if cur && cur != n {
        SetStatus("loadout " cur " -> " n)
        ClickXY(LOADOUT_BOX[1] + LOADOUT_BOX[3] // 2, LOADOUT_BOX[2] + LOADOUT_BOX[4] // 2)
        Sleep 1000
        if !running
            return false
        ClickXY(LOADOUT_ROWS[n][1], LOADOUT_ROWS[n][2])
        Sleep 1500
        ; одразу після перемикання кнопка часом не читається (28.10 21:40: "Switched to Loadout 3" був,
        ; а OCR - порожньо) - ще кілька спроб
        ; 6.11 21:59 / 22:06: "Switched to Loadout 3" was on screen, but the button still read the old number for a moment
        ; and the first read was taken - wait for the new number itself (up to ~5 s)
        Loop 7 {
            if (cur := ReadLoadout()) = n
                break
            Sleep 700
        }
    }
    if bagOpen                                            ; Bag відкритий - закриваємо (навіть якщо не прочитали)
        ClickXY(BAG_CLOSE[1], BAG_CLOSE[2])
    ParkMouse()
    Sleep 800
    if cur = n {
        curLoadout := n, failAt := 0
        Log("  loadout " n " ✓")
    } else {
        ; перемикали, а що стоїть - не знаємо: наступного разу перевіримо в Bag, а не повіримо старому
        if bagOpen
            curLoadout := cur
        failAt := A_TickCount, failWait := cur && n != 1 ? 600000 : 60000, failN := n   ; для рейду (1) і з прочитаним номером - теж 1 min
        Log("  loadout " n " failed (read: " (cur ? cur : bagOpen ? "nothing after switching" : "Bag did not open") ") - retrying in " failWait // 60000 " min")
        Screenshot("loadout")
    }
}

; Меню режимів відкрите, а loadout ще не той (бота перезапустили з відкритим меню - 28.10 19:12 Speed Raid
; пішов з loadout 2; або меню лишилось після невдалого Speed Raid) - закриваємо меню: у лобі EnsureLoadout
; поставить потрібний, а тоді знову PLAY.
MenuLoadoutWrong(n) {
    static lastLog := 0
    if !EnsureLoadout(n, true)
        return false
    SetStatus("modes menu: loadout first " n " - closing the menu")
    if A_TickCount - lastLog > 60000 {
        lastLog := A_TickCount
        Log("modes menu: loadout is not yet " n " - closing menu, will set it in the lobby")
    }
    ClickXY(MODES_CLOSE[1], MODES_CLOSE[2])
    ParkMouse()
    Sleep 800
    return true
}

; секунд до тижневого скидання Speed Raid з рядка "Weekly Reset in: 1 Day 3 Hours 5 Minutes" (0 - не прочитали):
; після нього використані персонажі знову вільні
; user, 8.11: Speed Raid pays special rewards for the first 50 runs of a week, after that "very little".
; Runs of this week so far. The week ends at the reset time shown in the Speed Raid window; resetSec = 0 when it was not read.
SpeedWeekRuns(resetSec) {
    end := IniRead(INI, "state", "speedWeekEnd", "")
    runs := IniRead(INI, "state", "speedWeekRuns", "0")
    runs := IsInteger(runs) ? Integer(runs) : 0
    try {
        if end != "" && DateDiff(A_Now, end, "Seconds") >= 0
            runs := 0, end := ""
    } catch
        end := ""
    if resetSec {
        e := DateAdd(A_Now, resetSec, "Seconds")
        if end != "" && DateDiff(e, end, "Seconds") > 86400     ; the shown reset jumped forward: the bot was off during the reset
            runs := 0
        end := e
    }
    IniWrite end, INI, "state", "speedWeekEnd"
    IniWrite runs, INI, "state", "speedWeekRuns"
    return runs
}

SpeedResetSec() {
    txt := OcrRegion(SPEED_RESET_BOX)
    if !InStr(txt, "eset")
        return 0
    s := 0
    if RegExMatch(txt, "i)(\d+)\s*d", &m)
        s += m[1] * 86400
    if RegExMatch(txt, "i)(\d+)\s*h", &m)
        s += m[1] * 3600
    if RegExMatch(txt, "i)(\d+)\s*m", &m)
        s += m[1] * 60
    return s
}

; наступна спроба Speed Raid - через sec секунд (пам'ятаємо в raid.ini, щоб пережити перезапуск бота)
SpeedLater(sec) {
    global speedDue
    speedDue := DateAdd(A_Now, sec, "Seconds")
    IniWrite speedDue, INI, "state", "speedDue"
}

; Меню режимів -> Speed Raid: картка -> Start -> найнижчий вільний персонаж -> Start.
; Будь-яка невдача - закриваємо вікно і пробуємо через 2 min (щоб не застрягти в лобі).
SpeedEnter(x, y) {
    global raidWalkDue, infLootDone, raidShotDone, lastDmg, dmgChanged, searchTurns, sameReads
    global learnLeft, comboSeen, lastCombo, portraitSig, walkAt, patrolIdx, speedFails
    ready := Trim(OcrRegion(SPEED_READY_BOX), " `r`n")
    ; на картці таймер замість "Ready to enter": "Ready in 00:01:13" (год:хв:с) - теж "Ready", тож дивимось на
    ; час (28.10 19:09: бот прийняв таймер за готовність, Start у вікні вибору не спрацював, меню зависло)
    timer := RegExMatch(ready, "(\d+)\s*[:.]\s*(\d\d)(?:\s*[:.]\s*(\d\d))?", &m)
    if timer || ready != "" && (!InStr(ready, "Ready") || RegExMatch(ready, "i)Ready\s*in")) {
        wait := !timer ? 120 : m[3] != "" ? m[1] * 3600 + m[2] * 60 + m[3] + 10 : m[1] * 60 + m[2] + 10
        Log("  Speed Raid not available yet (" ready ") - trying again in " Ceil(wait / 60) " min")
        SpeedLater(wait)
        ; закриваємо меню режимів: у лобі бот знову поставить loadout для Infinity (а не піде в неї з loadout 3)
        ClickXY(MODES_CLOSE[1], MODES_CLOSE[2])
        ParkMouse()
        Sleep 800
        return
    }
    SetStatus("Speed Raid: opening")
    ; меню режимів ще виїжджає - клік по картці в цей момент гра ігнорує (28.10 09:40: вікно не відкрилось,
    ; і Speed Raid зсунувся на 12 min). Чекаємо, клікаємо, а якщо вікна нема 3 с - ще раз.
    Sleep 700
    opened := false
    Loop 2 {
        if FindImg("speed_mode.png", &x, &y, 700, 860, 1300, 1000)
            ClickImg("speed_mode.png", x, y)
        ParkMouse()
        t0 := A_TickCount
        while !(opened := InStr(OcrRegion(SPEED_TITLE_BOX), "Speed")) && A_TickCount - t0 < 3000
            Sleep 300
        if opened
            break
        Log("  Speed Raid: window did not open - pressing the card again")
    }
    if !opened
        return SpeedFail("Speed Raid window did not open")
    resetSec := SpeedResetSec()                          ; the weekly reset is shown under the title
    Log("  Speed Raid: weekly reset in " (resetSec ? resetSec // 3600 " h " Mod(resetSec // 60, 60) " min" : "? (not read)"))
    weekRuns := SpeedWeekRuns(resetSec)
    if weekRuns >= SPEED_WEEK_MAX {
        wait := resetSec ? resetSec + 180 : 6 * 3600
        Log("  Speed Raid: " weekRuns " runs this week, the special rewards are used up - next try in " Ceil(wait / 3600) " h")
        ClickXY(SPEED_CLOSE[1], SPEED_CLOSE[2])
        ParkMouse()
        SpeedLater(wait)
        return
    }
    ClickXY(SPEED_START[1], SPEED_START[2])
    ParkMouse()
    Sleep 2000
    if !InStr(OcrRegion(SPEED_TITLE_BOX), "Select")
        return SpeedFail("character list did not open")
    SetStatus("Speed Raid: looking for a free character")
    if !PickSpeedChar(&cx, &cy) {
        wait := resetSec ? resetSec + 180 : 6 * 3600           ; until the weekly reset (+3 min), 6 h if it was not read
        Log("  Speed Raid: no free characters (all played this week) - next try after the weekly reset in " Ceil(wait / 3600) " h")
        Screenshot("speed_chars")
        ClickXY(SPEED_CLOSE[1], SPEED_CLOSE[2])
        Sleep 1000
        if InStr(OcrRegion(SPEED_TITLE_BOX), "Speed")      ; під списком ще вікно Speed Raid (див. SpeedFail)
            ClickXY(SPEED_CLOSE[1], SPEED_CLOSE[2])
        ParkMouse()
        SpeedLater(wait)
        return
    }
    ; персонаж -> Start; якщо вікно вибору не закрилось (28.10 14:09: Start "не спрацював", вікно висіло
    ; 12 min і бот перезапустив Roblox) - ще раз персонаж і Start, а тоді закриваємо й пробуємо пізніше
    Loop 2 {
        ClickXY(cx, cy)
        ParkMouse()
        Sleep 700
        if A_Index = 1
            Screenshot("speed_pick")                      ; видно, кого обрали
        ClickXY(SPEED_GO[1], SPEED_GO[2])
        ParkMouse()
        Sleep 2500
        if !InStr(OcrRegion(SPEED_TITLE_BOX), "Select")
            break
        if A_Index = 2 {
            Screenshot("speed_nogo")
            return SpeedFail("Start did not work (character window did not close)")
        }
        Log("  Speed Raid: character window still open after Start - selecting again")
    }
    SetEntered("speed")
    SpeedLater(SPEED_EVERY)               ; запас, якщо кінець бою не побачимо; точний час - після перемоги (Step)
    speedFails := 0
    FlushRun()
    infLootDone := false, raidShotDone := false
    lastDmg := "", dmgChanged := A_TickCount, searchTurns := 0, sameReads := 0
    raidWalkDue := true, learnLeft := 0, comboSeen := false, lastCombo := 0
    AutoReset()
    portraitSig := "", walkAt := 0, patrolIdx := 0
    Stat("speedRuns")
    IniWrite weekRuns + 1, INI, "state", "speedWeekRuns"
    Log("Speed Raid: start (character x=" cx " y=" cy ", run " weekRuns + 1 " of " SPEED_WEEK_MAX " this week)")
    ; телепорт: кілька секунд ще видно лобі з PLAY - чекаємо, поки воно зникне, інакше бот
    ; знову тисне Bag/PLAY посеред телепорту (28.10: loadout 2 "не вдалося" і 10 min без зміни)
    t0 := A_TickCount
    Sleep 3000
    while A_TickCount - t0 < 40000 && running && FindImg("play.png", &px, &py, 1500, 800, 1920, 1060)
        Sleep 500
    Sleep 2000
}

; Speed Raid, щойно підійшли до боса: E і R майже разом, X, Z, через 1 с - 5 4 3 2 1 по черзі.
; Зазвичай бос гине вже від цієї серії; далі - звичайний бій (скіли й помічники по готовності).
; Скіл під час анімації попереднього "з'їдається" - тиснемо, поки не піде на перезарядку (до 3 s left).
SpeedOpener() {
    global lastCast
    SetStatus("Speed Raid: E R X Z, then " SPEED_ORDER)
    Send "{e}"
    Sleep 60
    Send "{r}"
    Sleep 200
    Send "{x}"
    Sleep 200
    Send "{z}"
    Sleep 1000
    done := ""
    for k in StrSplit(SPEED_ORDER, " ") {
        if !SkillReady(k)                                 ; порожній слот 5 (не в усіх персонажів) - далі
            continue
        t0 := A_TickCount
        Loop {
            Send "{" k "}"
            Sleep 250
            if !SkillReady(k) {
                done .= k " "
                break
            }
        } until A_TickCount - t0 > 3000 || !running
    }
    lastCast := A_TickCount
    Log("Speed Raid: opening series E R X Z, skills fired: " (done = "" ? "none" : Trim(done)))
}

; перша невдача - повтор через 2 min (зазвичай випадковість); якщо знову - через 10 min,
; щоб не виходити з Infinity щокілька minилин, коли щось зламалось надовго
SpeedFail(why) {
    global speedFails
    ; 3 невдачі поспіль - найімовірніше, вільних персонажів уже нема (обрали затемненого, Start не йде):
    ; не виходимо з Infinity щодесять minилин, а відкладаємо Speed Raid на 6 год
    wait := ++speedFails >= 3 ? 6 * 3600 : speedFails > 1 ? 600 : 120
    Log("  Speed Raid: " why " - trying again in " wait // 60 " min" (wait > 3600 ? " (" speedFails " failures in a row, then Infinity)" : ""))
    Screenshot("speed_fail")
    ClickXY(SPEED_CLOSE[1], SPEED_CLOSE[2])
    ; хрестик списку персонажів повертає у вікно Speed Raid - закриваємо і його (29.10 16:21: бот лишився
    ; у вікні Speed Raid і чекав, "екран не розпізнано")
    Sleep 1000
    if InStr(OcrRegion(SPEED_TITLE_BOX), "Speed")
        ClickXY(SPEED_CLOSE[1], SPEED_CLOSE[2])
    ParkMouse()
    SpeedLater(wait)
}

; Найнижчий вільний персонаж (у кінці списку - найслабші). Використані цього тижня - затемнені.
; Гортаємо повзунком у самий низ; якщо там усі темні - піднімаємось по 120 px.
PickSpeedChar(&cx, &cy) {
    global speedBarX
    b := SPEED_GRID
    speedBarX := FindBarX()
    Log("  Speed Raid: scroll bar " (speedBarX ? "found at x=" speedBarX : "not found - scrolling with the mouse wheel"))
    Screenshot("speed_list")                              ; for checking where the bar is on this PC
    if !speedBarX
        return PickSpeedCharWheel(&cx, &cy)
    DragBar(b[2] + 45, b[2] + b[4] + 80)                  ; повзунок на початку списку -> униз до упору
    Sleep 800
    thumb := b[2] + b[4] - 45
    Loop 8 {
        ; обрізаний верхній ряд (видно лише край) не беремо: клік туди влучав у затемнену клітинку нижче
        ; (29.10 16:18) - його покаже прокрутка колесом нижче
        if SpeedScan(&cx, &cy) && cy > b[2] + 70
            return true
        if thumb - 120 < b[2]
            break
        DragBar(thumb, thumb - 120)
        thumb -= 120
        Sleep 700
    }
    ; кроки по 120 px не доходять до самого верху - верхній ряд лишався обрізаним, і вільних там не бачили
    ; (29.10 15:09 "вільних нема", а вгорі було ще 5) - насамкінець повзунок до упору вгору
    DragBar(thumb, b[2] - 80)
    Sleep 500
    ; і повзунок до упору не догортає (29.10 16:18: перший ряд видно лише краєм) - догортаємо колесом
    MouseMove b[1] + b[3] // 2 + 8, b[2] + b[4] // 2 + 8, 0
    Sleep 80
    MouseMove b[1] + b[3] // 2, b[2] + b[4] // 2, 0
    Sleep 150
    Loop 15 {
        Send "{WheelUp}"
        Sleep 30
    }
    Sleep 800
    return SpeedScan(&cx, &cy)
}

; Не затемнені клітинки в кожному стовпчику: у вікні 120 px заввишки > 5% світлих точок (> 100).
; Затемнений персонаж - максимум ~55, порожньо ~27; вільний темний (чорне волосся й одяг) у середньому лише ~72
; (29.10 13:08: середнє > 100 його не бачило - "вільних нема", хоча він був). Перевірено на 6 знімках списку.
; Беремо найнижчу, при рівних - праву.
SpeedScan(&cx, &cy) {
    b := SPEED_GRID, win := 120
    px := GrabPixels(b[1], b[2], b[3], b[4])
    best := 0, cx := 0, cy := 0
    for col in SPEED_COLS {
        x0 := col - b[1] - 50
        rows := []
        Loop b[4] {                                       ; скільки світлих точок у кожному рядку смуги 100 px
            y := A_Index - 1, s := 0
            Loop 25 {
                c := NumGet(px, (y * b[3] + x0 + (A_Index - 1) * 4) * 4, "uint")
                s += Max(c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF) > 100
            }
            rows.Push(s)
        }
        sum := 0
        Loop win
            sum += rows[A_Index]
        start := 0
        Loop b[4] - win {                                 ; ковзне вікно, запам'ятовуємо найнижче не затемнене
            if sum / (win * 25) > 0.05
                start := A_Index
            sum += rows[A_Index + win] - rows[A_Index]
        }
        if !start
            continue
        ; клік - у середину клітинки: низ світлої частини (рядки рамки, де світле все, не рахуємо) мінус 80 px
        ; (клітинка ~190 px). Раніше центр вікна падав на нижній край клітинки - клік влучав у затемнену
        ; нижче, "Character has already been used" (29.10 16:23)
        bottom := start
        Loop win
            if (n := rows[start + A_Index - 1]) >= 3 && n < 20
                bottom := start + A_Index - 1
        found := Max(20, bottom - 80)
        if found >= best - 60 {                           ; нижче або той самий ряд (стовпчики йдуть зліва направо)
            best := Max(best, found)
            cx := col, cy := b[2] + found
        }
    }
    return cx != 0
}

; X of the list's scroll thumb: the only light grey vertical strip right of the character cards.
; The window is narrow on purpose (the cards' light borders must stay out); 0 - not found (other UI scale).
FindBarX() {
    b := SPEED_GRID
    x0 := SPEED_BAR_X - 15, w := 45
    px := GrabPixels(x0, b[2], w, b[4])
    col := []
    best := 0
    Loop w {
        x := A_Index - 1, n := 0
        Loop b[4] {
            c := NumGet(px, ((A_Index - 1) * w + x) * 4, "uint")
            r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, bl := c & 0xFF
            if Min(r, g, bl) > 140 && Max(r, g, bl) - Min(r, g, bl) < 40
                n++
        }
        col.Push(n)
        best := Max(best, n)
    }
    if best < 25
        return 0
    first := 0, last := 0
    for i, n in col
        if n >= best * 0.7 {
            first := first ? first : i
            last := i
        }
    return x0 + (first + last) // 2 - 1
}

; no scroll bar found: bottom of the list with the wheel, then up in small steps (the whole list is scanned each time)
PickSpeedCharWheel(&cx, &cy) {
    b := SPEED_GRID
    SpeedWheel("Down", 60)
    Loop 25 {
        if SpeedScan(&cx, &cy) && cy > b[2] + 70
            return true
        SpeedWheel("Up", 3)
    }
    SpeedWheel("Up", 40)
    return SpeedScan(&cx, &cy)
}

SpeedWheel(dir, n) {
    b := SPEED_GRID
    MouseMove b[1] + b[3] // 2 + 8, b[2] + b[4] // 2 + 8, 0
    Sleep 80
    MouseMove b[1] + b[3] // 2, b[2] + b[4] // 2, 0
    Sleep 150
    Loop n {
        Send "{Wheel" dir "}"
        Sleep 30
    }
    Sleep 700
}

; тягне повзунок списку персонажів від y1 до y2 (Roblox рахує клік лише після наведення)
DragBar(y1, y2) {
    x := speedBarX
    MouseMove x + 3, y1 + 3, 0
    Sleep 80
    MouseMove x, y1, 0
    Sleep 150
    Click "Down"
    Sleep 120
    Loop 10 {
        MouseMove x, y1 + (y2 - y1) * A_Index // 10, 0
        Sleep 30
    }
    Sleep 120
    Click "Up"
}

; посилання на приватний сервер: raid.ini [raid] serverLink (порожнє значення - без сервера), інакше сервер автора
PrivateLink() => Trim(IniRead(INI, "raid", "serverLink", SERVER_LINK))

; ID гри для перезапуску: raid.ini [raid] placeId (можна вписати і посилання на гру), інакше Anime Dimensions Simulator
PlaceId() {
    id := IniRead(INI, "raid", "placeId", "6938803436")
    return RegExMatch(id, "\d{5,}", &m) ? m[0] : "6938803436"
}

; Закрити Roblox і зайти в гру знову (протокол roblox://). Повертає true, якщо вікно гри з'явилось.
; mode: "auto" - спершу браузер, потім roblox://; "browser" / "proto" - лише цей спосіб (тест, без паузи 10 min)
; minutes since RobloxPlayerBeta.exe started (also one started before the bot); 0 = not running or not read
RobloxAgeMin() {
    static pid := 0, started := ""
    if !(p := ProcessExist("RobloxPlayerBeta.exe"))
        return 0
    if p != pid {
        pid := p, started := ""
        try for proc in ComObjGet("winmgmts:").ExecQuery("SELECT CreationDate FROM Win32_Process WHERE ProcessId=" p)
            started := SubStr(proc.CreationDate, 1, 14)
    }
    try return started != "" ? DateDiff(A_Now, started, "Minutes") : 0
    return 0
}

RestartRoblox(why, mode := "auto", gap := RESTART_GAP) {
    global lastRestart, fightSince, portraitSig, walkAt, noGameSince, lastFight, raidDoneKey, raidRetryHour
    if mode = "auto" && A_TickCount - lastRestart < gap && lastRestart
        return false
    lastRestart := A_TickCount
    SetStatus("restarting Roblox: " why)
    ; a raid cut off in the fight (freeze, lost connection) gave no tokens: the hour is not "done" - while the raid can
    ; still be created (RAID_WINDOW), the bot goes for a new one after the restart (user, 10.11).
    ; Never after the raid's end screen or rewards were seen: the game allows one raid an hour (user, 10.11), and a raid
    ; can end before minute 10. At most one retry an hour, so a wrong guess costs one attempt.
    if lastEntered = "raid" && fightSince && raidDoneKey = RaidHourKey() && RaidMin() < RAID_WINDOW {
        if raidEndSeen
            Log("  the raid had already ended (end screen / rewards seen) - not trying another this hour")
        else if raidRetryHour = RaidHourKey()
            Log("  the raid was cut off again - one retry an hour, not trying another")
        else {
            raidDoneKey := "", raidRetryHour := RaidHourKey()
            IniWrite raidDoneKey, INI, "state", "raidDoneKey"
            Log("  the raid was cut off at minute " RaidMin() " before its end - trying a new one after the restart")
        }
    }
    Stat("restarts")
    Screenshot("restart")
    ReleaseKeys()
    ; як у WaitGame: перервати, якщо бота зупинили (F2); режими тесту (не auto) не перериваємо
    stopped := () => !(running || mode != "auto")
    if stopped() {
        Log("restart interrupted: bot stopped")
        return false
    }
    ; закриваємо гру, як хрестиком вікна; якщо не закрилась за 10 с - знімаємо процес
    if WinExist(GAME) {
        WinClose GAME
        WinWaitClose GAME, , 10
    }
    while ProcessExist("RobloxPlayerBeta.exe") && A_TickCount - lastRestart < 30000 {
        ProcessClose "RobloxPlayerBeta.exe"
        Sleep 1000
    }
    Sleep 3000
    ; спершу браузер (Join приватного сервера); не відкрилась гра за 60 с - запасний шлях roblox:// (публічний сервер)
    ok := false
    if stopped() {
        Log("restart interrupted: bot stopped")
        return false
    }
    if mode != "proto" && PrivateLink() = "" && JoinFromBrowser() {
        ok := WaitGame(mode = "browser" ? 120000 : 60000, mode)
        if stopped() {
            Log("restart interrupted: bot stopped")
            return false
        }
        if !ok {
            Log("  game did not open after Join")
            Screenshot("join_fail")                       ; що показує браузер (запит "Відкрити Roblox?", помилка)
        }
    }
    if !ok && mode != "browser" {
        id := PlaceId()
        if id = "" {
            Log("RESTART IMPOSSIBLE: game ID unknown (raid.ini [raid] placeId)")
            return false
        }
        if stopped() {
            Log("restart interrupted: bot stopped")
            return false
        }
        link := PrivateLink()
        Log("  launching " (link != "" ? "private server link" : "via roblox://, game " id))
        try Run link != "" ? link : "roblox://experiences/start?placeId=" id
        catch as e {
            Log("  could not launch Roblox: " e.Message)
            return false
        }
        ok := WaitGame(link != "" ? 60000 : 120000, mode)
        if stopped() {
            Log("restart interrupted: bot stopped")
            return false
        }
        ; 02.11 12:17: the share link only opened a roblox.com tab ("Download Roblox") and the game never started for 9 h -> plain roblox:// next
        if !ok && link != "" {
            Log("  private server link did not start the game - trying roblox://, game " id)
            Screenshot("join_fail")
            try Run "roblox://experiences/start?placeId=" id
            ok := WaitGame(120000, mode)
            if stopped() {
                Log("restart interrupted: bot stopped")
                return false
            }
        }
    }
    if !ok {
        Log("  Roblox window never appeared")
        return false
    }
    if stopped() {
        Log("restart interrupted: bot stopped")
        return false
    }
    Sleep 15000                                          ; гра вантажиться
    FixGameWindow()
    Log("  Roblox started again in " (A_TickCount - lastRestart) // 1000 " s")
    fightSince := 0, lastFight := 0, portraitSig := "", walkAt := 0, noGameSince := 0
    return true
}

; чекаємо вікно гри до ms ms (під час роботи бота - лише поки його не зупинили)
WaitGame(ms, mode) {
    t0 := A_TickCount
    while !WinExist(GAME) && A_TickCount - t0 < ms && (running || mode != "auto")
        Sleep 1000
    return WinExist(GAME) != 0
}

; Гра має бути розгорнутим вікном (з рамкою, над панеллю задач) - на це розраховані всі координати.
; Повний екран (F11) і мале вікно виправляємо.
FixGameWindow() {
    static lastFix := 0
    if !WinExist(GAME) || A_TickCount - lastFix < 10000   ; не смикати вікно частіше, ніж раз на 10 с
        return
    lastFix := A_TickCount
    WinActivate GAME
    Sleep 300
    WinGetClientPos , , , &ch, GAME
    if ch >= A_ScreenHeight {                             ; повний екран без рамки - вимикаємо його
        Log("  game opened fullscreen - F11")
        Send "{F11}"
        Sleep 2000
    }
    FitGameWindow()
}

GameSizeOk(cw, ch) => cw = GAME_W && Abs(ch - GAME_H) <= 2
GamePosOk(cx, cy) => cx = GAME_X && Abs(cy - GAME_Y) <= 2

; a normal (not maximised) window with the client area of exactly GAME_W x GAME_H at the top left of the screen
FitGameWindow() {
    if WinGetMinMax(GAME) != 0 {
        WinRestore GAME
        Sleep 600
    }
    Loop 3 {                                              ; borders and the title bar are different on every Windows: measure and correct
        WinGetPos &wx, &wy, &ww, &wh, GAME
        WinGetClientPos &cx, &cy, &cw, &ch, GAME
        WinMove wx + (GAME_X - cx), wy + (GAME_Y - cy), ww + (GAME_W - cw), wh + (GAME_H - ch), GAME
        Sleep 600
    }
    WinGetClientPos &cx, &cy, &cw, &ch, GAME
    Log("  Roblox window set: client " cw "x" ch " at " cx "," cy)
    return GameSizeOk(cw, ch) && GamePosOk(cx, cy)
}

; Сторінка гри в браузері -> перша кнопка Join (приватний сервер). true, якщо натиснули.
JoinFromBrowser() {
    if !WinExist(BROWSER) {
        Log("  browser with the Anime Dimensions page not found")
        return false
    }
    WinActivate BROWSER
    if WinGetMinMax(BROWSER) != 1
        WinMaximize BROWSER
    Sleep 1500
    ; device port: the web page is scaled with Windows (150% -> everything 1.5x bigger) and laid out for a wider screen,
    ; so the button can be anywhere across the page: search the whole width and scale the button size checks.
    ; At 1920x1080 / 100% this is the author's narrow band and offsets exactly.
    k := A_ScreenDPI / 96
    b := A_ScreenWidth = SCR_W && k = 1 ? JOIN_BOX : [0, Round(JOIN_BOX[2] * k), A_ScreenWidth - 1, A_ScreenHeight - 1]
    Loop 2 {
        ; перший темно-синій піксель згори, але лише якщо це кнопка (200x32): той самий колір і правіше, і нижче
        y := b[2], found := false
        while y < b[4] && PixelSearch(&jx, &jy, b[1], y, b[3], b[4], JOIN_COLOR, 12) {
            if SameColor(jx + Round(150 * k), jy + Round(4 * k), JOIN_COLOR, 20) && SameColor(jx + Round(2 * k), jy + Round(26 * k), JOIN_COLOR, 20) {
                found := true
                break
            }
            y := jy + 1
        }
        if found {
            jx += Round(80 * k), jy += Round(15 * k)
            ClickXY(jx, jy)
            ParkMouse()
            Log("  pressed Join in the browser (" jx ", " jy ")")
            return true
        }
        if A_Index = 1 {                                  ; сторінка могла застаріти - оновлюємо і пробуємо ще раз
            Send "{F5}"
            Sleep 10000
        }
    }
    Log("  Join button not found in the browser (is the Servers tab open?)")
    Screenshot("no_join")
    return false
}

SameColor(x, y, color, tol) {
    c := Integer(PixelGetColor(x, y))
    return Abs((c >> 16 & 0xFF) - (color >> 16 & 0xFF)) <= tol && Abs((c >> 8 & 0xFF) - (color >> 8 & 0xFF)) <= tol
        && Abs((c & 0xFF) - (color & 0xFF)) <= tol
}

; відлік "Respawn in N" угорі по центру: обабіч напису дві тонкі білі лінії на висоті y=85..86
; (x 632..840 і 1117..1329; ліва буває на рядок вище за праву). На знімках рейдів 26.10 - лише на кадрах з відліком.
RespawnScreen() {
    px := GrabPixels(660, 84, 640, 5)                     ; рядки 84..88
    lineL := false, lineR := false
    Loop 5 {
        row := (A_Index - 1) * 640 * 4, l := 0, r := 0
        x := 0
        while x < 160 {                                   ; ліва лінія 660..820 і права 1140..1300, кожен 8-й піксель
            c := NumGet(px, row + x * 4, "uint")
            l += (c >> 16 & 0xFF) > 200 && (c >> 8 & 0xFF) > 200 && (c & 0xFF) > 200
            c := NumGet(px, row + (x + 480) * 4, "uint")
            r += (c >> 16 & 0xFF) > 200 && (c >> 8 & 0xFF) > 200 && (c & 0xFF) > 200
            x += 8
        }
        lineL := lineL || l >= 18, lineR := lineR || r >= 18   ; з 20 точок кожної лінії
    }
    return lineL && lineR
}

; ресет потрібен: персонаж без скіла 5 (resetNo5) або третій персонаж (resetThird)
NeedReset() => cfg["resetNo5"] = "1" && NoSkill5() || cfg["resetThird"] = "1" && charIdx >= 3

; Esc-R-Enter: персонаж вмирає, знову виходить перший
ResetNo5() {
    global rdResetNo5, lastNo5Reset, charIdx
    charIdx := 0                                          ; після ресету Respawn дасть першого -> стане 1
    Log("  unwanted character after respawn - resetting to get the first one again")
    Screenshot("unwanted_char")
    SetStatus("character reset: Esc-R-Enter")
    rdResetNo5++
    if lastNo5Reset && A_TickCount - lastNo5Reset < 20000
        Log("WARNING: two characters without skill 5 in a row - check the loadout")
    lastNo5Reset := A_TickCount
    if rdResetNo5 > 3
        Log("WARNING: too many resets without skill 5 (" rdResetNo5 " per raid)")
    HoldKey("Esc")
    Sleep 1000
    HoldKey("r")
    Sleep 800
    HoldKey("Enter")
}

; У персонажа немає скіла 5: замість ромба (готовий - рожевий/фіолетовий, перезарядка - сірий) крізь слот
; видно підлогу рейду - яскраву помаранчеву/червону без синього або жовту лаву (див. SkillReady)
NoSkill5() {
    c := SkillColor("5")
    r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
    return Max(r, g, b) - Min(r, g, b) > READY_SAT && (b < 40 || g > 110)
}

; майже весь екран чорний (сітка 5x5 точок темніша за 12)
BlackScreen() {
    Loop 5 {
        x := SCR_W * A_Index // 6                         ; device port: the game area, not the desktop around it
        Loop 5 {
            c := Integer(PixelGetColor(x, SCR_H * A_Index // 6))
            if (c >> 16 & 0xFF) > 12 || (c >> 8 & 0xFF) > 12 || (c & 0xFF) > 12
                return false
        }
    }
    return true
}

; відводимо курсор у порожнє місце, щоб кнопки меню не підсвічувались від наведення
ParkMouse() {
    MouseMove 300, SCR_H // 2, 0
}

PngSize(file) {
    f := FileOpen(file, "r")
    f.Pos := 16
    w := DllCall("ws2_32\ntohl", "UInt", f.ReadUInt(), "UInt")
    h := DllCall("ws2_32\ntohl", "UInt", f.ReadUInt(), "UInt")
    f.Close()
    return [w, h]
}

; Бій: одна дія за тік. Під час комбо спамимо скіл комбо,
; інакше тиснемо перший готовий увімкнений скіл за порядком, а якщо готових немає - M1.
Fight() {
    global comboUntil, lockUntil, lastCast, farPress, spreadNext, spreadTry
    ; рухатись можна лише поза комбо і поза анімацією скілів, що блокують рух (4, 5):
    ; інакше крок "з'їдається", і персонаж збивається з маршруту
    canMove := A_TickCount >= comboUntil && A_TickCount >= lockUntil
    ; v0.3: в Infinity завжди стоїмо на місці (Patrol і Turn прибрані) - вороги самі йдуть під великі AOE
    ; помічники (E R Z X) не залежать від основних скілів і працюють навіть під час анімацій,
    ; тож тиснемо кожен, щойно він готовий - на кожному тіку, окремо від порядку 1-5
    ; В Infinity великі AOE (spread: 5 4 E R X) не тиснемо всі разом, а по одному: наступний - коли попередній
    ; відпрацював (spreadMs, для 5 - 10 с зі spreadDur), щоб AOE було весь час. Скіли поза списком (3 Z 2 1, M1) -
    ; як завжди, щойно готові - ними б'ємо, поки великий AOE діє.
    ; spreadKey - чия черга зараз ("" = нікого зі списку зараз не тиснемо).
    spreadKey := ""
    ; бос minилі в Infinity (смуга HP угорі) - паузи між AOE лише шкодять: усе одразу, як готове
    spread := !BossFight() && !InfBoss() ? " " cfg["spread"] " " : "  "
    if spread != "  " && A_TickCount >= spreadNext
        spreadKey := NextSpread()
    ; малі AOE (infSmall: 3 Z) не чіпаємо, поки великий AOE діє або якийсь великий готовий - лише коли всі на перезарядці
    hold := spread != "  " && (A_TickCount < spreadNext || spreadKey != "") ? " " cfg["infSmall"] " " : "  "
    assists := " " cfg["assists"] " "
    for key in StrSplit(cfg["assists"], " ")
        if key != "" && SKILL_POS.Has(key) && SkillOn(key) && (!InStr(spread, " " key " ") || key = spreadKey)
                && !InStr(hold, " " key " ")
                && SkillReady(key) {
            Send "{" key "}"
            FightLog("assist", "  assist " key)
            if key = spreadKey {
                ; чекаємо, поки AOE діє, лише якщо помічник справді вийшов. Іконка помічника сіріє повільніше
                ; за скіли 1-5 (28.10: за 0.45 с E жодного разу не зарахувався, і одразу йшов R) - дивимось до 1.5 с.
                ; Не посіріла - повтор за 1.5 с; 3 рази поспіль - вважаємо, що вийшов (щоб не застрягти на ньому).
                t0 := A_TickCount
                while SkillReady(key) && A_TickCount - t0 < 1500
                    Sleep 150
                if !SkillReady(key) || ++spreadTry >= 3 {
                    if spreadTry >= 3
                        FightLog("AOE not greyed", "  AOE " key ": icon did not grey out 3 times - assuming it fired")
                    spreadTry := 0
                    SpreadDone(key)
                } else {
                    FightLog("AOE " key " failed", "  AOE " key " failed - again in 1.5 s")
                    spreadNext := A_TickCount + 1500
                }
                spreadKey := ""
            }
        }
    comboOn := false                                                  ; v0.3: комбо прибране
    if A_TickCount < comboUntil && comboOn && cfg["comboSpam"] != "" {
        ; комбо: тримаємо клавішу затиснутою до кінця комбо (весь час, без перерв на інші перевірки)
        ; і кожні 50 ms шлемо повтор "натиснуто" - як фізична клавіша при утриманні
        k := cfg["comboSpam"]
        SetStatus("combo: holding " k, "combo")
        SetKeyDelay -1, -1
        Send "{" k " down}"
        while A_TickCount < comboUntil && running {
            Sleep 50
            Send "{" k " down}"
        }
        Send "{" k " up}"
        SetKeyDelay 30, 30
        return
    }
    LearnCooldowns()
    order := lastEntered = "speed" ? SPEED_ORDER : cfg["order"]
    for key in StrSplit(order, " ") {
        if key = "" || !SKILL_POS.Has(key) || !SkillOn(key) || InStr(assists, " " key " ")
            continue
        if skillSkip.Get(key, 0) > A_TickCount
            continue
        if InStr(spread, " " key " ") && key != spreadKey          ; Infinity: не його черга
            continue
        if InStr(hold, " " key " ")                                ; Infinity: малий AOE, а великий діє/готовий
            continue
        if SkillReady(key) {
            SetStatus("skill " key, "skill " key)
            ; персонаж зайнятий (анімація скіла 4/5 або щойно спрацював інший скіл) - натискання може "з'їстись",
            ; такий промах не рахуємо як порожній слот (інакше готовий скіл пропускався б 20 s left)
            ; (+2 с запасу: анімація 4 і комбо довші за lockMs - 28.10 у логах "1/2 не спрацював" майже завжди
            ; одразу після 4 чи комбо, і робочий скіл пропускався на 20 с; порожній слот не спрацьовує й поза цим)
            busyNow := A_TickCount < lockUntil + 2000 || A_TickCount - lastCast < 2500 || A_TickCount < comboUntil + 1500
            tSend := A_TickCount
            Send "{" key "}"
            if InStr(" " cfg["lockSkills"] " ", " " key " ")
                lockUntil := A_TickCount + Num("lockMs", 2500)
            ; комбо (затиснути 1 після 3) - завжди одразу після натискання: перевірка іконки в RDP запізнюється,
            ; і через неї комбо раніше часто не запускалось (28.10: ~600 разів на 2000 натискань 3)
            if comboOn && key = cfg["comboKey"]
                comboUntil := A_TickCount + Num("comboMs", 3000)
            ; чи скіл справді спрацював (пішов на перезарядку); у RDP іконка часом сіріє повільніше - ще одна перевірка
            Sleep 150
            if SkillReady(key)
                Sleep 300
            if !SkillReady(key) {
                lastCast := A_TickCount
                castAt[key] := tSend, castExact[key] := true      ; від цього моменту рахуємо перезарядку
                if Knockback() && (key = "1" || key = "2")
                    farPress := tSend                             ; перевірка "чи влучили" - у Step
                if key = spreadKey
                    SpreadDone(key)
                skillFails[key] := 0
            } else if !busyNow {
                skillFails[key] := skillFails.Get(key, 0) + 1
                FightLog("failed " key, "  " key " did not fire")
                if skillFails[key] >= SKILL_FAILS {
                    ; порожнім буває лише слот 5 (персонаж без пробудження); 1-4 є завжди, а "не спрацював" у них -
                    ; відкинуло, оглушило чи анімація (28.10: 1/2 пропускались на 20 с ~2 рази на minилину) - коротка пауза
                    skip := key = "5" ? SKILL_SKIP : SKILL_SKIP_SHORT
                    skillFails[key] := 0
                    skillSkip[key] := A_TickCount + skip
                    Log("  " key " " SKILL_FAILS " times in a row did not fire" (key = "5" ? " (empty slot?)" : "") " - skipping " skip // 1000 " s")
                }
            }
            return
        }
    }
    ; готових нема: скіл, якому до кінця перезарядки <= 2 с (як "2" на іконці), тиснемо щотіку -
    ; гра запустить його в ту ж мить, як він звільниться
    if PrimeSkill(order, assists, spread SubStr(hold, 2))
        return
    if cfg["m1"] = "1" {
        SetStatus("M1", "M1")
        MouseMove SCR_W // 2, SCR_H // 2, 0   ; щоб не клікнути по вікну бота
        Click
    } else
        SetStatus("all skills on cooldown")
}

; Перезарядка кожного скіла вчиться сама: від натискання до того, як іконка знову стала кольоровою
; (беремо найменше з виміряного - тік бота може запізнитись). Вимірюємо лише від точного моменту натискання.
LearnCooldowns() {
    for key, t in castAt.Clone() {
        if !SkillReady(key)
            continue
        if castExact[key] {
            ms := A_TickCount - t
            if ms > 1500 && ms < 120000 && (!skillCd.Has(key) || ms < skillCd[key]) {
                if !skillCd.Has(key) || skillCd[key] - ms > 500
                    Log("  cooldown " key ": " Round(ms / 1000, 1) " s")
                skillCd[key] := ms
            }
        }
        castAt.Delete(key)
    }
}

PrimeSkill(order, assists, spread) {
    global comboUntil, lastCast
    static comboFor := 0                                  ; для якого натискання 3 комбо вже запущено
    for key in StrSplit(order, " ") {
        if key = "" || !castAt.Has(key) || !skillCd.Has(key) || !SkillOn(key) || InStr(assists, " " key " ")
                || InStr(spread, " " key " ") || skillSkip.Get(key, 0) > A_TickCount
            continue
        left := castAt[key] + skillCd[key] - A_TickCount
        if left > 2000
            continue
        if left < -1500 {                                 ; вікно минуло, а скіл сірий - спрацював від нашого натискання
            castAt[key] += skillCd[key], castExact[key] := false
            continue
        }
        SetStatus("skill " key ": pressing early (" Round(Max(0, left) / 1000, 1) " s left)", "early")
        Send "{" key "}"
        ; перезарядка скінчилась - натиснутий наперед скіл саме зараз спрацьовує. Для 3 одразу комбо (затиснути 1),
        ; як після звичайного натискання: інакше комбо після 3 "наперед" не запускалось, а 1 тиснувся посеред
        ; анімації 3 і "не спрацьовував" (28.10 23:01)
        if left <= 0 {
            lastCast := A_TickCount
            if false && key = cfg["comboKey"] && comboFor != castAt[key] {   ; v0.3: комбо прибране
                comboFor := castAt[key]
                comboUntil := A_TickCount + Num("comboMs", 3000)
            }
        }
        return true
    }
    return false
}

; Infinity: на екрані смуга HP боса minилі (та сама, що в рейді: фіолетова, line y=188, лівий край x~785).
; 29.10: забіги закінчувались на minилях 150-160 - бос за 30 с двічі вбивав персонажа, а сам лишався з 25% HP,
; поки великі AOE чекали своєї черги по 7-10 с. Перевірка - 3 точки біля лівого краю, раз на 0.5 с.
InfBoss() {
    static at := 0, was := false
    if lastEntered != "infinity" || cfg["infBossBurst"] != "1"
        return false
    if A_TickCount - at < 500
        return was
    at := A_TickCount
    n := 0
    for x in [792, 800, 808] {
        c := PixelGetColor(x, 188)
        r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
        if b >= 200 && r >= 140 && r <= 235 && g >= 60 && g <= 160 && b - g > 80
            n++
    }
    now := n >= 3
    if now && !was
        FightLog("wave boss", "  Infinity: wave boss - all AOE at once")
    return was := now
}

; з готових скілів spread - той, що найдовше не спрацьовував (на початку - за порядком списку: 5 4 E R X).
; Раніше черга йшла строго по колу, і скіл, не готовий саме у свою чергу (E після 4), чекав ціле коло.
NextSpread() {
    best := "", bestAt := 0
    for key in StrSplit(Trim(cfg["spread"]), " ")
        if key != "" && SKILL_POS.Has(key) && SkillOn(key) && skillSkip.Get(key, 0) <= A_TickCount && SkillReady(key) {
            at := spreadUsed.Get(key, 0)
            if best = "" || at < bestAt
                best := key, bestAt := at
        }
    return best
}

; скіл зі spread спрацював: у кінець черги, а поки він діє (spreadMs або spreadDur) - пауза
SpreadDone(key) {
    global spreadNext
    spreadUsed[key] := A_TickCount
    ms := Num("spreadMs", 7000)
    for pair in StrSplit(cfg["spreadDur"], " ")
        if (kv := StrSplit(pair, ":")).Length = 2 && kv[1] = key && IsNumber(kv[2])
            ms := Round(kv[2] * 1000)
    spreadNext := A_TickCount + Min(ms, 30000)
    FightLog("AOE " key, "  AOE " key ": next in " ms // 1000 " s")
}

; Розвертає персонажа коротким натисканням клавіші руху по колу W, D, S, A (рух відносно камери),
; щоб скіли по черзі били в усі боки. Шукати смужки HP ворогів тут не можна: фіолетова мапа
; Infinity дає тисячі хибних збігів кольору.
TurnToEnemy() {
    global lastTurn, turnIdx
    lastTurn := A_TickCount
    turnIdx := Mod(turnIdx, 4) + 1
    key := ["w", "d", "s", "a"][turnIdx]
    SetStatus("turning " StrUpper(key), "turn")
    Send "{" key " down}"
    Sleep TURN_TAP
    Send "{" key " up}"
}

HoldKey(k, ms := 120) {
    Send "{" k " down}"
    Sleep ms
    Send "{" k " up}"
}

; "Відбиток" портрета: колір кожної точки, огрублений до 4 рівнів на канал (щоб легке світіння рамки
; не заважало), рядком "rgb,rgb,...".
ReadPortrait() {
    sig := ""
    for p in PORTRAIT_PTS {
        c := Integer(PixelGetColor(p[1], p[2]))
        sig .= ((c >> 22) & 3) "" ((c >> 14) & 3) "" ((c >> 6) & 3) ","
    }
    return sig
}

; Смерть/респавн: портрет змінився (4+ з 7 точок) і новий тримається 1.5 с -> вийшов наступний персонаж.
; У рейді через respawnWait підемо вперед до боса, в Infinity маршрут патруля почнеться знову з центру.
CheckRespawn() {
    global portraitSig, portraitNew, portraitSince, walkAt, patrolIdx, rdChanges, no5Pending, charIdx
    s := ReadPortrait()
    if portraitSig = "" {
        portraitSig := s
        return
    }
    a := StrSplit(s, ","), b := StrSplit(portraitSig, ",")
    diff := 0
    for i, v in a
        if v != b[i]
            diff++
    if diff < 4 {
        portraitNew := ""
        return
    }
    if portraitNew != s {                    ; новий відбиток - перевіряємо, чи він стабільний
        portraitNew := s, portraitSince := A_TickCount
        return
    }
    if A_TickCount - portraitSince < 1500
        return
    portraitSig := s, portraitNew := ""
    ; на початку бою відбиток ще з лобі/завантаження - це не смерть (29.10 17:01: "змінився персонаж" через 4 с
    ; після старту -> поворот камери на 95° від боса). Справжня смерть у перші 15 с - побачимо по відліку Respawn
    if fightSince && A_TickCount - fightSince < 15000 {
        Log("  portrait at fight start - remembered (not a death)")
        return
    }
    Log("character changed (death/respawn)")
    Stat("deaths")
    rdChanges++
    ; поки персонаж був мертвий, скіли "не спрацьовували" - у нового персонажа всі скіли знову доступні
    skillFails.Clear(), skillSkip.Clear()
    if lastEntered = "raid" {
        if A_TickCount - lastRespawnAt > 8000            ; респавн уже оброблено по відліку Respawn - вдруге не йдемо
            walkAt := A_TickCount + Min(Num("respawnWait", 3000), 20000)
        else
            no5Pending := true                           ; але скіл 5 нового персонажа перевіримо
    } else
        patrolIdx := 0
}

; Маршрут по арені. Персонаж з'являється в центрі; спершу один відрізок угору (до краю),
; далі по квадрату довкола центру: вправо, 2 вниз, 2 вліво, 2 вгору, вправо - і знову.
; Камера не обертається, тож W/A/S/D завжди ті самі напрямки на екрані. Маршрут - PATROL_ROUTE угорі.
Patrol() {
    global lastPatrol, patrolIdx
    lastPatrol := A_TickCount
    patrolIdx := patrolIdx = 0 ? 1 : patrolIdx >= PATROL_ROUTE.Length ? 2 : patrolIdx + 1
    key := PATROL_ROUTE[patrolIdx]
    SetStatus("patrol: walking " StrUpper(key) " (step " patrolIdx ")", "patrol")
    Send "{" key " down}"
    Sleep Min(Num("patrolWalk", 1000), 5000)
    Send "{" key " up}"
}

; колір точки скіла. Панель скілів знімаємо одним знімком (GrabPixels) і тримаємо 40 ms - у межах тіку:
; PixelGetColor на кожну з 9 точок окремо в RDP повільний. Після натискання бот чекає 150+ ms - знімок свіжий.
SkillColor(key, dx := 0, dy := 0) {
    static px := 0, at := 0
    b := SKILL_BAR, p := SKILL_POS[key]
    if !px || A_TickCount - at > 40
        px := GrabPixels(b[1], b[2], b[3], b[4]), at := A_TickCount
    return NumGet(px, ((p[2] + dy - b[2]) * b[3] + p[1] + dx - b[1]) * 4, "uint") & 0xFFFFFF
}

; Помічники (E R Z X): перезарядка - сірий ромб (~55-77, без кольору) з білим числом, готовий - портрет.
; Портрет буває майже весь темний (28.10: E в loadout 2 - чорний одяг і темно-червоне, насиченість <= 26,
; і бот жодного разу не тиснув E в Infinity), тому шукаємо не "кольорове", а "не сіре": точка кольорова
; (насиченість > 20) або темна (усі канали < 40). Таких 3+ з 5 - готовий. На 40 знімках: перезарядка 0 з 5, готовий 5 з 5.
SkillReady(key) {
    static ASSIST_PTS := [[0, 0], [0, -20], [-12, -12], [12, -12], [0, -30]]
    if !IsDigit(key) {
        n := 0
        for d in ASSIST_PTS {
            c := SkillColor(key, d[1], d[2])
            r := c >> 16 & 0xFF, gg := c >> 8 & 0xFF, b := c & 0xFF
            if Max(r, gg, b) - Min(r, gg, b) > 20 || Max(r, gg, b) < 40
                n++
        }
        return n >= 3
    }
    c := SkillColor(key)
    r := c >> 16 & 0xFF, gg := c >> 8 & 0xFF, b := c & 0xFF
    ; ромби скілів 1-5: готовий - рожево-коричневий (122,67,59) або фіолетовий (128,78,140), перезарядка - сірий.
    ; У персонажа без скіла 5 крізь порожній слот видно підлогу рейду - помаранчеву/червону, майже без синього
    ; (108,34,0), (255,54,0), або жовту лаву (255,230,125). Таку "готовність" не рахуємо.
    if b < 40 || gg > 110
        return false
    return Max(r, gg, b) - Min(r, gg, b) > READY_SAT
}

; Roblox's own "Disconnected / Leave / Reconnect" dialog, strict words only (no bare "connection": this runs in every state)
DisconnectDialog() {
    txt := OcrRegion(DISCONNECT_BOX)
    if RegExMatch(txt, "i)disconnected|reconnect|error code") {
        Log("  Disconnected dialog: " StrReplace(Trim(txt), "`n", " | "))
        return true
    }
    return false
}
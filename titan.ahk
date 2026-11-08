; titan.ahk - Titan farming: the Giant Dimension on Nightmare, played by the bot because Dimensions have no AUTO button.
; Observed 8.11: 11 enemies at the start, a second wave, 5 titans in a row at the top of the stairs, then one boss ("Plated Giant")
; shown with a purple HP bar and its distance ("443m") under it. A 10:00 timer; when it runs out: F rank, RETRY / LEAVE, lobby.
; Opening moves come from the user's Guts4.txt recording (key timing from second 21 of the file).

titanHudReset := true                             ; the 25 s without the HUD count from the start of a run
titanBossHit := 0                                 ; last time the boss was seen below full HP
titanArmed := 0                                   ; A_TickCount of Start / RETRY: the next fight is a fresh Titan run

; The walking of the user's Guts4.txt, cut into legs: [key, ms, dashes at these ms of the leg]. The game lags and enemies spawn late
; (8.11: the counter read 0, then 13 a few seconds later, and the bot had already left), so every leg ends with TitanClear.
TITAN_LEGS := [["w", 5720, []], ["d", 4370, []], ["w", 3660, []], ["a", 6300, []], ["a", 6310, [4700, 5120, 5660]],
    ["a", 7000, [1760, 5790, 6220, 6860]], ["a", 7000, [2110, 3620]], ["a", 7560, []], ["a", 2150, []], ["a", 3950, []],
    ["a", 5560, []], ["a", 1760, []], ["d", 280, []], ["a", 270, []], ["a", 1050, []], ["a", 3200, [1830, 2080]], ["d", 550, []]]
TITAN_STEADY := 12000                             ; ENEMIES LEFT unchanged this long = this part is finished
TITAN_CLEAR_MAX := 45000
; EnemiesSig() of each count, from 620 recorded frames (the digits are drawn identically every time; 12 and 13 share a print)
TITAN_COUNTS := Map("33,17,30,23,14", "0", "15,20,26,24,12", "1", "28,18,29,23,14", "2", "28,17,29,23,13", "3", "26,17,31,24,14", "4",
    "29,18,29,23,13", "5", "33,18,31,24,14", "6", "25,18,30,24,11", "7", "36,17,30,23,14", "8", "33,18,30,24,13", "9",
    "48,12,35,24,13", "10", "30,15,30,23,12", "11", "44,13,34,24,13", "12-13")
TITAN_ZERO_WAIT := 7000                           ; 0 left for this long = really finished; 8.11 the next 13 came about 4 s after a 0
TITAN_SKILLS := ["2", "1", "3", "4", "5", "e", "r", "z", "x"]   ; 2 first: the big AOE of loadout 2
TITAN_MAX := 640000                               ; the game's timer is 10:00

; Detail window of a dimension (Create visible): must be Giant Dimension on Nightmare. One step per tick.
TitanCreate(x, y) {
    global lastCreate
    if !InStr(OcrRegion([1070, 350, 190, 34]), "Giant") {
        SetStatus("Titan: wrong dimension open, going back to the list")
        ClickXY(1164, 776)
        ParkMouse()
        Sleep 1500
        return
    }
    diff := cfg["titanDiff"], rowY := diff = "Easy" ? 602 : diff = "Hard" ? 653 : 700
    if !InStr(OcrRegion([1120, 412, 140, 30]), diff) {
        SetStatus("Titan: choosing " diff)
        ClickXY(808, rowY)
        ParkMouse()
        Sleep 1000
        if !InStr(OcrRegion([1120, 412, 140, 30]), diff)
            return
    }
    ; Hardcore sits one row (82 px) above Friends Only, same switch
    static hardAt := 0
    wantOff := cfg["titanHard"] != "1", isOff := FriendsOff(x, y - 82)
    if wantOff != isOff && A_TickCount - hardAt > 20000 {
        hardAt := A_TickCount
        SetStatus("Titan: Hardcore " (wantOff ? "off" : "on"))
        ClickXY(x - 90, y + 25 - 82)
        ParkMouse()
        Sleep 800
        Log("  Titan: Hardcore now " (FriendsOff(x, y - 82) ? "OFF" : "ON"))
        return
    }
    SetStatus("Titan: pressing Create")
    ClickImg("create_final.png", x, y)
    ParkMouse()
    lastCreate := A_TickCount
    Sleep 1500
}

PickTitan() {
    static retryAt := 0
    if A_TickCount < retryAt
        return false
    if PickRaidByName(["", 0, "Giant Dimension", "i)Giant"], false)
        return true
    retryAt := A_TickCount + 30000
    return false
}

; the purple HP bar of the boss: its left end stays full longest
TitanBossBar() {
    n := 0
    for x in [790, 805, 820] {
        c := Integer(PixelGetColor(x, 197))
        r := c >> 16 & 0xFF, g := c >> 8 & 0xFF, b := c & 0xFF
        n += b > 225 && g < 125 && r > 130 && r < 200
    }
    return n >= 2
}

; the respawn point at the two pillars before the stairs (camera fixed after a respawn; sampled on 5 frames, 5 others differ)
TitanPillars() {
    Dark(x, y) {
        c := Integer(PixelGetColor(x, y))
        return (c >> 16 & 0xFF) < 100 && (c >> 8 & 0xFF) < 100
    }
    Loop 8 {
        c := Integer(PixelGetColor(960, 110))
        if Dark(1600, 500) && Dark(1560, 300) && (c >> 16 & 0xFF) > 190
            return true
        Sleep 400
    }
    return false
}

; distance to the boss in metres, -1 if not read
TitanBossDist() => RegExMatch(OcrRegion([880, 210, 160, 40]), "(\d+)\s*m", &m) ? Integer(m[1]) : -1

; the dark Time diamond of the fight HUD: 4 points around its text. Checked on 200 fight frames incl. white flashes; lobby and menus differ
TitanHud() {
    n := 0
    for p in [[1795, 880], [1795, 958], [1757, 922], [1833, 922]] {
        c := Integer(PixelGetColor(p[1], p[2]))
        hi := Max(c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF), lo := Min(c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF)
        n += hi >= 32 && hi < 90 && hi - lo <= 16        ; neutral grey: the dimmed menus are darker or tinted (8.11: a menu counted as a fight)
    }
    return n >= 3
}

; 8.11: the basic attack clicks where the mouse is; parked on the title bar the clicks were double-clicks and maximized Roblox,
; which moved the whole HUD. So the mouse stays over the game, and a changed window is put back at once.
TitanMouse() {
    MouseGetPos &mx, &my
    if Abs(mx - 960) > 60 || Abs(my - 500) > 60
        MouseMove 960, 500, 0
    if WinGetMinMax(GAME) != 0 {
        Log("  Titan: Roblox window was maximized - putting it back")
        ReleaseKeys()
        FitGameWindow()
    }
}

; Shift Lock (user, 8.11): "forward" follows the camera, so skills that turn the character cannot bend the route. It also holds the
; cursor at the middle of the window, which is how it is detected: a 12 px nudge comes back to the middle. The nudge is undone.
TitanLocked() {
    WinGetClientPos &cx, &cy, &cw, &ch, GAME
    mx := cx + cw // 2, my := cy + ch // 2
    MouseMove mx, my, 0
    Sleep 150
    MouseMove mx + 12, my, 0
    Sleep 300
    MouseGetPos &x, &y
    locked := Abs(x - mx) <= 4
    if locked
        MouseMove mx - 12, my, 0
    return locked
}

TitanLock(want) {
    if !WinExist(GAME)
        return
    try WinActivate GAME
    Sleep 100
    if TitanLocked() != want {
        Send "{LShift down}"
        Sleep 120
        Send "{LShift up}"
        Sleep 700
        Log("  Titan: Shift Lock " (want ? "on" : "off"))
    }
}

; The distance pill ("222m") floats over the target. Read it in a left, middle and right part of the screen and turn the camera
; toward it (8.11: walking straight ahead cost 6 min against a house wall). Not read = keep the direction (it may hide behind the name).
TitanSteer() {
    static zones := [[520, 100, 310, 170, -25], [1090, 100, 530, 170, 25]]
    for z in zones {
        if RegExMatch(OcrRegion([z[1], z[2], z[3], z[4]]), "\b(\d{2,4})\s*m\b", &m) {
            Log("  Titan: marker " m[1] " m on the " (z[5] < 0 ? "left" : "right") " - turning")
            px := Round(z[5] / 45 * CamPx()), n := Max(1, Abs(px) // 60)     ; Shift Lock: plain mouse movement turns the camera
            Loop n {
                DllCall("mouse_event", "uint", 1, "int", px // n, "int", 0, "uint", 0, "ptr", 0)
                Sleep 15
            }
            return true
        }
    }
    return false
}

; "" = still playing, "results" = RETRY / LEAVE, "lobby" = back in the lobby
TitanOver() {
    static playN := 0, at := 0, hudAt := 0
    ; 8.11 14:41: the run ended, the lobby came up in another window size so PLAY was not seen, and the bot "fought" in the
    ; lobby for 3 min. The ENEMIES LEFT panel is drawn over every effect: gone for 25 s = the run is over.
    h := ENEMIES_HOME
    if titanHudReset || TitanHud() || FindImg("enemies_left.png", &ex, &ey, h[1] - 12, h[2] - 12, h[1] + 66, h[2] + 38, "*80 *TransFF00FF") {
        hudAt := A_TickCount
        global titanHudReset := false
    } else if A_TickCount - hudAt > 25000
        return "gone"
    ; 8.11: leave.png is Infinity's picture and never matched here. The results screen dims the red count, so it is read only then
    static resAt := 0
    if EnemiesSig() = "" && A_TickCount - resAt > 1000 {
        resAt := A_TickCount
        txt := OcrRegion([700, 720, 700, 80])
        if InStr(txt, "RETRY") && InStr(txt, "LEAVE")
            return "results"
    }
    ; 8.11 19:35: PLAY matched on a bright floor, a false "lobby" in the middle of a run. The HUD rules that out
    if !TitanHud() && FindImg("play.png", &x, &y, 1500, 800, 1920, 1060) {
        if A_TickCount - at > 3000
            playN := 0
        at := A_TickCount
        if ++playN >= 3
            return (playN := 0, "lobby")
    } else
        playN := 0
    return ""
}

TitanCount() => TITAN_COUNTS.Get(EnemiesSig(), "?")

; "Game ends in N, Revive to continue": REVIVE costs 50 gems and attack clicks land mid-screen, so no click goes out while it shows
TitanRevive() {
    static at := 0, seen := false
    if A_TickCount - at < 700
        return seen
    at := A_TickCount
    seen := RegExMatch(OcrRegion([300, 150, 1320, 760]), "i)revive|game ends") > 0
    if seen
        Log("  Titan: Revive screen - no clicks")
    return seen
}

; waits ms; false as soon as the bot is stopped or the run is over
TitanWait(ms, &over) {
    t := A_TickCount
    while A_TickCount - t < ms {
        if !running
            return false
        if !WinActive(GAME) {
            ReleaseKeys()
            try WinActivate GAME
        }
        over := TitanOver()
        if over != ""
            return false
        Sleep 150
    }
    return true
}

; 8.11 (user): skills and basic attacks turn the character toward enemies, so "forward" changes and it walks into walls.
; Until the boss is really being hit only skill 2 and the assists are used; the whole kit once it takes damage.
TitanAttack(&over) {
    TitanMouse()
    full := A_TickCount - titanBossHit < 10000
    for k in full ? TITAN_SKILLS : ["2", "e", "r", "z", "x"] {
        if !running
            return false
        Send "{" k " down}"
        Sleep 60
        Send "{" k " up}"
        Sleep 40
        if full && !TitanRevive()
            Click
        Sleep 40
    }
    over := TitanOver()
    return over = ""
}

TitanReset() {
    if TitanRevive()                                  ; Enter would press the selected button
        return
    HoldKey("Esc", 150)
    Sleep 1000
    HoldKey("r", 150)
    Sleep 800
    HoldKey("Enter", 150)
}

; stands and uses skill 2 and the assists (they do not move the character, so the route stays true) until the count holds steady
TitanClear(&over) {
    sig := "", sameAt := A_TickCount, t1 := A_TickCount, cap := TITAN_CLEAR_MAX, zeroAt := 0
    while running && A_TickCount - t1 < cap && A_TickCount - sameAt < TITAN_STEADY {
        TitanMouse()
        n := EnemiesSig()
        if n != "" && n != sig
            sig := n, sameAt := A_TickCount
        if TITAN_COUNTS.Get(n, "") = "0" {
            if !zeroAt
                zeroAt := A_TickCount
            else if A_TickCount - zeroAt >= TITAN_ZERO_WAIT
                return true
        } else if n != ""
            zeroAt := 0
        for k in ["2", "e", "r", "z", "x"] {          ; no basic attack: it turns the character, and Revive sits mid-screen
            Send "{" k " down}"
            Sleep 60
            Send "{" k " up}"
            Sleep 50
        }
        over := TitanOver()
        if over != ""
            return false
        if TitanBossHurt()                            ; its count stays 1, so a steady count says nothing: stay until it is dead
            sameAt := A_TickCount, cap := 150000
        Sleep 350
    }
    return running
}

; 8.11: the boss bar appears at leg 5 of 17 and the boss dies around leg 6; the next stage (13 more) follows at the same spot and
; the remaining legs lead on from there. So the route is never cut short by the boss: TitanClear stays while it takes damage.
TitanBossHurt() {
    global titanBossHit
    if !TitanBossBar()
        return false
    if RegExMatch(OcrRegion([880, 182, 220, 32]), "([\d,]+)\s*/\s*([\d,]+)", &m) && m[1] != m[2] {
        titanBossHit := A_TickCount
        return true
    }
    return false
}

TitanOpening(&over) {
    for i, leg in TITAN_LEGS {
        if !running
            return false
        SetStatus("Titan: route leg " i "/" TITAN_LEGS.Length)
        t0 := A_TickCount
        Send "{" leg[1] " down}"
        for d in leg[3] {
            while A_TickCount - t0 < d
                Sleep 10
            Send "{q down}"
            Sleep 80
            Send "{q up}"
        }
        while A_TickCount - t0 < leg[2]
            Sleep 10
        Send "{" leg[1] " up}"
        if leg[2] < 1500                              ; small corrections: no need to stop
            continue
        SetStatus("Titan: clearing after leg " i)
        if !TitanClear(&over)
            return false
        Log("  Titan: leg " i " done, " TitanCount() " left (" (A_TickCount - t0) // 1000 " s at this stop)")
    }
    return true
}

; walk at the boss until it is close; distance is re-read while walking. false if the run ended
TitanWalk(&over) {
    SetStatus("Titan: walking to the boss")
    Send "{w down}"
    last := 99999, same := 0, lost := 0, t0 := A_TickCount
    while running && A_TickCount - t0 < 45000 {
        over := TitanOver()
        if over != ""
            break
        if !TitanBossBar() && ++lost >= 6
            break
        d := TitanBossDist()
        if d >= 0 {
            lost := 0
            if d <= 18
                break
            same := d >= last - 1 ? same + 1 : 0
            last := d
            if same >= 3 {                            ; stuck on something: dash and jump
                Log("  Titan: stuck at " d " m, dashing")
                Send "{q down}"
                Sleep 80
                Send "{q up}"
                Send "{Space down}"
                Sleep 150
                Send "{Space up}"
                same := 0
            }
        }
        Sleep 200
    }
    Send "{w up}"
    return running && over = ""
}

; One run, start to end. fresh = the bot pressed Start or RETRY itself, so the character is at the spawn
TitanRun(fresh) {
    global titanArmed, lastFight, fightSince, infDrop, titanBossHit
    titanBossHit := 0
    global titanHudReset := true
    titanArmed := 0, infDrop := false, over := ""
    t0 := A_TickCount
    MouseMove 960, 500, 0
    TitanLock(true)
    Log("Titan: run begins" (fresh ? "" : " (already in progress - no route)"))
    ReleaseKeys()
    try {
        if fresh {
            SetStatus("Titan: opening route")
            Sleep 800
            if !TitanOpening(&over) && over = ""
                return
            Log("  Titan: route done at " (A_TickCount - t0) // 1000 " s" (TitanBossHurt() ? ", boss in reach" : ""))
        }
        ; The game moves the respawn point forward as the run progresses. Boss bar up (only the boss is left) -> walk to it and
        ; fight. No bar -> reset; from the pillars respawn the straight bridge leads through the last group to the boss.
        noBar := A_TickCount - (fresh ? 0 : 60000), bossHitAt := 0, bossSeenAt := 0, bossLogged := false, resets := cfg["titanHard"] = "1" ? 2 : 99
        while running && over = "" && A_TickCount - t0 < TITAN_MAX {
            if TitanBossBar() {
                noBar := A_TickCount
                ; the distance pill overlaps the boss name and cannot be read; the HP can: full HP = not in reach yet, walk on
                hp := RegExMatch(OcrRegion([880, 182, 220, 32]), "([\d,]+)\s*/\s*([\d,]+)", &m) ? [StrReplace(m[1], ","), StrReplace(m[2], ",")] : 0
                if hp && hp[1] != hp[2]
                    bossHitAt := A_TickCount, titanBossHit := A_TickCount
                if !bossSeenAt
                    bossSeenAt := A_TickCount
                ; 8.11 15:32-15:39: 7 min walking into a house wall, the boss never hit. A respawn point gives a new way in
                if A_TickCount - Max(bossHitAt, bossSeenAt) > 35000 && resets > 0 {
                    resets--
                    Log("  Titan: boss not hit for 35 s - reset, " resets " left (" (A_TickCount - t0) // 1000 " s)")
                    TitanReset()
                    if !TitanWait(13000, &over)
                        break
                    bossSeenAt := A_TickCount
                    continue
                }
                if A_TickCount - bossHitAt > 8000 {
                    SetStatus("Titan: boss not hit yet, walking on")
                    TitanSteer()
                    HoldKey("w", 3000)
                    HoldKey("q", 90)
                    if hp && !bossLogged
                        bossLogged := true, Log("  Titan: walking to the boss, HP " hp[1] "/" hp[2] " (" (A_TickCount - t0) // 1000 " s)")
                }
                SetStatus("Titan: boss (" (A_TickCount - t0) // 1000 " s)")
                Loop 3
                    if !TitanAttack(&over)
                        break
                continue
            }
            ; user, 8.11: Shift again after the boss. 5 s without the bar = it is dead, not hidden by a flash
            if bossSeenAt && A_TickCount - noBar > 5000 {
                bossSeenAt := 0, bossLogged := false
                Log("  Titan: boss bar gone at " (A_TickCount - t0) // 1000 " s - checking Shift Lock")
                TitanLock(true)
            }
            if A_TickCount - noBar < 15000 {              ; the bar is hidden by a flash or a wave is being fought
                SetStatus("Titan: fighting (" (A_TickCount - t0) // 1000 " s)")
                if !TitanAttack(&over)
                    break
                continue
            }
            if resets <= 0 {                              ; no lives to spend: only walk and fight
                SetStatus("Titan: walking on (no resets left)")
                TitanSteer()
                HoldKey("w", 2500)
                Loop 3
                    if !TitanAttack(&over)
                        break
                continue
            }
            ; 8.11: lives went on resets while enemies were still coming, or with none left. Finish what is here first
            if !TitanClear(&over)
                break
            left := TitanCount()
            if left = "0" {                               ; nothing to fight: the next part or the end of the run is coming
                noBar := A_TickCount
                continue
            }
            Log("  Titan: " left " left and not coming (" (A_TickCount - t0) // 1000 " s)")
            resets--
            SetStatus("Titan: reset (" resets " left)")
            TitanReset()
            if !TitanWait(13000, &over)
                break
            noBar := A_TickCount
            TitanLock(true)                               ; a respawn may drop it
            at := TitanPillars()
            Log("  Titan: reset: " (at ? "at the pillars" : "other respawn point") " (" (A_TickCount - t0) // 1000 " s)")
            if !at {                                      ; a big titan stands near the other respawn points: it takes ~30 s
                SetStatus("Titan: fighting at the respawn point")
                HoldKey("w", 4000)
                t1 := A_TickCount
                while running && over = "" && A_TickCount - t1 < 16000 && !TitanBossBar()
                    if !TitanAttack(&over)
                        break
                ; the next group stands further on: walk and fight in steps (standing still it was never reached, 8.11)
                Loop 4 {
                    if !running || over != "" || TitanBossBar()
                        break
                    HoldKey("w", 2500)
                    Loop 3
                        if !TitanAttack(&over)
                            break
                }
                noBar := A_TickCount - 60000
                continue
            }
            t1 := A_TickCount
            while running && over = "" && A_TickCount - t1 < 90000 && !TitanBossBar() {
                SetStatus("Titan: advancing (" (A_TickCount - t1) // 1000 " s)")
                HoldKey("w", 2500)
                Loop 3
                    if !TitanAttack(&over)
                        break
            }
            noBar := A_TickCount
        }
    } finally {
        ReleaseKeys()
        TitanLock(false)                              ; menus cannot be clicked with the cursor held
        Send "{w up}{a up}{s up}{d up}"
        lastFight := A_TickCount - FIGHT_STICKY
        fightSince := 0
    }
    if !running
        return
    Log("Titan: run over after " (A_TickCount - t0) // 1000 " s (" (over = "" ? "time limit" : over) ")")
    if over = "" {
        RestartRoblox("Titan run did not end", , 60000)
        return
    }
    if over = "results"
        TitanResults()
}

; RETRY keeps farming without the lobby; LEAVE when another mode is due
TitanResults() {
    global titanArmed
    ParkMouse()
    Sleep 2500                                         ; rewards are drawn one by one
    Screenshot("titan_end")
    Log("  Titan results: " RegExReplace(OcrRegion([300, 200, 1320, 520]), "\s+", " "))
    goal := Target()
    if goal = "titan" {
        SetStatus("Titan: RETRY")
        Log("  Titan: pressing RETRY")
        ClickXY(803, 770)
        titanArmed := A_TickCount
    } else {
        SetStatus("Titan: LEAVE (" goal " is next)")
        ClickXY(1260, 771)
    }
    ParkMouse()
    Sleep 3000
}

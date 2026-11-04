; auto_boss.ahk - bossAuto: in Raid and Speed Raid the game's own Auto fights the boss; the bot only keeps Auto switched on.
; Facts (4.11): Auto stays on after a death inside the run, and turns off after a teleport / new run.
; Templates: img\auto_off.png = white "AUTO" letters of the OFF button (dark red diamond), img\auto_on.png = white "AUTO ON" letters.

AUTO_OFF_PTS := [[-6, 6], [54, 6], [24, -16]]    ; diamond fill (red) at offsets from the letters' top-left: guards against white blobs
autoTries := 0, autoAt := 0, autoWinAt := 0, autoFailLogged := false, autoOnLogged := false
autoSeen := 0                                    ; last tick with a sign of the run (ENEMIES LEFT or the Auto button)
autoBtnAt := 0                                   ; last tick the Auto button was seen

AutoReset() {
    global autoTries, autoAt, autoWinAt, autoFailLogged, autoOnLogged, autoBtnAt
    autoTries := 0, autoAt := 0, autoWinAt := 0, autoFailLogged := false, autoOnLogged := false, autoBtnAt := 0
}

AutoBox() => [AUTO_BTN[1] - 60, AUTO_BTN[2] - 60, AUTO_BTN[1] + 60, AUTO_BTN[2] + 60]

; OFF button visible near AUTO_BTN: letters match and the diamond around them is red
AutoOffVisible() {
    b := AutoBox()
    if !FindImg("auto_off.png", &x, &y, b[1], b[2], b[3], b[4])
        return false
    red := 0
    for p in AUTO_OFF_PTS {
        c := Integer(PixelGetColor(x + p[1], y + p[2]))
        r := c >> 16 & 0xFF, gg := c >> 8 & 0xFF, bl := c & 0xFF
        if r >= 100 && r - gg >= 40 && r - bl >= 40
            red++
    }
    return red >= 2
}

AutoOnVisible() {
    b := AutoBox()
    return FindImg("auto_on.png", &x, &y, b[1], b[2], b[3], b[4])
}

; The ENEMIES LEFT picture flickers on bright maps (4.11: one raid became 5 "fights"), so the run stays "in fight"
; while ENEMIES LEFT or the Auto button is seen, and after that until the lobby (PLAY) shows or 3 min pass without any sign.
; Returns the fight state to use instead of the raw ENEMIES LEFT result.
AutoRunOn(rawFight) {
    global autoSeen, autoBtnAt, fightSince
    if cfg["bossAuto"] != "1" || !BossFight()
        return rawFight
    if FindImg("play.png", &px, &py, 1500, 800, 1920, 1060) {    ; lobby: the run is over (or never began); ENEMIES LEFT seen here is a false hit
        if fightSince
            AutoRunEnd()
        return false
    }
    btn := AutoOffVisible() || AutoOnVisible()
    if btn
        autoBtnAt := A_TickCount
    if rawFight || btn {
        autoSeen := A_TickCount
        return true
    }
    if !fightSince                                          ; the run has not started yet
        return false
    if A_TickCount - autoSeen < 180000
        return true
    AutoRunEnd()
    return false
}

; run over: the fight ended at the last sign (not at the lobby), and the sticky time counts as run out
AutoRunEnd() {
    global lastFight, fightSince
    lastFight := autoSeen
    d := FIGHT_STICKY - (A_TickCount - lastFight)
    if d > 0
        lastFight -= d, fightSince -= d
}

; ms since the fight ended (the game's Speed Raid timer starts at the victory)
SinceFight() => cfg["bossAuto"] = "1" && autoSeen ? A_TickCount - autoSeen : A_TickCount - lastFight

; press AUTO only when the OFF look is really seen (never blindly: while dead Auto stays on)
AutoEnsure() {
    global autoTries, autoAt, autoWinAt, autoFailLogged, autoOnLogged
    if A_TickCount - autoAt < 1500                         ; give the click time to show
        return
    kind := lastEntered = "speed" ? "Speed Raid" : "raid"
    if AutoOffVisible() {
        if autoTries && A_TickCount - autoWinAt > 30000
            autoTries := 0                                  ; max 3 tries per 30 s
        if autoTries >= 3 {
            if !autoFailLogged {
                autoFailLogged := true
                Log("Auto: still off after 3 clicks")
                Screenshot("auto_fail")
            }
            return
        }
        if !autoTries
            autoWinAt := A_TickCount
        autoTries++
        autoAt := A_TickCount
        ClickXY(AUTO_BTN[1], AUTO_BTN[2])
        ParkMouse()
        Log(kind ": Auto pressed (try " autoTries ")")
    } else if !autoOnLogged && AutoOnVisible() {
        autoOnLogged := true
        Log("Auto: on")
    }
}

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
; Where each set of letters may be: a few px around where they sit (OFF "AUTO" 48x12 at 714,840, ON "AUTO ON" 63x9 at
; 706,842 on the 1920x1017 layout), all inside the diamond. 7.11 02:27: in the old 120x120 box the white floor at the box's
; corner matched the white letters first (ImageSearch returns the first hit), the non-white check rejected it and the real
; button was never looked at - "lobby" and LEAVE mid-fight on bright floors.
LetterBox(name) => name = "auto_on.png" ? [AUTO_BTN[1] - 38, AUTO_BTN[2] - 16, AUTO_BTN[1] + 37, AUTO_BTN[2] + 5]
                                        : [AUTO_BTN[1] - 32, AUTO_BTN[2] - 18, AUTO_BTN[1] + 32, AUTO_BTN[2] + 6]

; OFF button visible near AUTO_BTN: letters match and the diamond around them is red
AutoOffVisible() {
    b := LetterBox("auto_off.png")
    if !FindImg("auto_off.png", &x, &y, b[1], b[2], b[3], b[4])
        return false
    ; "AUTO" also fits inside "AUTO ON" (6.11 22:52 both matched on the same frame): ON is never off - a click would turn it off
    if AutoOnVisible()
        return false
    ; the OFF letters start at 714 (AUTO_BTN - 24), the "AUTO" of "AUTO ON" at 706: a match left of 710 is the ON button
    ; whose "ON" a flash hid - clicking it would turn Auto off (matters with Infinity on Auto: clicks every run)
    if x < AUTO_BTN[1] - 28
        return false
    ; the OFF diamond is red - or almost black (0x1F120F): 6.11 22:12-22:28 a Speed Raid ran 16 min with Auto off on the dark
    ; diamond, the bot never pressed it (it waited for red) and the character only died; one click turned it ON. Anything
    ; but white counts (a white blob that fits the letters is what this guards against)
    ok := 0
    for p in AUTO_OFF_PTS {
        c := Integer(PixelGetColor(x + p[1], y + p[2]))
        ok += Min(c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF) < 170
    }
    return ok >= 2
}

AutoOnVisible() {
    b := LetterBox("auto_on.png")
    return FindImg("auto_on.png", &x, &y, b[1], b[2], b[3], b[4])
}

; The AUTO button (OFF or ON) over the skill bar is shown only in a fight - Infinity, raid, Speed Raid - never in the lobby,
; the menus or the raid world. It is part of the HUD, so it is drawn over every effect. 6.11 (2560x1440 PC): a big white /
; yellow AOE washed the screen, play.png matched the white -> "lobby" mid-fight hundreds of times in 3 h (the bot stopped
; fighting, pressed "PLAY" in the arena, 7 Infinity runs instead of steady farming); and on a bright floor ENEMIES LEFT did
; not match for 90 s -> Esc, window crosses and Roblox restarts mid-fight. Checked on 98 screenshots of that night: the letters
; are always there in a fight. Around the letters the diamond is dark red, black in the flash or purple (ON) - never white,
; so a white blob that also fits the letters is rejected (2 of the points must not be white).
; The lobby for sure: PLAY with no AUTO button, on 3 ticks in a row (each within 3 s of the last). 6.11 22:04 one frame of a
; flash still read as "lobby" with FightHud in place; the real lobby stays for seconds, a flash does not. Several calls in the
; same tick (Step and AutoRunOn) count once.
LobbyPlay() {
    static streak := 0, at := 0, lastTick := -1, lastRes := false
    if tickNo = lastTick
        return lastRes
    lastTick := tickNo
    if hudSeen || !FindImg("play.png", &px, &py, 1500, 800, 1920, 1060) {
        streak := 0
        return lastRes := false
    }
    if A_TickCount - at > 3000
        streak := 0
    at := A_TickCount, streak++
    return lastRes := streak >= 3
}

; what FightHud sees right now, for the log when a fight is about to be called off
FightHudWhy() {
    s := ""
    for it in [["auto_off.png", AUTO_OFF_PTS], ["auto_on.png", AUTO_ON_PTS]] {
        b := LetterBox(it[1])
        f := FindImg(it[1], &x, &y, b[1], b[2], b[3], b[4])
        s .= (s = "" ? "" : "; ") it[1] " " (f ? "at " x "," y : "no")
        if f
            for p in it[2]
                s .= " " Format("{:06X}", PixelGetColor(x + p[1], y + p[2]))
    }
    return s
}

AUTO_ON_PTS := [[-6, 3], [70, 3], [32, -18], [32, 24]]     ; around the "AUTO ON" letters (63x9), same idea as AUTO_OFF_PTS
FightHud() {
    for it in [["auto_off.png", AUTO_OFF_PTS], ["auto_on.png", AUTO_ON_PTS]] {
        b := LetterBox(it[1])
        if !FindImg(it[1], &x, &y, b[1], b[2], b[3], b[4])
            continue
        n := 0
        for p in it[2] {
            c := Integer(PixelGetColor(x + p[1], y + p[2]))
            n += Min(c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF) < 170       ; not white
        }
        if n >= 2
            return true
    }
    return false
}

; The ENEMIES LEFT picture flickers on bright maps (4.11: one raid became 5 "fights"), so the run stays "in fight"
; while ENEMIES LEFT or the Auto button is seen, and after that until the lobby (PLAY) shows or 3 min pass without any sign.
; Returns the fight state to use instead of the raw ENEMIES LEFT result.
AutoRunOn(rawFight) {
    global autoSeen, autoBtnAt, fightSince
    if cfg["bossAuto"] != "1" || !BossFight()
        return rawFight
    ; lobby: the run is over (or never began); ENEMIES LEFT seen here is a false hit. Not while the AUTO button shows: then
    ; "PLAY" is a white flash in the fight (hudSeen - this tick's FightHud, see Step)
    if LobbyPlay() {
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
    kind := lastEntered = "speed" ? "Speed Raid" : lastEntered = "infinity" ? "Infinity" : "raid"
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

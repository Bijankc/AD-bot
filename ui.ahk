; ui.ahk - main window, hotbar and colour themes. Included from RaidBot.ahk.
; Default style "Cosmos" (dark purple space): dark aurora background, glass panels, blue-violet gradients, sakura pink only for
; active things. The whole window is ONE bitmap drawn with GDI+ (UiRender); clicks are matched against the
; rectangles collected while drawing (hits). Fonts: Sora (titles), Inter (text), JetBrains Mono (log, keys).
; If a font is not installed, put its .ttf files into the fonts\ folder next to the script, else Segoe UI / Consolas is used.

LOGO_T := 52, LOGO_S := LOGO_T / 100          ; logo tile size in px and its scale
APP_VERSION := "0.2.7"                   ; shown under the title
APP_AUTHOR  := "Samogub"                 ; shown next to the version

; ------------------------------ themes ------------------------------
; preset= in raid.ini [theme] picks one of these; bg, card, field, text, dim, on, off, idle, acc, acc2, hi can be
; overridden one by one with 6-digit hex values. acc -> acc2 is the button gradient, hi marks active things.
THEMES := Map(
    "cosmos",   {lite: 0, stars: 1, glow: 0.22, ov: "FFFFFF", bg: "010003", card: "05030B", field: "0A0613", text: "DDD6F2", dim: "7A6FA3", on: "A78BFA", off: "130D26", idle: "3E3466", acc: "6A3BD0", acc2: "3F1A94", hi: "BFA0FF"},
    "sakura",   {lite: 1, ov: "8A2F55", bg: "FBEFF3", card: "FFFFFF", field: "F7DCE6", text: "4A2535", dim: "9A6B7C", on: "E0558A", off: "EBCFDA", idle: "C9A3B2", acc: "F28FB4", acc2: "D9578F", hi: "C2336E"},
    "midnight", {lite: 0, ov: "FFFFFF", bg: "0B0F1A", card: "141A2E", field: "1D2540", text: "E8ECF8", dim: "8A93B2", on: "7CF0B6", off: "2B3354", idle: "566086", acc: "5B8CFF", acc2: "7C5CFF", hi: "FF9EC4"},
    "aurora",   {lite: 0, ov: "FFFFFF", bg: "050B13", card: "0D1A25", field: "163042", text: "E4F5F1", dim: "78A6A8", on: "5CF2C0", off: "1F3B4C", idle: "46707A", acc: "20C9B0", acc2: "7B5CF0", hi: "7CFFD0"},
    "metallic", {lite: 0, ov: "FFFFFF", bg: "090B10", card: "13171F", field: "1F2531", text: "E9EDF5", dim: "8B94A8", on: "C8D2E6", off: "2A3142", idle: "566074", acc: "9AA7C2", acc2: "4B5873", hi: "DCE6FA"},
    "ember",    {lite: 0, ov: "FFFFFF", bg: "0D0806", card: "1A1210", field: "2B1D18", text: "F7ECE3", dim: "A58B7C", on: "FFB86B", off: "3D2A23", idle: "6E5347", acc: "EE7A3C", acc2: "B8365A", hi: "FFC48A"},
    "ironrose", {lite: 0, ov: "FFFFFF", bg: "060A11", card: "0F171F", field: "19262F", text: "E3EEF0", dim: "7E9BA2", on: "A6D8D8", off: "21313A", idle: "4B6670", acc: "5E8F9B", acc2: "24445A", hi: "AFD8DD"},
    "author",   {lite: 0, ov: "FFFFFF", bg: "08080A", card: "131316", field: "202024", text: "ECECEF", dim: "9A9AA2", on: "CFCFD8", off: "2E2E34", idle: "5E5E66", acc: "7B7D8A", acc2: "3E3F4A", hi: "E4E2EC"})
RAIDS_READY := " divine halloween shiro onehero saiya sungomi tiger dual monke cursed "   ; raids that can be picked (found in the Create list by name)
THEME_ORDER := ["cosmos", "sakura", "midnight", "aurora", "metallic", "ironrose", "ember", "author"]
THEME_TITLES := Map("cosmos", "Cosmos", "author", "Graphite", "midnight", "Midnight Sakura", "metallic", "Metallic", "ironrose", "Iron Rose")          ; shown instead of the capitalised key

ThemeName() {
    name := IniRead(INI, "theme", "preset", "cosmos")
    return THEMES.Has(name) ? name : "cosmos"
}

ThemeLoad() {
    base := THEMES[ThemeName()]
    o := {}
    for k in ["bg", "card", "field", "text", "dim", "on", "off", "idle", "acc", "acc2", "hi", "ov"] {
        v := IniRead(INI, "theme", k, "")
        o.%k% := RegExMatch(v, "^[0-9A-Fa-f]{6}$") ? v : base.%k%
    }
    o.lite := base.lite
    o.stars := base.HasOwnProp("stars") ? base.stars : 0     ; twinkling stars over the backdrop
    o.glow := base.HasOwnProp("glow") ? base.glow : 1        ; strength of the backdrop glows
    return o
}

SetTheme(name) {
    global C
    IniWrite name, INI, "theme", "preset"
    for k in ["bg", "card", "field", "text", "dim", "on", "off", "idle", "acc", "acc2", "hi", "ov"]
        IniDelete INI, "theme", k              ; a preset click replaces earlier per-colour overrides
    C := ThemeLoad()
    g.BackColor := C.bg
    mini.BackColor := C.bg
    miniTxt.SetFont("c" C.text)
}

C := ThemeLoad()

; ------------------------------ state ------------------------------
GW := 1000, GH := 640                    ; logical window size (everything is laid out in these units)
UI_K := IsNumber(IniRead(INI, "ui", "scale", "0")) ? Number(IniRead(INI, "ui", "scale", "0")) / 100 : 0          ; [ui] scale=125 (percent) forces the size; 0 = automatic
if UI_K <= 0
    UI_K := Max(1, A_ScreenDPI / 96)                                ; same size as Windows scaling (100% -> 1000x640)
UI_K := Max(0.75, Min(UI_K, (A_ScreenHeight - 80) / GH))             ; always fits on the screen
PW := Round(GW * UI_K), PH := Round(GH * UI_K)                     ; real window size in pixels
LOGH := 128                              ; height of the log panel at the bottom
CX := 222, CY := 76, CWD := GW - 222 - 16, CHT := GH - 76 - 16 - LOGH - 12   ; content area
GdipInit()
if !InStr(RAIDS_READY, " " cfg["raidName"] " ")           ; only tested features are active in the public build
    cfg["raidName"] := "divine"
statsArm := 0                                          ; tick of the first click on "Reset statistics"
gr := 0                                  ; GDI+ graphics of the frame being drawn
hits := []                               ; clickable rectangles of the last frame
hoverId := ""
lastStatus := ""                         ; last status text (SetStatus)
setupDone := IniRead(INI, "setup", "done", "0") = "1"   ; the first-run Setup check must be passed once
setupOpen := false                       ; the Setup check opened again from the menu
setupRan := false, setupRes := []        ; results of the last Check
uiStatus := "stopped"
uiLog := []                              ; last log lines shown in the bottom panel
dRaid := "", dSpeed := "", dGoal := "", dDone := ""
layoutMons := 0
curPage := IniRead(INI, "ui", "page", "home")
if !InStr(" home modes m_raid m_speed m_inf m_titan stats look ", " " curPage " ")
    curPage := "home"

; -DPIScale: PW/PH are already real pixels (UI_K includes the Windows scale); with DPI scaling on, Show scaled them
; again at 150% and made an invisible 2250x1440 window behind the 1500x960 one
g := Gui("+AlwaysOnTop -Caption -DPIScale", "AD Bot")
g.BackColor := C.bg
g.MarginX := 0, g.MarginY := 0
uiBmp := 0                                                     ; last finished frame (HBITMAP), blitted straight onto the window
uiBack := 0                                                    ; cached aurora backdrop (GDI+ bitmap), drawn once per theme
uiBackKey := ""
OnMessage(0x201, UiClick)                                      ; WM_LBUTTONDOWN
OnMessage(0x200, UiMove)                                       ; WM_MOUSEMOVE
OnMessage(0x14, (wParam, lParam, msg, hwnd) => hwnd = g.Hwnd ? 1 : "")   ; WM_ERASEBKGND: never erase (no flicker)
OnMessage(0xF, UiPaint)                                        ; WM_PAINT
g.OnEvent("Close", (*) => ExitApp())

; Hotbar for one monitor: while the bot runs the big window would cover the game (the bot looks for images on
; the screen), so only this thin strip is shown at the top centre. +E0x20 - clicks pass through to the game.
mini := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
mini.BackColor := C.bg
mini.MarginX := 14, mini.MarginY := 5
mini.SetFont("s10 c" C.text, "Segoe UI")
miniTxt := mini.Add("Text", "w520 h20 0x200", "")

g.Show("Hide w" PW " h" PH)
DllCall("SetWindowRgn", "ptr", g.Hwnd, "ptr", DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", PW + 1, "int", PH + 1, "int", Round(28 * UI_K), "int", Round(28 * UI_K), "ptr"), "int", 1)
UiCompute()
UiRender(true)
Layout()
SetTimer(UiTick, 500)
SetTimer(StarTick, 200)                                  ; star animation: about 5 frames a second, only for themes with stars

; ------------------------------ public hooks used by the bot ------------------------------
UiInvalidate() => SetTimer(UiRender, -20)
PaintRun() => UiInvalidate()

UiSetStatus(text) {
    global uiStatus
    uiStatus := text
    UiInvalidate()
}

UiLogPush(text) {
    text := Trim(text)
    stamp := FormatTime(, "HH:mm:ss") "  "
    first := true
    while text != "" {                                   ; long lines are wrapped (the panel is about 90 characters wide)
        chunk := SubStr(text, 1, 88)
        if StrLen(text) > 88 && (p := InStr(chunk, " ", , -1)) > 40
            chunk := SubStr(text, 1, p)
        uiLog.Push((first ? stamp : "          ") Trim(chunk))
        text := LTrim(SubStr(text, StrLen(chunk) + 1))
        first := false
    }
    while uiLog.Length > 80
        uiLog.RemoveAt(1)
    UiInvalidate()
}

; while the bot runs: only the hotbar on the game screen, also with two monitors (the big window there was in the way);
; stopped: the big window, on the second monitor if there is one
Layout() {
    global layoutMons
    layoutMons := MonitorGetCount()
    if running {
        g.Hide()
        mini.Show("x0 y24 AutoSize NoActivate")
        ; real pixels: at Windows scale 150% mini.GetPos gives the size divided by 1.5 (548x31 for 822x46), which
        ; put the strip off centre and cut its rounded region (below) to two thirds of the text
        WinGetPos(, , &mw, &mh, "ahk_id " mini.Hwnd)
        ; device port: on a screen taller than the game area the strip goes below the game (y >= SCR_H, which no
        ; search or screenshot reaches), so it never covers anything the bot looks at; else the author's place at the top
        MonitorGetWorkArea(MonitorGetPrimary(), , , , &wb)
        if wb - SCR_H >= mh + 8
            mini.Move(GAME_X + (GAME_W - mw) // 2, SCR_H + (wb - SCR_H - mh) // 2)
        else
            mini.Move((A_ScreenWidth - mw) // 2, 24)
        DllCall("SetWindowRgn", "ptr", mini.Hwnd, "ptr", DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", mw + 1, "int", mh + 1, "int", 16, "int", 16, "ptr"), "int", 1)
        return
    }
    mini.Hide()
    prim := MonitorGetPrimary()
    Loop layoutMons {
        if A_Index = prim
            continue
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        g.Show("x" (l + (r - l - PW) // 2) " y" (t + (b - t - PH) // 2) " NoActivate")
        return
    }
    g.Show("x" ((A_ScreenWidth - PW) // 2) " y" ((A_ScreenHeight - PH) // 2) " NoActivate")
}

StarTick() {
    if C.stars && DllCall("IsWindowVisible", "ptr", g.Hwnd)
        UiRender()
}

UiTick() {
    static ticks := 0, lastSig := ""
    ticks++
    if Mod(ticks, 4) = 0 && MonitorGetCount() != layoutMons    ; a monitor was plugged / unplugged
        Layout()
    if running
        MiniUpdate()
    if !DllCall("IsWindowVisible", "ptr", g.Hwnd)
        return
    sig := UiCompute()
    if sig != lastSig {
        lastSig := sig
        UiRender()
    }
}

; strings for the Dashboard tiles; returns a signature of everything that changes on screen
UiCompute() {
    global dRaid, dSpeed, dGoal, dDone
    left := 3600 - SecOfHour()
    dRaid := cfg["raid"] = "1" ? Format("{:02}:{:02}", left // 60, Mod(left, 60)) : "—"
    sLeft := speedDue ? DateDiff(speedDue, A_Now, "Seconds") : 0         ; <= 0: Speed Raid is available now
    dSpeed := cfg["speed"] != "1" ? "—" : sLeft <= 0 ? "ready"
        : sLeft >= 3600 ? Round(sLeft / 3600) " h" : Format("{:02}:{:02}", sLeft // 60, Mod(sLeft, 60))
    goal := cfg["fightOnly"] = "1" ? "fight" : Target()
    dGoal := goal = "raid" ? "Raid" : goal = "speed" ? "Speed" : goal = "infinity" ? "Infinity" : goal = "titan" ? "Dimension" : goal = "fight" ? "Fight" : "—"
    dDone := raidDoneKey = RaidHourKey() ? "done" : "not yet"
    return dRaid "|" dSpeed "|" dGoal "|" dDone "|" uiStatus "|" running "|" curPage "|" hoverId "|" uiLog.Length
        . "|" (WinExist(GAME) != 0) "|" curLoadout "|" (running && A_TickCount - lastFight < FIGHT_STICKY)
        . "|" sess["raids"] "," sess["infRuns"] "," sess["raidGems"] "," sess["raidTokens"] "," runTokens
        . "|" (curPage = "stats" ? A_Sec // 5 : "") "|" setupDone setupOpen setupRan setupRes.Length
}

; ------------------------------ Setup check ------------------------------
SetupRun() {
    global setupRes, setupRan
    SetStatus("Setup check running")
    setupRes := SetupChecks(true), setupRan := true
    for it in setupRes
        Log("setup check: " it.state " - " it.name (it.fix != "" ? " (" it.fix ")" : ""))
    SetStatus("Setup check done")
}

SetupFails() {
    n := 0
    for it in setupRes
        n += it.state = "fail"
    return n
}

SetupReopen() {
    global setupOpen, setupRan, setupRes
    setupOpen := true, setupRan := false, setupRes := []
}

SetupClose() {
    global setupDone, setupOpen
    if !setupDone {
        setupDone := true
        IniWrite "1", INI, "setup", "done"
        Log("setup check passed")
    }
    setupOpen := false
}

; ------------------------------ clicks ------------------------------
HitAt(lParam) {
    x := (lParam & 0xFFFF) / UI_K, y := ((lParam >> 16) & 0xFFFF) / UI_K
    i := hits.Length
    while i >= 1 {
        h := hits[i]
        if x >= h.x && x < h.x + h.w && y >= h.y && y < h.y + h.h
            return h
        i--
    }
    return {id: "", fn: "", y: y}
}

UiClick(wParam, lParam, msg, hwnd) {
    if hwnd != g.Hwnd
        return
    h := HitAt(lParam)
    if IsObject(h.fn) {
        h.fn.Call()
        Sfx(SubStr(h.id, 1, 2) = "t_" ? (cfg.Get(SubStr(h.id, 3), "0") = "1" ? "on" : "off") : "click")
        UiInvalidate()
        return 0
    }
    if h.y < 62                                         ; empty part of the top bar: drag the window
        PostMessage(0xA1, 2, 0, , "ahk_id " g.Hwnd)
}

UiMove(wParam, lParam, msg, hwnd) {
    global hoverId
    if hwnd != g.Hwnd
        return
    id := HitAt(lParam).id
    if id != hoverId {
        hoverId := id
        UiInvalidate()
    }
}

Hit(x, y, w, h, id, fn) => hits.Push({x: x, y: y, w: w, h: h, id: id, fn: fn})
IsHot(id) => hoverId = id

SetPage(name) {
    global curPage
    curPage := name
    IniWrite name, INI, "ui", "page"
}

FlipKey(key) {
    if busy && !running {
        Log("toggle click ignored: bot is still stopping")
        return
    }
    cfg[key] := cfg[key] = "1" ? "0" : "1"
    IniWrite cfg[key], INI, "raid", key
    Log("setting " key " = " cfg[key] " (applies at once)")
}

PickEntry(key) {
    if cfg["raidEntry"] = key
        return
    cfg["raidEntry"] := key
    IniWrite key, INI, "raid", "raidEntry"
    Log("setting raidEntry = " key " (applies at once)")
}

RaidShort(k) => k = "saiya" ? "Saiya UI" : k = "shiro" ? "Infinity Shiro" : k = "divine" ? "Divine" : k = "onehero" ? "One Hero" : StrReplace(RAIDS[k][3], " Raid")

PickRaid(key) {
    if cfg["raidName"] = key || !InStr(RAIDS_READY, " " key " ")
        return
    cfg["raidName"] := key
    IniWrite key, INI, "raid", "raidName"
    Log("setting raid = " RAIDS[key][3] " (applies at once)")
}

OpenPath(p) {
    if FileExist(p)
        Run(p)
}

; F3: stop and reload the script (the new copy replaces this one: #SingleInstance Force); it does not start the bot
RestartBot() {
    Log("RESTART (F3)")
    if running
        Stop()
    Run('"' A_AhkPath '" "' A_ScriptFullPath '"')
}

; button "Private server": open the author's private server link (Roblox asks to open the game)
JoinPrivateServer() {
    Log("opening the private server link")
    try Run(PrivateLink())
}

ToggleRun() {
    if running
        Stop()
    else
        Start()
}

; ------------------------------ GDI+ drawing helpers ------------------------------
GdipInit() {
    if !DllCall("GetModuleHandle", "str", "gdiplus", "ptr")
        DllCall("LoadLibrary", "str", "gdiplus")
    si := Buffer(24, 0)
    NumPut("uint", 1, si)                                 ; GdiplusStartupInput.GdiplusVersion
    DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0)   ; until the bot exits
}

Col(hex, a := 255) => (a << 24) | Integer("0x" hex)

Canvas(w, h, fill) {
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &gr := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gr, "int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gr, "int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "ptr", gr, "uint", Col(fill))
    return [bmp, gr]
}

ToHbm(cv) {
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", cv[2])
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", cv[1], "ptr*", &hbm := 0, "uint", 0xFF000000)
    DllCall("gdiplus\GdipDisposeImage", "ptr", cv[1])
    return hbm
}

RRPath(x, y, w, h, r) {
    d := Min(r * 2, w, h)
    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path := 0)
    for a in [[x, y, 180], [x + w - d, y, 270], [x + w - d, y + h - d, 0], [x, y + h - d, 90]]
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", a[1], "float", a[2], "float", d, "float", d, "float", a[3], "float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "ptr", path)
    return path
}

FillRR(x, y, w, h, r, hex, a := 255) {
    path := RRPath(x, y, w, h, r)
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

LineBrush(x, y, w, h, hex1, a1, hex2, a2, vert) {
    pts := Buffer(16)
    NumPut("float", x, "float", y, "float", vert ? x : x + w, "float", vert ? y + h : y, pts)
    DllCall("gdiplus\GdipCreateLineBrush", "ptr", pts, "ptr", pts.Ptr + 8, "uint", Col(hex1, a1), "uint", Col(hex2, a2), "int", 0, "ptr*", &br := 0)
    return br
}

GradRR(x, y, w, h, r, hex1, a1, hex2, a2, vert := false) {
    path := RRPath(x, y, w, h, r)
    br := LineBrush(x, y, w, h, hex1, a1, hex2, a2, vert)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

StrokeRR(x, y, w, h, r, hex, a := 255, wd := 1) {
    path := RRPath(x + 0.5, y + 0.5, w - 1, h - 1, r)
    DllCall("gdiplus\GdipCreatePen1", "uint", Col(hex, a), "float", wd, "int", 2, "ptr*", &pen := 0)
    DllCall("gdiplus\GdipDrawPath", "ptr", gr, "ptr", pen, "ptr", path)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

Dot(x, y, d, hex, a := 255) {
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillEllipse", "ptr", gr, "ptr", br, "float", x, "float", y, "float", d, "float", d)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; soft glow: stacked translucent ellipses (centre cx, cy, radii rx, ry)
Glow(cx, cy, rx, ry, hex, a) {
    Loop 14 {
        s := 1 - (A_Index - 1) / 14
        DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, Max(1, a // 14)), "ptr*", &br := 0)
        DllCall("gdiplus\GdipFillEllipse", "ptr", gr, "ptr", br, "float", cx - rx * s, "float", cy - ry * s, "float", 2 * rx * s, "float", 2 * ry * s)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    }
}

; glass panel: dark tint, light top-lit gradient, thin light border
Glass(x, y, w, h, r := 18, hot := false) {
    FillRR(x, y, w, h, r, C.card, C.lite ? 225 : 170)
    GradRR(x, y, w, h, r, C.ov, hot ? 26 : (C.lite ? 6 : 18), C.ov, C.lite ? 1 : 3, true)
    StrokeRR(x, y, w, h, r, C.ov, hot ? 70 : 38)
}

FontFam(role) {
    static fams := Map(), coll := 0, inited := false
    static names := Map("title", ["Sora", "Segoe UI Semibold", "Segoe UI"], "ui", ["Inter", "Segoe UI"],
        "mono", ["JetBrains Mono", "Consolas"], "icon", ["Segoe MDL2 Assets"])
    if fams.Has(role)
        return fams[role]
    if !inited {
        inited := true
        if FileExist(A_ScriptDir "\fonts\*.ttf") {
            DllCall("gdiplus\GdipNewPrivateFontCollection", "ptr*", &coll)
            Loop Files A_ScriptDir "\fonts\*.ttf"
                DllCall("gdiplus\GdipPrivateAddFontFile", "ptr", coll, "wstr", A_LoopFileFullPath)
        }
    }
    for nm in names[role] {
        fam := 0
        if coll && !DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", nm, "ptr", coll, "ptr*", &fam) && fam {
            fams[role] := fam
            return fam
        }
        fam := 0
        if !DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", nm, "ptr", 0, "ptr*", &fam) && fam {
            fams[role] := fam
            return fam
        }
    }
    return 0
}

FontOf(role, px, bold) {
    static cache := Map()
    key := role "|" px "|" bold
    if cache.Has(key)
        return cache[key]
    fam := FontFam(role)
    font := 0
    if DllCall("gdiplus\GdipCreateFont", "ptr", fam, "float", px, "int", bold, "int", 2, "ptr*", &font) || !font
        DllCall("gdiplus\GdipCreateFont", "ptr", fam, "float", px, "int", 0, "int", 2, "ptr*", &font)   ; no bold face installed
    cache[key] := font
    return font
}

StrFmt(align) {
    static f := Map()
    if !f.Has(align) && align = -1 {                                                         ; paragraph: wraps, top-left
        DllCall("gdiplus\GdipCreateStringFormat", "int", 0, "int", 0, "ptr*", &fmt := 0)
        f[align] := fmt
    }
    if !f.Has(align) {
        DllCall("gdiplus\GdipCreateStringFormat", "int", 0x1000, "int", 0, "ptr*", &fmt := 0)   ; no wrap
        DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", align)                    ; 0 left, 1 centre, 2 right
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", fmt, "int", 1)                    ; centred vertically
        DllCall("gdiplus\GdipSetStringFormatTrimming", "ptr", fmt, "int", 3)                     ; ... at the end
        f[align] := fmt
    }
    return f[align]
}

; text in the box (x, y, w, h); role: title / ui / mono / icon
Tx(text, role, px, bold, hex, x, y, w, h, align := 0, a := 255) {
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    rc := Buffer(16)
    NumPut("float", x, "float", y, "float", w, "float", h, rc)
    DllCall("gdiplus\GdipDrawString", "ptr", gr, "wstr", text, "int", -1, "ptr", FontOf(role, px, bold), "ptr", rc, "ptr", StrFmt(align), "ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; paragraph that wraps inside the box (x, y, w, h)
TxP(text, role, px, hex, x, y, w, h, a := 255) {
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    rc := Buffer(16)
    NumPut("float", x, "float", y, "float", w, "float", h, rc)
    DllCall("gdiplus\GdipDrawString", "ptr", gr, "wstr", text, "int", -1, "ptr", FontOf(role, px, 0), "ptr", rc, "ptr", StrFmt(-1), "ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

TxW(text, role, px, bold) {
    rc := Buffer(16, 0), box := Buffer(16, 0)
    NumPut("float", 0, "float", 0, "float", 2000, "float", 100, rc)
    DllCall("gdiplus\GdipMeasureString", "ptr", gr, "wstr", text, "int", -1, "ptr", FontOf(role, px, bold), "ptr", rc, "ptr", StrFmt(0), "ptr", box, "ptr", 0, "ptr", 0)
    return NumGet(box, 8, "float")
}

; ------------------------------ widgets ------------------------------
Btn(x, y, w, h, label, id, fn, primary := false, icon := "") {
    hot := IsHot(id)
    if primary
        GradRR(x, y, w, h, 14, C.acc, 255, C.acc2, 255)
    else {
        FillRR(x, y, w, h, 14, C.field)
        StrokeRR(x, y, w, h, 14, running && id = "run" ? C.hi : C.ov, running && id = "run" ? 200 : 34)
    }
    if hot
        FillRR(x, y, w, h, 14, C.ov, 26)
    fg := primary ? "FFFFFF" : C.text
    if icon != "" {
        tw := TxW(label, "ui", 14, 1)
        x0 := x + (w - (22 + 8 + tw)) / 2
        Tx(icon, "icon", 16, 0, primary ? "FFFFFF" : C.hi, x0, y, 22, h, 1)
        Tx(label, "ui", 14, 1, fg, x0 + 30, y, tw + 12, h)
    } else
        Tx(label, "ui", 14, 1, fg, x, y, w, h, 1)
    Hit(x, y, w, h, id, fn)
}

Chip(x, y, w, h, label, on, id, fn) {
    if on {
        GradRR(x, y, w, h, 12, C.acc, 255, C.acc2, 255)
        StrokeRR(x, y, w, h, 12, C.hi, 170)
    } else {
        FillRR(x, y, w, h, 12, C.field)
        StrokeRR(x, y, w, h, 12, C.ov, 22)
    }
    if IsHot(id)
        FillRR(x, y, w, h, 12, C.ov, 24)
    Tx(label, "ui", 14, 1, on ? "FFFFFF" : C.dim, x, y, w, h, 1)
    Hit(x, y, w, h, id, fn)
}

; locked chip: dimmed, not clickable; tag (e.g. "Soon") is drawn on the right
ChipOff(x, y, w, h, label, tag := "") {
    FillRR(x, y, w, h, 12, C.field, 110)
    if tag != "" {
        Tx(label, "ui", 13, 1, C.idle, x + 14, y, w - 100, h, 0, 170)
        Tx(tag, "ui", 10, 1, C.hi, x, y, w - 12, h, 2, 220)
    } else
        Tx(label, "ui", 14, 1, C.idle, x, y, w, h, 1, 170)
}

DrawSwitch(x, y, on) {
    if on
        GradRR(x, y, 46, 26, 13, C.acc, 255, C.acc2, 255)
    else
        FillRR(x, y, 46, 26, 13, C.off)
    Dot(on ? x + 23 : x + 3, y + 3, 20, on ? "FFFFFF" : "C4CADB")
}

ToggleRow(x, y, w, label, desc, key, off := false) {
    id := "t_" key
    on := cfg[key] = "1" && !off
    if off {                                               ; locked: greyed out, no clicks
        Tx(label, "ui", 14, 1, C.idle, x + 12, y + 6, w - 90, 22, 0, 150)
        Tx(desc, "ui", 11, 0, C.idle, x + 12, y + 28, w - 90, 18, 0, 150)
        FillRR(x + w - 60, y + 13, 46, 26, 13, C.off, 120)
        Dot(x + w - 57, y + 16, 20, "C4CADB", 90)
        return
    }
    if IsHot(id)
        FillRR(x, y, w, 52, 12, C.ov, 12)
    Tx(label, "ui", 14, 1, on ? C.text : C.dim, x + 12, y + 6, w - 90, 22)
    Tx(desc, "ui", 11, 0, C.dim, x + 12, y + 28, w - 90, 18)
    DrawSwitch(x + w - 60, y + 13, on)
    Hit(x, y, w, 52, id, FlipKey.Bind(key))
}

Panel(x, y, w, h, title) {
    Glass(x, y, w, h)
    Tx(title, "title", 15, 1, C.text, x + 20, y + 14, w - 40, 24)
}

Caption(text, x, y, w := 300) => Tx(StrUpper(text), "ui", 11, 1, C.dim, x, y, w, 16)

KeyCap(x, y, text) {
    tw := TxW(text, "mono", 12, 1)
    FillRR(x, y, tw + 18, 24, 7, C.field)
    StrokeRR(x, y, tw + 18, 24, 7, C.ov, 40)
    Tx(text, "mono", 12, 1, C.text, x, y, tw + 18, 24, 1)
    return tw + 18
}

; ------------------------------ frame ------------------------------
UiRender(force := false) {
    global gr, hits, uiBmp
    if !force && !DllCall("IsWindowVisible", "ptr", g.Hwnd)
        return
    Critical "On"                         ; mouse messages must not interrupt a half-drawn frame (hits would be incomplete -> hover flicker)
    UiCompute()
    cv := Canvas(PW, PH, C.bg)
    gr := cv[2]
    DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", UI_K, "float", UI_K, "int", 0)
    hits := []
    DrawBackdrop()
    if C.stars
        DrawStars()
    DrawTopbar()
    DrawSidebar()
    switch curPage {
        case "modes":   PageModes()
        case "m_raid":  PageRaid()
        case "m_speed": PageSpeed()
        case "m_inf":   PageInfinity()
        case "m_titan": PageTitan()
        case "stats":  PageStats()
        case "look":   PageLook()
        default:       PageHome()
    }
    DrawLogPanel()
    if !setupDone || setupOpen
        DrawSetup()
    hbm := ToHbm(cv)
    gr := 0
    if uiBmp
        DllCall("DeleteObject", "ptr", uiBmp)
    uiBmp := hbm
    UiBlit()
    Critical "Off"
}

; copy the finished frame onto the window in one BitBlt (no control repaint, so no flicker while the mouse moves)
UiBlit(hdc := 0) {
    own := !hdc
    if own
        hdc := DllCall("GetDC", "ptr", g.Hwnd, "ptr")
    mdc := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
    old := DllCall("SelectObject", "ptr", mdc, "ptr", uiBmp, "ptr")
    DllCall("BitBlt", "ptr", hdc, "int", 0, "int", 0, "int", PW, "int", PH, "ptr", mdc, "int", 0, "int", 0, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", mdc, "ptr", old)
    DllCall("DeleteDC", "ptr", mdc)
    if own
        DllCall("ReleaseDC", "ptr", g.Hwnd, "ptr", hdc)
}

UiPaint(wParam, lParam, msg, hwnd) {
    if hwnd != g.Hwnd
        return
    ps := Buffer(72, 0)
    hdc := DllCall("BeginPaint", "ptr", hwnd, "ptr", ps, "ptr")
    if uiBmp
        UiBlit(hdc)
    DllCall("EndPaint", "ptr", hwnd, "ptr", ps)
    return 0
}

; the aurora glows are expensive: draw them once into a cached bitmap and just paste it every frame
DrawBackdrop() {
    global uiBack, uiBackKey, gr
    key := C.bg C.card C.acc C.acc2 C.hi C.lite C.glow UI_K
    if !uiBack || uiBackKey != key {
        if uiBack
            DllCall("gdiplus\GdipDisposeImage", "ptr", uiBack)
        cv := Canvas(PW, PH, C.bg)
        real := gr
        gr := cv[2]
        DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", UI_K, "float", UI_K, "int", 0)
        br := LineBrush(0, 0, GW, GH, C.bg, 255, C.card, 255, true)
        DllCall("gdiplus\GdipFillRectangle", "ptr", gr, "ptr", br, "float", 0, "float", 0, "float", GW, "float", GH)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
        Glow(260, 40, 420, 240, C.acc, Round((C.lite ? 55 : 70) * C.glow))
        Glow(GW - 100, GH - 60, 460, 260, C.acc2, Round((C.lite ? 45 : 70) * C.glow))
        Glow(GW - 140, 30, 240, 130, C.hi, Round((C.lite ? 40 : 34) * C.glow))
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
        gr := real
        uiBack := cv[1]
        uiBackKey := key
    }
    DllCall("gdiplus\GdipResetWorldTransform", "ptr", gr)
    DllCall("gdiplus\GdipDrawImageI", "ptr", gr, "ptr", uiBack, "int", 0, "int", 0)
    DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", UI_K, "float", UI_K, "int", 0)
}

; faint blue stars: each one fades in and out over 4-9 s and shows up in a new place every cycle
; (position = hash of star number and cycle number, so nothing is stored)
DrawStars() {
    t := A_TickCount / 1000
    Loop 90 {
        i := A_Index
        ph := t / (4 + Mod(i * 7, 6)) + Mod(i * 0.37, 1)
        cyc := Floor(ph)
        a := Sin((ph - cyc) * 3.14159) ** 2
        if a < 0.06
            continue
        x := Mod(i * 73856093 + cyc * 19349663, 1000003) / 1000003 * GW
        y := Mod(i * 83492791 + cyc * 49979687, 999983) / 999983 * GH
        Dot(x, y, Mod(i, 4) = 0 ? 3 : 2, "8AB4FF", Round(a * 190))
    }
}

Poly(pts, hex, a := 255) {
    buf := Buffer(pts.Length * 8)
    for i, p in pts
        NumPut("float", p[1], "float", p[2], buf, (i - 1) * 8)
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillPolygon", "ptr", gr, "ptr", br, "ptr", buf, "int", pts.Length, "int", 0)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

Oval(x, y, w, h, hex) {
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillEllipse", "ptr", gr, "ptr", br, "float", x, "float", y, "float", w, "float", h)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

DrawLogo(x, y) {
    GradRR(x, y, LOGO_T, LOGO_T, 15, C.acc, 255, C.acc2, 255)
    Tx(Chr(0xE99A), "icon", 26, 0, "FFFFFF", x, y, LOGO_T, LOGO_T, 1)
}
DrawTopbar() {
    GradRR(24, 13, 36, 36, 12, C.acc, 255, C.acc2, 255)
    DrawLogo(16, 4)
    Tx("AD Bot", "title", 18, 1, C.text, 78, 8, 100, 26)
    Tx("v" APP_VERSION " · public build · by " APP_AUTHOR, "mono", 10, 0, C.dim, 78, 31, 230, 16)
    ; status pill
    if running {
        FillRR(306, 16, 124, 30, 15, C.hi, 36)
        StrokeRR(306, 16, 124, 30, 15, C.hi, 150)
        Dot(320, 26, 10, C.hi)
        Tx("RUNNING", "ui", 12, 1, C.hi, 338, 16, 90, 30)
    } else {
        FillRR(306, 16, 124, 30, 15, C.field)
        Dot(320, 26, 10, C.idle)
        Tx("STOPPED", "ui", 12, 1, C.dim, 338, 16, 90, 30)
    }
    Tx(uiStatus, "ui", 13, 0, C.dim, 448, 9, GW - 448 - 270, 44)
    ; indicators
    roblox := WinExist(GAME) != 0
    fight := running && A_TickCount - lastFight < FIGHT_STICKY
    Dot(GW - 262, 25, 10, roblox ? C.on : C.idle)
    Tx("Roblox", "ui", 12, 0, roblox ? C.text : C.idle, GW - 246, 9, 60, 44)
    Dot(GW - 180, 25, 10, fight ? C.hi : C.idle)
    Tx("Fight", "ui", 12, 0, fight ? C.text : C.idle, GW - 164, 9, 50, 44)
    ; window buttons
    for b in [["min", GW - 92, 0xE921], ["close", GW - 52, 0xE8BB]] {
        hot := IsHot(b[1])
        if hot
            FillRR(b[2], 15, 34, 32, 10, b[1] = "close" ? "E5484D" : C.ov, b[1] = "close" ? 190 : 30)
        Tx(Chr(b[3]), "icon", 11, 0, C.text, b[2], 15, 34, 32, 1)
        Hit(b[2], 15, 34, 32, b[1], b[1] = "min" ? (() => g.Minimize()) : (() => ExitApp()))
    }
}

DrawSidebar() {
    Glass(16, 76, 190, GH - 92)
    items := [["home", "Dashboard", 0xE80F], ["modes", "Modes", 0xE713],
              ["stats", "Statistics", 0xE9D2], ["look", "Appearance", 0xE790], ["setup", "Setup check", 0xE9D9]]
    y := 92
    for it in items {
        id := "nav_" it[1]
        on := curPage = it[1] || (it[1] = "modes" && SubStr(curPage, 1, 2) = "m_")
        if on {
            FillRR(26, y, 170, 44, 12, C.hi, 30)
            FillRR(26, y + 11, 4, 22, 2, C.hi)
        } else if IsHot(id)
            FillRR(26, y, 170, 44, 12, C.ov, 14)
        Tx(Chr(it[3]), "icon", 17, 0, on ? C.hi : C.dim, 40, y, 26, 44, 1)
        Tx(it[2], "ui", 14, on, on ? C.text : C.dim, 76, y, 118, 44)
        Hit(26, y, 170, 44, id, it[1] = "setup" ? SetupReopen : SetPage.Bind(it[1]))
        y += 52
    }
    Btn(28, GH - 16 - 12 - 50 - 10 - 40, 166, 40, "Private server", "join", JoinPrivateServer, false, Chr(0xE774))
    Btn(28, GH - 16 - 12 - 50, 166, 50, running ? "Stop" : "Start", "run", ToggleRun, !running, Chr(running ? 0xE71A : 0xE768))
}

DrawLogPanel() {
    y := GH - 16 - LOGH
    Glass(CX, y, CWD, LOGH)
    Caption("Log", CX + 20, y + 12)
    x := CX + CWD - 290
    x += KeyCap(x, y + 9, "F1") + 6
    Tx("Start", "ui", 12, 0, C.dim, x, y + 9, 44, 24)
    x += 56
    x += KeyCap(x, y + 9, "F2") + 6
    Tx("Stop", "ui", 12, 0, C.dim, x, y + 9, 44, 24)
    x += 52
    x += KeyCap(x, y + 9, "F3") + 6
    Tx("Restart", "ui", 12, 0, C.dim, x, y + 9, 60, 24)
    n := uiLog.Length
    Loop Min(5, n) {
        i := n - Min(5, n) + A_Index
        Tx(uiLog[i], "mono", 12, 0, i = n ? C.text : C.dim, CX + 20, y + 40 + (A_Index - 1) * 17, CWD - 40, 17, 0, i = n ? 255 : 200)
    }
    if n = 0
        Tx("Nothing yet. Press Start or F1.", "mono", 12, 0, C.idle, CX + 20, y + 40, CWD - 40, 17)
}

; First-run Setup check: a card over the whole window. Until it is passed once, nothing under it can be clicked.
DrawSetup() {
    global hits
    keep := []
    for h in hits                                         ; only the top bar (drag / minimise / close) stays usable
        if h.y < 62
            keep.Push(h)
    hits := keep
    FillRR(0, 62, GW, GH - 62, 2, C.bg, 235)
    x := 90, y := 74, w := 820, h := 552
    FillRR(x, y, w, h, 20, C.bg, 255)                     ; opaque base, so nothing shows through the glass
    Glass(x, y, w, h, 20)
    Tx(setupDone ? "Setup check" : "Welcome - check your setup first", "title", 22, 1, C.text, x + 28, y + 20, w - 56, 32)
    Tx("Press Check. The bot tests what it can on this PC and tells you how to fix the rest.", "ui", 13, 0, C.dim, x + 28, y + 56, w - 56, 20)
    Caption("Automatic checks", x + 28, y + 96)
    Caption("Set these in the game yourself", x + 490, y + 96, 300)
    ry := y + 122
    if !setupRan
        Tx("Not checked yet.", "ui", 13, 0, C.idle, x + 28, ry, 400, 24)
    for it in setupRes {
        col := it.state = "ok" ? "3DD68C" : it.state = "warn" ? "F5B942" : "F2555A"
        Dot(x + 28, ry + 2, 24, col)
        Tx(Chr(it.state = "ok" ? 0xE73E : it.state = "warn" ? 0xE7BA : 0xE711), "icon", 13, 0, "FFFFFF", x + 28, ry + 2, 24, 24, 1)
        Tx(it.name, "ui", 14, 1, C.text, x + 64, ry, 400, 22)
        if it.fix != ""
            TxP(it.fix, "ui", 11, C.dim, x + 64, ry + 22, 410, 32)   ; wraps to two lines
        ry += it.fix != "" ? 60 : 40
    }
    tips := ["Graphics quality: set it to the lowest (Esc > Settings in Roblox).",
             "Turn off visual effects and extra animations in the game settings: they hide the colours the bot reads.",
             "Keep Roblox in a window on your main monitor (not F11). Do not resize it: the bot sets the size.",
             "Loadouts: 1 for raids, 2 for Infinity, 3 for Speed Raid - or turn Loadouts off in Modes."]
    ty := y + 122
    for t in tips {
        Dot(x + 490, ty + 6, 8, C.hi)
        TxP(t, "ui", 12, C.text, x + 510, ty, 280, 64)
        ty += 70
    }
    ; bottom bar
    by := y + h - 68
    Btn(x + 28, by, 200, 44, setupRan ? "Check again" : "Check now", "setup_check", SetupRun, !setupRan, Chr(0xE9D9))
    fails := SetupFails()
    ok := setupDone || setupRan && !fails
    msg := !setupRan ? "Press Check to continue." : fails ? fails " problem" (fails > 1 ? "s" : "") " to fix, then Check again." : "All good."
    Tx(msg, "ui", 13, 1, setupRan && !fails ? "3DD68C" : C.dim, x + 250, by, 330, 44)
    if ok
        Btn(x + w - 228, by, 200, 44, setupDone ? "Close" : "Continue", "setup_go", SetupClose, setupRan)
    else {
        FillRR(x + w - 228, by, 200, 44, 14, C.field, 120)
        Tx("Continue", "ui", 14, 1, C.idle, x + w - 228, by, 200, 44, 1, 150)
    }
}

; ------------------------------ pages ------------------------------
PageHome() {
    tw := (CWD - 3 * 12) // 4
    for i, t in [["NEXT RAID", dRaid], ["NEXT SPEED RAID", dSpeed], ["GOAL", dGoal], ["THIS HOUR'S RAID", dDone]] {
        x := CX + (i - 1) * (tw + 12)
        Glass(x, CY, tw, 92)
        Tx(t[1], "ui", 11, 1, C.dim, x + 18, CY + 14, tw - 36, 16)
        Tx(t[2], "title", 24, 1, t[2] = "done" ? C.hi : C.text, x + 18, CY + 38, tw - 36, 42)
    }
    ay := CY + 104, aw := 440, ah := CHT - 104
    Panel(CX, ay, aw, ah, "Activity")
    Tx(running ? uiStatus : "Press Start (or F1) to begin", "ui", 16, 0, C.text, CX + 20, ay + 48, aw - 40, 30)
    Caption("Raid", CX + 20, ay + 98)
    Tx(RaidTitle(), "ui", 15, 1, C.hi, CX + 20, ay + 116, aw - 150, 26)
    Tx("Loadout " (curLoadout ? curLoadout : "?"), "ui", 13, 1, C.dim, CX + aw - 130, ay + 116, 110, 26, 2)
    Caption("Modes", CX + 20, ay + 158)
    mx := CX + 20
    for m in [["raid", "Raid"], ["speed", "Speed Raid"], ["infinity", "Infinity"], ["titan", "Dimension"]] {
        on := cfg[m[1]] = "1"
        w := TxW(m[2], "ui", 13, 1) + 32
        if on {
            FillRR(mx, ay + 180, w, 30, 15, C.hi, 36)
            StrokeRR(mx, ay + 180, w, 30, 15, C.hi, 150)
        } else
            FillRR(mx, ay + 180, w, 30, 15, C.field)
        Tx(m[2], "ui", 13, 1, on ? C.hi : C.idle, mx, ay + 180, w, 30, 1)
        mx += w + 10
    }
    Caption("Hotkeys", CX + 20, ay + 226)
    x := CX + 20
    x += KeyCap(x, ay + 246, "F1") + 8
    Tx("start", "ui", 12, 0, C.dim, x, ay + 246, 50, 24)
    x += 60
    x += KeyCap(x, ay + 246, "F2") + 8
    Tx("stop", "ui", 12, 0, C.dim, x, ay + 246, 50, 24)
    x += 56
    x += KeyCap(x, ay + 246, "F3") + 8
    Tx("restart", "ui", 12, 0, C.dim, x, ay + 246, 70, 24)
    rx := CX + aw + 12, rw := CWD - aw - 12
    Panel(rx, ay, rw, ah, "This run")
    rows := [["Raids", sess["raids"]], ["Infinity runs", sess["infRuns"]], ["Gems", sess["raidGems"]],
             ["Tokens", sess["raidTokens"] (runKind = "raid" && runTokens ? "  +" runTokens : "")]]
    for i, r in rows {
        y := ay + 50 + (i - 1) * 50
        Tx(r[1], "ui", 13, 0, C.dim, rx + 20, y, 140, 36)
        Tx(String(r[2]), "mono", 20, 1, C.text, rx + 20, y, rw - 40, 36, 2)
        if i < rows.Length
            FillRR(rx + 20, y + 42, rw - 40, 1, 1, C.ov, 22)
    }
}

; ---- helpers for the settings pages ----
BackBar(title, hint) {
    Btn(CX, CY, 96, 34, "Back", "back", SetPage.Bind("modes"), false, Chr(0xE72B))
    Tx(title, "title", 18, 1, C.text, CX + 112, CY, 300, 34)
    Tx(hint, "ui", 12, 0, C.dim, CX + 330, CY, CWD - 330, 34, 2)
}

; one setting with - / + buttons: value is cfg[key], shown as value / div + unit
Stepper(x, y, w, label, key, step, lo, hi, div, unit, def := 0, caption := "", off := false) {
    Tx(label, "ui", 13, 0, off ? C.idle : C.text, x, y, w - 190, 36)
    if caption != ""
        Tx(caption, "ui", 11, 0, C.dim, x, y + 30, w - 190, 16)
    bx := x + w - 176
    if off {
        FillRR(bx, y + 3, 32, 30, 12, C.field, 120)
        FillRR(bx + 144, y + 3, 32, 30, 12, C.field, 120)
        Tx(Round(Num(key, def) / div, div = 1 ? 0 : div = 100 ? 2 : 1) (unit = "" ? "" : " " unit), "mono", 13, 1, C.idle, bx + 34, y, 76, 36, 1)
        return
    }
    Chip(bx, y + 3, 32, 30, "-", false, "dn_" key, StepCfg.Bind(key, -step, lo, hi, def))
    Tx(Round(Num(key, def) / div, div = 1 ? 0 : div = 100 ? 2 : 1) (unit = "" ? "" : " " unit), "mono", 13, 1, C.text, bx + 34, y, 76, 36, 1)
    Chip(bx + 144, y + 3, 32, 30, "+", false, "up_" key, StepCfg.Bind(key, step, lo, hi, def))
}

StepCfg(key, d, lo, hi, def) {
    v := Min(hi, Max(lo, Num(key, def) + d))
    cfg[key] := String(v)
    IniWrite v, INI, "raid", key
    Log("setting " key " = " v " (applies at once)")
}

; ------------------------------ sounds: button clicks ------------------------------
; click sounds: sfx\click.wav, on.wav, off.wav (SoundPlay, asynchronous)
Sfx(name) {
    if cfg["sfx"] = "1" && FileExist(f := A_ScriptDir "\sfx\" name ".wav")
        try SoundPlay(f)
}

; setting stored as "MM:SS"
TimeStepper(x, y, w, label, key, step, lo, hi, def, caption := "") {
    Tx(label, "ui", 13, 0, C.text, x, y, w - 190, 36)
    if caption != ""
        Tx(caption, "ui", 11, 0, C.dim, x, y + 30, w - 190, 16)
    bx := x + w - 176
    sec := MinSec(cfg[key], def)
    Chip(bx, y + 3, 32, 30, "-", false, "dn_" key, StepTime.Bind(key, -step, lo, hi, def))
    Tx(Format("{:02}:{:02}", sec // 60, Mod(sec, 60)), "mono", 13, 1, C.text, bx + 34, y, 76, 36, 1)
    Chip(bx + 144, y + 3, 32, 30, "+", false, "up_" key, StepTime.Bind(key, step, lo, hi, def))
}

StepTime(key, d, lo, hi, def) {
    sec := Min(hi, Max(lo, MinSec(cfg[key], def) + d))
    cfg[key] := Format("{}:{:02}", sec // 60, Mod(sec, 60))
    IniWrite cfg[key], INI, "raid", key
    Log("setting " key " = " cfg[key] " (applies at once)")
}

; a key in a space separated list setting (spread = "5 4 e r x")
ToggleList(key, k) {
    list := ""
    found := false
    for s in StrSplit(Trim(cfg[key]), " ") {
        if s = ""
            continue
        if s = k
            found := true
        else
            list .= (list = "" ? "" : " ") s
    }
    if !found
        list .= (list = "" ? "" : " ") k
    cfg[key] := list
    IniWrite list, INI, "raid", key
    Log("setting " key " = " list " (applies at once)")
}

ModeCard(x, y, w, h, title, desc, key, page, btnText := "Settings", soon := false) {
    hot := IsHot("mc_" title)
    Glass(x, y, w, h, 18, hot)
    Tx(title, "title", 16, 1, C.text, x + 20, y + 9, w - 110, 26)
    TxP(desc, "ui", 11, C.dim, x + 20, y + 35, w - 40, 30)
    if page != ""
        Hit(x, y, w, h, "mc_" title, SetPage.Bind(page))
    if soon
        Tx(soon = true ? "Coming soon" : soon, "ui", 11, 1, C.hi, x + w - 230, y + 9, 210, 26, 2)
    else if key != "" {
        on := cfg[key] = "1"
        DrawSwitch(x + w - 66, y + 9, on)
        Hit(x + w - 76, y + 4, 62, 38, "tg_" key, FlipKey.Bind(key))
    }
    if page != "" {
        Chip(x + 20, y + h - 30, 120, 24, btnText "  >", false, "go_" title, SetPage.Bind(page))
    }
}

PageModes() {
    cw2 := (CWD - 12) // 2, ch := (CHT - 24) // 3
    cards := [["Raid", "Enters the raid at the start of every hour. The game's Auto button fights; choose the raid and the start options.", "raid", "m_raid"],
              ["Speed Raid", "Every 30 min with the lowest unused character. Needs loadout 3 if loadouts are on.", "speed", "m_speed"],
              ["Infinity", "Farms waves while the raid is closed. The character stands still and uses the big AOE skills.", "infinity", "m_inf"],
              ["Dimension", "Titan or Curse Dimension instead of Infinity. Used first when both are on.", "titan", "m_titan"],
              ["Loadouts", "Switches the Bag loadout: raid 1, Infinity 2, Speed Raid 3. Set your loadouts first.", "loadouts", ""]]
    for i, mc in cards {   ; not "c": it would shadow the global theme object C
        col := Mod(i - 1, 2), row := (i - 1) // 2
        ModeCard(CX + col * (cw2 + 12), CY + row * (ch + 12), cw2, ch, mc[1], mc[2], mc[3], mc[4], "Settings", false)
    }
}

PageRaid() {
    BackBar("Raid", "Every hour, from createFrom (59:30) until the raid starts")
    py := CY + 46
    ph := 114                                              ; two rows of five chips (10 raids)
    Panel(CX, py, CWD, ph, "Raid to farm")
    cols := 5, cw5 := (CWD - 40 - (cols - 1) * 8) // cols, i := 0
    for k, v in RAIDS {
        if InStr(RAIDS_READY, " " k " ")
            Chip(CX + 20 + Mod(i, cols) * (cw5 + 8), py + 40 + (i // cols) * 36, cw5, 29, RaidShort(k), cfg["raidName"] = k, "raid_" k, PickRaid.Bind(k))
        i++
    }
    pe := py + ph + 10                                     ; how the bot gets in
    gf := cfg["raidEntry"] = "gf"
    Panel(CX, pe, CWD, 76, "Enter the raid by")
    cw4 := (CWD - 40 - 3 * 8) // 4
    Chip(CX + 20, pe + 38, cw4, 29, "Create", !gf, "entry_create", PickEntry.Bind("create"))
    Chip(CX + 20 + cw4 + 8, pe + 38, cw4, 29, "Group Finder", gf, "entry_gf", PickEntry.Bind("gf"))
    TxP(gf ? "Queues with other players. Not in the raid 2 min after it opens: the bot creates it, open to others."
           : "The bot creates the raid itself at createFrom.", "ui", 11, C.dim, CX + 20 + 2 * (cw4 + 8) + 8, pe + 34, 2 * cw4 - 8, 36)
    py2 := pe + 86
    Panel(CX, py2, CWD, 146, "Raid settings")
    colw := (CWD - 40 - 24) // 2
    solo := cfg["soloRaid"] = "1" && !gf                   ; Group Finder: a created raid is the fallback - always open
    ToggleRow(CX + 20, py2 + 38, colw, "Solo mode (Friends Only)", gf ? "Off with Group Finder: the fallback raid is open" : "Nobody can join, so Start is pressed at once", "soloRaid", gf)
    TxP("The game's Auto button does the fighting in the raid: the bot only keeps it on and waits for the end.", "ui", 11, C.dim, CX + 20, py2 + 92, colw, 40)
    rx := CX + 20 + colw + 24
    Stepper(rx, py2 + 38, colw, "PARTY wait before Start", "startDelay", 1, 0, 30, 1, "s", 10, "Needs Friends Only off", solo)
    Stepper(rx, py2 + 84, colw, "Early start at bonus", "startBonus", 10, 0, 300, 1, "%", 110, "Needs Friends Only off", solo)
}
PageSpeed() {
    BackBar("Speed Raid", "A short raid with one character, available every 30 minutes")
    Panel(CX, CY + 46, CWD, 244, "How it works")
    TxP("Every 30 minutes the bot opens the modes menu, picks Speed Raid and the lowest character that has not been used this week (used characters are dimmed).`n`nThe game's Auto button does the fighting: the bot only keeps it on until the run ends.`n`nSpeed Raid has priority over Infinity but not over the hourly raid. It is not started in the last 8 minutes of the hour.`n`nSpeed Raid resets once a week and used characters become free again. The author recommends running it on weekends, when the rewards are x2. When all characters are used, the bot waits for the weekly reset and then continues.", "ui", 13, C.text, CX + 20, CY + 90, CWD - 40, 196)
    Panel(CX, CY + 302, CWD, CHT - 302, "Settings")
    ToggleRow(CX + 20, CY + 344, (CWD - 40 - 24) // 2, "Speed Raid enabled", "Turn it off to skip Speed Raid completely", "speed")
    ToggleRow(CX + 20 + (CWD - 40 - 24) // 2 + 24, CY + 344, (CWD - 40 - 24) // 2, "Switch loadout", "All modes: raid 1, Infinity 2, Speed Raid 3", "loadouts")
}

PickTitanDiff(d) {
    cfg["titanDiff"] := d
    IniWrite d, INI, "raid", "titanDiff"
    Log("setting titanDiff = " d " (applies at the next run)")
}

PickTitanDim(d) {
    cfg["titanDim"] := d
    IniWrite d, INI, "raid", "titanDim"
    Log("setting titanDim = " d " (applies at the next run)")
}

PageTitan() {
    BackBar("Dimension", "Dimensions played by the bot on loadout 2")
    py := CY + 46
    Panel(CX, py, CWD, 92, "Mode")
    cw2 := (CWD - 40 - 12) // 2
    for i, d in [["Giant", "Titan"], ["Curse", "Curse"]]           ; [value in raid.ini titanDim, label]
        Chip(CX + 20 + (i - 1) * (cw2 + 12), py + 44, cw2, 32, d[2], cfg["titanDim"] = d[1], "tdim_" d[1], PickTitanDim.Bind(d[1]))
    py += 104
    Panel(CX, py, CWD, 92, "Difficulty")
    cw3 := (CWD - 40 - 2 * 12) // 3
    for i, d in ["Easy", "Hard", "Nightmare"]
        Chip(CX + 20 + (i - 1) * (cw3 + 12), py + 44, cw3, 32, d, cfg["titanDiff"] = d, "tdiff_" d, PickTitanDiff.Bind(d))
    py2 := py + 104
    Panel(CX, py2, CWD, 106, "Settings")
    colw := (CWD - 40 - 24) // 2
    ToggleRow(CX + 20, py2 + 40, colw, "Dimension enabled", "Replaces Infinity between raids", "titan")
    ToggleRow(CX + 20 + colw + 24, py2 + 40, colw, "Hardcore", "3 lives, +1 reward", "titanHard")
}

PageInfinity() {
    BackBar("Infinity", "Focus on big, long AOE skills - not the game's Auto Play")
    py := CY + 46
    Panel(CX, py, CWD, 200, "How the character fights")
    Tx("Infinity keeps its focus for late-end game", "ui", 11, 0, C.dim, CX + 20 + TxW("How the character fights", "title", 15, 1) + 14, py + 14, 320, 24)
    colw := (CWD - 40 - 24) // 2
    TxP(cfg["infFullAuto"] = "1" ? "The game's Auto plays: the bot only keeps it on. The settings on the right are used only when Auto is off."
        : "The character stands still: enemies walk into the big AOE skills, all other skills are pressed as soon as they are ready.", "ui", 12, C.dim, CX + 20, py + 44, colw, 70)
    ToggleRow(CX + 20, py + 130, colw, "Game's Auto plays", "Off = the bot presses the skills", "infFullAuto")
    rx := CX + 20 + colw + 24
    TimeStepper(rx, py + 40, colw, "Leave Infinity at", "infStop", 30, 600, 3480, 57 * 60 + 30, "Author recommends 57:30")
    Stepper(rx, py + 92, colw, "Pause between AOE", "spreadMs", 500, 1000, 20000, 1000, "s", 7000, "Author recommends 7 s", false)
    Stepper(rx, py + 144, colw, "Auto if enemies stuck", "infAuto", 5000, 0, 60000, 1000, "s", 15000, "AUTO for 5 s; 0 = off")
    py2 := py + 210
    Panel(CX, py2, CWD, CHT - 46 - 210, "Big AOE skills")
    nk := SKILL_KEYS.Length
    cw := (CWD - 40 - (nk - 1) * 8) // nk
    for i, k in SKILL_KEYS
        if SkillOn(k)
            Chip(CX + 20 + (i - 1) * (cw + 8), py2 + 36, cw, 30, StrUpper(k), InStr(" " cfg["spread"] " ", " " k " "), "sp_" k, ToggleList.Bind("spread", k))
        else
            ChipOff(CX + 20 + (i - 1) * (cw + 8), py2 + 36, cw, 30, StrUpper(k))
    TxP("Blue skills are the big area attacks. The bot presses them one at a time with a pause, so their effects do not overlap. All other skills are pressed as soon as they are ready.", "ui", 12, C.dim, CX + 20, py2 + 72, CWD - 40, 40)
}

PageStats() {
    Panel(CX, CY, CWD, 112, "Today")
    tw := (CWD - 40) // 3
    for i, t in [["raids", "Raids"], ["infRuns", "Infinity runs"], ["deaths", "Deaths"]] {
        x := CX + 20 + (i - 1) * tw
        Tx(StatDay(t[1]), "mono", 28, 1, C.text, x, CY + 44, tw - 10, 40)
        Tx(t[2], "ui", 12, 0, C.dim, x, CY + 82, tw - 10, 20)
    }
    py := CY + 124, hw := (CWD - 12) // 2
    for i, t in [["raidGems", "Gems"], ["raidTokens", "Tokens"]] {
        x := CX + (i - 1) * (hw + 12)
        Panel(x, py, hw, 132, t[2])
        cur := t[1] = "raidTokens" && runKind = "raid" && runTokens ? "  +" runTokens : ""
        Tx(sess[t[1]] cur, "mono", 28, 1, C.hi, x + 20, py + 44, hw - 40, 40)
        Tx("this run", "ui", 11, 0, C.dim, x + 20, py + 84, hw - 40, 16)
        Tx("today " StatDay(t[1]) "   ·   total " IniRead(INI, "stats", t[1] "Total", "0"), "mono", 12, 0, C.dim, x + 20, py + 102, hw - 40, 20)
    }
    ay := py + 144
    Panel(CX, ay, CWD, CHT - 144 - 124, "All time")
    Tx("raids " IniRead(INI, "stats", "raidsTotal", "0") "   ·   Infinity " IniRead(INI, "stats", "infRunsTotal", "0")
        . "   ·   deaths " IniRead(INI, "stats", "deathsTotal", "0"), "mono", 13, 0, C.text, CX + 20, ay + 44, CWD - 40, 24)
    Tx("Roblox restarts " IniRead(INI, "stats", "restartsTotal", "0") "   ·   Speed Raids " IniRead(INI, "stats", "speedRunsTotal", "0"), "mono", 13, 0, C.dim, CX + 20, ay + 70, CWD - 40, 24)
    armed := statsArm && A_TickCount - statsArm < 4000
    Btn(CX + CWD - 220, ay + 8, 200, 30, armed ? "Click again to reset" : "Reset statistics", "statsreset", StatsReset)
}

; two clicks within 4 s: wipes every counter (today, all time, this run) - the Speed Raid timer and other settings stay
StatsReset() {
    global statsArm
    if !statsArm || A_TickCount - statsArm > 4000 {
        statsArm := A_TickCount
        return
    }
    statsArm := 0
    IniDelete INI, "stats"
    for k in sess
        sess[k] := 0
    Log("statistics reset")
}

PageLook() {
    Panel(CX, CY, CWD, 140, "Colour theme")
    n := THEME_ORDER.Length, gap := 10
    sw := (CWD - 40 - (n - 1) * gap) // n
    cur := ThemeName()
    for i, name in THEME_ORDER {
        t := THEMES[name]
        x := CX + 20 + (i - 1) * (sw + gap), y := CY + 44
        id := "th_" name
        FillRR(x, y, sw, 76, 14, t.bg)
        GradRR(x + 10, y + 8, sw - 20, 26, 9, t.acc, 255, t.acc2, 255)
        FillRR(x + 10, y + 40, (sw - 20) // 2, 6, 3, t.hi)
        FillRR(x + 10, y + 50, sw - 20, 6, 3, t.card)
        StrokeRR(x, y, sw, 76, 14, name = cur ? C.hi : C.ov, name = cur ? 255 : 36, name = cur ? 2 : 1)
        if IsHot(id)
            FillRR(x, y, sw, 76, 14, C.ov, 18)
        Tx(THEME_TITLES.Get(name, StrUpper(SubStr(name, 1, 1)) SubStr(name, 2)), "ui", 10, 1, name = cur ? C.hi : C.dim, x, y + 58, sw, 16, 1)
        if name = "cosmos"                                 ; the author's default
            Tx("Author's pick", "ui", 10, 1, C.hi, x, y + 80, sw, 14, 1)
        Hit(x, y, sw, 76, id, SetTheme.Bind(name))
    }
    my := CY + 150
    Panel(CX, my, CWD, 80, "Sound")
    colw := (CWD - 40 - 24) // 2
    rx := CX + 20 + colw + 24
    ToggleRow(CX + 20, my + 34, colw, "Button sounds", "A short click when you press a button", "sfx")
    py := CY + 240
    Panel(CX, py, CWD, CHT - 240, "Files")
    bw := (CWD - 40 - 2 * 12) // 3
    Btn(CX + 20, py + 38, bw, 38, "Log file", "f_log", OpenPath.Bind(LOGFILE), false, Chr(0xE7C3))
    Btn(CX + 20 + bw + 12, py + 38, bw, 38, "Settings (raid.ini)", "f_ini", OpenPath.Bind(INI), false, Chr(0xE713))
    Btn(CX + 20 + 2 * (bw + 12), py + 38, bw, 38, "Screenshots", "f_shots", OpenPath.Bind(SHOTDIR), false, Chr(0xE722))
    Tx("Custom colours: add  bg= card= acc= acc2= hi=  (6-digit hex) under [theme] in raid.ini. Clicking a preset clears them.", "ui", 11, 0, C.dim, CX + 20, py + 84, CWD - 40, 18)
}

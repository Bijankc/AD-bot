#Requires AutoHotkey v2.0
#SingleInstance Force
; device_check.ahk - checks that this PC shows Roblox the way the bot's images were captured.
; Use: open Roblox, join Anime Dimensions, wait in the LOBBY (PLAY button visible), then run this file.
; It sets the Roblox window the same way the bot does (1920x1017 at 0,23 at 100%; 1920x1046 at 0,-6 at 150%), saves a screenshot of the game area
; to shots\device_check.png and writes the results to device_check.txt (and shows them).
SetWorkingDir A_ScriptDir
CoordMode "Pixel", "Screen"
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

GAME := "ahk_exe RobloxPlayerBeta.exe"
; the same as RaidBot.ahk: Roblox's top bar grows with the Windows scale, the window grows and moves up by as much
GAME_BAR_EXTRA := Round(58 * A_ScreenDPI / 96) - 58
GAME_W := 1920, GAME_H := 1017 + GAME_BAR_EXTRA, GAME_X := 0, GAME_Y := 23 - GAME_BAR_EXTRA, SCR_W := 1920, SCR_H := 1080
IMGDIR := A_ScriptDir "\img\"
OUT := A_ScriptDir "\device_check.txt"
rep := ""
try FileDelete OUT
Say(s) {
    global rep
    rep .= s "`n"
    try FileAppend s "`n", OUT, "UTF-8"            ; line by line: if something hangs, the file shows where
}

Say("AD Bot device check " FormatTime(, "yyyy-MM-dd HH:mm:ss"))
Say("screen " A_ScreenWidth "x" A_ScreenHeight ", Windows scale " Round(A_ScreenDPI / 96 * 100) "%")
MonitorGetWorkArea(MonitorGetPrimary(), &wl, &wt, &wr, &wb)
Say("work area " wl "," wt " - " wr "," wb (wb >= GAME_Y + GAME_H ? " (taskbar below the game area: ok)" : " (TASKBAR COVERS THE GAME AREA)"))

if !(hwnd := WinExist(GAME)) {
    Say("FAIL: Roblox is not running. Open the game, wait in the lobby and run this again.")
    Finish()
}
; how Roblox handles Windows scaling: 0 = unaware (Windows stretches it - images would NOT match), 1 = system, 2 = per monitor
ctx := DllCall("GetWindowDpiAwarenessContext", "ptr", hwnd, "ptr")
aw := DllCall("GetAwarenessFromDpiAwarenessContext", "ptr", ctx, "int")
Say("Roblox DPI awareness: " aw (aw = 0 ? " (UNAWARE - Windows stretches Roblox, this setup cannot work at 150%)" : " (draws in real pixels: ok)"))

if WinGetMinMax(GAME) = -1 || WinGetMinMax(GAME) = 1
    WinRestore GAME
WinActivate GAME
Sleep 600
WinGetClientPos , , , &ch, GAME
if ch >= A_ScreenHeight {
    Send "{F11}"
    Sleep 2000
}
Loop 3 {
    WinGetPos &wx, &wy, &ww, &wh, GAME
    WinGetClientPos &cx, &cy, &cw, &ch, GAME
    WinMove wx + (GAME_X - cx), wy + (GAME_Y - cy), ww + (GAME_W - cw), wh + (GAME_H - ch), GAME
    Sleep 600
}
WinGetClientPos &cx, &cy, &cw, &ch, GAME
ok := cx = GAME_X && Abs(cy - GAME_Y) <= 2 && cw = GAME_W && Abs(ch - GAME_H) <= 2
Say("Roblox client " cw "x" ch " at " cx "," cy (ok ? " (ok)" : " (WRONG - expected " GAME_W "x" GAME_H " at " GAME_X "," GAME_Y ")"))
MouseMove 300, SCR_H // 2, 0                       ; like the bot's ParkMouse: no hover highlight on buttons
Sleep 2500                                         ; Roblox re-lays out its interface after a resize

DirCreate A_ScriptDir "\shots"
SaveRegion(A_ScriptDir "\shots\device_check.png", 0, 0, SCR_W, SCR_H)
Say("screenshot: shots\device_check.png")

; PLAY in the lobby: the bot's own region and tolerance; also at 1.5x to tell whether Roblox enlarged its interface
Say("")
playOk := false
for f in ["play.png", "play_2.png"]
    if Find(f, 1500, 800, 1920, 1060, "*40 *TransFF00FF", &x, &y) {
        Say("PLAY found at its normal size (" f " at " x "," y "): the images match this PC")
        playOk := true
        break
    }
if !playOk {
    sz := PngSize(IMGDIR "play.png")
    big := Find("play.png", 0, 0, SCR_W, SCR_H, "*60 *TransFF00FF *w" Round(sz[1] * 1.5) " *h" Round(sz[2] * 1.5), &x, &y)
    Say(big ? "PLAY found only at 1.5x size (" x "," y "): Roblox enlarged its interface with the Windows scale - the images do NOT match"
            : "PLAY not found (is the lobby with the PLAY button on screen?)")
}
Say("")
Say(playOk && ok && aw != 0 ? "RESULT: OK - this PC is set up like the author's, the bot can run."
                            : "RESULT: NOT OK - see the lines above.")
Finish()

Find(name, x1, y1, x2, y2, opts, &x, &y) {
    x := 0, y := 0
    try return ImageSearch(&x, &y, x1, y1, x2, y2, opts " " IMGDIR name)
    return false
}

Finish() {
    if !A_Args.Length                                  ; "quiet" from the command line: no message box
        MsgBox rep, "AD Bot device check", "T120"
    ExitApp
}

PngSize(file) {
    f := FileOpen(file, "r")
    f.Pos := 16
    w := DllCall("ws2_32\ntohl", "UInt", f.ReadUInt(), "UInt")
    h := DllCall("ws2_32\ntohl", "UInt", f.ReadUInt(), "UInt")
    f.Close()
    return [w, h]
}

SaveRegion(file, sx, sy, w, h) {
    sdc := DllCall("GetDC", "ptr", 0, "ptr"), mdc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
    hbm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", w, "int", h, "ptr")
    old := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
    DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", sdc, "int", sx, "int", sy, "uint", 0x40CC0020)
    DllCall("SelectObject", "ptr", mdc, "ptr", old)
    DllCall("DeleteDC", "ptr", mdc), DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
    if !DllCall("GetModuleHandle", "str", "gdiplus", "ptr")
        DllCall("LoadLibrary", "str", "gdiplus")
    si := Buffer(24, 0), NumPut("uint", 1, si)
    DllCall("gdiplus\GdiplusStartup", "ptr*", &tok := 0, "ptr", si, "ptr", 0)
    DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &bmp := 0)
    clsid := Buffer(16), DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid)
    DllCall("gdiplus\GdipSaveImageToFile", "ptr", bmp, "wstr", file, "ptr", clsid, "ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "ptr", bmp), DllCall("gdiplus\GdiplusShutdown", "ptr", tok)
    DllCall("DeleteObject", "ptr", hbm)
}

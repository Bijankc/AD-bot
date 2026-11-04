; rewards.ahk - REWARDS panel (Speed Raid, new Raid screen): the gem card and the raid-token card are found by
; their icons (img\card_gem.png / card_gem_2.png / card_token.png, the icon above the number), the white number at the
; card's bottom-left is read by OCR. Own OCR files (OCR3_*), so nothing clashes with the counter OCR or ReadLootNumber.

OCR3_IN  := A_Temp "\adbot_ocr3.png"
OCR3_OUT := A_Temp "\adbot_ocr3.txt"
CARD_BOX := [700, 330, 1700, 560]                ; where the cards can be (they move with the card order, up to 5 cards)
tokFromScreen := false                            ; raid tokens of this run were read from the results: the in-fight counter must not be added

CardFind(name, &x, &y) => FindImg(name, &x, &y, CARD_BOX[1], CARD_BOX[2], CARD_BOX[3], CARD_BOX[4])

; number area: 64x34 at the card's bottom-left, from the icon template position
CardRegion(x, y) => [x - 30, y + 56, 64, 34]

CardParse(txt) {
    if RegExMatch(txt, "\d[\d,]*", &m) && (n := Integer(StrReplace(m[0], ","))) > 0 && n < 1000000
        return n
    return 0
}

CardNumber(x, y) {
    b := CardRegion(x, y)
    if SaveRegion(OCR3_IN, b[1], b[2], b[3], b[4]) != 0
        return 0
    for opts in ["-White", "-White -Thresh 175"] {
        OcrCall(OCR3_IN, OCR3_OUT, opts)
        txt := ""
        try txt := FileRead(OCR3_OUT, "UTF-8")
        try FileDelete OCR3_OUT
        if (n := CardParse(txt))
            return n
    }
    return 0
}

; kind: "raid" / "speed". true = the panel was there (read or not), false = no gem card on the screen
RewardCards(kind) {
    global runTokens, tokFromScreen
    ; raid results (4.11): other icons than Speed - raid_*_icon.png match exactly, card_* do not; they sit 7,10 px left/up of card_*
    gemT := kind = "raid" ? "raid_gem_icon.png" : "card_gem.png", tokT := kind = "raid" ? "raid_token_icon.png" : "card_token.png"
    dx := kind = "raid" ? 7 : 0, dy := kind = "raid" ? 10 : 0
    if !CardFind(gemT, &gx, &gy)
        return false
    SetStatus("results: reading rewards")
    ParkMouse()
    Sleep 1200                                           ; the cards are drawn one by one
    gems := 0, tokens := 0
    Loop 3 {
        if A_Index > 1
            Sleep 800
        if !gems && CardFind(gemT, &gx, &gy)
            gems := CardNumber(gx + dx, gy + dy)
        if !tokens && CardFind(tokT, &tx, &ty)
            tokens := CardNumber(tx + dx, ty + dy)
        if gems && tokens
            break
    }
    title := kind = "speed" ? "Speed Raid" : RaidTitle()
    pre := kind = "speed" ? "speed" : "raid"
    if gems
        Stat(pre "Gems", gems)
    if tokens {
        Stat(pre "Tokens", tokens)
        if kind = "raid"
            runTokens := 0, tokFromScreen := true         ; counted from the screen, the in-fight counter is not added
    }
    Log(title ": gems " (gems ? gems : "?") ", tokens " (tokens ? tokens : "?")
        . (gems && tokens ? "" : " (a card or number was not found - see the shot)"))
    return true
}

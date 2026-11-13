param([string]$Img, [string]$Out, [switch]$White, [switch]$Red,[int]$Scale = 3, [switch]$Lines, [int]$Thresh = 215,
      [string]$Serve, [int]$Parent = 0)
# Розпізнає текст на картинці вбудованим у Windows 10 OCR (Windows.Media.Ocr, англійська) і пише його в $Out.
# Викликає RaidBot.ahk: лічильник нагород у бою ("Rewards: 24") і числа під іконками нагород рейду.
# -White: лишити тільки білий текст (числа поверх іконок) - білі пікселі стають чорними на білому тлі.
#   Windows OCR на коротких числах капризний: те саме число читається не при кожному масштабі,
#   тому пробуємо масштаби 2, 3, 1, 4 по черзі, поки не з'являться цифри.
#   -Thresh: з якої яскравості (кожен канал) піксель вважається білим (за замовчуванням 215).
# -Lines: кожен рядок як "y<Tab>текст", де y - центр рядка в пікселях вихідної картинки (список рейдів:
#   бот шукає рядок з назвою рейду і тисне Create під ним).
# -Serve <тека>: режим сервера. Запуск PowerShell і завантаження OCR коштують ~1 с, тож бот запускає
#   сервер один раз і кладе в теку запити *.req (рядки: картинка, файл результату, ключі як у командному
#   рядку). Сервер сам закривається, коли зникає процес бота (-Parent).
try {
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
    $null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    function Await($op, [Type]$t) { $task = $asTask.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(-1) | Out-Null; $task.Result }
    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new("en-US"))
    $initError = ""
} catch {
    $initError = "ERROR " + $_.Exception.Message
}

function Recognize([System.Drawing.Bitmap]$bmpIn, [string]$tmp, [bool]$lines, [int]$scale) {
    $bmpIn.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($tmp)) ([Windows.Storage.StorageFile])
    $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $dec = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $sb = Await ($dec.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $res = Await ($engine.RecognizeAsync($sb)) ([Windows.Media.Ocr.OcrResult])
    $stream.Dispose()
    if ($lines) {
        return (($res.Lines | ForEach-Object {
            $r = ($_.Words | Select-Object -First 1).BoundingRect
            "{0}`t{1}" -f [int](($r.Y + $r.Height / 2) / $scale), $_.Text }) -join "`n")
    }
    return (($res.Lines | ForEach-Object { $_.Text }) -join "`n")
}

# одна картинка -> текст у файл $out
function OcrFile([string]$img, [string]$out, [bool]$white, [int]$scale, [bool]$lines, [int]$thresh) {
    try {
        if ($initError) { throw $initError }
        $tmp = [IO.Path]::ChangeExtension($img, ".ocr.png")
        $src = [System.Drawing.Bitmap]::FromFile($img)
        if ($white) {
            # поріг на рідному розмірі: білий текст -> чорний, решта -> біле
            $bw = New-Object System.Drawing.Bitmap $src.Width, $src.Height
            for ($y = 0; $y -lt $src.Height; $y++) {
                for ($x = 0; $x -lt $src.Width; $x++) {
                    $c = $src.GetPixel($x, $y)
                    # -Red (12.11): the red ENEMIES LEFT count of the Dimensions - red pixels become black
                    $hit = if ($script:redMode) { $c.R -gt 180 -and $c.G -lt 130 } else { $c.R -gt $thresh -and $c.G -gt $thresh -and $c.B -gt $thresh }
                    $v = if ($hit) { 0 } else { 255 }
                    $bw.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($v, $v, $v))
                }
            }
            $src.Dispose()
            $text = ""
            foreach ($sc in 2, 3, 1, 4) {
                # збільшуємо і кладемо на широкі білі поля: короткі числа без полів OCR часто не бачить
                $w = $bw.Width * $sc; $h = $bw.Height * $sc
                $pad = New-Object System.Drawing.Bitmap ($w + 120), ($h + 80)
                $gr = [System.Drawing.Graphics]::FromImage($pad)
                $gr.Clear([System.Drawing.Color]::White)
                $gr.DrawImage($bw, 60, 40, $w, $h)
                $gr.Dispose()
                $text = Recognize $pad $tmp $lines $sc
                $pad.Dispose()
                if ($text -match '\d') { break }
            }
            $bw.Dispose()
        } else {
            # дрібний текст гри розпізнається краще, якщо збільшити картинку
            $big = New-Object System.Drawing.Bitmap $src, ($src.Width * $scale), ($src.Height * $scale)
            $src.Dispose()
            $text = Recognize $big $tmp $lines $scale
            $big.Dispose()
        }
        Remove-Item $tmp -ErrorAction SilentlyContinue
    } catch {
        $text = "ERROR " + $_.Exception.Message
    }
    # пишемо через тимчасовий файл і перейменування, щоб бот не прочитав напівзаписаний результат
    [IO.File]::WriteAllText("$out.tmp", $text, (New-Object Text.UTF8Encoding($false)))
    Move-Item "$out.tmp" $out -Force
}

if (-not $Serve) {
    $script:redMode = $Red.IsPresent
    OcrFile $Img $Out ($White.IsPresent -or $Red.IsPresent) $Scale $Lines.IsPresent $Thresh
    exit
}

# ---- режим сервера ----
$lastParentCheck = [DateTime]::Now
while ($true) {
    if ($Parent -and ([DateTime]::Now - $lastParentCheck).TotalSeconds -ge 2) {
        $lastParentCheck = [DateTime]::Now
        try { $null = [System.Diagnostics.Process]::GetProcessById($Parent) } catch { break }
    }
    $reqs = @()
    try { $reqs = [IO.Directory]::GetFiles($Serve, "*.req") | Sort-Object } catch { }
    foreach ($req in $reqs) {
        try {
            $a = [IO.File]::ReadAllLines($req)
            Remove-Item $req -Force -ErrorAction SilentlyContinue
        } catch { continue }
        if ($a.Count -lt 2) { continue }
        # ключі - як у командному рядку: -White, -Lines, -Scale N, -Thresh N
        $opt = if ($a.Count -gt 2) { $a[2] -split '\s+' } else { @() }
        $script:redMode = $opt -contains '-Red'
        $white = ($opt -contains '-White') -or $script:redMode; $lines = $opt -contains '-Lines'; $scale = 3; $thresh = 215
        for ($i = 0; $i -lt $opt.Count - 1; $i++) {
            if ($opt[$i] -eq '-Scale') { $scale = [int]$opt[$i + 1] }
            if ($opt[$i] -eq '-Thresh') { $thresh = [int]$opt[$i + 1] }
        }
        OcrFile $a[0] $a[1] $white $scale $lines $thresh
    }
    Start-Sleep -Milliseconds 30
}

Add-Type -AssemblyName System.Drawing

function New-Bitmap {
    param(
        [int]$Width,
        [int]$Height
    )

    return [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Fill-Rect {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [System.Drawing.Color]$Color
    )

    for ($py = $Y; $py -lt ($Y + $Height); $py++) {
        for ($px = $X; $px -lt ($X + $Width); $px++) {
            if (($px -ge 0) -and ($py -ge 0) -and ($px -lt $Bitmap.Width) -and ($py -lt $Bitmap.Height)) {
                $Bitmap.SetPixel($px, $py, $Color)
            }
        }
    }
}

function Draw-HLine {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$X1,
        [int]$X2,
        [int]$Y,
        [System.Drawing.Color]$Color
    )

    for ($x = $X1; $x -le $X2; $x++) {
        if (($x -ge 0) -and ($x -lt $Bitmap.Width) -and ($Y -ge 0) -and ($Y -lt $Bitmap.Height)) {
            $Bitmap.SetPixel($x, $Y, $Color)
        }
    }
}

function Draw-VLine {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Y1,
        [int]$Y2,
        [int]$X,
        [System.Drawing.Color]$Color
    )

    for ($y = $Y1; $y -le $Y2; $y++) {
        if (($X -ge 0) -and ($X -lt $Bitmap.Width) -and ($y -ge 0) -and ($y -lt $Bitmap.Height)) {
            $Bitmap.SetPixel($X, $y, $Color)
        }
    }
}

function Draw-FilledCircle {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$CenterX,
        [int]$CenterY,
        [int]$Radius,
        [System.Drawing.Color]$Color
    )

    for ($y = -$Radius; $y -le $Radius; $y++) {
        for ($x = -$Radius; $x -le $Radius; $x++) {
            if (($x * $x) + ($y * $y) -le ($Radius * $Radius)) {
                $px = $CenterX + $x
                $py = $CenterY + $y
                if (($px -ge 0) -and ($py -ge 0) -and ($px -lt $Bitmap.Width) -and ($py -lt $Bitmap.Height)) {
                    $Bitmap.SetPixel($px, $py, $Color)
                }
            }
        }
    }
}

function Draw-NoteSprite {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$OffsetX,
        [int]$OffsetY,
        [System.Drawing.Color]$Fill,
        [System.Drawing.Color]$Shade,
        [System.Drawing.Color]$Highlight
    )

    Draw-FilledCircle $Bitmap ($OffsetX + 16) ($OffsetY + 16) 9 $Fill
    Draw-FilledCircle $Bitmap ($OffsetX + 16) ($OffsetY + 16) 7 $Shade
    Draw-FilledCircle $Bitmap ($OffsetX + 12) ($OffsetY + 12) 3 $Highlight
}

function Draw-HitZone {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$OffsetX,
        [int]$OffsetY,
        [System.Drawing.Color]$Fill,
        [System.Drawing.Color]$Shade,
        [System.Drawing.Color]$Highlight
    )

    Fill-Rect $Bitmap ($OffsetX + 2) $OffsetY 20 10 $Fill
    Fill-Rect $Bitmap ($OffsetX + 3) ($OffsetY + 1) 18 8 $Shade
    Fill-Rect $Bitmap ($OffsetX + 4) ($OffsetY + 1) 12 2 $Highlight
    Fill-Rect $Bitmap ($OffsetX + 11) ($OffsetY + 0) 2 10 $Highlight
}

function Get-NearestPaletteColor {
    param(
        [System.Drawing.Color]$Source,
        [System.Drawing.Color[]]$Palette
    )

    $bestColor = $Palette[0]
    $bestDistance = [double]::MaxValue

    foreach ($color in $Palette) {
        $dr = $Source.R - $color.R
        $dg = $Source.G - $color.G
        $db = $Source.B - $color.B
        $distance = ($dr * $dr) + ($dg * $dg) + ($db * $db)

        if ($distance -lt $bestDistance) {
            $bestDistance = $distance
            $bestColor = $color
        }
    }

    return $bestColor
}

function Build-BackgroundFromOriginal {
    param(
        [string]$SourcePath,
        [string]$OutputPath
    )

    $bgPalette = @(
        [System.Drawing.Color]::FromArgb(255, 0, 0, 0),
        [System.Drawing.Color]::FromArgb(255, 24, 18, 30),
        [System.Drawing.Color]::FromArgb(255, 46, 40, 56),
        [System.Drawing.Color]::FromArgb(255, 78, 72, 92),
        [System.Drawing.Color]::FromArgb(255, 118, 114, 130),
        [System.Drawing.Color]::FromArgb(255, 168, 166, 176),
        [System.Drawing.Color]::FromArgb(255, 224, 224, 224),
        [System.Drawing.Color]::FromArgb(255, 116, 24, 20),
        [System.Drawing.Color]::FromArgb(255, 228, 56, 48),
        [System.Drawing.Color]::FromArgb(255, 255, 200, 52),
        [System.Drawing.Color]::FromArgb(255, 160, 116, 20),
        [System.Drawing.Color]::FromArgb(255, 32, 124, 28),
        [System.Drawing.Color]::FromArgb(255, 96, 244, 88),
        [System.Drawing.Color]::FromArgb(255, 120, 76, 40),
        [System.Drawing.Color]::FromArgb(255, 208, 176, 120),
        [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
    )

    $source = [System.Drawing.Bitmap]::FromFile($SourcePath)
    $laneCenters = @(128, 160, 192)
    $laneColors = @(
        [System.Drawing.Color]::FromArgb(255, 168, 166, 176),
        [System.Drawing.Color]::FromArgb(255, 168, 166, 176),
        [System.Drawing.Color]::FromArgb(255, 168, 166, 176)
    )
    $laneGlowColors = @(
        [System.Drawing.Color]::FromArgb(255, 78, 72, 92),
        [System.Drawing.Color]::FromArgb(255, 78, 72, 92),
        [System.Drawing.Color]::FromArgb(255, 78, 72, 92)
    )
    $scaled = New-Bitmap -Width 320 -Height 224
    $g = [System.Drawing.Graphics]::FromImage($scaled)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $cropRect = [System.Drawing.Rectangle]::new(224, 120, 576, 605)
    $g.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, 320, 224), $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()

    # Reserve the top area for score / song title and clean lane markers from the original.
    Fill-Rect $scaled 0 0 320 46 $bgPalette[0]

    for ($lane = 0; $lane -lt 3; $lane++) {
        $center = $laneCenters[$lane]
        Fill-Rect $scaled ($center - 8) 46 16 178 $bgPalette[0]
        Fill-Rect $scaled ($center - 2) 46 4 178 $laneColors[$lane]
        Fill-Rect $scaled ($center - 4) 46 1 178 $laneGlowColors[$lane]
        Fill-Rect $scaled ($center + 3) 46 1 178 $laneGlowColors[$lane]
    }

    $output = New-Bitmap -Width 320 -Height 256
    Fill-Rect $output 0 0 320 256 $bgPalette[0]

    for ($row = 0; $row -lt 4; $row++) {
        for ($index = 0; $index -lt 16; $index++) {
            Fill-Rect $output ($index * 8) ($row * 8) 8 8 $bgPalette[$index]
        }
    }

    for ($y = 0; $y -lt 224; $y++) {
        for ($x = 0; $x -lt 320; $x++) {
            $color = $scaled.GetPixel($x, $y)
            $output.SetPixel($x, $y + 32, (Get-NearestPaletteColor -Source $color -Palette $bgPalette))
        }
    }

    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($OutputPath)) | Out-Null
    $output.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $output.Dispose()
    $scaled.Dispose()
    $source.Dispose()
}

function Build-PaletteSpriteSheet {
    param(
        [System.Drawing.Color[]]$PaletteColors,
        [scriptblock]$DrawContent,
        [int]$ContentHeight,
        [string]$OutputPath,
        [int]$CanvasWidth = 128
    )

    $transparent = $PaletteColors[0]
    $bitmap = New-Bitmap -Width $CanvasWidth -Height (32 + $ContentHeight)

    Fill-Rect $bitmap 0 0 $bitmap.Width $bitmap.Height $transparent

    for ($row = 0; $row -lt 4; $row++) {
        for ($index = 0; $index -lt 16; $index++) {
            $color = $PaletteColors[[Math]::Min($index, $PaletteColors.Count - 1)]
            Fill-Rect $bitmap ($index * 8) ($row * 8) 8 8 $color
        }
    }

    & $DrawContent $bitmap

    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($OutputPath)) | Out-Null
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

$transparent = [System.Drawing.Color]::FromArgb(255, 255, 0, 255)
$redPalette = @(
    $transparent,
    [System.Drawing.Color]::FromArgb(255, 120, 0, 0),
    [System.Drawing.Color]::FromArgb(255, 190, 16, 16),
    [System.Drawing.Color]::FromArgb(255, 255, 32, 32),
    [System.Drawing.Color]::FromArgb(255, 255, 120, 120)
)

$yellowPalette = @(
    $transparent,
    [System.Drawing.Color]::FromArgb(255, 152, 112, 0),
    [System.Drawing.Color]::FromArgb(255, 220, 172, 0),
    [System.Drawing.Color]::FromArgb(255, 255, 220, 40),
    [System.Drawing.Color]::FromArgb(255, 255, 244, 168)
)

$greenPalette = @(
    $transparent,
    [System.Drawing.Color]::FromArgb(255, 0, 104, 0),
    [System.Drawing.Color]::FromArgb(255, 16, 176, 16),
    [System.Drawing.Color]::FromArgb(255, 40, 240, 40),
    [System.Drawing.Color]::FromArgb(255, 160, 255, 160)
)

Build-PaletteSpriteSheet -PaletteColors $redPalette -ContentHeight 32 -OutputPath (Join-Path $PSScriptRoot "..\\res\\sprites\\notes\\note_red.png") -DrawContent {
    param($bmp)
    Draw-NoteSprite $bmp 0 32 $redPalette[3] $redPalette[2] $redPalette[4]
}

Build-PaletteSpriteSheet -PaletteColors $yellowPalette -ContentHeight 32 -OutputPath (Join-Path $PSScriptRoot "..\\res\\sprites\\notes\\note_yellow.png") -DrawContent {
    param($bmp)
    Draw-NoteSprite $bmp 0 32 $yellowPalette[3] $yellowPalette[2] $yellowPalette[4]
}

Build-PaletteSpriteSheet -PaletteColors $greenPalette -ContentHeight 32 -OutputPath (Join-Path $PSScriptRoot "..\\res\\sprites\\notes\\note_green.png") -DrawContent {
    param($bmp)
    Draw-NoteSprite $bmp 0 32 $greenPalette[3] $greenPalette[2] $greenPalette[4]
}

Build-PaletteSpriteSheet -PaletteColors $redPalette -ContentHeight 16 -CanvasWidth 144 -OutputPath (Join-Path $PSScriptRoot "..\\res\\ui\\hit_zone\\hit_zone_red.png") -DrawContent {
    param($bmp)
    Draw-HitZone $bmp 0 32 $redPalette[3] $redPalette[2] $redPalette[4]
}

Build-PaletteSpriteSheet -PaletteColors $yellowPalette -ContentHeight 16 -CanvasWidth 144 -OutputPath (Join-Path $PSScriptRoot "..\\res\\ui\\hit_zone\\hit_zone_yellow.png") -DrawContent {
    param($bmp)
    Draw-HitZone $bmp 0 32 $yellowPalette[3] $yellowPalette[2] $yellowPalette[4]
}

Build-PaletteSpriteSheet -PaletteColors $greenPalette -ContentHeight 16 -CanvasWidth 144 -OutputPath (Join-Path $PSScriptRoot "..\\res\\ui\\hit_zone\\hit_zone_green.png") -DrawContent {
    param($bmp)
    Draw-HitZone $bmp 0 32 $greenPalette[3] $greenPalette[2] $greenPalette[4]
}

Build-BackgroundFromOriginal -SourcePath (Join-Path $PSScriptRoot "..\\res\\imported\\gameplay\\Fondo.png") -OutputPath (Join-Path $PSScriptRoot "..\\res\\backgrounds\\gameplay\\lane_bg.png")

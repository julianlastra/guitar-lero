Add-Type -AssemblyName System.Drawing

function New-Bitmap {
    param(
        [int]$Width,
        [int]$Height
    )

    return [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Get-Saturation {
    param([System.Drawing.Color]$Color)

    $max = [Math]::Max($Color.R, [Math]::Max($Color.G, $Color.B))
    $min = [Math]::Min($Color.R, [Math]::Min($Color.G, $Color.B))

    if ($max -eq 0) { return 0.0 }
    return ($max - $min) / [double]$max
}

function Get-ColorDistance {
    param(
        [System.Drawing.Color]$A,
        [System.Drawing.Color]$B
    )

    return ([Math]::Abs($A.R - $B.R) + [Math]::Abs($A.G - $B.G) + [Math]::Abs($A.B - $B.B))
}

function Get-Corners {
    param([System.Drawing.Bitmap]$Bitmap)

    return @(
        $Bitmap.GetPixel(0, 0),
        $Bitmap.GetPixel($Bitmap.Width - 1, 0),
        $Bitmap.GetPixel(0, $Bitmap.Height - 1),
        $Bitmap.GetPixel($Bitmap.Width - 1, $Bitmap.Height - 1)
    )
}

function Get-MinCornerDistance {
    param(
        [System.Drawing.Color]$Color,
        [object[]]$Corners
    )

    $minDistance = 999999

    foreach ($corner in $Corners) {
        $distance = Get-ColorDistance $Color $corner
        if ($distance -lt $minDistance) {
            $minDistance = $distance
        }
    }

    return $minDistance
}

function Find-SeedBounds {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [double]$SaturationThreshold,
        [int]$MinChannel
    )

    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $color = $Bitmap.GetPixel($x, $y)
            $max = [Math]::Max($color.R, [Math]::Max($color.G, $color.B))
            if ($max -lt $MinChannel) { continue }

            if ((Get-Saturation $color) -lt $SaturationThreshold) { continue }

            if ($x -lt $minX) { $minX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }

    if ($maxX -lt 0) {
        throw "No se encontraron seeds en el recorte."
    }

    return @{
        X = $minX
        Y = $minY
        Width = $maxX - $minX + 1
        Height = $maxY - $minY + 1
    }
}

function Copy-Crop {
    param(
        [System.Drawing.Bitmap]$Source,
        [System.Drawing.Rectangle]$Rect
    )

    $crop = New-Bitmap -Width $Rect.Width -Height $Rect.Height
    $g = [System.Drawing.Graphics]::FromImage($crop)
    $g.DrawImage($Source, [System.Drawing.Rectangle]::new(0, 0, $Rect.Width, $Rect.Height), $Rect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    return $crop
}

function Convert-ToTransparentSprite {
    param(
        [System.Drawing.Bitmap]$Bitmap
    )

    $corners = Get-Corners $Bitmap
    $out = New-Bitmap -Width $Bitmap.Width -Height $Bitmap.Height

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $color = $Bitmap.GetPixel($x, $y)
            $max = [Math]::Max($color.R, [Math]::Max($color.G, $color.B))
            $saturation = Get-Saturation $color
            $cornerDistance = Get-MinCornerDistance $color $corners
            $keep = $false

            if (($saturation -ge 0.18) -and ($max -ge 45)) {
                $keep = $true
            }
            elseif (($max -le 70) -and ($cornerDistance -ge 50)) {
                $keep = $true
            }
            elseif (($max -ge 180) -and ($cornerDistance -ge 60)) {
                $keep = $true
            }

            if ($keep) {
                $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $color))
            }
            else {
                $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
            }
        }
    }

    return $out
}

function Resize-Bitmap {
    param(
        [System.Drawing.Bitmap]$Source,
        [int]$Width,
        [int]$Height
    )

    $dest = New-Bitmap -Width $Width -Height $Height
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($Source, [System.Drawing.Rectangle]::new(0, 0, $Width, $Height))
    $g.Dispose()
    return $dest
}

function Place-OnCanvas {
    param(
        [System.Drawing.Bitmap]$Source,
        [int]$CanvasWidth,
        [int]$CanvasHeight
    )

    $dest = New-Bitmap -Width $CanvasWidth -Height $CanvasHeight
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.DrawImage($Source, 0, 0, $Source.Width, $Source.Height)
    $g.Dispose()
    return $dest
}

function Get-OpaqueColorsByFrequency {
    param([System.Drawing.Bitmap]$Source)

    $counts = @{}

    for ($y = 0; $y -lt $Source.Height; $y++) {
        for ($x = 0; $x -lt $Source.Width; $x++) {
            $color = $Source.GetPixel($x, $y)
            if ($color.A -eq 0) { continue }

            $key = "{0:X2}{1:X2}{2:X2}" -f $color.R, $color.G, $color.B
            if ($counts.ContainsKey($key)) {
                $counts[$key]++
            }
            else {
                $counts[$key] = 1
            }
        }
    }

    return $counts.GetEnumerator() |
        Sort-Object Value -Descending |
        ForEach-Object {
            $r = [Convert]::ToInt32($_.Key.Substring(0, 2), 16)
            $g = [Convert]::ToInt32($_.Key.Substring(2, 2), 16)
            $b = [Convert]::ToInt32($_.Key.Substring(4, 2), 16)
            [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
        }
}

function Convert-ToRescompRGBSprite {
    param(
        [System.Drawing.Bitmap]$Source,
        [System.Drawing.Color]$TransparentColor
    )

    $paletteColors = New-Object System.Collections.Generic.List[System.Drawing.Color]
    $paletteColors.Add($TransparentColor)

    foreach ($color in (Get-OpaqueColorsByFrequency -Source $Source)) {
        if ($paletteColors.Count -ge 16) { break }
        $paletteColors.Add($color)
    }

    while ($paletteColors.Count -lt 16) {
        $paletteColors.Add($TransparentColor)
    }

    $canvas = New-Bitmap -Width 128 -Height 64

    for ($y = 0; $y -lt 64; $y++) {
        for ($x = 0; $x -lt 128; $x++) {
            $canvas.SetPixel($x, $y, $TransparentColor)
        }
    }

    for ($row = 0; $row -lt 4; $row++) {
        for ($index = 0; $index -lt 16; $index++) {
            $color = $paletteColors[$index]
            for ($tileY = 0; $tileY -lt 8; $tileY++) {
                for ($tileX = 0; $tileX -lt 8; $tileX++) {
                    $canvas.SetPixel(($index * 8) + $tileX, ($row * 8) + $tileY, $color)
                }
            }
        }
    }

    for ($y = 0; $y -lt $Source.Height; $y++) {
        for ($x = 0; $x -lt $Source.Width; $x++) {
            $color = $Source.GetPixel($x, $y)
            if ($color.A -eq 0) {
                $canvas.SetPixel($x, $y + 32, $TransparentColor)
            }
            else {
                $canvas.SetPixel($x, $y + 32, [System.Drawing.Color]::FromArgb(255, $color.R, $color.G, $color.B))
            }
        }
    }

    return $canvas
}

function Export-SpriteFromRegion {
    param(
        [string]$SourcePath,
        [System.Drawing.Rectangle]$Region,
        [string]$OutputPath,
        [int]$OutputWidth,
        [int]$OutputHeight,
        [int]$Padding = 10,
        [int]$CanvasWidth = 0,
        [int]$CanvasHeight = 0,
        [switch]$BuildRescompSprite
    )

    $source = [System.Drawing.Bitmap]::FromFile($SourcePath)
    $regionCrop = Copy-Crop -Source $source -Rect $Region
    $seedBounds = Find-SeedBounds -Bitmap $regionCrop -SaturationThreshold 0.18 -MinChannel 55

    $x = [Math]::Max(0, $seedBounds.X - $Padding)
    $y = [Math]::Max(0, $seedBounds.Y - $Padding)
    $w = [Math]::Min($regionCrop.Width - $x, $seedBounds.Width + ($Padding * 2))
    $h = [Math]::Min($regionCrop.Height - $y, $seedBounds.Height + ($Padding * 2))

    $tightRect = [System.Drawing.Rectangle]::new($x, $y, $w, $h)
    $tightCrop = Copy-Crop -Source $regionCrop -Rect $tightRect
    $transparent = Convert-ToTransparentSprite -Bitmap $tightCrop
    $scaled = Resize-Bitmap -Source $transparent -Width $OutputWidth -Height $OutputHeight
    $final = $scaled

    if (($CanvasWidth -gt 0) -and ($CanvasHeight -gt 0)) {
        $final = Place-OnCanvas -Source $scaled -CanvasWidth $CanvasWidth -CanvasHeight $CanvasHeight
    }

    if ($BuildRescompSprite) {
        $rescompSprite = Convert-ToRescompRGBSprite -Source $scaled -TransparentColor ([System.Drawing.Color]::FromArgb(255, 255, 0, 255))
        if ($final -ne $scaled) {
            $final.Dispose()
        }
        $final = $rescompSprite
    }

    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($OutputPath)) | Out-Null
    $final.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

    if ($final -ne $scaled) {
        $final.Dispose()
    }
    $scaled.Dispose()
    $transparent.Dispose()
    $tightCrop.Dispose()
    $regionCrop.Dispose()
    $source.Dispose()
}

$notesSource = Join-Path $PSScriptRoot "..\\res\\imported\\gameplay\\Notas.png"
$barsSource = Join-Path $PSScriptRoot "..\\res\\imported\\gameplay\\Barras zona de impacto.png"

Export-SpriteFromRegion -SourcePath $notesSource -Region ([System.Drawing.Rectangle]::new(190, 250, 320, 320)) -OutputPath (Join-Path $PSScriptRoot "..\\res\\sprites\\notes\\note_red.png") -OutputWidth 32 -OutputHeight 32 -BuildRescompSprite
Export-SpriteFromRegion -SourcePath $notesSource -Region ([System.Drawing.Rectangle]::new(620, 250, 320, 320)) -OutputPath (Join-Path $PSScriptRoot "..\\res\\sprites\\notes\\note_yellow.png") -OutputWidth 32 -OutputHeight 32 -BuildRescompSprite
Export-SpriteFromRegion -SourcePath $notesSource -Region ([System.Drawing.Rectangle]::new(1010, 250, 320, 320)) -OutputPath (Join-Path $PSScriptRoot "..\\res\\sprites\\notes\\note_green.png") -OutputWidth 32 -OutputHeight 32 -BuildRescompSprite

Export-SpriteFromRegion -SourcePath $barsSource -Region ([System.Drawing.Rectangle]::new(170, 120, 320, 220)) -OutputPath (Join-Path $PSScriptRoot "..\\res\\ui\\hit_zone\\hit_zone_red.png") -OutputWidth 64 -OutputHeight 16 -Padding 8
Export-SpriteFromRegion -SourcePath $barsSource -Region ([System.Drawing.Rectangle]::new(560, 120, 320, 220)) -OutputPath (Join-Path $PSScriptRoot "..\\res\\ui\\hit_zone\\hit_zone_yellow.png") -OutputWidth 64 -OutputHeight 16 -Padding 8
Export-SpriteFromRegion -SourcePath $barsSource -Region ([System.Drawing.Rectangle]::new(980, 120, 320, 220)) -OutputPath (Join-Path $PSScriptRoot "..\\res\\ui\\hit_zone\\hit_zone_green.png") -OutputWidth 64 -OutputHeight 16 -Padding 8

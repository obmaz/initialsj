Add-Type -AssemblyName System.Drawing

function Test-BackgroundPixel {
  param(
    [System.Drawing.Color]$Color
  )

  if ($Color.A -eq 0) {
    return $false
  }

  $avg = ($Color.R + $Color.G + $Color.B) / 3.0
  $spread = (
    [Math]::Max($Color.R, [Math]::Max($Color.G, $Color.B)) -
    [Math]::Min($Color.R, [Math]::Min($Color.G, $Color.B))
  )

  return (($avg -ge 175 -and $spread -le 28) -or ($avg -ge 235))
}

$targets = Get-ChildItem 'assets\images\vehicles\player_*_3d.png' |
  Where-Object { $_.Name -ne 'player_ae86_3d.png' }

foreach ($target in $targets) {
  $bitmap = [System.Drawing.Bitmap]::new($target.FullName)
  try {
    $width = $bitmap.Width
    $height = $bitmap.Height
    $edgeXs = @(0, ($width - 1))
    $edgeYs = @(0, ($height - 1))
    $visited = New-Object 'bool[,]' $width, $height
    $queue = [System.Collections.Generic.Queue[System.Drawing.Point]]::new()

    for ($x = 0; $x -lt $width; $x++) {
      foreach ($y in $edgeYs) {
        if (-not $visited[$x, $y] -and (Test-BackgroundPixel $bitmap.GetPixel($x, $y))) {
          $visited[$x, $y] = $true
          $queue.Enqueue([System.Drawing.Point]::new($x, $y))
        }
      }
    }

    for ($y = 0; $y -lt $height; $y++) {
      foreach ($x in $edgeXs) {
        if (-not $visited[$x, $y] -and (Test-BackgroundPixel $bitmap.GetPixel($x, $y))) {
          $visited[$x, $y] = $true
          $queue.Enqueue([System.Drawing.Point]::new($x, $y))
        }
      }
    }

    while ($queue.Count -gt 0) {
      $point = $queue.Dequeue()
      foreach ($offset in @(
          [System.Drawing.Point]::new(-1, 0),
          [System.Drawing.Point]::new(1, 0),
          [System.Drawing.Point]::new(0, -1),
          [System.Drawing.Point]::new(0, 1)
        )) {
        $nx = $point.X + $offset.X
        $ny = $point.Y + $offset.Y

        if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $width -or $ny -ge $height) {
          continue
        }

        if ($visited[$nx, $ny]) {
          continue
        }

        if (-not (Test-BackgroundPixel $bitmap.GetPixel($nx, $ny))) {
          continue
        }

        $visited[$nx, $ny] = $true
        $queue.Enqueue([System.Drawing.Point]::new($nx, $ny))
      }
    }

    for ($x = 0; $x -lt $width; $x++) {
      for ($y = 0; $y -lt $height; $y++) {
        if ($visited[$x, $y]) {
          $color = $bitmap.GetPixel($x, $y)
          $bitmap.SetPixel(
            $x,
            $y,
            [System.Drawing.Color]::FromArgb(0, $color.R, $color.G, $color.B)
          )
        }
      }
    }

    $tempPath = Join-Path $target.DirectoryName ($target.BaseName + '.tmp.png')
    if (Test-Path $tempPath) {
      Remove-Item -LiteralPath $tempPath -Force
    }
    $bitmap.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "Updated $($target.Name)"
  }
  finally {
    $bitmap.Dispose()
  }

  Move-Item -LiteralPath $tempPath -Destination $target.FullName -Force
}

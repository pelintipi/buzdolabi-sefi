# assets\app_icon\icon_1024.png dosyasından iOS ve web ikonlarını üretir:
#   powershell -ExecutionPolicy Bypass -File tool\ikonlari_uret.ps1
# (Önce ikonu çiz: flutter test tool\uygulama_ikonu_test.dart)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$proje = Split-Path -Parent $PSScriptRoot
$kaynak = [System.Drawing.Image]::FromFile("$proje\assets\app_icon\icon_1024.png")

function Yaz([int]$px, [string]$hedef) {
  # App Store saydamlık kanalı olan ikonu reddeder: 24 bit RGB.
  $bmp = New-Object System.Drawing.Bitmap($px, $px, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.DrawImage($kaynak, 0, 0, $px, $px)
  $g.Dispose()
  $bmp.Save($hedef, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

# iOS: Contents.json'daki her dosya, boyut × ölçek pikselde.
$set = "$proje\ios\Runner\Assets.xcassets\AppIcon.appiconset"
$json = Get-Content "$set\Contents.json" -Raw | ConvertFrom-Json
$sayi = 0
foreach ($img in $json.images) {
  if (-not $img.filename) { continue }
  $boyut = [double]($img.size -split 'x')[0]
  $olcek = [double]($img.scale -replace 'x', '')
  Yaz ([int][math]::Round($boyut * $olcek)) "$set\$($img.filename)"
  $sayi++
}

# Web (tarayıcı ve "Ana Ekrana Ekle").
Yaz 192 "$proje\web\icons\Icon-192.png"
Yaz 512 "$proje\web\icons\Icon-512.png"
Yaz 192 "$proje\web\icons\Icon-maskable-192.png"
Yaz 512 "$proje\web\icons\Icon-maskable-512.png"
Yaz 32 "$proje\web\favicon.png"

$kaynak.Dispose()
Write-Output "iOS: $sayi ikon, web: 5 ikon üretildi."

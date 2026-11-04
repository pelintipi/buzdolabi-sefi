# Ekran testlerinin görüntülerinden yerel önizleme sayfası üretir:
#   powershell -File tool\onizleme.ps1          (önce testleri çalıştırır)
#   powershell -File tool\onizleme.ps1 -TestYok (sadece sayfayı yeniden kurar)
# Çıktı: onizleme\index.html — tarayıcıda çift tıklayarak açılır. Link ya da
# internet gerekmez; klasör .gitignore'da, GitHub'a gönderilmez.
param([switch]$TestYok)

$ErrorActionPreference = 'Stop'
$proje = Split-Path -Parent $PSScriptRoot
Set-Location $proje

if (-not $TestYok) {
  $env:PATH = "$env:USERPROFILE\flutter\bin;$env:PATH"
  # Kısa (8.3) geçici klasör yolu Flutter paketlerini bozuyor.
  $env:TEMP = "$env:USERPROFILE\AppData\Local\Temp"; $env:TMP = $env:TEMP
  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'Testler geçmedi, önizleme üretilmedi.' }
}

$cikti = Join-Path $proje 'onizleme'
if (Test-Path $cikti) { Remove-Item -Recurse -Force $cikti }
New-Item -ItemType Directory -Force "$cikti\img", "$cikti\fonts" | Out-Null
Copy-Item -Recurse "$PSScriptRoot\onizleme\props" "$cikti\props"
Copy-Item "$proje\assets\fonts\*.ttf" "$cikti\fonts\"

# Ana akış + ek akışlar (önek, klasör). Sıra şablondaki /*PROTO2..6*/ ile aynı.
$akislar = @(
  @('t', 'degisiklik_raporlari\2026-11-04_tiktok-kaydet'),
  @('a', 'degisiklik_raporlari\2026-11-04_anket-ve-tarif-sekmeleri'),
  @('v', 'degisiklik_raporlari\2026-11-04_v2-ozellikler'),
  @('k', 'degisiklik_raporlari\2026-11-04_koleksiyonlar'),
  @('h', 'degisiklik_raporlari\2026-11-04_ana-sayfa')
)
Copy-Item "$proje\test_raporu\*.png" "$cikti\img\"
foreach ($a in $akislar) {
  Get-ChildItem "$proje\$($a[1])\*.png" |
    ForEach-Object { Copy-Item $_.FullName "$cikti\img\$($a[0])$($_.Name)" }
}

$enc = New-Object System.Text.UTF8Encoding($false)
$sayfa = [IO.File]::ReadAllText("$PSScriptRoot\onizleme\sablon.html", $enc)
$sayfa = $sayfa.Replace('/*PROTO*/null',
  [IO.File]::ReadAllText("$proje\test_raporu\prototip.json", $enc))
for ($i = 0; $i -lt $akislar.Count; $i++) {
  $json = [IO.File]::ReadAllText("$proje\$($akislar[$i][1])\prototip.json", $enc)
  $sayfa = $sayfa.Replace("/*PROTO$($i + 2)*/null", $json)
}
[IO.File]::WriteAllText("$cikti\index.html", $sayfa, $enc)

$ekran = (Get-ChildItem "$cikti\img\*.png").Count
Write-Output "Önizleme hazır: $cikti\index.html ($ekran ekran)"

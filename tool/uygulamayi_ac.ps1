# Uygulamanın kendisini bu bilgisayardan yayınlar; tarayıcıda ve aynı Wi-Fi'deki
# telefonda gerçek uygulama gibi açılır (yapıt ya da internet linki yok):
#   powershell -ExecutionPolicy Bypass -File tool\uygulamayi_ac.ps1
# Kapatmak için bu pencerede q'ya bas ya da pencereyi kapat.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$env:PATH = "$env:USERPROFILE\flutter\bin;$env:PATH"
# Kısa (8.3) geçici klasör yolu Flutter paketlerini bozuyor.
$env:TEMP = "$env:USERPROFILE\AppData\Local\Temp"; $env:TMP = $env:TEMP

$port = 8080
$ip = Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
  Select-Object -First 1 -ExpandProperty IPAddress

Write-Output ''
Write-Output "  Bilgisayarda: http://localhost:$port"
if ($ip) { Write-Output "  Telefonda (aynı Wi-Fi): http://${ip}:$port" }
Write-Output '  İlk açılışta Windows güvenlik duvarı izin sorarsa "Özel ağlar"a izin ver.'
Write-Output ''

# --release: telefonda hızlı çalışsın diye. 0.0.0.0: ağdaki cihazlar da erişsin.
# ANKET_HER_ACILISTA: test için her yenilemede açılış anketi yeniden çıkar ve
# dolaptaki malzemeler silinir (yalnızca bu yerel test sunucusunda).
flutter run -d web-server --release --web-hostname 0.0.0.0 --web-port $port `
  --dart-define=ANKET_HER_ACILISTA=true

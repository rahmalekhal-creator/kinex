# Kinex: check the server, connect the phone (cable OR Wi-Fi), install and start the app.
#
# WAMP is started automatically if it is not running.
#
# Normal use (copy the whole line into PowerShell):
#     powershell -ExecutionPolicy Bypass -File D:\startup\kinex\Kinex\tool\phone.ps1 -NoBuild   install the app that is already built
#     powershell -ExecutionPolicy Bypass -File D:\startup\kinex\Kinex\tool\phone.ps1            build first (after code changes, takes a while)
#     powershell -ExecutionPolicy Bypass -File D:\startup\kinex\Kinex\tool\phone.ps1 -Logs      show the timing log of the app
#
# Wi-Fi: do this ONCE (and again after the phone restarts or changes Wi-Fi), with the cable plugged in:
#     powershell -ExecutionPolicy Bypass -File D:\startup\kinex\Kinex\tool\phone.ps1 -SetupWifi
# After that you can unplug the cable: the script reconnects over Wi-Fi by itself.
param([switch]$Logs, [switch]$NoBuild, [switch]$SetupWifi)

$ErrorActionPreference = 'Continue'
$proj = 'D:\startup\kinex\Kinex'
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:GRADLE_USER_HOME = 'D:\kinex-tools\gradle'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$pkg = 'com.example.reeducation'
$wifiFile = 'D:\kinex-tools\phone_wifi.txt'      # remembers the phone's Wi-Fi address, e.g. 192.168.1.4:5555

function Test-Backend {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 6 'http://localhost/reed/get_patient_videos_home.php?account_id=1'
        return ($r.Content -match '"error"')   # a JSON answer from the PHP code (it reached the database)
    } catch { return $false }
}
function Get-Devices { @(& $adb devices | Select-String '\sdevice$' | ForEach-Object { ($_.Line -split '\s+')[0] }) }

Write-Host '== 1/3 server (WAMP: Apache + MySQL)'
if (-not (Test-Backend) -and (Test-Path 'C:\wamp64\wampmanager.exe')) {
    Write-Host '   starting WAMP...'
    Start-Process 'C:\wamp64\wampmanager.exe'
    for ($i = 0; $i -lt 30 -and -not (Test-Backend); $i++) { Start-Sleep 3 }
}
if (-not (Test-Backend)) {
    Write-Host '   The server does not answer. Do this, then run the script again:'
    Write-Host '     1. Start WAMP (Start menu -> WAMP64) and wait until its taskbar icon is GREEN.'
    Write-Host '     2. Check that the folder C:\wamp64\www\reed exists (it should link to D:\startup\kinex\Kinex\reed).'
    exit 1
}
Write-Host '   server answers: OK'

Write-Host '== 2/3 phone'
& $adb start-server | Out-Null
$devs = Get-Devices
$usb = $devs | Where-Object { $_ -notmatch ':\d+$' } | Select-Object -First 1

if ($SetupWifi) {
    if (-not $usb) { Write-Host '   Plug the phone in with the CABLE (unlocked, USB debugging allowed) and run this again.'; exit 1 }
    $ip = (& $adb -s $usb shell "ip -f inet addr show wlan0") | Select-String 'inet (\d+\.\d+\.\d+\.\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Select-Object -First 1
    if (-not $ip) { Write-Host '   The phone has no Wi-Fi address: connect the phone to the same Wi-Fi as this PC, then run again.'; exit 1 }
    & $adb -s $usb tcpip 5555 | Out-Null
    Start-Sleep 3
    & $adb connect "${ip}:5555"
    Set-Content -Path $wifiFile -Value "${ip}:5555"
    Write-Host "   Wi-Fi set up: ${ip}:5555. You can unplug the cable and run the normal command."
    exit 0
}

$serial = $usb
if (-not $serial) {
    # no cable: try the Wi-Fi address that was saved by -SetupWifi
    $wifi = $devs | Where-Object { $_ -match ':\d+$' } | Select-Object -First 1
    if (-not $wifi -and (Test-Path $wifiFile)) {
        $addr = (Get-Content $wifiFile -Raw).Trim()
        Write-Host "   no cable: connecting over Wi-Fi to $addr ..."
        & $adb connect $addr | Out-Null
        Start-Sleep 2
        $wifi = Get-Devices | Where-Object { $_ -match ':\d+$' } | Select-Object -First 1
    }
    $serial = $wifi
}
if (-not $serial) {
    Write-Host '   NO PHONE FOUND.'
    Write-Host '   - With the cable: plug it in, unlock the phone, tap "Allow USB debugging".'
    Write-Host '   - Over Wi-Fi: the phone must be on the same Wi-Fi as this PC. If it was restarted or changed Wi-Fi,'
    Write-Host '     plug the cable once and run this script with -SetupWifi.'
    exit 1
}
Write-Host ('   using ' + $serial + $(if ($serial -match ':\d+$') { '  (Wi-Fi)' } else { '  (cable)' }))
# lets the phone reach the PC server through this connection: the app uses 127.0.0.1:8080
& $adb -s $serial reverse tcp:8080 tcp:80 | Out-Null

if ($Logs) {
    & $adb -s $serial logcat -c
    Write-Host 'Timing log of the app (use the app now; press Ctrl+C to stop):'
    & $adb -s $serial logcat -s flutter:I | Select-String 'kinex'
    exit 0
}

Write-Host '== 3/3 app'
Set-Location $proj
if (-not $NoBuild) { flutter build apk --release --target-platform android-arm64 }
& $adb -s $serial install -r "$proj\build\app\outputs\flutter-apk\app-release.apk"
& $adb -s $serial shell pm grant $pkg android.permission.CAMERA
& $adb -s $serial shell am start -n "$pkg/.MainActivity" | Out-Null
Write-Host ''
Write-Host 'The app is open on the phone.'
Write-Host $(if ($serial -match ':\d+$') { 'You are on Wi-Fi: no cable needed, but keep the phone and this PC on the same Wi-Fi.' } else { 'Keep the cable plugged in while you use the app.' })

# ============================================================
#  在雷电模拟器中预览
#  1) 启动模拟器  2) 安装 APK  3) 启动 App  4) 截图到 tools/shots/
#
#  用法:
#    pwsh tools/run-on-emulator.ps1
#    pwsh tools/run-on-emulator.ps1 -Apk path\to\app-release.apk -ShotName release
#    pwsh tools/run-on-emulator.ps1 -LDPlayerRoot 'D:\leidian\LDPlayer14'
# ============================================================
param(
    [string]$Apk = '',
    [string]$Package = 'com.momiji.tavern',
    [string]$ShotName = 'shot',
    [string]$LDPlayerRoot = 'E:\leidian\LDPlayer14',
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'

$Ws = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($Apk)) {
    $Apk = Join-Path $Ws 'app\build\app\outputs\flutter-apk\app-debug.apk'
}

$ldc   = Join-Path $LDPlayerRoot 'ldconsole.exe'
$adb   = Join-Path $LDPlayerRoot 'adb.exe'
$shots = Join-Path $Ws 'tools\shots'
New-Item -ItemType Directory -Force -Path $shots | Out-Null

foreach ($exe in @($ldc, $adb)) {
    if (-not (Test-Path $exe)) { throw "找不到 $exe，请用 -LDPlayerRoot 指定雷电安装目录" }
}

# ---- 1) 启动模拟器（已启动则跳过）----
$devices = & $adb devices 2>$null | Select-String 'emulator-|127\.0\.0\.1:'
if (-not $devices) {
    Write-Host '== 启动雷电模拟器 ==' -ForegroundColor Cyan
    & $ldc launch --index 0 | Out-Null
    $ok = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 3
        & $adb connect 127.0.0.1:5555 2>$null | Out-Null
        $d = & $adb devices 2>$null
        if ($d -match 'device$' -or $d -match "`tdevice") { $ok = $true; break }
    }
    if (-not $ok) { Write-Host '模拟器未在 180 秒内就绪，继续尝试…' -ForegroundColor Yellow }
}

# ---- 只保留一个 adb 目标，避免 "more than one device" ----
$serial = ((& $adb devices) | Select-String "`tdevice$" | ForEach-Object { ($_ -split "`t")[0].Trim() } | Select-Object -First 1)
if (-not $serial) { throw '没有可用的模拟器设备' }
& $adb devices | Select-String ':5555' | ForEach-Object {
    if ($_ -notmatch [regex]::Escape($serial)) { & $adb disconnect (($_ -split "`t")[0].Trim()) 2>$null | Out-Null }
}
Write-Host "device = $serial" -ForegroundColor Green

# 等待系统启动完成
for ($i = 0; $i -lt 40; $i++) {
    $boot = (& $adb -s $serial shell getprop sys.boot_completed 2>$null) -join ''
    if ($boot.Trim() -eq '1') { break }
    Start-Sleep -Seconds 3
}
Write-Host ("Android " + ((& $adb -s $serial shell getprop ro.build.version.release) -join '').Trim() +
            " / API " + ((& $adb -s $serial shell getprop ro.build.version.sdk) -join '').Trim())

if (-not $NoLaunch) {
    if (-not (Test-Path $Apk)) { throw "找不到 APK：$Apk" }

    Write-Host '== 安装 APK ==' -ForegroundColor Cyan
    & $adb -s $serial install -r -d $Apk
    if ($LASTEXITCODE -ne 0) { throw '安装失败' }

    Write-Host '== 启动 App ==' -ForegroundColor Cyan
    & $adb -s $serial shell am start -n "$Package/.MainActivity" | Out-Null
    Start-Sleep -Seconds 8
}

# ---- 2) 截图 ----
Write-Host '== 截图 ==' -ForegroundColor Cyan
& $adb -s $serial shell screencap -p /sdcard/$ShotName.png
& $adb -s $serial pull /sdcard/$ShotName.png (Join-Path $shots "$ShotName.png") | Out-Null
& $adb -s $serial shell rm -f /sdcard/$ShotName.png
Write-Host "screenshot -> $(Join-Path $shots "$ShotName.png")" -ForegroundColor Green

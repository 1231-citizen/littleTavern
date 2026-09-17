# ============================================================
#  构建 APK
#  用法:
#    pwsh tools/build-apk.ps1                    # debug 包（快，用于预览）
#    pwsh tools/build-apk.ps1 -Release           # release 包
#    pwsh tools/build-apk.ps1 -ToolchainRoot D:\AndroidDev
# ============================================================
param(
    [switch]$Release,
    [string]$ToolchainRoot = 'E:\AndroidDev'
)

$ErrorActionPreference = 'Stop'

# 仓库根目录 = 脚本所在目录的上一级（无需硬编码路径）
$Ws   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Root = $ToolchainRoot

# ---- 工具链环境（SDK 在 $Root，构建缓存留在仓库内）----
$env:JAVA_HOME        = Join-Path $Root 'jdk'
$env:ANDROID_HOME     = Join-Path $Root 'android-sdk'
$env:ANDROID_SDK_ROOT = Join-Path $Root 'android-sdk'
$env:PUB_CACHE        = Join-Path $Ws '.pub-cache'
$env:GRADLE_USER_HOME = Join-Path $Ws '.gradle'

$flutterBin = Join-Path $Root 'flutter\bin'
$jdkBin     = Join-Path $Root 'jdk\bin'
$ptools     = Join-Path $Root 'android-sdk\platform-tools'
$env:PATH = "$flutterBin;$jdkBin;$ptools;$env:PATH"
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'

$flutter = Join-Path $flutterBin 'flutter.bat'
if (-not (Test-Path $flutter)) {
    throw "找不到 Flutter: $flutter`n请用 -ToolchainRoot 指定工具链目录，或先运行 tools/install-toolchain.ps1"
}

Set-Location (Join-Path $Ws 'app')

Write-Host '== flutter pub get ==' -ForegroundColor Cyan
& $flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'pub get 失败' }

if ($Release) {
    Write-Host '== flutter build apk --release ==' -ForegroundColor Cyan
    & $flutter build apk --release
} else {
    Write-Host '== flutter build apk --debug ==' -ForegroundColor Cyan
    & $flutter build apk --debug
}
if ($LASTEXITCODE -ne 0) { throw '构建失败' }

$outDir = Join-Path $Ws 'app\build\app\outputs\flutter-apk'
$apk = Join-Path $outDir $(if ($Release) { 'app-release.apk' } else { 'app-debug.apk' })
if (Test-Path $apk) {
    $mb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
    Write-Host "== APK: $apk ($mb MB) ==" -ForegroundColor Green
} else {
    throw "没有找到产物 APK：$apk"
}

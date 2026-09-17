# ============================================================
#  类酒馆 App - Flutter/Android 工具链安装脚本
#  安装位置: E:\AndroidDev   (SDK 全部落在 E 盘)
#  构建缓存: 工作区内 .pub-cache / .gradle (避免写系统盘)
# ============================================================
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$Root     = 'E:\AndroidDev'
$Dist     = Join-Path $Root '_dist'
$Ws       = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PubCache = Join-Path $Ws '.pub-cache'
$GradleH  = Join-Path $Ws '.gradle'
$Log      = Join-Path $Ws 'tools\install.log'

New-Item -ItemType Directory -Force -Path $Root, $Dist, $PubCache, $GradleH | Out-Null

function Log($msg) {
    $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $msg
    Write-Host $line
    Add-Content -Path $Log -Value $line -Encoding UTF8
}
Set-Content -Path $Log -Value "=== install start $(Get-Date) ===" -Encoding UTF8

# ---------- 下载器（优先 node，curl 在本机 schannel 偶发失败） ----------
$NodeFetch = Join-Path $Ws 'tools\fetch.js'
Log "downloader: node ($NodeFetch)"

function Fetch($url, $out, $label) {
    if ((Test-Path $out) -and ((Get-Item $out).Length -gt 1MB)) {
        Log ("SKIP {0} (already {1:n1} MB)" -f $label, ((Get-Item $out).Length / 1MB)); return
    }
    Log "DOWNLOAD $label <- $url"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if (Test-Path $NodeFetch) {
        & node $NodeFetch $url $out
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { throw "node download failed for $url" }
    } elseif (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L --fail --retry 4 --retry-delay 3 --connect-timeout 30 -o $out $url
        if ($LASTEXITCODE -ne 0) { throw "curl failed ($LASTEXITCODE) for $url" }
    } else {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    }
    $sw.Stop()
    Log ("DONE {0}  {1:n1} MB in {2:n1} min" -f $label, ((Get-Item $out).Length / 1MB), $sw.Elapsed.TotalMinutes)
}

function Unzip($zip, $dest) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Log "EXTRACT $zip -> $dest"
    $tar = Get-Command tar.exe -ErrorAction SilentlyContinue
    if ($tar) {
        & tar.exe -xf $zip -C $dest
        if ($LASTEXITCODE -ne 0) { throw "tar extract failed for $zip" }
    } else {
        Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
    }
}

# ---------- 1. Flutter SDK ----------
$flutterZip = Join-Path $Dist 'flutter_windows_3.47.4-stable.zip'
Fetch 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.4-stable.zip' $flutterZip 'Flutter 3.47.4'
if (-not (Test-Path (Join-Path $Root 'flutter\bin\flutter.bat'))) {
    Unzip $flutterZip $Root
}

# ---------- 2. JDK 17 (Temurin, 清华镜像，GitHub 直连在国内不稳定) ----------
$jdkZip = Join-Path $Dist 'temurin17.zip'
Fetch 'https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip' $jdkZip 'Temurin JDK 17'
$jdkDir = Join-Path $Root 'jdk'
if (-not (Test-Path (Join-Path $jdkDir 'bin\java.exe'))) {
    $tmp = Join-Path $Root '_jdk_tmp'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Unzip $jdkZip $tmp
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    Move-Item $inner.FullName $jdkDir
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------- 3. Android cmdline-tools ----------
$clZip = Join-Path $Dist 'cmdline-tools.zip'
Fetch 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' $clZip 'Android cmdline-tools'
$Sdk = Join-Path $Root 'android-sdk'
$clLatest = Join-Path $Sdk 'cmdline-tools\latest'
if (-not (Test-Path (Join-Path $clLatest 'bin\sdkmanager.bat'))) {
    $tmp2 = Join-Path $Root '_cl_tmp'
    if (Test-Path $tmp2) { Remove-Item $tmp2 -Recurse -Force }
    Unzip $clZip $tmp2
    New-Item -ItemType Directory -Force -Path (Split-Path $clLatest) | Out-Null
    if (Test-Path $clLatest) { Remove-Item $clLatest -Recurse -Force }
    Move-Item (Join-Path $tmp2 'cmdline-tools') $clLatest
    Remove-Item $tmp2 -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------- 4. 环境变量 ----------
$env:JAVA_HOME         = $jdkDir
$env:ANDROID_HOME      = $Sdk
$env:ANDROID_SDK_ROOT  = $Sdk
$env:PUB_CACHE         = $PubCache
$env:GRADLE_USER_HOME  = $GradleH
$env:PATH              = "$Root\flutter\bin;$jdkDir\bin;$Sdk\platform-tools;$Sdk\cmdline-tools\latest\bin;$env:PATH"

Log "JAVA_HOME=$env:JAVA_HOME"
& (Join-Path $jdkDir 'bin\java.exe') -version 2>&1 | ForEach-Object { Log "  java: $_" }

# ---------- 5. 接受许可 + 安装 SDK 包 ----------
$sdkmanager = Join-Path $clLatest 'bin\sdkmanager.bat'
Log 'ACCEPT LICENSES...'
$yes = (1..40 | ForEach-Object { 'y' })
$yes | & $sdkmanager --sdk_root=$Sdk --licenses 2>&1 | ForEach-Object { Log "  lic: $_" }

Log 'INSTALL SDK PACKAGES...'
$pkgs = @('platform-tools', 'platforms;android-35', 'platforms;android-36', 'build-tools;35.0.0', 'build-tools;36.0.0')
& $sdkmanager --sdk_root=$Sdk @pkgs 2>&1 | ForEach-Object { Log "  sdk: $_" }

# ---------- 6. Flutter 预热 + doctor ----------
Log 'FLUTTER CONFIG...'
& (Join-Path $Root 'flutter\bin\flutter.bat') config --android-sdk $Sdk 2>&1 | ForEach-Object { Log "  cfg: $_" }
Log 'FLUTTER PRECACHE (下载 Dart SDK / 引擎产物, 体积较大)...'
& (Join-Path $Root 'flutter\bin\flutter.bat') precache --android --universal 2>&1 | ForEach-Object { Log "  pre: $_" }
Log 'FLUTTER DOCTOR...'
& (Join-Path $Root 'flutter\bin\flutter.bat') doctor -v 2>&1 | ForEach-Object { Log "  doc: $_" }

Log '=== INSTALL FINISHED ==='

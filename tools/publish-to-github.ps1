# ============================================================
#  一键发布到 GitHub
#  前置：本机已登录 GitHub CLI（脚本会提示怎么做）
#
#  用法:
#    pwsh tools/publish-to-github.ps1
#    pwsh tools/publish-to-github.ps1 -RepoName myTavern -Visibility private
#    pwsh tools/publish-to-github.ps1 -SkipRelease      # 不发 Release
# ============================================================
param(
    [string]$RepoName = 'littleTavern',
    [ValidateSet('public', 'private')][string]$Visibility = 'public',
    [string]$Tag = 'v1.0.0',
    [string]$ToolchainRoot = 'E:\AndroidDev',
    [string]$Proxy = '',
    [switch]$SkipRelease
)

$ErrorActionPreference = 'Stop'
$Ws = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Ws

# ---------- 0. 代理（国内直连 github.com 基本不可用，自动识别 Clash 等本地端口）----------
function Get-LocalProxy {
    foreach ($p in 7897, 7890, 7891, 7898, 10809, 10808, 1080, 2080) {
        $c = Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return "http://127.0.0.1:$p" }
    }
    return ''
}
if ([string]::IsNullOrWhiteSpace($Proxy)) { $Proxy = Get-LocalProxy }
if ($Proxy) {
    $env:HTTPS_PROXY = $Proxy
    $env:HTTP_PROXY  = $Proxy
    git config http.proxy  $Proxy
    git config https.proxy $Proxy
    Write-Host "使用代理: $Proxy" -ForegroundColor Green
} else {
    Write-Host '未检测到本地代理，将尝试直连 GitHub（国内通常不可用，可用 -Proxy 指定）' -ForegroundColor Yellow
}

# ---------- 1. 找到 gh ----------
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) {
    $cand = Join-Path $ToolchainRoot 'gh\bin\gh.exe'
    if (Test-Path $cand) { $gh = $cand }
}
if (-not $gh) {
    throw "找不到 GitHub CLI。安装：winget install GitHub.cli  或  https://cli.github.com/"
}
Write-Host "gh: $gh" -ForegroundColor DarkGray

# ---------- 2. 检查登录状态 ----------
& $gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host '尚未登录 GitHub。请在另一个终端执行：' -ForegroundColor Yellow
    Write-Host "  `"$gh`" auth login --hostname github.com --git-protocol https --web" -ForegroundColor Cyan
    Write-Host '授权完成后重新运行本脚本即可。' -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

# ---------- 3. 用 GitHub 账号作为提交身份 ----------
$login = (& $gh api user --jq '.login' | Out-String).Trim()
$email = (& $gh api user --jq '.email // empty' | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($email)) { $email = "$login@users.noreply.github.com" }
git config user.name  $login
git config user.email $email
Write-Host "提交身份: $login <$email>" -ForegroundColor Green

# 已有提交且作者不是你的账号时才改写，避免每次都 amend 导致 push 被拒
git rev-parse --verify HEAD 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    git add -A
    git commit -m '小酒馆 v1.0.0：面向手机端的类酒馆角色扮演对话应用' | Out-Null
} else {
    $curEmail = (git log -1 --format='%ae').Trim()
    if ($curEmail -ne $email) {
        git commit --amend --reset-author --no-edit | Out-Null
        Write-Host "已把最新提交的作者由 $curEmail 改为 $email" -ForegroundColor DarkGray
    } else {
        Write-Host "提交作者已是 $email，跳过 amend" -ForegroundColor DarkGray
    }
}

# ---------- 4. 建仓库并推送 ----------
$exists = $false
& $gh repo view "$login/$RepoName" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { $exists = $true }

if ($exists) {
    Write-Host "仓库 $login/$RepoName 已存在，改为推送" -ForegroundColor Yellow
    git remote remove origin 2>$null
    git remote add origin "https://github.com/$login/$RepoName.git"
    git push -u origin main
} else {
    & $gh repo create $RepoName "--$Visibility" --source=. --remote=origin --push `
        --description '面向手机端的类酒馆角色扮演对话应用 · Flutter + DeepSeek'
    if ($LASTEXITCODE -ne 0) { throw '创建仓库失败' }
}
Write-Host "仓库地址: https://github.com/$login/$RepoName" -ForegroundColor Green

# ---------- 5. Release + APK 附件 ----------
if (-not $SkipRelease) {
    $apkDir = Join-Path $Ws 'app\build\app\outputs\flutter-apk'
    $assets = @()
    # Release 附件只放发布包：debug 包体积大且不适合对外分发
    foreach ($f in 'app-release.apk') {
        $p = Join-Path $apkDir $f
        if (Test-Path $p) { $assets += $p }
    }
    if ($assets.Count -eq 0) {
        Write-Host '未找到 APK，跳过 Release（先运行 tools/build-apk.ps1 -Release）' -ForegroundColor Yellow
    } else {
        $notes = Join-Path $Ws 'tools\release-notes.md'
        $ghArgs = @('release', 'create', $Tag) + $assets + @('--title', '小酒馆 v1.0.0')
        if (Test-Path $notes) { $ghArgs += @('--notes-file', $notes) }
        & $gh @ghArgs
        if ($LASTEXITCODE -ne 0) { throw '创建 Release 失败' }
        Write-Host "Release: https://github.com/$login/$RepoName/releases/tag/$Tag" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host '发布完成。' -ForegroundColor Green

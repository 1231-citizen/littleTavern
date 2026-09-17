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
    [switch]$SkipRelease
)

$ErrorActionPreference = 'Stop'
$Ws = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Ws

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

# 已有提交则把作者改成你的身份，避免占位作者
git rev-parse --verify HEAD 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    git commit --amend --reset-author --no-edit | Out-Null
    Write-Host '已把首次提交的作者改为你的账号' -ForegroundColor DarkGray
} else {
    git add -A
    git commit -m '小酒馆 v1.0.0：面向手机端的类酒馆角色扮演对话应用' | Out-Null
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

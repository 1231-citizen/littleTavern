# ============================================================
#  持续重试推送到 GitHub
#  github.com 在本机是"通一分钟断五分钟"，靠单次 push 很难成功，
#  这个脚本会一直重试，直到某次连接窗口足够长把 16MB 推上去。
#
#  用法:
#    pwsh tools/push-to-github.ps1                 # 最多重试 40 次（约 30 分钟）
#    pwsh tools/push-to-github.ps1 -MaxAttempts 100
# ============================================================
param(
    [int]$MaxAttempts = 40,
    [int]$GapSeconds = 8,
    [string]$ToolchainRoot = 'E:\AndroidDev'
)

$ErrorActionPreference = 'Continue'
$Ws = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Ws
$env:GIT_TERMINAL_PROMPT = '0'

# 大缓冲 + HTTP/1.1：对不稳定的线路更友好
git config http.version HTTP/1.1
git config http.postBuffer 524288000
git config http.lowSpeedLimit 1000
git config http.lowSpeedTime 60

# 确认 remote
$remote = git remote get-url origin 2>$null
if (-not $remote) {
    Write-Host '未配置 origin，请先运行 tools/publish-to-github.ps1' -ForegroundColor Yellow
    exit 1
}
Write-Host "remote: $remote"

function Test-GitHub {
    try {
        $r = Invoke-WebRequest -Uri 'https://github.com' -Method Head -TimeoutSec 6 -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        # PowerShell 的 TLS 栈在本机常误报，退回用 node 探
        $probe = & node -e "fetch('https://github.com',{method:'HEAD',signal:AbortSignal.timeout(6000)}).then(()=>process.exit(0)).catch(()=>process.exit(1))" 2>$null
        return ($LASTEXITCODE -eq 0)
    }
}

$ok = $false
for ($i = 1; $i -le $MaxAttempts; $i++) {
    Write-Host ''
    Write-Host "=== 第 $i / $MaxAttempts 次 ===" -ForegroundColor Cyan

    if (-not (Test-GitHub)) {
        Write-Host 'github.com 当前不可达，等待下一个连接窗口…' -ForegroundColor DarkGray
        Start-Sleep -Seconds $GapSeconds
        continue
    }

    Write-Host 'github.com 可达，开始推送…' -ForegroundColor Green
    $out = git push -u origin main 2>&1
    $out | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -eq 0) { $ok = $true; break }
    Start-Sleep -Seconds $GapSeconds
}

Write-Host ''
if ($ok) {
    Write-Host '推送成功！' -ForegroundColor Green
    Write-Host "仓库：https://github.com/1231-citizen/littleTavern" -ForegroundColor Green
    Write-Host ''
    Write-Host '接着发 Release（把 release APK 作为附件）：' -ForegroundColor Cyan
    Write-Host '  pwsh tools/publish-to-github.ps1        # 仓库已存在时会自动跳过创建、直接推 + 发 Release'
} else {
    Write-Host '仍然没能推上去。可在有代理的环境下：' -ForegroundColor Yellow
    Write-Host '  $env:HTTPS_PROXY="http://127.0.0.1:端口"; pwsh tools/push-to-github.ps1'
    exit 1
}

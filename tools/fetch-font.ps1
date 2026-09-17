# ============================================================
#  下载中文字体（霞鹜文楷 Light）
#
#  为什么单独一个脚本：字体 26MB，超过 GitHub 网页上传的单文件 25MB 限制。
#  所以「网页上传」版本的源码包里不含字体，克隆/解压后跑一次本脚本即可补齐。
#  如果你是用 git push 推的（仓库里已含字体），则不需要执行。
#
#  用法:
#    pwsh tools/fetch-font.ps1
# ============================================================
param(
    [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$Ws = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $Ws 'app\assets\fonts'
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$dest = Join-Path $OutDir 'LXGWWenKai-Light.ttf'

if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 20MB)) {
    Write-Host "字体已存在：$dest（$([math]::Round((Get-Item $dest).Length/1MB,1)) MB）" -ForegroundColor Green
    exit 0
}

$fetchJs = Join-Path $Ws 'tools\fetch.js'
$urls = @(
    'https://ghfast.top/https://github.com/lxgw/LxgwWenKai/releases/download/v1.520/LXGWWenKai-Light.ttf',
    'https://gh-proxy.com/https://github.com/lxgw/LxgwWenKai/releases/download/v1.520/LXGWWenKai-Light.ttf',
    'https://github.com/lxgw/LxgwWenKai/releases/download/v1.520/LXGWWenKai-Light.ttf'
)

foreach ($u in $urls) {
    Write-Host "尝试：$u"
    try {
        if (Test-Path $fetchJs) {
            & node $fetchJs $u $dest
            if ($LASTEXITCODE -eq 0 -and (Test-Path $dest)) { break }
        } else {
            & curl.exe -L --fail --retry 3 -o $dest $u
            if ($LASTEXITCODE -eq 0 -and (Test-Path $dest)) { break }
        }
    } catch {
        Write-Host "  失败：$($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 20MB)) {
    Write-Host "字体就绪：$dest（$([math]::Round((Get-Item $dest).Length/1MB,1)) MB）" -ForegroundColor Green
} else {
    Write-Host '字体下载失败，请手动下载后放到：' -ForegroundColor Yellow
    Write-Host "  $dest"
    Write-Host '  下载页：https://github.com/lxgw/LxgwWenKai/releases'
    exit 1
}

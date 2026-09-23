# 打 GitHub Release 用的离线包（大文件挂 Release，不进 Git）
# 用法: .\pack-release.ps1 [-Version 1.0.1]
param(
  [string]$Version = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if (-not $Version) {
  $Version = Get-Date -Format "yyyy.M.d"
}
$tag = "v$Version"
$outDir = Join-Path $root "dist-release"
$stageName = "lancang-open-webui-$Version-windows"
$stage = Join-Path $outDir $stageName
$zipPath = Join-Path $outDir "$stageName.zip"

# 先确保自定义 wheel 存在
$lancang = Get-ChildItem (Join-Path $root "wheels") -Filter "open_webui*lancang*.whl" -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $lancang) {
  Write-Host "未找到 lancang wheel，先执行 pack-custom-wheel.ps1 ..."
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "pack-custom-wheel.ps1")
  $lancang = Get-ChildItem (Join-Path $root "wheels") -Filter "open_webui*lancang*.whl" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $lancang) { throw "仍无 lancang wheel" }

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

function Copy-Tree($src, $dst) {
  if (-not (Test-Path $src)) { return $false }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
  Copy-Item -Recurse -Force $src $dst
  return $true
}

# 源码与脚本（小文件）
$files = @(
  "README.md", "install.ps1", "start.ps1", "stop.ps1", "pack-offline.ps1",
  "pack-custom-wheel.ps1", "pack-release.ps1", "serve_backend.py",
  ".env.intranet.example", ".gitignore",
  "launcher\app.py", "launcher\index.html", "launcher\LancangAI.spec"
)
foreach ($f in $files) {
  $from = Join-Path $root $f
  if (Test-Path $from) {
    $to = Join-Path $stage $f
    New-Item -ItemType Directory -Force -Path (Split-Path $to -Parent) | Out-Null
    Copy-Item -Force $from $to
  }
}
Get-ChildItem $root -Filter "*.txt" -File | ForEach-Object {
  Copy-Item -Force $_.FullName (Join-Path $stage $_.Name)
}

# wheels：自定义包 + torch（不要 official.bak）
$wheelsDst = Join-Path $stage "wheels"
New-Item -ItemType Directory -Force -Path $wheelsDst | Out-Null
Copy-Item -Force $lancang.FullName $wheelsDst
Get-ChildItem (Join-Path $root "wheels") -Filter "torch*.whl" | ForEach-Object {
  Copy-Item -Force $_.FullName $wheelsDst
}

# runtime（内嵌 Python，双击 exe / start.ps1 需要）
if (-not (Copy-Tree (Join-Path $root "runtime") (Join-Path $stage "runtime"))) {
  Write-Warning "缺少 runtime\，解压后需本机 Python 3.11 + uv"
}

# redist
Copy-Tree (Join-Path $root "redist") (Join-Path $stage "redist") | Out-Null

# 启动器 exe
foreach ($exe in @("LancangAI.exe", "澜沧江AI.exe")) {
  $p = Join-Path $root $exe
  if (Test-Path $p) { Copy-Item -Force $p (Join-Path $stage $exe) }
}

# 使用说明
@"
澜沧江 Open WebUI 发行包 $tag
================================

1. 解压到任意目录（路径不要有奇怪权限）
2. Copy-Item .env.intranet.example .env
3. 按内网改 .env 里的 OPENAI_API_BASE_URL
4. 执行 .\install.ps1   （会安装 wheels 里的自定义 open-webui+lancang）
5. 双击 澜沧江AI.exe / LancangAI.exe，或执行 .\start.ps1

说明：
- 本 zip 走 GitHub Release 分发，不进 Git 仓库
- 自定义包：wheels\open_webui-*-lancang*.whl（已含千问/悬浮白字等修改）
- 不要用官方 PyPI 的 open-webui 覆盖本包
"@ | Set-Content -Encoding UTF8 (Join-Path $stage "使用说明.txt")

if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Write-Host "压缩 $zipPath ..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

$sizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host "完成: $zipPath ($sizeMb MB)"
Write-Host "TAG=$tag"
Write-Host "ZIP=$zipPath"

# 写出给 gh release 用的元数据
@{
  tag = $tag
  version = $Version
  zip = $zipPath
  size_mb = $sizeMb
} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $outDir "release-meta.json")

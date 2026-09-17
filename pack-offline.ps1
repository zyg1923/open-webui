$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$uv = "$env:USERPROFILE\.local\bin\uv.exe"
$python = Join-Path $root ".venv\Scripts\python.exe"
$wheels = Join-Path $root "wheels"
New-Item -ItemType Directory -Force -Path $wheels | Out-Null
if (-not (Test-Path $python)) { throw "请先完成安装" }
Write-Host "下载 wheels 到 $wheels （内网离线安装用）"
& $uv pip download --python $python -d $wheels open-webui
Write-Host "完成。把整个 $root 拷到内网后执行 install.ps1"

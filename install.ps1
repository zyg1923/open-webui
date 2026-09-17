$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$uv = "$env:USERPROFILE\.local\bin\uv.exe"
if (-not (Test-Path $uv)) {
  throw "未找到 uv。有外网时先执行: irm https://astral.sh/uv/install.ps1 | iex"
}

if (-not (Test-Path (Join-Path $root ".venv\Scripts\python.exe"))) {
  & $uv python install 3.11
  & $uv venv --python 3.11 (Join-Path $root ".venv")
}

$python = Join-Path $root ".venv\Scripts\python.exe"
$wheels = Join-Path $root "wheels"
if (Test-Path $wheels) {
  Write-Host "离线安装 wheels ..."
  & $uv pip install --python $python --no-index --find-links $wheels open-webui
} else {
  Write-Host "在线安装 open-webui（清华镜像）..."
  $env:UV_LINK_MODE = "copy"
  & $uv pip install --python $python --index-url "https://pypi.tuna.tsinghua.edu.cn/simple" --extra-index-url "https://pypi.org/simple" --find-links (Join-Path $root "wheels") "open-webui==0.11.3"
}

Write-Host "安装完成。运行 start.ps1"

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

# 优先安装自定义 open_webui-*lancang*.whl（你的改包）
$custom = $null
if (Test-Path $wheels) {
  $custom = Get-ChildItem $wheels -Filter "open_webui*lancang*.whl" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
}

if ($custom) {
  Write-Host "安装自定义包（替换官方 open-webui）: $($custom.Name)"
  if (Test-Path $wheels) {
    & $uv pip install --python $python --no-index --find-links $wheels --force-reinstall $custom.FullName
  } else {
    & $uv pip install --python $python --force-reinstall $custom.FullName
  }
} elseif (Test-Path $wheels) {
  Write-Host "未找到 lancang 自定义 wheel，离线安装官方 open-webui ..."
  & $uv pip install --python $python --no-index --find-links $wheels open-webui
} else {
  Write-Host "在线安装官方 open-webui==0.11.3（清华镜像）..."
  $env:UV_LINK_MODE = "copy"
  & $uv pip install --python $python --index-url "https://pypi.tuna.tsinghua.edu.cn/simple" --extra-index-url "https://pypi.org/simple" "open-webui==0.11.3"
}

& $python -c "import importlib.metadata as m; print('installed open-webui', m.version('open-webui'))"
Write-Host "安装完成。运行 start.ps1"

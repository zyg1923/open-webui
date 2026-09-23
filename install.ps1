$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$wheels = Join-Path $root "wheels"
$uv = "$env:USERPROFILE\.local\bin\uv.exe"
$runtimePy = Join-Path $root "runtime\python.exe"
$venvPy = Join-Path $root ".venv\Scripts\python.exe"

function Ensure-Venv {
  if (Test-Path $venvPy) { return }
  if (Test-Path $uv) {
    & $uv python install 3.11
    & $uv venv --python 3.11 (Join-Path $root ".venv")
    return
  }
  if (Test-Path $runtimePy) {
    Write-Host "未找到 uv，改用 runtime\python.exe 创建 .venv ..."
    & $runtimePy -m venv (Join-Path $root ".venv")
    return
  }
  throw "未找到 uv，也未找到 runtime\python.exe。请安装 uv，或使用带 runtime 的 Release 离线包。"
}

Ensure-Venv
$python = $venvPy
if (-not (Test-Path $python)) { throw "创建 .venv 失败" }

# 升级 pip，便于离线装 wheel
& $python -m pip install --upgrade pip setuptools wheel 2>$null | Out-Null

$custom = $null
if (Test-Path $wheels) {
  $custom = Get-ChildItem $wheels -Filter "open_webui*lancang*.whl" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
}

function Install-WithUv([string]$spec) {
  if (Test-Path $wheels) {
    & $uv pip install --python $python --no-index --find-links $wheels --force-reinstall $spec
  } else {
    & $uv pip install --python $python --force-reinstall $spec
  }
}

function Install-WithPip([string]$spec) {
  if (Test-Path $wheels) {
    & $python -m pip install --no-index --find-links $wheels --force-reinstall $spec
  } else {
    & $python -m pip install --force-reinstall $spec
  }
}

if ($custom) {
  Write-Host "安装自定义包（替换官方 open-webui）: $($custom.Name)"
  if (Test-Path $uv) {
    Install-WithUv $custom.FullName
  } else {
    Install-WithPip $custom.FullName
  }
} elseif (Test-Path $wheels) {
  Write-Host "未找到 lancang 自定义 wheel，离线安装官方 open-webui ..."
  if (Test-Path $uv) {
    & $uv pip install --python $python --no-index --find-links $wheels open-webui
  } else {
    & $python -m pip install --no-index --find-links $wheels open-webui
  }
} else {
  Write-Host "在线安装官方 open-webui==0.11.3（清华镜像）..."
  $env:UV_LINK_MODE = "copy"
  if (Test-Path $uv) {
    & $uv pip install --python $python --index-url "https://pypi.tuna.tsinghua.edu.cn/simple" --extra-index-url "https://pypi.org/simple" "open-webui==0.11.3"
  } else {
    & $python -m pip install -i "https://pypi.tuna.tsinghua.edu.cn/simple" "open-webui==0.11.3"
  }
}

& $python -c "import importlib.metadata as m; print('installed open-webui', m.version('open-webui'))"
Write-Host "安装完成。"
Write-Host "下一步: Copy-Item .env.intranet.example .env  （再改网关地址）"
Write-Host "然后: 双击 澜沧江AI.exe / LancangAI.exe，或执行 .\start.ps1"

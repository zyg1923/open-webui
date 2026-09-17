$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$dataDir = Join-Path $root "data"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

$envFile = Join-Path $root ".env"
if (Test-Path $envFile) {
  Get-Content $envFile -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) { return }
    $eq = $line.IndexOf("=")
    if ($eq -lt 1) { return }
    $name = $line.Substring(0, $eq).Trim()
    $value = $line.Substring($eq + 1).Trim().Trim("'").Trim('"')
    [Environment]::SetEnvironmentVariable($name, $value, "Process")
  }
}

$env:DATA_DIR = $dataDir
if (-not $env:PORT) { $env:PORT = "3000" }
if (-not $env:HOST) { $env:HOST = "0.0.0.0" }

$py = Join-Path $root "runtime\python.exe"
$script = Join-Path $root "serve_backend.py"
if (-not (Test-Path $py)) {
  throw "未找到 $py"
}
if (-not (Test-Path $script)) {
  throw "未找到 $script"
}

$env:VIRTUAL_ENV = Join-Path $root ".venv"
$env:PYTHONNOUSERSITE = "1"
$env:PYTHONPATH = Join-Path $root ".venv\Lib\site-packages"

Write-Host "Open WebUI: http://127.0.0.1:$($env:PORT)"
Write-Host "OpenAI Base: $($env:OPENAI_API_BASE_URL)"
& $py $script

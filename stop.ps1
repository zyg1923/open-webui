$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Get-CimInstance Win32_Process |
  Where-Object { $_.CommandLine -and $_.CommandLine -match "open_webui" } |
  ForEach-Object {
    Write-Host "stop pid=$($_.ProcessId)"
    Stop-Process -Id $_.ProcessId -Force
  }
Write-Host "done"

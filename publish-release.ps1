# 打包 +（可选）推送到 GitHub Release
# 用法:
#   .\publish-release.ps1 -Version 1.0.1
#   .\publish-release.ps1 -Version 1.0.1 -SkipUpload   # 只打包不上传
param(
  [Parameter(Mandatory = $true)][string]$Version,
  [switch]$SkipUpload
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$gh = "C:\Program Files\GitHub CLI\gh.exe"
$tag = "v$Version"

Write-Host "==> 1/3 打自定义 wheel"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "pack-custom-wheel.ps1")

Write-Host "==> 2/3 打 Release zip"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "pack-release.ps1") -Version $Version

$zip = Join-Path $root "dist-release\lancang-open-webui-$Version-windows.zip"
if (-not (Test-Path $zip)) { throw "未生成 $zip" }

if ($SkipUpload) {
  Write-Host "已跳过上传。本地包: $zip"
  exit 0
}

if (-not (Test-Path $gh)) { throw "未安装 GitHub CLI (gh)。可先 -SkipUpload，再到能登录的机器上传。" }

Write-Host "==> 3/3 推送代码并创建 GitHub Release"
& $gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
  throw "未登录 GitHub。请先执行: gh auth login ，再用浏览器/Token 登录（不要用账户密码）。"
}

git push -u origin HEAD
if ($LASTEXITCODE -ne 0) { throw "git push 失败" }

$existing = & $gh release view $tag 2>$null
if ($LASTEXITCODE -eq 0) {
  Write-Host "Release $tag 已存在，上传/覆盖资产 ..."
  & $gh release upload $tag $zip --clobber
} else {
  git tag -f $tag
  git push origin $tag --force
  & $gh release create $tag $zip --title $tag --notes @"
## 澜沧江 Open WebUI $tag

离线 Windows 包（含自定义 ``open-webui+lancang``、torch、runtime、启动器）。

### 同事怎么用
1. 打开本页 Assets，下载 ``lancang-open-webui-$Version-windows.zip``
2. 解压
3. ``Copy-Item .env.intranet.example .env``，改网关地址
4. ``.\install.ps1``
5. 双击 ``澜沧江AI.exe`` 或 ``LancangAI.exe``（或 ``.\start.ps1``）

不要只用 ``git clone``：仓库里没有 wheel/runtime。
"@
}

Write-Host "完成。Release: "
& $gh release view $tag --json url -q .url

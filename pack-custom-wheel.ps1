# 用当前 .venv 里改过的 open_webui，打成自定义 wheel，替换官方包
# 输出: wheels\open_webui-0.11.3+lancang.1-py3-none-any.whl
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$py = Join-Path $root "runtime\python.exe"
if (-not (Test-Path $py)) { $py = Join-Path $root ".venv\Scripts\python.exe" }
if (-not (Test-Path $py)) { throw "未找到 python" }

& $py -c @"
from __future__ import annotations
import base64, hashlib, os, re, shutil, zipfile
from pathlib import Path

root = Path(r'$($root.Replace('\','/'))')
site = root / '.venv' / 'Lib' / 'site-packages'
pkg = site / 'open_webui'
info = site / 'open_webui-0.11.3.dist-info'
wheels = root / 'wheels'
ver = '0.11.3+lancang.1'
out = wheels / f'open_webui-{ver}-py3-none-any.whl'

if not pkg.is_dir():
    raise SystemExit(f'missing {pkg}')
if not info.is_dir():
    raise SystemExit(f'missing {info}')
wheels.mkdir(parents=True, exist_ok=True)

stage = root / 'data' / '_wheel_stage'
if stage.exists():
    shutil.rmtree(stage)
stage_pkg = stage / 'open_webui'
stage_info = stage / f'open_webui-{ver}.dist-info'
shutil.copytree(pkg, stage_pkg)
shutil.copytree(info, stage_info)

meta = (stage_info / 'METADATA').read_text(encoding='utf-8')
meta = re.sub(r'(?m)^Version:\s*.+$', f'Version: {ver}', meta, count=1)
(stage_info / 'METADATA').write_text(meta, encoding='utf-8')

# RECORD
rows = []
for path in stage.rglob('*'):
    if not path.is_file():
        continue
    rel = path.relative_to(stage).as_posix()
    if rel.endswith('/RECORD') or rel == f'open_webui-{ver}.dist-info/RECORD':
        continue
    data = path.read_bytes()
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b'=').decode('ascii')
    rows.append(f'{rel},sha256={digest},{len(data)}')
rows.append(f'open_webui-{ver}.dist-info/RECORD,,')
(stage_info / 'RECORD').write_text('\n'.join(rows) + '\n', encoding='utf-8')

if out.exists():
    out.unlink()
with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
    for path in stage.rglob('*'):
        if path.is_file():
            zf.write(path, path.relative_to(stage).as_posix())

official = wheels / 'open_webui-0.11.3-py3-none-any.whl'
bak = wheels / 'open_webui-0.11.3-py3-none-any.whl.official.bak'
if official.exists() and not bak.exists():
    official.rename(bak)
    print('backed up official wheel ->', bak.name)

shutil.rmtree(stage)
print('wrote', out)
print('size_mb', round(out.stat().st_size / 1024 / 1024, 1))
"@

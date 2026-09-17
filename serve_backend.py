# -*- coding: utf-8 -*-
"""绕过 uv 跳板，用 runtime Python 直接启动 Open WebUI。目录搬家后仍可用。"""
from __future__ import annotations

import os
import site
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VENV = ROOT / ".venv"
SITE = VENV / "Lib" / "site-packages"
RUNTIME = ROOT / "runtime"


def load_env(root: Path) -> None:
    env_file = root / ".env"
    if not env_file.is_file():
        return
    text = env_file.read_text(encoding="utf-8-sig")
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        os.environ[name.strip()] = value.strip().strip("'").strip('"')


def main() -> None:
    os.chdir(ROOT)
    (ROOT / "data").mkdir(parents=True, exist_ok=True)
    load_env(ROOT)
    os.environ["DATA_DIR"] = str(ROOT / "data")
    os.environ["PORT"] = os.environ.get("PORT") or "3000"
    os.environ["HOST"] = os.environ.get("HOST") or "0.0.0.0"
    os.environ["VIRTUAL_ENV"] = str(VENV)
    os.environ["PYTHONNOUSERSITE"] = "1"

    if not SITE.is_dir():
        raise SystemExit("未找到 .venv\\Lib\\site-packages")

    sys.path.insert(0, str(SITE))
    site.addsitedir(str(SITE))
    for extra_py in (SITE / "win32", SITE / "win32" / "lib", SITE / "Pythonwin"):
        if extra_py.is_dir():
            sys.path.insert(0, str(extra_py))

    if sys.platform == "win32":
        extras = [
            RUNTIME,
            VENV / "Scripts",
            SITE / "torch" / "lib",
            SITE / "numpy.libs",
            SITE / "pywin32_system32",
            SITE / "win32",
        ]
        for extra in extras:
            if extra.is_dir():
                try:
                    os.add_dll_directory(str(extra))
                except (OSError, AttributeError):
                    os.environ["PATH"] = str(extra) + os.pathsep + os.environ.get("PATH", "")

    from open_webui import app

    host = os.environ["HOST"]
    port = os.environ["PORT"]
    app(["serve", "--host", host, "--port", port])


if __name__ == "__main__":
    main()

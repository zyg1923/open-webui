# -*- coding: utf-8 -*-
"""澜沧江 AI 启动器：托盘后台 + 简易控制页。关闭网页不退出。"""
from __future__ import annotations

import os
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess

CREATE_NO_WINDOW = 0x08000000
CTRL_PORT = 17890
CHAT_PORT = 3000
MUTEX_NAME = "Local\\LancangAIOpenWebUI"


def app_root() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent.parent


def bundled_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(getattr(sys, "_MEIPASS"))
    return Path(__file__).resolve().parent


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
    os.environ["DATA_DIR"] = str(root / "data")
    os.environ["PORT"] = str(CHAT_PORT)
    os.environ["HOST"] = "0.0.0.0"


def rewrite_pyvenv(root: Path) -> None:
    runtime = root / "runtime"
    cfg = root / ".venv" / "pyvenv.cfg"
    if not runtime.is_dir() or not cfg.parent.is_dir():
        return
    home = str(runtime.resolve())
    cfg.write_text(
        "\n".join(
            [
                "home = " + home,
                "implementation = CPython",
                "uv = 0.12.14",
                "version_info = 3.11",
                "include-system-site-packages = false",
                "",
            ]
        ),
        encoding="utf-8",
    )


def port_open(port: int) -> bool:
    import socket

    sock = socket.socket()
    sock.settimeout(0.4)
    try:
        sock.connect(("127.0.0.1", port))
        return True
    except OSError:
        return False
    finally:
        sock.close()


def wait_port(port: int, seconds: float = 90) -> bool:
    deadline = time.time() + seconds
    while time.time() < deadline:
        if port_open(port):
            return True
        time.sleep(0.4)
    return False


class Controller:
    def __init__(self) -> None:
        self.root = app_root()
        self.child = None
        self.httpd = None
        self.tray = None
        self._log = None
        self._stop = threading.Event()

    def start_backend(self) -> None:
        (self.root / "data").mkdir(parents=True, exist_ok=True)
        rewrite_pyvenv(self.root)
        load_env(self.root)
        if port_open(CHAT_PORT):
            return
        py = self.root / "runtime" / "python.exe"
        script = self.root / "serve_backend.py"
        if not py.is_file():
            raise FileNotFoundError("未找到 runtime\\python.exe")
        if not script.is_file():
            raise FileNotFoundError("未找到 serve_backend.py")
        env = os.environ.copy()
        site_packages = str(self.root / ".venv" / "Lib" / "site-packages")
        env["VIRTUAL_ENV"] = str(self.root / ".venv")
        env["PYTHONNOUSERSITE"] = "1"
        env["PYTHONPATH"] = site_packages + os.pathsep + env.get("PYTHONPATH", "")
        log_path = self.root / "data" / "backend.log"
        self._log = open(log_path, "ab", buffering=0)
        flags = CREATE_NO_WINDOW
        self.child = subprocess.Popen(
            [str(py), str(script)],
            cwd=str(self.root),
            env=env,
            creationflags=flags,
            stdout=self._log,
            stderr=self._log,
        )

    def open_chat(self) -> None:
        webbrowser.open("http://127.0.0.1:%s" % CHAT_PORT)

    def open_panel(self) -> None:
        webbrowser.open("http://127.0.0.1:%s" % CTRL_PORT)

    def shutdown(self) -> None:
        if self._stop.is_set():
            return
        self._stop.set()
        if self.child and self.child.poll() is None:
            if sys.platform == "win32":
                subprocess.run(
                    ["taskkill", "/F", "/T", "/PID", str(self.child.pid)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    creationflags=CREATE_NO_WINDOW,
                )
            else:
                self.child.terminate()
                try:
                    self.child.wait(timeout=8)
                except Exception:
                    self.child.kill()
        logf = getattr(self, "_log", None)
        if logf:
            try:
                logf.close()
            except Exception:
                pass
        if self.httpd:
            threading.Thread(target=self.httpd.shutdown, daemon=True).start()
        if self.tray:
            try:
                self.tray.stop()
            except Exception:
                pass


def make_icon():
    from PIL import Image, ImageDraw

    img = Image.new("RGBA", (64, 64), (16, 18, 21, 255))
    draw = ImageDraw.Draw(img)
    draw.ellipse((8, 8, 56, 56), fill=(79, 140, 255, 255))
    return img


def run_tray(ctrl: Controller) -> None:
    import pystray
    from pystray import MenuItem as Item

    menu = pystray.Menu(
        Item("打开控制页", lambda: ctrl.open_panel()),
        Item("打开对话", lambda: ctrl.open_chat()),
        Item("退出后台", lambda: ctrl.shutdown()),
    )
    ctrl.tray = pystray.Icon("lancang-ai", make_icon(), "澜沧江 AI", menu)
    ctrl.tray.run()


def run_panel(ctrl: Controller) -> None:
    html_path = bundled_dir() / "index.html"
    html = html_path.read_bytes() if html_path.is_file() else b"<p>missing index.html</p>"

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.startswith("/open-chat"):
                ctrl.open_chat()
                self._ok(b'{"ok":true}')
                return
            if self.path.startswith("/quit"):
                self._ok(b'{"ok":true}')
                threading.Thread(target=ctrl.shutdown, daemon=True).start()
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html)))
            self.end_headers()
            self.wfile.write(html)

        def _ok(self, body):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, fmt, *args):
            return

    httpd = ThreadingHTTPServer(("127.0.0.1", CTRL_PORT), Handler)
    ctrl.httpd = httpd
    httpd.serve_forever()


_MUTEX_HANDLE = None


def already_running() -> bool:
    global _MUTEX_HANDLE
    if sys.platform != "win32":
        return False
    try:
        import ctypes

        kernel32 = ctypes.windll.kernel32
        handle = kernel32.CreateMutexW(None, False, MUTEX_NAME)
        _MUTEX_HANDLE = handle
        last = kernel32.GetLastError()
        return last == 183
    except Exception:
        return False


def main() -> None:
    if already_running():
        webbrowser.open("http://127.0.0.1:%s" % CTRL_PORT)
        return
    ctrl = Controller()
    ctrl.start_backend()
    threading.Thread(target=run_panel, args=(ctrl,), daemon=True).start()
    wait_port(CTRL_PORT, 10)
    threading.Thread(target=lambda: (wait_port(CHAT_PORT, 90), ctrl.open_panel()), daemon=True).start()
    run_tray(ctrl)
    ctrl.shutdown()


if __name__ == "__main__":
    main()

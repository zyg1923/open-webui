# Open WebUI（无 Docker，Windows）

仓库地址：https://github.com/zyg1923/open-webui

```powershell
git clone https://github.com/zyg1923/open-webui.git
```

Windows 上不用 Docker 运行。克隆后没有 `.venv`、`wheels`、`runtime` 和启动器 exe，按下面的「迁到内网」和「未提交到 Git 的文件」安装、打包。

## 本机启动

1. 先启动 `blade-ai-web`（dev 端口 **9005**）。
2. 双击或 PowerShell：

```powershell
cd F:\job\open-webui
.\start.ps1
```

3. 浏览器打开 http://127.0.0.1:3000  
   第一个注册的账号是管理员。

模型应出现：`Deepseek-32B`、`Qwen3-30B`、`Embedding` 等。内网上游暂时不通时，页面能开、拉模型可能失败，属预期。

停止：`.\stop.ps1`

## 已配参数（`.env`）

| 项 | 值 |
|----|----|
| OpenAI Base | `http://127.0.0.1:9005/openai-gateway/v1` |
| API Key | 研发部 Bearer（与 `aiweb.openai-gateway.api-key` 相同） |
| Chat | Deepseek-32B / Qwen3-30B |
| RAG Embedding | `Embedding` |
| STT | `Wishper` |
| Ollama | 关闭 |

迁内网时只改 `.env` 里带 `127.0.0.1:9005` 的三处 Base URL，例如：

```text
http://<blade-ai-web内网IP>:9005/openai-gateway/v1
```

经 Blade 网关：

```text
http://<网关IP>/blade-ai-web/openai-gateway/v1
```

## 迁到内网 Windows（同样无 Docker）

目标机需要 **64 位 Windows**，目录建议仍用 `F:\job\open-webui`（路径变了也能跑，`start.ps1` 会按脚本所在目录设 `DATA_DIR`）。

### 有外网的这台机器上先打包

安装完成后执行：

```powershell
cd F:\job\open-webui
.\pack-offline.ps1
```

会生成 `wheels\`。把整个 `F:\job\open-webui` 拷走（含 `.venv` 可选用，**更稳的是目标机重装 venv**）。

### 内网机

1. 安装 [Python 3.11 Windows 64-bit](https://www.python.org/downloads/release/python-3119/)（勾选 Add to PATH），或把本机 `%USERPROFILE%\.local\bin\uv.exe` 和 uv 的 Python 一并拷过去。
2. 若目标机没有 uv：把 `C:\Users\<用户>\.local\bin\uv.exe` 拷到目标机并加入 PATH。
3. 拷贝本目录后，在目标机执行：

```powershell
cd F:\job\open-webui
# 若 .venv 是从别的电脑拷来的，先删掉再装：
# Remove-Item -Recurse -Force .venv
.\install.ps1
```

`install.ps1` 发现有 `wheels\` 时会离线安装，不访问 PyPI。

4. 改 `.env` 的 OpenAI Base 为内网 `blade-ai-web` 地址。
5. `.\start.ps1`

### 不要拷坏的东西

- `.venv` 跨机器拷贝经常因路径/用户不同失效，内网优先 `install.ps1` + `wheels`。
- `data\` 是会话/账号库，需要保留历史再拷。

## 未提交到 Git 的文件

这些文件有用，但不是源码。克隆仓库后不会自动出现，需要按下面方式补上。单文件超过 100MB 的，GitHub 会直接拒绝，所以不能靠 Git 同步。

| 路径 | 作用 | 没有它会怎样 | 怎么补 |
| --- | --- | --- | --- |
| `.venv\` | 已安装的 Python 包，真正跑页面的代码在这里 | `start.ps1` 起不来 | 有网执行 `.\install.ps1`；内网把 `wheels\` 一起拷来再执行 `.\install.ps1` |
| `wheels\` | 离线安装包。其中 `torch` 轮子约 118MB，`open_webui` 轮子约 139MB | 没外网时无法 `install.ps1` | 有网机器执行 `.\pack-offline.ps1`，再用 U 盘或共享目录拷贝，不要走 Git |
| `runtime\` | 内嵌 Python 3.11，约 70MB。`start.ps1` 和启动器都找 `runtime\python.exe` | 双击 exe 或 `start.ps1` 会报找不到 Python | 从已经能跑的机器整目录拷贝。这是运行环境，不是本仓库编译出来的 |
| `data\` | 账号、会话数据库 | 程序能开，但没有历史账号和对话 | 需要保留历史时单独拷贝 |
| `.env` | 网关地址和密钥 | 用仓库里的 `.env.intranet.example` 复制一份再改 | 不要把真实密钥提交到 Git |
| `LancangAI.exe`、`澜沧江AI.exe` | 启动器编译结果，各约 28MB | 仍可用 `.\start.ps1` 启动 | 见下方重新打包 |
| `launcher\build\`、`launcher\dist\` | PyInstaller 中间文件和输出 | 不影响源码 | 重新打包时自动生成 |

已经提交、需要保留的内容：

- `redist\vc\` 里的 VC++ 运行库。体积小，Torch 在 Windows 上需要它们。
- `.venv` 里改过的 5 个文件（前端页面、`custom.css`、`main.py`、`middleware.py`）。其余 `.venv` 不入库。

### 重新打包启动器

在已安装 PyInstaller 的环境中：

```powershell
cd F:\job\open-webui\launcher
python -m PyInstaller --noconfirm LancangAI.spec
```

把生成的 exe 复制到仓库根目录，文件名用 `LancangAI.exe` 或 `澜沧江AI.exe`。发给同事时按 `发给同事.txt`：整个目录打包，必须带上 `runtime\`、`.venv\`、`.env`、`serve_backend.py`，不要只发一个 exe。

## GitHub 发版（推荐）

大文件（自定义 wheel、runtime、exe）**不进 Git**，挂在 Release：

```powershell
# 1. 用当前改过的代码打自定义 wheel
.\pack-custom-wheel.ps1

# 2. 打发行 zip（含 wheels + runtime + exe + 脚本）
.\pack-release.ps1 -Version 1.0.1

# 3. 能访问 GitHub 时：登录后推送并创建 Release
gh auth login
git push -u origin main
git tag v1.0.1
git push origin v1.0.1
gh release create v1.0.1 "dist-release\lancang-open-webui-1.0.1-windows.zip" --title "v1.0.1" --notes "澜沧江 Open WebUI 离线包（含自定义 open-webui+lancang）"
```

同事：打开仓库 Releases → 下载 zip → 解压 → 按 `使用说明.txt` 安装。

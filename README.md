# Open WebUI（无 Docker，Windows）

目录：`F:\job\open-webui`  
接本仓库 `OpenAIGetWayController`：Chat / Embedding / Wishper。

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

## 源码

运行用的是 PyPI 包 `open-webui`（对应 https://github.com/open-webui/open-webui 发行版），不是 Docker。

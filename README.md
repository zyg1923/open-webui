# Open WebUI（无 Docker，Windows）— 澜沧江定制版

仓库：https://github.com/zyg1923/open-webui

> **同事请优先下载 Release 离线包**，不要只靠 `git clone`。  
> Git 里只有脚本和说明；自定义程序包（wheel）、`runtime`、exe 在 **Releases** 里。

---

## 同事：怎么下载、怎么装（推荐）

### 1. 下载

1. 打开最新发行版：https://github.com/zyg1923/open-webui/releases/tag/v1.0.1  
   （以后有新版本就打开 https://github.com/zyg1923/open-webui/releases 选最新）  
2. 在 **Assets** 里下载：  
   `lancang-open-webui-1.0.1-windows.zip`（约 311MB）

不要只用 `git clone`：仓库里没有 wheel / runtime / exe。

### 2. 安装

```powershell
# 解压后进入目录
cd <解压目录>

# 生成配置
Copy-Item .env.intranet.example .env
notepad .env
# 把 OPENAI_API_BASE_URL / RAG_ / AUDIO_ 三处改成你们内网 blade-ai-web 网关地址

# 安装（会装 wheels 里的自定义 open-webui+lancang，不是官网原版）
.\install.ps1

# 启动
# 双击 澜沧江AI.exe 或 LancangAI.exe
# 或：
.\start.ps1
```

浏览器打开：http://127.0.0.1:3000  

停止：托盘「退出后台」，或 `.\stop.ps1`。

### 3. 说明

| 文件 | 作用 |
|------|------|
| `wheels\open_webui-*-lancang*.whl` | **你们的定制包**（千问空回复、悬浮白字等已打进包） |
| `wheels\torch-*.whl` | 依赖 |
| `runtime\` | 内嵌 Python，一般不用再装系统 Python |
| `澜沧江AI.exe` / `LancangAI.exe` | 启动器（托盘 + 控制页 17890 + 对话 3000） |

`install.ps1` 会优先安装 `*lancang*` 包；有 `runtime` 时即使没有 `uv` 也能装。

---

## 仅克隆 Git 行不行？

可以拿脚本，但**不能直接跑起来**。缺少：

- `wheels\`（含自定义 lancang 包）
- `runtime\`
- 启动器 exe  

这些超过 GitHub 单文件 100MB 限制，**必须走 Releases / 共享盘**，不能 `git add` 进仓库。

若坚持从源码装：先拿到上述文件放到仓库目录，再执行 `.\install.ps1`。

---

## 维护者：怎么发版

在已经改好、能跑的机器上：

```powershell
cd F:\job\open-webui

# 一键：打自定义 wheel → 打 zip →（登录后）上传 Release
.\publish-release.ps1 -Version 1.0.1

# 若当前网不能登录 GitHub，先只打包：
.\publish-release.ps1 -Version 1.0.1 -SkipUpload
# 生成：dist-release\lancang-open-webui-1.0.1-windows.zip
```

能访问 GitHub 时：

```powershell
# 不要用账户密码。用浏览器或 Token：
gh auth login

git push -u origin main
.\publish-release.ps1 -Version 1.0.1
```

分步命令（与上面等价）：

```powershell
.\pack-custom-wheel.ps1
.\pack-release.ps1 -Version 1.0.1
git tag v1.0.1
git push origin main
git push origin v1.0.1
gh release create v1.0.1 "dist-release\lancang-open-webui-1.0.1-windows.zip" --title "v1.0.1" --notes "澜沧江离线包"
```

---

## 本机开发启动（已有完整目录时）

```powershell
cd F:\job\open-webui
.\start.ps1
```

浏览器：http://127.0.0.1:3000  

`.env` 示例见 `.env.intranet.example`。内网改三处 Base URL，例如：

```text
http://<网关IP>/blade-ai-web/openai-gateway/v1
```

停止：`.\stop.ps1`

---

## 重新打包启动器 exe（可选）

```powershell
cd F:\job\open-webui\launcher
python -m PyInstaller --noconfirm LancangAI.spec
# 把 dist\LancangAI.exe 拷到仓库根目录，可再复制一份改名为 澜沧江AI.exe
```

改对话逻辑（千问等）后要给同事：跑 `.\pack-custom-wheel.ps1` 再发版，**不必**每次重打 exe。

---

## 未进 Git 的大文件

| 路径 | 怎么给同事 |
|------|------------|
| `wheels\` | Release zip / 共享盘 |
| `runtime\` | Release zip |
| `*.exe` | Release zip |
| `.venv\` | 同事本地 `install.ps1` 生成 |
| `.env` / `data\` | 各自机器生成，勿提交密钥 |

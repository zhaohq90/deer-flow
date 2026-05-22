# DeerFlow 本地开发环境配置指南

> 本文档记录了 DeerFlow 在本机上的安装、配置和运行方式。

---

## 一、服务架构

DeerFlow 启动后会运行以下 4 个核心服务：

| 服务名称 | 端口 | 说明 |
|----------|------|------|
| **LangGraph** | 2024 | 后端 Agent 运行引擎，基于 LangGraph 框架 |
| **Gateway API** | 8001 | FastAPI 网关，提供 `/api/*` 接口 |
| **Frontend** | 3000 | Next.js 前端应用（开发模式） |
| **Nginx** | 2026 | 反向代理，统一入口 |

**服务访问地址：**
- Web 应用: http://localhost:2026
- API Gateway: http://localhost:2026/api/*
- LangGraph API: http://localhost:2026/api/langgraph/*

---

## 二、启动服务

### 方式一：使用 Makefile（推荐）

```bash
# 进入项目目录
cd /Users/zhaohq/projects/deer-flow

# 开发模式（热重载）
make dev

# 生产模式（无热重载）
make start
```

### 方式二：使用启动脚本

```bash
# 开发模式
./scripts/start-deerflow.sh --dev

# 生产模式
./scripts/start-deerflow.sh --prod
```

**注意：** 脚本执行完成后窗口会保持打开，显示 "按任意键关闭窗口..."，需手动按键关闭。
服务在后台运行，关闭窗口不影响服务状态。

### 方式三：手动启动各服务

```bash
# 1. 启动 LangGraph（后台运行）
cd backend
uv run langgraph dev --no-browser --allow-blocking --server-log-level info &

# 2. 启动 Gateway API
uv run uvicorn app.gateway.app:app --host 0.0.0.0 --port 8001 --reload &

# 3. 启动 Frontend
cd frontend
pnpm dev &

# 4. 启动 Nginx
nginx -c docker/nginx/nginx.local.conf -p .
```

---

## 三、停止服务

### 方式一：使用 Makefile

```bash
make stop
```

### 方式二：使用停止脚本

```bash
./scripts/stop-deerflow.sh
```

### 方式三：手动停止

```bash
# 停止所有相关进程
pkill -f "langgraph dev"
pkill -f "uvicorn app.gateway.app:app"
pkill -f "next dev"
pkill -f "next-server"
nginx -s quit
```

---

## 四、环境依赖

| 工具 | 版本要求 | 安装方式 |
|------|----------|----------|
| Python | 3.12+ | 系统自带或 `brew install python` |
| Node.js | 22+ | `brew install node` |
| pnpm | 10+ | `npm install -g pnpm` |
| uv | 最新版 | `curl -LsSf https://astral.sh/uv/install.sh | sh` |
| nginx | 最新版 | `brew install nginx` |

**检查依赖：**
```bash
PYTHON=python3 make check
```

---

## 五、配置修改记录

### 5.1 模型配置（config.yaml）

配置了 GLM-5 模型，使用 Anthropic 兼容网关：

```yaml
models:
  - name: glm-5
    display_name: GLM-5
    use: langchain_anthropic:ChatAnthropic
    model: glm-5
    api_key: $ANTHROPIC_AUTH_TOKEN
    base_url: $ANTHROPIC_BASE_URL
    max_tokens: 8192
    supports_vision: true
```

### 5.2 环境变量配置（.env）

已在 `.env` 文件中配置必要的环境变量：

```bash
# Anthropic API (GLM-5 via compatible gateway)
ANTHROPIC_AUTH_TOKEN=sk-sp-064ecd47b4d94efd981296ea84acff75
ANTHROPIC_BASE_URL=https://coding.dashscope.aliyuncs.com/apps/anthropic
```

**注意：** 启动脚本会自动加载 `.env` 文件中的环境变量。

### 5.2 飞书集成配置（config.yaml）

```yaml
channels:
  langgraph_url: http://localhost:2024
  gateway_url: http://localhost:8001

  feishu:
    enabled: true
    app_id: cli_a92500a6c639dcb6
    app_secret: yrPBuGFg3vUO0eZOxxMR7gvJju3CnGXP
```

**飞书连接状态：**
- WebSocket 已连接到 `wss://msg-frontier.feishu.cn/ws/v2`

---

## 六、日志文件

所有日志存放在 `logs/` 目录：

| 日志文件 | 内容 |
|----------|------|
| `langgraph.log` | LangGraph Agent 运行日志 |
| `gateway.log` | Gateway API 日志 |
| `frontend.log` | Next.js 前端日志 |
| `nginx.log` | Nginx 访问日志 |
| `nginx-error.log` | Nginx 错误日志 |

**查看日志：**
```bash
# 查看飞书连接状态
grep -i feishu logs/gateway.log

# 查看 LangGraph 启动日志
tail -f logs/langgraph.log
```

---

## 七、常用命令速查

```bash
# 安装依赖
make install

# 生成配置文件
make config

# 检查环境
PYTHON=python3 make check

# 启动开发环境
make dev

# 停止所有服务
make stop

# 清理临时文件
make clean

# 查看服务状态
curl http://localhost:8001/health

# 查看可用模型
curl http://localhost:2026/api/models
```

---

## 八、飞书机器人配置说明

### 飞书开放平台配置步骤

1. 登录 [飞书开放平台](https://open.feishu.cn/)
2. 进入应用管理，找到 App ID: `cli_a92500a6c639dcb6`
3. 启用 **机器人能力**
4. 配置事件订阅，订阅 `im.message.receive_v1` 事件
5. 发布应用版本

### 验证连接状态

```bash
grep "connected to wss://msg-frontier.feishu.cn" logs/gateway.log
```

---

## 九、项目目录结构

```
/Users/zhaohq/projects/deer-flow/
├── config.yaml          # 主配置文件
├── Makefile             # 构建命令
├── backend/             # Python 后端
│   ├── .venv/           # Python 虚拟环境
│   ├── app/             # 应用代码
│   └── packages/        # 内部包
├── frontend/            # Next.js 前端
├── docker/              # Docker 配置
│   └── nginx/           # Nginx 配置
├── scripts/             # 工具脚本
│   ├── start-deerflow.sh  # 启动脚本
│   └── stop-deerflow.sh   # 停止脚本
├── logs/                # 运行日志
└── docs/                # 文档
    └── DEERFLOW_SETUP.md  # 本配置文档
```

---

## 十、常见问题与解决方案

### 10.1 启动脚本环境变量未加载问题

**问题描述：**

执行 `./scripts/start-deerflow.sh` 后，LangGraph 服务无法启动，日志显示：
```
ValueError: Environment variable ANTHROPIC_AUTH_TOKEN not found for config value $ANTHROPIC_AUTH_TOKEN
```

**问题原因：**

启动脚本使用 `make dev-daemon` 命令启动服务，该命令通过 `nohup sh -c` 在子 shell 中运行 LangGraph 和 Gateway。子 shell 在启动时不会自动加载父 shell 的环境变量，导致 `config.yaml` 中引用的 `$ANTHROPIC_AUTH_TOKEN` 等环境变量无法解析。

**修复内容：**

| 文件 | 修改内容 |
|------|----------|
| `.env` | 添加 `ANTHROPIC_AUTH_TOKEN` 和 `ANTHROPIC_BASE_URL` 环境变量定义 |
| `scripts/start-daemon.sh` | 在文件开头添加 `.env` 文件加载逻辑：`source "$REPO_ROOT/.env"` |
| `scripts/start-daemon.sh` | 修改 LangGraph/Gateway 启动命令，在子 shell 中显式加载 `.env` |
| `scripts/start-deerflow.sh` | 使用 `make dev-daemon` 后台启动，添加服务状态检查 |
| `scripts/stop-deerflow.sh` | 添加 "按任意键关闭窗口..." 提示 |

**修复后的启动命令（start-daemon.sh）：**

```bash
# 在子 shell 中加载 .env 文件
nohup sh -c 'cd backend && if [ -f ../.env ]; then set -a && source ../.env && set +a; fi && NO_COLOR=1 uv run langgraph dev ...' &
```

### 10.2 脚本执行后窗口自动关闭问题

**问题描述：**

双击运行启动/停止脚本后，终端窗口立即关闭，无法查看执行结果。

**解决方案：**

在脚本末尾添加等待用户输入的代码：

```bash
echo "按任意键关闭窗口..."
read -n 1 -s
```

此命令类似 Windows 的 `pause`，会等待用户按下任意键后才关闭窗口。

---

## 十一、脚本文件说明

### 11.1 启动脚本 (scripts/start-deerflow.sh)

**功能：**
- 检查配置文件和环境依赖
- 加载 `.env` 环境变量
- 使用 `make dev-daemon` 在后台启动所有服务
- 检查各服务启动状态
- 显示访问地址和日志位置
- 等待用户按键关闭窗口

**用法：**
```bash
./scripts/start-deerflow.sh        # 开发模式
./scripts/start-deerflow.sh --prod # 生产模式
```

### 11.2 停止脚本 (scripts/stop-deerflow.sh)

**功能：**
- 停止 LangGraph、Gateway、Frontend、Nginx 所有进程
- 清理 Sandbox 容器
- 显示各服务停止状态
- 等待用户按键关闭窗口

**用法：**
```bash
./scripts/stop-deerflow.sh
```

---

*文档生成时间: 2026-03-28*
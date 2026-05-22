#!/bin/bash
#
# DeerFlow 停止脚本
# 用法: ./scripts/stop-deerflow.sh
#
# 执行完成后窗口保持打开，按任意键关闭
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "=========================================="
echo "  停止 DeerFlow 服务"
echo "=========================================="
echo ""

# 停止 LangGraph
echo "停止 LangGraph..."
pkill -f "langgraph dev" 2>/dev/null || true
pkill -f "langgraph-api" 2>/dev/null || true

# 停止 Gateway (Uvicorn)
echo "停止 Gateway API..."
pkill -f "uvicorn app.gateway.app:app" 2>/dev/null || true

# 停止 Frontend (Next.js)
echo "停止 Frontend..."
pkill -f "next dev" 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
pkill -f "next-server" 2>/dev/null || true

# 停止 Nginx
echo "停止 Nginx..."
nginx -c "$PROJECT_ROOT/docker/nginx/nginx.local.conf" -p "$PROJECT_ROOT" -s quit 2>/dev/null || true
sleep 1
pkill -9 nginx 2>/dev/null || true
killall -9 nginx 2>/dev/null || true

# 清理 sandbox 容器
echo "清理 Sandbox 容器..."
"$PROJECT_ROOT/scripts/cleanup-containers.sh" deer-flow-sandbox 2>/dev/null || true

# 清理 Python 子进程
sleep 1
pkill -f "uv run" 2>/dev/null || true

echo ""
echo "=========================================="
echo "  所有服务已停止"
echo "=========================================="
echo ""

# 显示状态
echo "进程状态检查:"
if pgrep -f "langgraph" > /dev/null; then
    echo "  ⚠ LangGraph 进程仍在运行"
else
    echo "  ✓ LangGraph 已停止"
fi

if pgrep -f "uvicorn" > /dev/null; then
    echo "  ⚠ Gateway 进程仍在运行"
else
    echo "  ✓ Gateway 已停止"
fi

if pgrep -f "next" > /dev/null; then
    echo "  ⚠ Frontend 进程仍在运行"
else
    echo "  ✓ Frontend 已停止"
fi

if pgrep -f "nginx" > /dev/null; then
    echo "  ⚠ Nginx 进程仍在运行"
else
    echo "  ✓ Nginx 已停止"
fi

echo ""
echo "按任意键关闭窗口..."
read -n 1 -s
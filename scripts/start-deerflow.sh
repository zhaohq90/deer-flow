#!/bin/bash
#
# DeerFlow 启动脚本
# 用法: ./scripts/start-deerflow.sh [--dev|--prod]
#
# 服务在后台启动，窗口保持打开，按任意键关闭
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# 加载环境变量
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# 参数解析
DEV_MODE=true
for arg in "$@"; do
    case "$arg" in
        --dev)  DEV_MODE=true ;;
        --prod) DEV_MODE=false ;;
        *) echo "未知参数: $arg"; echo "用法: $0 [--dev|--prod]"; exit 1 ;;
    esac
done

echo "=========================================="
echo "  启动 DeerFlow 开发环境"
echo "=========================================="
echo ""

# 检查配置文件
if [ ! -f "$PROJECT_ROOT/config.yaml" ]; then
    echo "错误: 配置文件 config.yaml 不存在"
    echo "请先运行: make config"
    echo ""
    echo "按任意键关闭窗口..."
    read -n 1 -s
    exit 1
fi

# 检查 Python
PYTHON=python3
if ! command -v $PYTHON &> /dev/null; then
    echo "错误: Python3 未安装"
    echo ""
    echo "按任意键关闭窗口..."
    read -n 1 -s
    exit 1
fi

echo "启动模式: $([ "$DEV_MODE" = true ] && echo '开发模式 (后台运行)' || echo '生产模式')"
echo ""

# 创建日志目录
mkdir -p logs

# 使用 dev-daemon 启动服务（后台模式）
export PYTHON=$PYTHON
make dev-daemon 2>&1

# 等待服务完全启动
sleep 3

# 检查服务状态
echo ""
echo "=========================================="
echo "  服务状态检查"
echo "=========================================="

check_service() {
    local name=$1
    local port=$2
    if curl -s http://localhost:$port > /dev/null 2>&1; then
        echo "  ✓ $name 运行正常 (端口 $port)"
    else
        echo "  ✗ $name 未启动 (端口 $port)"
    fi
}

check_service "LangGraph" 2024
check_service "Gateway" 8001
check_service "Frontend" 3000
check_service "Nginx" 2026

echo ""
echo "=========================================="
echo "  服务已启动"
echo "=========================================="
echo ""
echo "  访问地址: http://localhost:2026"
echo ""
echo "  日志文件:"
echo "    - LangGraph: logs/langgraph.log"
echo "    - Gateway:   logs/gateway.log"
echo "    - Frontend:  logs/frontend.log"
echo "    - Nginx:     logs/nginx.log"
echo ""
echo "  停止服务: ./scripts/stop-deerflow.sh"
echo ""
echo "按任意键关闭此窗口..."
read -n 1 -s
#!/bin/bash
# 一键检查所有服务状态
echo "=========================================="
echo "  Hermes Agent 部署状态检查"
echo "=========================================="
echo ""

echo "[1/6] Docker 容器状态"
sudo docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep -E "NAMES|hermes" || echo "  未找到 Hermes 容器"
echo ""

echo "[2/6] simple_proxy2 聊天代理"
if ps aux | grep -v grep | grep -q simple_proxy2; then
    echo "  ✅ simple_proxy2 运行中（端口 9222）"
else
    echo "  ❌ simple_proxy2 未运行"
fi
echo ""

echo "[3/6] 聊天代理健康检查"
curl -s --max-time 3 http://localhost:9222/ping 2>/dev/null && echo "" || echo "  本地 /ping 失败"
echo ""

echo "[4/6] Hermes Docker 健康检查"
curl -s --max-time 5 http://localhost:8642/health 2>/dev/null || echo "  本地健康检查失败"
echo ""

echo "[5/6] cloudflared 服务"
if sudo systemctl is-active --quiet cloudflared 2>/dev/null; then
    echo "  ✅ cloudflared systemd 运行中"
elif ps aux | grep -v grep | grep -q cloudflared; then
    echo "  ✅ cloudflared 进程运行中（非 systemd）"
else
    echo "  ❌ cloudflared 未运行"
fi
echo ""

echo "[6/6] cloudflared Tunnel URL"
journalctl -u cloudflared --no-pager -n 20 2>/dev/null | grep -i "trycloudflare" | tail -1 || echo "  未找到 URL（服务器重启后 URL 会变化，需重新获取）"
echo ""

echo "=========================================="
echo "  检查完成"
echo "=========================================="
echo ""
echo "聊天界面访问方式："
echo "  1. 获取新 URL: bash /tmp/get_url.sh"
echo "  2. 重启所有服务: bash /tmp/restart_all.sh"
echo "  3. 测试 API: bash /tmp/test_api.sh"

#!/bin/bash
# 重启所有服务（正确的启动顺序）
echo "正在重启所有服务..."
echo ""

echo "[1/4] 停止现有 cloudflared"
pkill -f cloudflared 2>/dev/null
sleep 2
echo "  已停止"

echo "[2/4] 重启 Hermes Docker 容器"
sudo docker restart hermes
sleep 3
echo "  Docker 重启完成"

echo "[3/4] 启动聊天代理（simple_proxy2.py，端口 9222）"
# 先停掉旧的
PIDS=$(pgrep -f simple_proxy2)
if [ -n "$PIDS" ]; then
    kill $PIDS 2>/dev/null
    sleep 1
fi
# 启动新的
cd /tmp && nohup python3 simple_proxy2.py > /tmp/proxy.log 2>&1 &
sleep 2
# 验证
if curl -s http://localhost:9222/ping | grep -q ok; then
    echo "  ✅ simple_proxy2 启动成功"
else
    echo "  ❌ simple_proxy2 启动失败，查看日志: tail /tmp/proxy.log"
fi

echo "[4/4] 启动 cloudflared 隧道（暴露 9222 端口）"
nohup cloudflared tunnel --url http://localhost:9222 > /tmp/cloudflared-chat.log 2>&1 &
sleep 10
URL=$(grep -i trycloudflare /tmp/cloudflared-chat.log | tail -1 | grep -o 'https://[^ ]*trycloudflare.com')
if [ -n "$URL" ]; then
    echo "  ✅ cloudflared 启动成功"
    echo ""
    echo "=========================================="
    echo "  🎉 聊天界面地址：$URL"
    echo "=========================================="
else
    echo "  ❌ cloudflared URL 未找到"
fi
echo ""
echo "如需手动获取 URL，请运行："
echo "  journalctl -u cloudflared --no-pager -n 10 | grep trycloudflare"
echo "或：grep trycloudflare /tmp/cloudflared-chat.log"

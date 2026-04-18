#!/bin/bash
# restart_all.sh — 重启 Hermes 所有服务（正确顺序）
set -e

echo ">>> 停止旧服务..."
pkill -f cloudflared || true
pkill -f simple_proxy2 || true
pkill -f "vite" || true
sleep 2

echo ">>> 启动 Hermes Docker..."
docker start hermes-agent || docker run -d \
  --name hermes-agent \
  -p 0.0.0.0:8642:8000 \
  -e OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
  -e API_SERVER_KEY="hermes-api-key-2026" \
  -e API_SERVER_HOST=0.0.0.0 \
  --restart unless-stopped \
  nousresearch/hermes-agent:latest
sleep 3

echo ">>> 启动聊天代理（端口 9222）..."
cd /tmp && nohup python3 simple_proxy2.py > /tmp/proxy.log 2>&1 &
sleep 2

echo ">>> 启动官方管理面板（端口 5173）..."
cd /home/ubuntu/hermes-local/web && nohup npm run dev > /tmp/vite-webui.log 2>&1 &
sleep 3

echo ">>> 启动 cloudflared 隧道..."
# 聊天界面隧道
nohup cloudflared tunnel --url http://localhost:9222 > /tmp/cloudflared-chat2.log 2>&1 &
sleep 3
# 官方面板隧道
nohup cloudflared tunnel --url http://localhost:5173 > /tmp/cloudflared-webui.log 2>&1 &
sleep 3

echo ""
echo "=== 当前可用地址 ==="
for log in /tmp/cloudflared-chat2.log /tmp/cloudflared-webui.log; do
  name=$(basename $log .log)
  url=$(grep -o 'https://[^ ]*trycloudflare.com' $log 2>/dev/null | tail -1)
  echo "  [$name] $url"
done
echo ""
echo ">>> 重启完成！"
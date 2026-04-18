#!/bin/bash
# check_status.sh — 一键检查 Hermes 所有服务状态
echo "=== Hermes 服务状态检查 ==="
echo ""

# Docker
if docker ps | grep -q hermes-agent; then
  echo "[OK] Hermes Docker 容器运行中"
else
  echo "[FAIL] Hermes Docker 容器未运行"
fi

# 端口监听
for port in 8642 9222 9119 5173; do
  if ss -tlnp 2>/dev/null | grep -q ":$port "; then
    echo "[OK] 端口 $port 监听中"
  else
    echo "[FAIL] 端口 $port 未监听"
  fi
done

# 进程检查
for svc in "simple_proxy2" "vite" "mihomo"; do
  if pgrep -f "$svc" > /dev/null; then
    echo "[OK] $svc 进程运行中"
  else
    echo "[WARN] $svc 进程未找到"
  fi
done

# cloudflared 隧道
echo ""
echo "=== Cloudflared 隧道 ==="
for log in /tmp/cloudflared-chat.log /tmp/cloudflared-chat2.log /tmp/cloudflared-webui.log; do
  if [ -f "$log" ]; then
    name=$(basename $log .log)
    url=$(grep -o 'https://[^ ]*trycloudflare.com' $log 2>/dev/null | tail -1)
    if [ -n "$url" ]; then
      echo "[OK] [$name] $url"
    else
      echo "[WARN] [$name] 无有效 URL"
    fi
  fi
done

# API 测试
echo ""
echo "=== API 健康检查 ==="
curl -s http://localhost:8642/health | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'[OK] Hermes API: {d.get(\"status\")}')" 2>/dev/null || echo "[WARN] Hermes API 健康检查失败"
curl -s http://localhost:9222/ping | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'[OK] 聊天代理 /ping: {d}')" 2>/dev/null || echo "[WARN] 聊天代理不可用"
curl -s -o /dev/null -w '[OK] Vite 页面: HTTP %{http_code}\n' http://localhost:5173/ 2>/dev/null || echo "[FAIL] Vite 页面无法访问"
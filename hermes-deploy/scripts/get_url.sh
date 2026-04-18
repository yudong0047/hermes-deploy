#!/bin/bash
# get_url.sh — 获取所有 cloudflared 隧道 URL
echo "=== Cloudflared 隧道 URL ==="
echo ""

# 检查各日志文件
for log in /tmp/cloudflared-chat.log /tmp/cloudflared-chat2.log /tmp/cloudflared-webui.log; do
  if [ -f "$log" ]; then
    name=$(basename $log .log)
    url=$(grep -o 'https://[^ ]*trycloudflare.com' "$log" 2>/dev/null | tail -1)
    if [ -n "$url" ]; then
      echo "[$name]"
      echo "  $url"
      echo ""
    fi
  fi
done

# journalctl 兜底
echo "=== Journalctl 兜底查找 ==="
journalctl -u cloudflared --no-pager -n 50 2>/dev/null | grep -o 'https://[^ ]*trycloudflare.com' | sort -u | while read url; do
  echo "[journal] $url"
done
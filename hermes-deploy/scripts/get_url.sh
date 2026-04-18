#!/bin/bash
# 获取当前 cloudflared Tunnel URL
# 优先从 systemd journal 获取，其次从日志文件

echo "=== cloudflared Tunnel URL ==="
echo ""

URL=$(journalctl -u cloudflared --no-pager -n 30 2>/dev/null | grep -i "trycloudflare" | tail -1 | grep -o 'https://[^ ]*trycloudflare.com')

if [ -z "$URL" ]; then
    URL=$(grep -i "trycloudflare" /tmp/cloudflared-chat.log 2>/dev/null | tail -1 | grep -o 'https://[^ ]*trycloudflare.com')
fi

if [ -z "$URL" ]; then
    URL=$(grep -i "trycloudflare" /var/log/cloudflared.log 2>/dev/null | tail -1 | grep -o 'https://[^ ]*trycloudflare.com')
fi

if [ -n "$URL" ]; then
    echo "✅ $URL"
    echo ""
    echo "聊天界面：$URL"
else
    echo "❌ 未找到 Tunnel URL"
    echo ""
    echo "可能原因：服务器重启后 cloudflared 未自动启动"
    echo "解决：运行 bash /tmp/restart_all.sh"
fi

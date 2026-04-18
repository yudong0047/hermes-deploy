#!/bin/bash
# 测试 Hermes API 功能（通过聊天代理端口 9222）
API_KEY="hermes-api-key-2026"
MODEL="google/gemma-4-26b-a4b-it:free"

echo "=========================================="
echo "  Hermes API 功能测试"
echo "=========================================="
echo ""

echo "[1/4] 聊天代理 /ping 健康检查"
PING=$(curl -s --max-time 5 http://localhost:9222/ping)
if echo "$PING" | grep -q ok; then
    echo "  ✅ /ping 正常: $PING"
else
    echo "  ❌ /ping 失败: $PING"
fi
echo ""

echo "[2/4] Hermes Docker /health 健康检查"
HEALTH=$(curl -s --max-time 5 http://localhost:8642/health)
if [ -n "$HEALTH" ]; then
    echo "  ✅ $HEALTH"
else
    echo "  ❌ Hermes 容器无响应"
fi
echo ""

echo "[3/4] 模型列表（通过代理）"
curl -s --max-time 15 -X POST http://localhost:9222/api/chat \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"what models do you have\"}],\"max_tokens\":20}" \
    | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'error' in d:
        print('  ⚠️ 错误: ' + str(d['error']))
    else:
        print('  ✅ 请求成功')
        content = d.get('choices', [{}])[0].get('message', {}).get('content', '')
        print('  回复: ' + content[:200])
except Exception as e:
    print('  解析: ' + str(e))
" 2>/dev/null || echo "  ❌ 请求失败"
echo ""

echo "[4/4] cloudflared Tunnel URL"
URL=$(journalctl -u cloudflared --no-pager -n 20 2>/dev/null | grep -i "trycloudflare" | tail -1 | grep -o 'https://[^ ]*trycloudflare.com')
if [ -n "$URL" ]; then
    echo "  ✅ $URL"
else
    echo "  ⚠️ 未找到 URL（服务器重启后会变化）"
fi
echo ""

echo "=========================================="
echo "  测试完成"
echo "=========================================="

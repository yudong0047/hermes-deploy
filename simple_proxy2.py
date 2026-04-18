#!/usr/bin/env python3
"""Simple proxy server with debug logging"""

from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError
import json
import sys

API_BASE = "http://localhost:8642"
API_KEY = "hermes-api-key-2026"
PORT = 9222

class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {args[0]}")
        sys.stdout.flush()
    
    def send_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.send_header('Content-Length', '0')
        self.send_cors_headers()
        self.end_headers()
    
    def do_POST(self):
        if self.path == "/api/chat":
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            print(f"Received request: {body[:200]}", flush=True)
            
            try:
                req = Request(
                    f"{API_BASE}/v1/chat/completions",
                    data=body,
                    headers={
                        'Content-Type': 'application/json',
                        'Authorization': f'Bearer {API_KEY}'
                    },
                    method='POST'
                )
                with urlopen(req, timeout=60) as response:
                    result = response.read()
                    print(f"API response: {result[:100]}", flush=True)
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_cors_headers()
                    self.send_header('Content-Length', len(result))
                    self.end_headers()
                    self.wfile.write(result)
            except HTTPError as e:
                error_body = e.read()
                print(f"HTTP Error {e.code}: {error_body}", flush=True)
                self.send_response(e.code)
                self.send_header('Content-Type', 'application/json')
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(error_body)
            except Exception as e:
                print(f"Error: {e}", flush=True)
                error_msg = json.dumps({"error": str(e)}).encode()
                self.send_response(500)
                self.send_header('Content-Type', 'application/json')
                self.send_cors_headers()
                self.end_headers()
                self.wfile.write(error_msg)
            return
        
        self.send_error(404)
    
    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(CHAT_HTML.encode())
        elif self.path == "/ping":
            body = b'{"ok":true}'
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(body))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

CHAT_HTML = '''<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Hermes Chat</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui,-apple-system,sans-serif;background:#1a1a2e;color:#eee;height:100vh;display:flex;flex-direction:column;overflow:hidden}
.header{background:#16213e;padding:14px 20px;border-bottom:1px solid #0f3460;display:flex;align-items:center;gap:10px;flex-shrink:0}
.header h1{font-size:17px;color:#00d9ff;font-weight:600}
.status{margin-left:auto;font-size:12px;padding:3px 10px;border-radius:10px;background:#0f3460}
.connected{color:#00ff88}.error{color:#ff6b6b}
/* 聊天区域 */
.chat{flex:1;overflow-y:auto;padding:16px 20px;display:flex;flex-direction:column;gap:12px}
/* 消息行 — 用 flex 控制左右 */
.row{display:flex;width:100%}
.row.user{justify-content:flex-end}
.row.assistant{justify-content:flex-start}
/* 气泡 */
.bubble{max-width:72%;padding:11px 15px;border-radius:18px;line-height:1.65;font-size:14px;word-break:break-word}
.row.user .bubble{background:#00d9ff;color:#000;border-bottom-right-radius:4px}
.row.assistant .bubble{background:#16213e;border:1px solid #0f3460;border-bottom-left-radius:4px;color:#e8e8e8}
/* Markdown 渲染样式 */
.bubble strong{font-weight:700}
.bubble em{font-style:italic}
.bubble code{background:#0a0a1a;padding:2px 6px;border-radius:4px;font-family:monospace;font-size:13px;color:#00d9ff}
.bubble pre{background:#0a0a1a;padding:10px;border-radius:8px;overflow-x:auto;margin:6px 0}
.bubble pre code{background:none;padding:0;color:#a8d8a8;font-size:13px}
.bubble p{margin:4px 0}
.bubble ul,.bubble ol{padding-left:20px;margin:4px 0}
.bubble li{margin:2px 0}
.bubble h1,.bubble h2,.bubble h3{margin:8px 0 4px;color:#00d9ff}
.bubble h1{font-size:16px}.bubble h2{font-size:15px}.bubble h3{font-size:14px}
.bubble hr{border:none;border-top:1px solid #0f3460;margin:8px 0}
/* 正在输入动画 */
.typing span{display:inline-block;width:7px;height:7px;margin:0 2px;background:#00d9ff;border-radius:50%;animation:bounce 1.2s infinite}
.typing span:nth-child(2){animation-delay:.2s}
.typing span:nth-child(3){animation-delay:.4s}
@keyframes bounce{0%,80%,100%{transform:translateY(0)}40%{transform:translateY(-6px)}}
/* 输入框 */
.input-bar{background:#16213e;padding:12px 16px;border-top:1px solid #0f3460;display:flex;gap:10px;flex-shrink:0}
.input-bar textarea{flex:1;background:#0f3460;border:none;padding:10px 15px;border-radius:20px;color:#fff;font-size:14px;outline:none;resize:none;height:42px;max-height:120px;line-height:1.4;font-family:inherit;overflow-y:auto}
.input-bar button{background:#00d9ff;border:none;padding:10px 20px;border-radius:20px;color:#000;font-weight:bold;cursor:pointer;white-space:nowrap;font-size:14px;align-self:flex-end}
.input-bar button:disabled{background:#444;color:#888;cursor:not-allowed}
.input-bar button:hover:not(:disabled){background:#00c4e8}
</style>
</head>
<body>
<div class="header">
  <h1>&#127381; Hermes Chat</h1>
  <span class="status" id="s">检查中...</span>
</div>
<div class="chat" id="chat">
  <div class="row assistant"><div class="bubble">你好！有什么可以帮你的？</div></div>
</div>
<div class="input-bar">
  <textarea id="inp" placeholder="输入消息，按 Enter 发送，Shift+Enter 换行..." rows="1"></textarea>
  <button id="btn" onclick="send()">发送</button>
</div>
<script>
const MODEL = 'google/gemma-4-26b-a4b-it:free';
let history = [];
let busy = false;

// 简易 Markdown 解析
function md(text) {
  let t = text
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  // 代码块
  t = t.replace(/```(\\w*)\\n?([\\s\\S]*?)```/g, (_,lang,code)=>`<pre><code>${code.trim()}</code></pre>`);
  // 行内代码
  t = t.replace(/`([^`]+)`/g,'<code>$1</code>');
  // 标题
  t = t.replace(/^### (.+)$/gm,'<h3>$1</h3>');
  t = t.replace(/^## (.+)$/gm,'<h2>$1</h2>');
  t = t.replace(/^# (.+)$/gm,'<h1>$1</h1>');
  // 加粗 / 斜体
  t = t.replace(/\\*\\*([^*]+)\\*\\*/g,'<strong>$1</strong>');
  t = t.replace(/\\*([^*]+)\\*/g,'<em>$1</em>');
  // 有序 / 无序列表
  t = t.replace(/^- (.+)$/gm,'<li>$1</li>').replace(/(<li>.*<\\/li>)/s, s=>`<ul>${s}</ul>`);
  t = t.replace(/^\\d+\\. (.+)$/gm,'<li>$1</li>');
  // 分割线
  t = t.replace(/^---$/gm,'<hr>');
  // 换行转 <br>（非标签内）
  t = t.replace(/\\n{2,}/g,'</p><p>').replace(/\\n/g,'<br>');
  return `<p>${t}</p>`;
}

function addBubble(role, html, isHTML=false) {
  const row = document.createElement('div');
  row.className = `row ${role}`;
  const b = document.createElement('div');
  b.className = 'bubble';
  if (isHTML) b.innerHTML = html; else b.textContent = html;
  row.appendChild(b);
  document.getElementById('chat').appendChild(row);
  row.scrollIntoView({behavior:'smooth', block:'end'});
  return b;
}

function showTyping() {
  const row = document.createElement('div');
  row.className = 'row assistant';
  row.id = 'typing-row';
  row.innerHTML = '<div class="bubble typing"><span></span><span></span><span></span></div>';
  document.getElementById('chat').appendChild(row);
  row.scrollIntoView({behavior:'smooth', block:'end'});
}

function removeTyping() {
  const el = document.getElementById('typing-row');
  if (el) el.remove();
}

async function send() {
  const inp = document.getElementById('inp');
  const text = inp.value.trim();
  if (!text || busy) return;
  busy = true;
  document.getElementById('btn').disabled = true;

  addBubble('user', text);
  history.push({role:'user', content:text});
  inp.value = '';
  inp.style.height = '42px';

  showTyping();
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify({model:MODEL, messages:history, max_tokens:2000})
    });
    const data = await resp.json();
    removeTyping();
    if (data.error) {
      addBubble('assistant', '⚠️ 错误：' + (data.error.message || JSON.stringify(data.error)));
    } else {
      const content = data.choices?.[0]?.message?.content || '（无回复）';
      addBubble('assistant', md(content), true);
      history.push({role:'assistant', content});
    }
  } catch(e) {
    removeTyping();
    addBubble('assistant', '⚠️ 网络错误：' + e.message);
  }
  busy = false;
  document.getElementById('btn').disabled = false;
  inp.focus();
}

// Enter 发送，Shift+Enter 换行
document.getElementById('inp').addEventListener('keydown', e => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    send();
  }
});
// 自动撑高 textarea
document.getElementById('inp').addEventListener('input', function() {
  this.style.height = '42px';
  this.style.height = Math.min(this.scrollHeight, 120) + 'px';
});

// 状态检测
(async()=>{
  try{
    const r = await fetch('/ping');
    if(r.ok){
      document.getElementById('s').textContent='已连接';
      document.getElementById('s').className='status connected';
    } else throw new Error();
  } catch(e){
    document.getElementById('s').textContent='连接失败';
    document.getElementById('s').className='status error';
  }
})();
</script>
</body></html>'''

if __name__ == '__main__':
    HTTPServer(('0.0.0.0', PORT), Handler).serve_forever()

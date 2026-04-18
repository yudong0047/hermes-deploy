---
name: hermes-deploy
description: >
  腾讯云 Hermes Agent 部署与管理技能。触发词：「部署 Hermes」「腾讯云部署」「服务器部署」
  「Hermes Agent」「cloudflared」「外网访问」「聊天界面」「修复 Hermes」
  「Hermes 打不开」「Hermes 连接失败」「重启 Hermes」「官方面板」「管理后台」「Web UI」「Hermes v0.10」。涵盖 SSH 连接、systemd 服务、
  Docker 容器、cloudflared 隧道、聊天界面问题排查和 API 调试。
---

# Hermes Agent 腾讯云部署技能

本技能用于在腾讯云 Ubuntu 服务器上部署和管理 Hermes Agent，并提供聊天界面。
**完整项目历时**：从服务器初始化 → Docker 部署 → 解决透明代理层 → Web UI 配置 → 聊天界面构建 → 多轮迭代优化。

---

## 一、服务器基本信息

| 项目 | 值 |
|------|----|
| 服务器 IP | 124.221.18.54 |
| SSH 用户 | ubuntu |
| SSH 密钥 | `C:\Users\Administrator\.ssh\hermes_temp.pem` |
| SSH 别名 | `hermes-server`（~/.ssh/config 配置） |
| 操作系统 | Ubuntu 24.04 |
| 认证方式 | 仅密钥登录，密码已禁用 |

**连接方式**：
```bash
ssh hermes-server
# 或完整写法
ssh -i "C:\Users\Administrator\.ssh\hermes_temp.pem" ubuntu@124.221.18.54
```

---

## 二、完整项目架构

```
用户浏览器
    ↓ HTTPS
cloudflared Quick Tunnel
    ↓ HTTP
simple_proxy2.py (端口 9222)  ← 聊天界面 + API 代理
    ↓ HTTP（同一机器内部）
Hermes Docker 容器 (端口 8642)  ← nousresearch/hermes-agent
    ↓ HTTPS
OpenRouter API  ← 调用 AI 模型
    ↓（可选）
mihomo 代理 (127.0.0.1:7890/7891)
```

---

## 三、已部署服务清单

| 服务 | 端口/地址 | 状态 | 说明 |
|------|----------|------|------|
| Hermes Docker | 0.0.0.0:8642 | ✅ 运行中 | nousresearch/hermes-agent，API 服务 |
| simple_proxy2.py | 0.0.0.0:9222 | ✅ 运行中 | 聊天界面 + API 代理，位于 /tmp/simple_proxy2.py |
| cloudflared | systemd | ✅ 运行中 | Quick Tunnel，暴露 9222 端口 |
| mihomo | 127.0.0.1:7890/7891 | ✅ 运行中 | Clash Meta 透明代理 |
| Hermes Web UI | 127.0.0.1:9119 | ✅ 运行中 | 本地安装版 v0.10.0（次要） |

---

## 四、API 认证体系

| Key | 用途 | 格式 |
|-----|------|------|
| `hermes-api-key-2026` | 访问本地 Hermes API（对外统一用这个） | `Authorization: Bearer hermes-api-key-2026` |
| `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` | 转发到 OpenRouter 调用 AI | 环境变量 `OPENROUTER_API_KEY` |

**注意**：用户请求统一用 Hermes API Key 认证，不暴露 OpenRouter Key。

---

## 五、两个访问入口

### 入口 1 — 轻量聊天界面（推荐日常使用）
- 地址：`https://barn-rivers-compare-works.trycloudflare.com`
- 特点：简单直接，快速对话，支持 Markdown，Shift+Enter 换行

### 入口 2 — 官方管理面板（功能完整）
- 地址：`https://society-wishing-differently-titans.trycloudflare.com`
- 包含页面：Status、Config、Env、Logs、Sessions、Analytics、Cron、Skills
- 启动方式：`cd /home/ubuntu/hermes-local/web && npm run dev`

⚠️ 两个地址都是临时的，服务器重启后需重新获取（见运维脚本 get_url.sh）。

---

### 5.1 轻量聊天界面

**当前访问地址**（重启后会变）：
```
https://barn-rivers-compare-works.trycloudflare.com
```

**使用方法**：
1. 浏览器打开上述地址
2. 右上角显示"已连接"（绿色）= 正常
3. 底部输入框输入消息，**按 Enter 发送**，Shift+Enter 换行
4. AI 回复支持 Markdown 渲染（加粗、代码块、列表等）

---

## 六、运维脚本清单

脚本存放在 `C:\Users\Administrator\.workbuddy\skills\hermes-deploy\scripts\`。

**上传并执行流程**（Windows PowerShell 注意 `$()` 会本地展开）：
```powershell
# 上传脚本到服务器
scp -i 'C:\Users\Administrator\.ssh\hermes_temp.pem' -o StrictHostKeyChecking=no `
    scripts/check_status.sh hermes-server:/tmp/

# 在服务器执行
ssh hermes-server "bash /tmp/check_status.sh"
```

### 6.1 check_status.sh — 一键状态检查
检查所有服务（Docker、cloudflared、mihomo、端口监听、隧道 URL）。

### 6.2 restart_all.sh — 重启所有服务
按正确顺序重启：先停 cloudflared → 启动新 cloudflared → 重启 Hermes 容器。

### 6.3 get_url.sh — 获取当前 Tunnel URL
从 journalctl 提取 cloudflared 生成的 trycloudflare.com 地址。

### 6.4 test_api.sh — API 功能测试
测试健康检查、模型列表、聊天功能三重验证。

### 6.5 官方管理面板（v0.10.0）
源码路径：`/home/ubuntu/hermes-local/web/`（Vite + React + Tailwind v4）

**技术栈**：React 19 + Vite 7 + Tailwind CSS v4 + Lucide 图标 + React Router v7

**包含页面**：Status（状态）、Config（配置）、Env（环境变量）、Logs（日志）、
Sessions（会话历史）、Analytics（使用分析）、Cron（定时任务）、Skills（技能管理）

**启动**：
```bash
cd /home/ubuntu/hermes-local/web && npm run dev
# 监听 0.0.0.0:5173，/api 代理到 http://127.0.0.1:9119
```

**隧道**：
```bash
cloudflared tunnel --url http://localhost:5173
```

---

## 七、常见问题处理

### Q1: 聊天页面打不开
**原因**：cloudflared URL 变化（服务器重启后常见）
**解决**：
```bash
ssh hermes-server "journalctl -u cloudflared --no-pager -n 10 | grep trycloudflare"
```

### Q2: 页面显示"检查中..."一直不动
**原因**：代理的状态检测原来依赖 AI 响应，AI 响应慢导致页面卡住
**现状**：已修复为 `/ping` 接口秒回。如果仍卡住，检查 simple_proxy2.py 是否在运行：
```bash
ssh hermes-server "ps aux | grep simple_proxy2 | grep -v grep"
```

### Q3: 状态显示"已连接"但发消息无回复
**排查步骤**：
```bash
# 1. 检查 Docker 是否正常运行
ssh hermes-server "sudo docker ps | grep hermes"

# 2. 直接测试 Hermes API
ssh hermes-server "curl -s -X POST http://localhost:8642/v1/chat/completions \\
  -H 'Content-Type: application/json' \\
  -H 'Authorization: Bearer hermes-api-key-2026' \\
  -d '{\"model\":\"google/gemma-4-26b-a4b-it:free\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}'"
```

### Q4: API 返回 401 Unauthorized
**检查**：确认使用的是 Hermes API Key（`hermes-api-key-2026`），不是 OpenRouter Key

### Q5: 模型返回 429 Too Many Requests
**原因**：免费模型有频率限制
**解决**：等待 1 分钟再试，或考虑升级到付费模型

### Q6: 服务全部不响应
**执行重启脚本**：
```bash
# 上传并执行
scp scripts/restart_all.sh hermes-server:/tmp/
ssh hermes-server "bash /tmp/restart_all.sh"
```

### Q7: 消息气泡显示异常（没有左右对齐）
**原因**：旧版 simple_proxy.py 的 CSS 语法错误（`self:flex-end` 拼写错误）
**解决**：已升级到 simple_proxy2.py，正常运行。如果界面异常，清缓存刷新。

---

## 八、完整部署流程（从零重建参考）

### 阶段 1：环境准备
```bash
# 安装 Docker
sudo apt update && sudo apt install docker.io

# 安装 cloudflared
sudo wget -qO /usr/local/bin/cloudflared \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
sudo chmod +x /usr/local/bin/cloudflared
```

### 阶段 2：启动 Hermes 容器
```bash
sudo docker run -d \
  --name hermes \
  -p 8642:8000 \
  -e OPENROUTER_API_KEY=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 \
  -e API_SERVER_KEY=hermes-api-key-2026 \
  -e HOST=0.0.0.0 \
  -v hermes-data:/opt/data \
  nousresearch/hermes-agent
```

### 阶段 3：部署聊天代理（simple_proxy2.py）
这是整个项目的核心——提供嵌入式聊天界面的 HTTP 服务。

上传文件：
```bash
scp simple_proxy2.py hermes-server:/tmp/
```

在服务器启动：
```bash
ssh hermes-server "cd /tmp && nohup python3 simple_proxy2.py > /tmp/proxy.log 2>&1 &"
```

验证：
```bash
ssh hermes-server "curl -s http://localhost:9222/ping"
# 应返回: {"ok":true}
```

### 阶段 4：配置 cloudflared systemd 服务
```ini
# /etc/systemd/system/cloudflared-chat.service
[Unit]
Description=Cloudflare Tunnel for Hermes Chat
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:9222
Restart=on-failure
StandardOutput=append:/var/log/cloudflared-chat.log
StandardError=append:/var/log/cloudflared-chat.log

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable cloudflared-chat
sudo systemctl start cloudflared-chat
# 获取 URL
journalctl -u cloudflared-chat --no-pager -n 10 | grep trycloudflare
```

---

## 九、聊天界面技术细节

simple_proxy2.py 的 HTML 界面实现要点：

1. **状态检测**：页面加载时用 `fetch('/ping')` 替代调用 AI API，实现毫秒级状态确认
2. **消息气泡**：用 `.row{justify-content:flex-end}`（用户）和 `.row{justify-content:flex-start}`（AI）实现左右对齐
3. **Markdown 渲染**：用正则实现加粗、斜体、代码块、列表、标题、分割线的 HTML 转换
4. **输入框**：textarea + `Shift+Enter` 换行 + 自动高度撑高
5. **正在输入**：三个圆点 CSS 动画，等待 AI 响应时显示

**聊天界面 HTML 路径**：直接在 simple_proxy2.py 中内嵌 CHAT_HTML 变量

---

## 十、踩坑经验（血的教训）

**服务器运维类**
- SSH 命令转义：PowerShell 中 `$(...)` 先在本地展开再发 SSH，复杂命令必须上传 .sh 脚本执行
- cloudflared URL 临时性：每次重启 cloudflared 会生成新 URL，必须重新获取
- 获取 cloudflared URL 优先级：`journalctl -u cloudflared` > `/var/log/cloudflared.log`
- SSH 并行执行：用 `&` 后台任务时确保 `sleep` 等待，否则命令还没生效就断了

**Hermes Agent 类**
- API 认证：Hermes 内部 API Key 是 `hermes-api-key-2026`，不是 OpenRouter Key
- OpenRouter Key 仅用于容器内部转发 AI 请求
- Web UI 命令是 `hermes dashboard`，不是 `hermes web`
- Dashboard 安全限制：默认拒绝绑定 0.0.0.0，必须 localhost + cloudflared 暴露

**聊天界面类**
- 状态检测不能用 AI API：AI 响应慢（5~15秒），页面会长时间显示"检查中"，用户以为坏了
- CSS 语法：`.user{self:flex-end}` 中 `self` 是无效属性名，应为 `.user{justify-content:flex-end}`（父级 flex）
- Markdown 解析：用户输入用 `textContent` 防 XSS，AI 回复用正则转 HTML 后用 `innerHTML`
- 列表渲染正则：`<li>` 标签可能跨行，需要 `/s` 修饰符

**腾讯云特殊问题**
- 透明代理层：腾讯云轻量服务器有透明代理，直接暴露 80/443 端口会被拦截返回 502
- nginx 反向代理方案无效：nginx 配置正确但仍被代理层拦截
- 唯一有效方案：cloudflared quick tunnel，通过 Cloudflare 边缘节点中转彻底绕过

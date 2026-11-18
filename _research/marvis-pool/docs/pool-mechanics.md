# Marvis 令牌池机制详解

## 1. 池的本质

Marvis 的"池"是一个**服务端记账、客户端查询**的令牌钱包：

- 服务端维护每个账号的额度状态（总量 / 已用 / 冻结 / 可用）
- 客户端（插件）通过 `POST /v3/marvis_get_wallet` 查询
- 客户端负责把钱包状态翻译成 magpie 能理解的"额度窗口"
- 每天北京时间 0 点由服务端重置

## 2. 数据流

```
用户请求
  → magpie 网关
  → marvis 插件（带 uskey 身份）
  → Marvis 模型服务（实际消耗 token）
  → 服务端记账（计价折算）
  → /v3/marvis_get_wallet 反映最新余额
  → 插件 usage 钩子 → magpie 卡片 + 路由排序
```

## 3. 计价折算（核心公式）

```
billable = cache_read_tokens × 0
         + input_tokens × 0.5
         + output_tokens × 2
```

**推导**：README 给出示例表，合计 10,000 用量 token → 2,000 计价 token，即 5:1。

**含义**：日常对话中缓存命中率越高，实际可消耗的 token 越多；输出最"贵"。

## 4. 重置时间的时区处理

服务端不返回重置时间，客户端用"北京时间映射到 UTC 字段"的技巧避免依赖本地时区：

```js
const CN_OFFSET_MS = 8 * 3600_000
const cn = new Date(now.getTime() + CN_OFFSET_MS)
const todayMidnightCn = Date.UTC(
  cn.getUTCFullYear(), cn.getUTCMonth(), cn.getUTCDate()
) - CN_OFFSET_MS
const next = now < todayMidnightCn ? todayMidnightCn : todayMidnightCn + 86_400_000
return new Date(next).toISOString()
```

## 5. 路由语义（关键坑）

magpie 的智能路由**只读窗口的 `used` 字段**：

- 有 `used` → 计入占比，参与排序
- 没有 `used`（text-only / aside）→ 不计入，账号在路由里"等于不存在"
- 钱包型（只有 `balance`）→ 例外，宿主按余额读，仍可路由

因此插件的 `quota.mjs` 构造器强制要求：`amount + limit` 必须同时补出 `used`，否则抛 `QuotaShapeError`。

## 6. uskey 的两用限制

- 一个 uskey 只能用**两次**，第三次必返 403
- 插件策略：`getUskey()` 随机取、用完即弃、不缓存
- 扫码登录类型：`loginType=1`（QQ）等；支持导入已登录客户端账号

## 7. 风控边界

| 错误 | 含义 | 应对 |
|---|---|---|
| `403` | uskey 无效 / 身份冒充被拦截 | 换 uskey；持续则停、降并发、换出口 |
| `4100404` | 请求被风控拦截 | 偶发重试；持续则换出口（换账号无效） |
| `503 + risk_blocked` | 插件对风控的封装（可重试语义） | 宿主重试逻辑不变 |

> 2026-11-17 起，官方不再适配"已知客户端身份冒充"，风控成为常态。

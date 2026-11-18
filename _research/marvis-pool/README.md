# 腾讯 Marvis「令牌池」技术研究

> 一份关于 **腾讯 Marvis 桌面端每日重置令牌池** 的公开技术拆解：它是什么、怎么发放、社区插件如何把它接进通用模型网关、以及"池"的调度与风控边界。
>
> 本次研究基于公开 GitHub 仓库与源码静态分析，属于**第三方独立研究**，与腾讯官方无关。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
![Status](https://img.shields.io/badge/status-research%20only-blue)

---

## 0. 一句话结论

**Marvis 的"池"是一个"每日重置的计价令牌钱包"**：每个账号每天有 **1000 万计价 token** 的额度池，按北京时间每天 0 点重置；社区通过扫码登录拿到账号身份（uskey），把模型能力代理转发到 magpie / DSH 等网关，并按"缓存命中不计费、输入输出按不同权重折算"的方式计量消耗。

---

## 1. 关键事实速览

| 项目 | 结论 | 来源 |
|---|---|---|
| 池的规模 | 每账号每天 **10,000,000 计价 token** | magpie-marvis README |
| 重置时间 | **北京时间每天 0 点**（issue #12 确认） | `src/hooks/usage.mjs::nextResetAt` |
| 重置机制 | 由服务端完成，客户端按固定规则推算时间 | 同上 |
| 计量方式 | 缓存命中 `cache_read`=0；输入×0.5、输出×2 折算 | README「计价」表 |
| 折算关系 | 每 5 个用量 token ≈ 1 个计价 token（≈5000 万实际用量） | README「计价」注释 |
| 冻结额度 | `frozen_tokens` 单独字段，不计入路由，只展示 | `src/hooks/usage.mjs` |
| 余额接口 | `POST /v3/marvis_get_wallet` | README / usage.mjs |
| 身份凭证 | 扫码登录后得到 `uskey`，缓存复用；一次 uskey 只能用两次 | README「一个 uskey 只能用两次」 |
| 接入宿主 | magpie 供应商插件（provider plugin）、DeepSeek Harness（DSH） | magpie-marvis |

---

## 2. "池"的结构

### 2.1 令牌钱包模型

服务端的钱包查询接口 `POST /v3/marvis_get_wallet` 返回：

```jsonc
{
  "total_tokens": 10000000,   // 总量（计价 token，每天重置）
  "used_tokens":  6432691,    // 已用（计价 token）
  "frozen_tokens": 0,         // 冻结中
  "avail_tokens":  3567309,   // 可用 = total - used（近似）
  "total_cost":    0,         // 成本
  "status":        "ok"
}
```

> 注意：这是**计价 token**，不是模型实际收的 token。两者按 §2.2 的权重折算。

### 2.2 计价折算规则（来自 README）

```
计价 token = cache_read × 0
           + 输入 × 0.5
           + 输出 × 2
```

| 场景 | 用量 token | 计价 token |
|---|---:|---:|
| 缓存命中 | 6,000 | 0 |
| 输入 | 2,000 | 1,000 |
| 输出 | 2,000 | 1,000 |
| **合计** | **10,000** | **2,000** |

即 **用量 : 计价 = 5 : 1**。因此"每天 1000 万计价 token"约等于 **5000 万实际用量 token**。

### 2.3 每日重置的推算逻辑

服务端**不返回**下次重置时间，客户端按规则推算（不依赖机器时区）：

```js
// 把北京时间映射到 UTC 字段上计算
const CN_OFFSET_MS = 8 * 3600_000
const cn = new Date(now.getTime() + CN_OFFSET_MS)
const todayMidnightCn = Date.UTC(cn.getUTCFullYear(), cn.getUTCMonth(), cn.getUTCDate()) - CN_OFFSET_MS
const next = now.getTime() < todayMidnightCn
  ? todayMidnightCn
  : todayMidnightCn + 86_400_000
```

> 这个 `resetsAt` **只影响卡片显示**，不参与路由排序——路由只认 `used` 占比。

---

## 3. 社区如何把"池"接进网关

### 3.1 链路总览

```
Claude Code / Codex / Gemini CLI / DSH
        │  (OpenAI / Anthropic / Gemini 协议)
        ▼
   magpie 网关 127.0.0.1:3425
        │  provider plugin
        ▼
  magpie-marvis 插件（社区，非官方）
        │  扫码登录 → uskey（缓存复用）
        ▼
  腾讯 Marvis 桌面端账号的模型能力
        │
        ▼
  每日 1000 万计价 token 池（服务端结算）
```

### 3.2 插件侧与"池"相关的核心文件

| 文件 | 作用 |
|---|---|
| `src/hooks/usage.mjs` | 调用钱包接口，构造 magpie 额度窗口；推算重置时间 |
| `src/quota.mjs` | 额度窗口构造器，拦截"静默失败"的错误写法 |
| `src/marvis/expiry.mjs` | uskey 过期判断 |
| `src/refresh-lock.mjs` | 刷新锁，避免并发刷新 |
| `src/marvis/profile.mjs` | 账号画像（openid / guid / loginType） |
| `src/marvis/protocol.mjs` | 业务请求头构造 |
| `src/hooks/refresh.mjs` | 登录态刷新钩子 |

### 3.3 额度窗口的四种形态（quota.mjs）

magpie 的路由**只认 `used`**（有 `used` 的窗口才计入占比与排序）：

| 形态 | 字段 | 路由是否计入 |
|---|---|---|
| 占比型 | `used`（0–100） | ✅ |
| 数量型 | `amount` + `limit`（自动算 `used`） | ✅ |
| 钱包型 | `balance` + `unit` | ✅（按余额读） |
| 文本型 | `textOnly: true` + `display` | ❌ 只上卡片 |
| aside | `aside: true` | ❌ 用光也不停账号 |

Marvis 的主窗口用**数量型**（`amount=used_tokens, limit=total_tokens`），确保跨 magpie 版本行为一致。

---

## 4. 风控与边界（重要）

这个"池"不是无代价的，社区实测暴露了明确边界：

1. **非官方**：插件与腾讯无关，本质是账号身份的代理转发。
2. **风控常态化**：2026-11-17 起官方"已知客户端身份冒充"不再适配；`403` / `4100404 请求被风控拦截` 成为常态。
   - 偶发一次 = 一次性 uskey 用完，重试即可；
   - 持续每次 = 设备/出口被风控，停几分钟、不并发、换出口（**换账号没用**）。
3. **一个 uskey 只能用两次**：第 3 次必返 403；插件按"用后即弃"策略自动取新 uskey。
4. **扫码登录**：支持 QQ / 微信扫码，或导入已登录 Marvis 客户端的账号（`--marvis_auth?login_type=1&bc=1&state=...` 回调）。
5. **项目状态**：`MYCF711/magpie-marvis` 已**暂停维护**，只修明显故障与安全/合规问题，保留公开与安装。

> 本项目仅做**技术研究与机制说明**，不提供任何绕过风控、批量注册或规避限制的代码。

---

## 5. 和 magpie / XD Pool 的关系

| | magpie | Marvis 池 | XD Pool（WorkBuddy） |
|---|---|---|---|
| 定位 | 通用模型网关 | 每日重置令牌池（资源） | DSH 插件生态的积分调度层 |
| 服务对象 | 所有编程 Agent | Marvis 账号 | DSH 用户 |
| 计量单位 | 各provider自定义 | 计价 token（每账号 1000 万/日） | 积分（3/7/30 天过期） |
| 核心策略 | 意图路由 + 故障转移 | 服务端按日重置 | 最近过期优先 |

三者可以叠加理解：**magpie 是管道，Marvis 池是管道里流的资源之一，XD Pool 是另一套独立的资源管理策略**。

---

## 6. 复现与实验

```bash
# 查看 Magpie 生态中 Marvis 插件的额度钩子实现
# 仓库：MYCF711/magpie-marvis
# 文件：src/hooks/usage.mjs, src/quota.mjs

# 安装（研究用途，注意风控风险）
magpie plugin add MYCF711/magpie-marvis

# 查询钱包余额（需要已登录账号的 uskey）
# POST /v3/marvis_get_wallet
```

示例代码见 [`examples/`](./examples/)，详细拆解见 [`docs/`](./docs/)。

---

## 7. 参考与来源

- `MYCF711/magpie-marvis` — 社区 Marvis 供应商插件（README / src / HOOKS.md / GUIDE.md）
- `yetone/magpie` — 通用模型网关（usemagpie.ai）
- `Xun-Prog/dsh-xdpool-billing` — XD Pool 积分面板（对照参考）
- 官方 magpie issue #468（额度窗口路由语义）、#12（重置时间）、#68（风控文案）

---

## 8. 法律与伦理声明

- 本研究基于**公开信息**，仅用于技术学习与机制探讨。
- "Marvis"为腾讯产品；本项目**不属于腾讯**，不与其关联或背书。
- 请勿用于规避服务条款、批量套利或任何违反平台规则的行为。
- 开源协议：MIT。

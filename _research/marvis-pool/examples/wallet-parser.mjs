/**
 * 示例：Marvis 令牌池钱包解析与计价折算
 *
 * 纯教学代码，不依赖任何真实账号或凭证。
 * 数据来源格式参考 magpie-marvis 的 /v3/marvis_get_wallet 响应。
 */

// POST /v3/marvis_get_wallet 的响应体示意（脱敏示例数据）
const SAMPLE_WALLET = {
  total_tokens: 10_000_000, // 每日计价 token 总量
  used_tokens: 6_432_691,
  frozen_tokens: 0,
  avail_tokens: 3_567_309,
  total_cost: 0,
  status: 'ok',
}

/** 用量 token → 计价 token 的权重（来自 README） */
const WEIGHTS = {
  cache_read: 0,
  input: 0.5,
  output: 2,
}

/** 计算计价 token */
export function billableTokens({ cache_read = 0, input = 0, output = 0 }) {
  return (
    cache_read * WEIGHTS.cache_read +
    input * WEIGHTS.input +
    output * WEIGHTS.output
  )
}

/** 下一个北京时间 0 点（UTC 毫秒），不依赖机器时区 */
export function nextResetAt(now = new Date()) {
  const CN_OFFSET_MS = 8 * 3600_000
  const cn = new Date(now.getTime() + CN_OFFSET_MS)
  const todayMidnightCn =
    Date.UTC(cn.getUTCFullYear(), cn.getUTCMonth(), cn.getUTCDate()) - CN_OFFSET_MS
  const next =
    now.getTime() < todayMidnightCn ? todayMidnightCn : todayMidnightCn + 86_400_000
  return new Date(next).toISOString()
}

/** 把钱包解析成 magpie 风格的数量型额度窗口 */
export function toUsageWindow(wallet) {
  const total = Number(wallet.total_tokens ?? 0)
  const used = Number(wallet.used_tokens ?? 0)
  const avail = Number(wallet.avail_tokens ?? Math.max(0, total - used))
  const usedPct = total > 0 ? Math.round((used / total) * 10_000) / 100 : 0

  return {
    plan: 'Marvis 令牌',
    windows: [
      {
        name: '令牌用量',
        amount: used,
        limit: total,
        unit: 'tokens',
        used: usedPct,
        resetsAt: nextResetAt(),
        display: `${avail.toLocaleString('en-US')} 可用 / 共 ${total.toLocaleString('en-US')}`,
      },
    ],
  }
}

// 演示（跨平台上匹配主模块：把 import.meta.url 与 argv[1] 都规整成 file URL）
import { pathToFileURL } from 'node:url'
const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
if (isMain) {
  console.log('计价折算示例：', billableTokens({ cache_read: 6000, input: 2000, output: 2000 }), '计价 token')
  console.log('下次重置：', nextResetAt())
  console.log(JSON.stringify(toUsageWindow(SAMPLE_WALLET), null, 2))
}

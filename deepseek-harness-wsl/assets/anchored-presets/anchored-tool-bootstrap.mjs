/**
 * Experimental first-request anchor for DeepSeek Harness.
 *
 * Derived from xiaobright/dsh-anchored-standard at commit
 * 6472c1c9431dcfd9072be23bff781b76fe7146c0 (MIT). See NOTICE.
 */
export const name = 'dsh-wsl-anchored-tool-bootstrap'
export const inject = []

const PROMOTE_EVENTS = {
  'tool-call': ['tool/call'],
  'assistant-message': ['assistant/message'],
  either: ['tool/call', 'assistant/message'],
}

function nonEmptyStrings(value, field) {
  if (!Array.isArray(value) || value.length === 0
      || value.some((item) => typeof item !== 'string' || item.length === 0)) {
    throw new TypeError(`${name}: ${field} must be a non-empty string array`)
  }
  return [...new Set(value)]
}

function suppressedSources(value) {
  const selected = value === undefined ? ['skill-catalog', 'agent-instructions'] : value
  if (!Array.isArray(selected)
      || selected.some((item) => typeof item !== 'string' || item.length === 0)) {
    throw new TypeError(`${name}: suppressedContextSources must be a string array`)
  }
  return new Set(selected)
}

export function apply(ctx, config = {}) {
  const commonTools = nonEmptyStrings(config.commonTools ?? ['read'], 'commonTools')
  const shellTools = nonEmptyStrings(config.shellTools ?? ['bash', 'pwsh'], 'shellTools')
  const promoteOn = config.promoteOn ?? 'either'
  const promoteEvents = PROMOTE_EVENTS[promoteOn]
  if (!promoteEvents) throw new TypeError(`${name}: invalid promoteOn value ${JSON.stringify(promoteOn)}`)
  const bootstrapMaxTokens = config.bootstrapMaxTokens ?? 1024
  if (!Number.isSafeInteger(bootstrapMaxTokens) || bootstrapMaxTokens <= 0) {
    throw new TypeError(`${name}: bootstrapMaxTokens must be a positive safe integer`)
  }
  const hiddenSources = suppressedSources(config.suppressedContextSources)
  const promoted = new Set()
  let warned = false

  const warnOnce = (message) => {
    if (warned) return
    warned = true
    try { ctx.logger.warn(message) } catch { /* diagnostic only */ }
  }

  const isPromoted = (agent) => {
    const session = agent?.session
    if (!session) return true
    if (promoted.has(session.id)) return true
    const hit = session.events.some((event) => promoteEvents.includes(event.type))
    if (hit) promoted.add(session.id)
    return hit
  }

  ctx.on('system-prompt/assemble', async (_assembly, context, next) => {
    const assembled = await next()
    try {
      if (isPromoted(context.agent)) return assembled
      const available = new Set(assembled.tools.map((tool) => tool.name))
      const shells = shellTools.filter((tool) => available.has(tool))
      const missing = commonTools.filter((tool) => !available.has(tool))
      if (shells.length !== 1 || missing.length) {
        warnOnce(`${name}: bootstrap tools drifted; exposing the full catalog`)
        return assembled
      }
      const allowed = new Set([...shells, ...commonTools])
      return { ...assembled, tools: assembled.tools.filter((tool) => allowed.has(tool.name)) }
    } catch (error) {
      warnOnce(`${name}: bootstrap failed; exposing the full catalog: ${String(error?.message ?? error)}`)
      return assembled
    }
  })

  ctx.on('agent/request', async (payload, next) => {
    const resolved = await next()
    if (isPromoted(payload.agent)) {
      if (resolved.maxTokens !== bootstrapMaxTokens) return resolved
      const { maxTokens: _removed, ...rest } = resolved
      return rest
    }
    return { ...resolved, maxTokens: bootstrapMaxTokens }
  })

  ctx.on('agent/pre-step', async ({ agent }, next) => {
    const decision = await next()
    if (decision.kind === 'reject' || isPromoted(agent) || hiddenSources.size === 0) return decision
    try {
      if (!Array.isArray(decision.messages)) return decision
      const messages = decision.messages.filter((message) => !hiddenSources.has(message?.source?.kind))
      return messages.length === decision.messages.length ? decision : { ...decision, messages }
    } catch (error) {
      warnOnce(`${name}: context filter failed; keeping context: ${String(error?.message ?? error)}`)
      return decision
    }
  }, { prepend: true })
}

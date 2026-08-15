import assert from 'node:assert/strict'
import { test } from 'node:test'
import { apply } from '../deepseek-harness-wsl/assets/anchored-presets/anchored-tool-bootstrap.mjs'

test('first request is anchored and the next durable turn restores the full catalog', async () => {
  const handlers = new Map()
  const ctx = {
    logger: { warn: () => {} },
    on(event, handler) { handlers.set(event, handler) },
  }
  apply(ctx, {})
  const session = { id: 's1', events: [] }
  const agent = { session }
  const tools = [{ name: 'bash' }, { name: 'read' }, { name: 'web_search' }]

  const firstCatalog = await handlers.get('system-prompt/assemble')({}, { agent }, async () => ({ tools }))
  assert.deepEqual(firstCatalog.tools.map((tool) => tool.name), ['bash', 'read'])
  const firstRequest = await handlers.get('agent/request')({ agent }, async () => ({ temperature: 0 }))
  assert.equal(firstRequest.maxTokens, 1024)
  const firstContext = await handlers.get('agent/pre-step')({ agent }, async () => ({
    kind: 'continue',
    messages: [
      { source: { kind: 'skill-catalog' }, text: 'automatic' },
      { source: { kind: 'user' }, text: 'task' },
    ],
  }))
  assert.deepEqual(firstContext.messages.map((message) => message.text), ['task'])

  session.events.push({ type: 'assistant/message' })
  const fullCatalog = await handlers.get('system-prompt/assemble')({}, { agent }, async () => ({ tools }))
  assert.deepEqual(fullCatalog.tools, tools)
  const secondRequest = await handlers.get('agent/request')({ agent }, async () => ({ maxTokens: 1024, temperature: 0 }))
  assert.equal('maxTokens' in secondRequest, false)
})

test('tool drift degrades to the full catalog', async () => {
  const handlers = new Map()
  const warnings = []
  apply({ logger: { warn: (message) => warnings.push(message) }, on: (event, handler) => handlers.set(event, handler) }, {})
  const tools = [{ name: 'bash' }, { name: 'web_search' }]
  const result = await handlers.get('system-prompt/assemble')({}, { agent: { session: { id: 's2', events: [] } } }, async () => ({ tools }))
  assert.deepEqual(result.tools, tools)
  assert.equal(warnings.length, 1)
})

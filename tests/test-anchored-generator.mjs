import assert from 'node:assert/strict'
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'
import { test } from 'node:test'

const generator = resolve('deepseek-harness-wsl/scripts/generate-anchored-preset.mjs')
const plugin = resolve('deepseek-harness-wsl/assets/anchored-presets/anchored-tool-bootstrap.mjs')
const ordinary = `- id: persona\n  name: '@deepseek-ai/dsh-persona'\n  config:\n    text: >-\n      You are a coding agent powered by the {{model}} model. Your working directory is {{cwd}}.\n\n- id: agent-instructions\n  name: '@deepseek-ai/dsh-agent-instructions'\n\n- id: bash\n  name: '@deepseek-ai/dsh-tool-bash'\n- id: pwsh\n  name: '@deepseek-ai/dsh-tool-pwsh'\n- id: fs\n  name: '@deepseek-ai/dsh-tool-fs'\n`

test('generator copies an official preset and records a managed manifest', async () => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-anchor-'))
  try {
    const source = join(root, 'standard')
    const target = join(root, 'anchored-standard')
    await mkdir(source)
    await writeFile(join(source, 'agent.cordis.yml'), ordinary)
    await writeFile(join(source, 'preset.yml'), 'name: Standard\n')
    const result = spawnSync(process.execPath, [generator, source, target, plugin, 'standard', '0.1.0-test'], { encoding: 'utf8' })
    assert.equal(result.status, 0, result.stderr)
    const generated = await readFile(join(target, 'agent.cordis.yml'), 'utf8')
    assert.match(generated, /^# Experimental first-request anchor/)
    assert.match(generated, /complete: true/)
    const manifest = JSON.parse(await readFile(join(target, '.deepseek-harness-wsl-anchor.json'), 'utf8'))
    assert.equal(manifest.owner, 'deepseek-harness-wsl-skill')
    assert.equal(manifest.harnessVersion, '0.1.0-test')
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

test('generator refuses an unknown persona shape', async () => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-anchor-drift-'))
  try {
    const source = join(root, 'standard')
    await mkdir(source)
    await writeFile(join(source, 'agent.cordis.yml'), ordinary.replace('You are a coding agent', 'Changed upstream persona'))
    await writeFile(join(source, 'preset.yml'), 'name: Standard\n')
    const result = spawnSync(process.execPath, [generator, source, join(root, 'target'), plugin, 'standard', '0.1.0-test'], { encoding: 'utf8' })
    assert.notEqual(result.status, 0)
    assert.match(result.stderr, /refusing an unsafe rewrite/)
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})

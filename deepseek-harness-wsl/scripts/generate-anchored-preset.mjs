import { cp, readFile, writeFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { basename, dirname, isAbsolute, join, relative, resolve } from 'node:path'

const [sourceArg, targetArg, pluginArg, mode, harnessVersion] = process.argv.slice(2)
if (!sourceArg || !targetArg || !pluginArg || !['standard', 'code', 'cordis'].includes(mode)) {
  throw new Error('usage: generate-anchored-preset.mjs SOURCE TARGET PLUGIN standard|code|cordis VERSION')
}

const source = resolve(sourceArg)
const target = resolve(targetArg)
const plugin = resolve(pluginArg)
const sourceToTarget = relative(source, target)
if (sourceToTarget === '' || (!sourceToTarget.startsWith('..') && !isAbsolute(sourceToTarget))) {
  throw new Error('unsafe source/target relationship')
}

const configPath = join(source, 'agent.cordis.yml')
const sourceConfig = await readFile(configPath, 'utf8')
const personaStart = "- id: persona\n  name: '@deepseek-ai/dsh-persona'\n  config:\n"
const nextRow = '\n- id: agent-instructions\n'
const normalized = sourceConfig.replaceAll('\r\n', '\n')
const personaOffset = normalized.indexOf(personaStart)
const personaEnd = normalized.indexOf(nextRow, personaOffset)
if (personaOffset < 0 || personaEnd < 0 || normalized.indexOf(personaStart, personaOffset + 1) >= 0) {
  throw new Error(`official ${mode} persona shape changed; refusing an unsafe rewrite`)
}
const sourcePersona = normalized.slice(personaOffset, personaEnd)
const ordinaryPersona = `${personaStart}    text: >-\n      You are a coding agent powered by the {{model}} model. Your working directory is {{cwd}}.\n`
const cordisPersonaLooksOfficial = sourcePersona.includes('running on the DeepSeek Harness')
  && sourcePersona.includes('Load the `editing-cordis-compositions` skill')
if ((mode === 'cordis' && !cordisPersonaLooksOfficial)
    || (mode !== 'cordis' && sourcePersona !== ordinaryPersona)) {
  throw new Error(`official ${mode} persona text changed; refusing an unsafe rewrite`)
}
for (const required of ['@deepseek-ai/dsh-tool-bash', '@deepseek-ai/dsh-tool-pwsh', '@deepseek-ai/dsh-tool-fs']) {
  if (!sourceConfig.includes(required)) throw new Error(`official ${mode} preset no longer contains ${required}`)
}
if (sourceConfig.includes('anchored-tool-bootstrap.mjs')) throw new Error('source already contains an anchor')

await cp(source, target, { recursive: true, force: false, errorOnExist: true })
await cp(plugin, join(target, 'anchored-tool-bootstrap.mjs'), { force: false, errorOnExist: true })
await cp(join(dirname(plugin), 'NOTICE'), join(target, 'NOTICE'), { force: false, errorOnExist: true })

const bootstrap = `# Experimental first-request anchor. This row must remain first.\n- id: anchored-tool-bootstrap\n  name: ./anchored-tool-bootstrap.mjs\n  config:\n    shellTools: [bash, pwsh]\n    commonTools: [read]\n    promoteOn: either\n    bootstrapMaxTokens: 1024\n    suppressedContextSources: [agent-instructions, skill-catalog]\n\n`
const persona = `- id: persona\n  name: '@deepseek-ai/dsh-persona'\n  config:\n    text: You are a helpful software engineer assistant.\n    complete: true\n    includeRuntimeContext: false\n`
const generated = bootstrap + normalized.slice(0, personaOffset) + persona + normalized.slice(personaEnd)
await writeFile(join(target, 'agent.cordis.yml'), generated, 'utf8')

const labels = { standard: 'Standard', code: 'PTC / Code', cordis: 'Cordis / Creator' }
await writeFile(join(target, 'preset.yml'),
  `name: Anchored ${labels[mode]} (experimental)\n`
  + `description: Minimal-aligned first request, then the complete official ${labels[mode]} catalog. Community experiment; no performance guarantee.\n`
  + `order: 50\n`, 'utf8')

const sha256 = createHash('sha256').update(sourceConfig).digest('hex')
const manifest = {
  schema: 1,
  owner: 'deepseek-harness-wsl-skill',
  mode,
  sourcePreset: basename(source),
  harnessVersion: harnessVersion || 'unknown',
  sourceAgentCordisSha256: sha256,
  upstreamExperiment: 'xiaobright/dsh-anchored-standard@6472c1c9431dcfd9072be23bff781b76fe7146c0',
  generatedAt: new Date().toISOString(),
}
await writeFile(join(target, '.deepseek-harness-wsl-anchor.json'), `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 })

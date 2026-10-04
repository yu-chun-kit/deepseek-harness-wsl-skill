# Official release compatibility audit

Checked **2026-10-04** against official npm metadata and release-tagged DeepSeek sources. The installer resolves channels again on every install/update.

| Channel | Exact version | npm publication (UTC) | Treatment |
|---|---|---|---|
| `latest`, `next` | `0.2.0-rc.2` | 2026-09-29 | Repository baseline; requires `-AcceptPrerelease` |
| `alpha` | `0.2.1-alpha.1` | 2026-10-03 | Explicit trial; requires `-Channel alpha -AcceptPrerelease` |

Sources: [official registry](https://registry.npmjs.org/@deepseek-ai%2fdsh), [RC release](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.0-rc.2), [alpha release](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.1-alpha.1).

## Installer and runtime

The published CLI has no `engines` field. The source range remains `^22.19.0 || >=24.0.0`, so the Linux Node check remains unchanged. Source development pins pnpm 11.7.0; this is not a published CLI installation requirement. Profile plugin management separately uses pnpm. See [development prerequisites](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/docs/development.md) and [CLI package resolution](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/apps/cli/reference/README.md).

An exact npm install verifies the CLI version and executable, not the health of existing custom profiles, plugin dependencies, model selections or sessions. Keep package verification, profile migration, Web startup and model requests as separate checks. Replacing installed plugin versions requires a restart. The RC also updates the third-party catalog; some saved model IDs may need reselection. See [RC migration notes](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.0-rc.2). Do not rewrite user settings automatically.

## Presets and Minimal

Current Web presets live in `@deepseek-ai/dsh-web-app/presets/{standard,ptc,cordis,minimal}.patch.yml`. Each declares a `dsh-agent-preset` row with `config.id` and `config.plugins`. Web preset edits persist in `$DSH_HOME/profiles/web/cordis.patch.yml`. The CLI no longer ships `config/agent-presets`; copying `.agent-presets/anchored-*` is not current registration. See [Web composition](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/packages/bundle/web-app/README.md) and [preset API](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/packages/preset/agent-preset/README.md).

Minimal exposes one persistent shell: Bash on Linux/macOS or PowerShell on Windows. The editor and its filesystem provider were removed from shipped minimal compositions; fixed complete persona, suppressed runtime context and absence of compaction remain. See [Minimal patch](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/packages/bundle/web-app/presets/minimal.patch.yml) and [September simplification](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/.agents/notes/implemented/simplification/2026-09-03-minimal-profiles-persistent-shell-only.md).

The Anchored generator remains for compatible legacy layouts and removal of helper-owned copies. Current `status` explains the missing layout; `install`/`update` fail before replacing presets. A future port requires current schema/request-hook validation and controlled behavior comparisons. Historical scores do not establish current compatibility or performance.

## Web startup and alpha differences

The RC defaults to loopback port 3080, opens the local browser, and prints an authenticated startup URL. Its process token exchanges for a signed cookie; SSH or `--no-open` requires manually opening that URL. Treat it as sensitive runtime data. Select a workspace before starting a session. See [Web authentication](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/packages/bundle/web-app/README.md) and [workspace guide](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/docs/user/guide/index.md).

RC [startup.ts](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/packages/bundle/web-app/src/startup.ts) rejects `--host 0.0.0.0`. Some upstream LAN prose describes a lower-level composition capability; it does not prove this CLI flag works. `--trusted-host` changes accepted authorities, not the bind interface or authentication.

The [alpha release](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.1-alpha.1) adds `--public-url`, moves automation into Web, removes runtime invariant plugins/exports, and replaces input-area `stats` extension IDs with separate `activity`/`usage` entries. Extensions using those surfaces need review before an alpha trial. This repository does not apply those changes to installed profiles.

## Reproducible checks

`tests/fixtures/upstream-0.2.0-rc.2` freezes the published CLI manifest, Minimal patch, dated channels, source URLs and SHA-256 hashes. The CLI tarball was verified against official npm SHA-512 integrity before extracting the manifest. Tests use isolated temporary homes and mocks; they never install a live release or send model requests.

This refresh also verifies read-only status and metadata preview against Ubuntu WSL2 with Linux Node 24 and the already-installed RC. This is not a clean-install, custom-plugin boot or paid model acceptance test.

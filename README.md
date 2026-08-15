# DeepSeek Harness on WSL — Codex Skill and Installer

A community-maintained Codex skill and resumable PowerShell installer for running the **official [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)** inside WSL2 on Windows.

It installs the official npm package, `@deepseek-ai/dsh`, into Linux—not a fork, wrapper model, or similarly named third-party harness.

> [!IMPORTANT]
> This is an unofficial community project. DeepSeek Harness itself is currently a developer preview and may introduce breaking changes. This repository does not claim that DeepSeek-V4-Pro is proven to be overfit to Harness, or that Linux makes the model intrinsically smarter.

## 中文摘要

這個 repo 提供一個可交給 agent 使用的 Skill，以及一個從 Windows 執行的安裝器。它會偵測 WSL2、優先重用既有 Ubuntu、在 WSL 內準備 Linux Node.js、選擇安全可用的 npm 或 pnpm、核對套件是否指向 DeepSeek 官方 repo，然後安裝解析後的**精確版本**。如果電腦尚未安裝 WSL，它只會說明選項；不會因為執行 `status` 或普通安裝命令就擅自新增 WSL。

WSL2 的定位是「相容性優先」：讓 Windows 使用者更接近 DeepSeek 技術報告披露的 `bash + file-edit` code-agent 評測形態。這不是 DeepSeek 官方的 Windows/WSL 效能結論，也沒有公開的嚴格 A/B 測試證明模型在 Linux 上本質更強。

## Why WSL?

DeepSeek's V4 technical report describes code-agent evaluation with a minimal tool set consisting of Bash and a file-edit tool. The public Harness minimal preset similarly uses persistent Bash and `str_replace_editor`.

Native Windows remains supported by Harness. WSL2 is recommended here because it gives Windows users Linux paths, permissions, signals, shell behavior, and common SWE/terminal tooling. It is a reproducibility and compatibility choice—not a model inference optimization.

There is also an important timeline distinction: the public minimal preset landed after the V4 technical report. It is reasonable to say that the public preset aligns with the disclosed internal evaluation shape; it is not reasonable to claim that the model was trained against today's public preset.

## Beginner decision: native Windows or WSL2?

If WSL2 is already installed and used, reusing it is usually the lowest-friction path for this repository. If WSL2 is absent, choose deliberately:

| Path | Best fit | Tradeoff |
|---|---|---|
| Native Windows | A beginner who wants the official Harness UI with the smallest platform change | Uses Windows/PowerShell semantics rather than the Bash environment this repository targets |
| WSL2 | Someone who wants Linux/Bash tool compatibility and closer alignment with the disclosed Bash-based agent setup | Adds an Ubuntu environment, Linux account, virtual disk, resource usage, and possible reboot/support burden |

DeepSeek documents the published CLI as a Node.js package and the official codebase has native Windows support. This repository intentionally implements only the WSL path; it does not claim that WSL is required.

For the native Windows path, follow the official README: install a supported Windows Node.js, then run `npx @deepseek-ai/dsh web` in PowerShell. This Skill does not automate that separate path.

Microsoft currently documents WSL2's default VM **limit** as 50% of Windows RAM, all logical processors, and swap equal to 25% of Windows RAM rounded up to the nearest GB. These are limits, not memory preallocated at Windows startup: usage grows and shrinks with the workload. WSL starts when WSL or a dependent application invokes it, then manages the VM lifecycle automatically. Open handles, settings, and idle management affect observed state; a Linux background service alone does not guarantee that the VM stays running.

DeepSeek has not published a supported Harness RAM minimum, a per-session RAM figure, or a formula for several simultaneous conversations. Therefore this project does not label `memory=2GB` as recommended. A fixed 2 GiB cap may be enough for a light UI session on one machine and still fail when agent subprocesses compile native modules, run tests, or work in several active sessions; there is no official guarantee either way.

Official engineering notes illustrate why a chat-count formula would mislead: one measurement attributed about 1.31 MB to each live standard agent and 57.8 MB to 50 such agents, while a separate restore profile for a 1.3-million-event session reached about 1,060 MiB peak RSS after optimization. Those are implementation measurements, not requirements, and neither accounts for arbitrary shell tools, builds, tests, or language servers launched by an agent.

> [!CAUTION]
> `%USERPROFILE%\.wslconfig` applies globally to all WSL2 distributions, not only Harness. A low cap can also constrain Docker Desktop or unrelated Linux work. This project reports whether that file exists but never reads, creates, merges, or overwrites it. Microsoft now recommends changing WSL resource settings through WSL Settings; make such a global change only after observing the actual workload.

## Quick start

Clone or download this repository, open PowerShell in its root, then inspect the current state:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action status
```

Preview changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -WhatIf
```

Install or resume installation with one command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -Yes
```

If status reports that WSL is absent and you intentionally choose the WSL2 path, preview the platform addition first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -InstallWslIfMissing:$true -AcceptPrerelease -WhatIf
```

Then rerun that command from an elevated PowerShell with `-Yes` instead of `-WhatIf`. The explicit `-InstallWslIfMissing:$true` is required only when adding WSL/Ubuntu; it is not needed once a usable distribution exists.

The two platform paths use separate Node.js installations. A Windows Node.js installation serves native Windows Harness; it does not count as the Linux Node.js required inside WSL. If WSL is selected and Linux Node.js is absent, this installer previews and installs a compatible Linux Node.js under the Linux user's home rather than reusing `node.exe` through `/mnt/c`.

The current official source-development range is Node.js 22.19+ or 24+, while the published CLI package currently does not declare its own `engines` field. This installer therefore uses the current official source range as its conservative compatibility floor and installs the current LTS when it must add Node. It does not mistake the source-only pnpm requirement for an npm-package requirement.

The default `-PackageManager auto` preserves the manager recorded by an earlier managed install. On a fresh install it uses pnpm only when a Linux-native pnpm already has a writable user global directory; otherwise it falls back to npm. It never uses a Windows `pnpm` exposed through `/mnt/c` and does not bootstrap pnpm silently.

DeepSeek's official distinction matters here: the published CLI is documented with `npx @deepseek-ai/dsh web`; `pnpm install`, `pnpm run build`, and `pnpm dsh web` are the repository-checkout workflow. The CLI also forwards profile plugin management to pnpm. This project supports an existing pnpm without claiming it is mandatory for the published package.

When pnpm is selected, the installer still uses npm bundled with the required Linux Node.js installation for registry identity, repository, dist-tag, and integrity checks. pnpm controls the global package transaction; it does not replace those verification steps.

At the time this project was authored, npm's official `latest` tag still resolved to an RC build, which is why the example explicitly includes `-AcceptPrerelease`. Remove that switch when `latest` resolves to a stable release.

### Fresh Windows installation is resumable, not magically reboot-free

If WSL or Ubuntu is not installed, the default command stops after showing host RAM/CPU/system-drive free space and the native-Windows-versus-WSL choice. Only the explicit `-InstallWslIfMissing:$true` form starts the official Windows WSL installation flow. Windows may require an administrator terminal and a reboot. Ubuntu may then require one local first-run to create the Linux username and password.

The installer never self-elevates or reboots the computer. Complete the requested system step and rerun the same command; completed phases are reused.

If a pre-existing or imported distribution opens directly as `root` and never shows a first-run prompt, the installer stops before mutation. A user must be created explicitly. On current WSL releases, the safe recovery shape is:

```powershell
$distro = 'Ubuntu-24.04' # Replace with the exact reviewed distro name.
$linuxUser = 'alice'     # Replace with the user's chosen new Linux account.
wsl.exe -d $distro -u root -- adduser $linuxUser
wsl.exe -d $distro -u root -- usermod -aG sudo $linuxUser
wsl.exe --manage $distro --set-default-user $linuxUser
wsl.exe -d $distro -- id
```

Review both variables before running the commands. They are intentionally not run by the one-click installer: account naming, password entry, and changing a distro's effective user require explicit user participation. If `wsl --manage` is unavailable, use Microsoft or distribution-specific recovery guidance rather than replacing `/etc/wsl.conf`.

## Run Harness

From a WSL terminal, change to the project that Harness may access and start the Web UI:

```bash
cd ~/projects/your-project
dsh web
```

Open <http://127.0.0.1:3080>, select **Settings → Models**, and enter the DeepSeek API key there. The official UI treats keys as write-only and stores the credential under `$DSH_HOME/.credentials.yaml` while returning a redacted descriptor to the page.

For Linux-heavy agent work, keep active repositories under the distribution's Linux filesystem, such as `~/projects`, rather than `/mnt/c` or `/mnt/e`. Cross-filesystem work is supported, but Git/npm workloads and Linux permission semantics are usually better on the WSL ext4 filesystem.

## Use the Codex skill

Copy the `deepseek-harness-wsl` folder into your personal Codex skills directory without overwriting an existing copy you have not reviewed:

```powershell
$destination = Join-Path $env:USERPROFILE '.codex\skills\deepseek-harness-wsl'
if (Test-Path -LiteralPath $destination) { throw "Skill already exists: $destination" }
Copy-Item -LiteralPath .\deepseek-harness-wsl -Destination $destination -Recurse
```

Then ask Codex:

```text
Use $deepseek-harness-wsl to inspect my Windows/WSL setup and install the official DeepSeek Harness in WSL2.
```

Other useful prompts:

```text
Use $deepseek-harness-wsl to update Harness, showing the exact old and new versions first.
```

```text
Use $deepseek-harness-wsl to verify that Node, npm, and dsh are Linux binaries and that my install points to the official package.
```

## Minimal mode

Start `dsh web`, create a session, and select **极简模式 / Minimal** in the Web UI. It is an agent preset, not a separate `dsh minimal` CLI command.

The preset intentionally presents a very small model-facing surface. Better results in that surface may reflect distribution matching, tool protocol, reasoning-trace handling, context policy, or shell behavior. Calling it proven "overfitting" requires controlled cross-harness ablations that are not currently public.

## Safe updates and rollback

Update through the same entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action update -AcceptPrerelease -Yes
```

The helper does not blindly execute `npx @latest`. It:

1. queries the official npm registry;
2. resolves the selected channel to an exact version;
3. displays repository and integrity metadata;
4. verifies that the repository points to `deepseek-ai/deepseek-harness`;
5. installs the exact resolved version;
6. records the previous and installed versions without secrets.

Roll back to a known exact version:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -PackageVersion 0.1.0-rc.6 -AcceptPrerelease -Yes
```

## Parameters

| Parameter | Purpose |
|---|---|
| `-Action status` | Inspect without installing |
| `-Action install` | Install or resume |
| `-Action update` | Resolve and install the selected current channel |
| `-Action uninstall` | Remove only Harness through the selected manager; preserve data, Node, distro, and WSL |
| `-Distribution <name>` | Use one exact installed WSL distribution |
| `-Channel latest\|next` | Select an npm dist-tag before exact-version resolution |
| `-PackageManager auto\|npm\|pnpm` | Preserve the recorded manager; otherwise use existing usable Linux pnpm or fall back to npm |
| `-PackageVersion <semver>` | Install one exact version |
| `-FetchRetries 0..10` | Fetch retries for this run only; default 4 |
| `-FetchTimeoutSeconds 30..900` | Per-request network timeout for this run; default 300 seconds |
| `-NetworkConcurrency 1..50` | Registry connections for this run; default 15, lower for an unstable link |
| `-DownloadAttempts 1..3` | Attempts for the same verified exact version; default 2 |
| `-NativeBuildTools auto\|skip` | Preflight Ubuntu native build requirements, or explicitly skip them |
| `-AcceptPrerelease` | Explicitly allow RC/beta versions |
| `-Yes` | Accept the displayed package/prerequisite changes |
| `-WhatIf` | Preview mutations; metadata checks may still use the network |
| `-SkipNodeInstall` | Require a compatible existing Linux Node.js |
| `-InstallWslIfMissing:$true` | Explicitly opt in to adding WSL/Ubuntu when none is usable; default is false |

## Support and validation matrix

| Environment | Status |
|---|---|
| Windows 11 x64 + current WSL2 + Ubuntu 24.04 | PowerShell parsing, Bash parsing, status path, root boundary, and dry-run package verification tested |
| Existing Ubuntu WSL2 with Linux Node.js 24 | Status and exact-version npm metadata dry-run tested |
| System Node under `/usr` with an unwritable npm global prefix | User-owned prefix selection dry-run and isolated profile-persistence regression-tested |
| Non-login npm/pnpm status and managed paths | New/legacy state, pnpm restoration, external/special-character prefixes, and exact `dsh` path regression-tested |
| Native dependency and unstable downloads | Build-tools preflight plus bounded timeout/concurrency behavior covered by mock regression tests |
| Fresh WSL install across administrator/reboot/first-run boundaries | Designed as a resumable flow; not automatically reboot-tested |
| Harness RAM and concurrent-session sizing | No official minimum or formula published; no fixed `2GB` recommendation is made |
| Windows 10 2004+ / ARM64 / non-Ubuntu distributions | Expected to require environment-specific validation; not claimed as tested |

Static validation includes the Skill Creator validator. The scripts intentionally have no live Harness installation or paid API smoke test in their repository test path.

When compatible Linux Node/npm is absent, the first `-WhatIf` output is a phase-one preview. It lists prerequisite, pinned nvm, and profile changes but cannot resolve the exact npm target yet. Run the same preview again after Node is available to inspect registry, repository, integrity, and exact package-version metadata.

## What the installer changes

Depending on the starting state, it may:

- add Ubuntu 24.04 through the official `wsl --install` command;
- install missing Ubuntu `git`, `curl`, and CA certificates;
- install missing `build-essential` and Python 3 when a changed Harness version may need to compile `node-pty`;
- clone a pinned nvm Git tag, verify its expected commit, and install the current Node.js LTS for the Linux user;
- add one marked nvm loader block to `~/.profile`, after backing it up;
- when the effective npm global prefix is not user-writable, create `~/.local` and add one marked `NPM_CONFIG_PREFIX`/`PATH` block to `~/.profile`, after backing it up;
- install an exact `@deepseek-ai/dsh` version into that user's Linux npm prefix;
- or, when selected, use an already configured Linux pnpm whose global bin is writable inside that user's home;
- write a user-only version/package-manager/managed-path rollback record under `~/.local/state/deepseek-harness-wsl/`.

It does **not** change the default distro, convert WSL1, edit `.wslconfig`, alter VPN/DNS/firewall settings, expose the Web UI beyond localhost, store API keys, modify a project, delete Harness data, or unregister a distribution.

The Windows-side status output includes total/available RAM, logical CPU count, free space on the system drive, WSL distributions currently reported as running, and only the presence or absence of `.wslconfig`. It does not infer which application started a distribution, dump that global configuration, or choose a cap. The Linux model itself remains in DeepSeek's cloud API; local resource use comes from WSL, Harness, tools, builds, tests, and other subprocesses.

## Secrets and permissions

- Never paste a DeepSeek API key into an agent conversation or command-line argument.
- Never commit `.credentials.yaml`, `.env`, or shell history containing credentials.
- Harness sessions default to a workspace-write permission preset. Choose the workspace deliberately and review tool approvals.
- API authentication and paid model calls are separate from installation verification. This project does not send a paid smoke-test request automatically.

## Troubleshooting

### Windows feels slower or `vmmem` is large

First check which distributions are actually running and whether Harness, Docker, tests, or other Linux background services are still active. Closing the Web UI tab does not necessarily terminate its server or its child processes.

Do not immediately paste a generic `memory=2GB` block into `.wslconfig`. That cap is global, requires the WSL VM to restart before it applies, and has no DeepSeek-supported relationship to a number of conversations. Use Windows Task Manager, WSL Settings, and workload-specific process inspection to observe the peak first. `wsl --shutdown` terminates every running distribution, so this project never runs it automatically.

WSL2 distributions store Linux files in dynamically expanding virtual disks. Deleting Linux files reduces guest-filesystem usage but does not guarantee that the host VHD file immediately shrinks. Follow Microsoft's current disk-space guide for the installed WSL version; do not manually delete or edit `ext4.vhdx`.

### Multiple WSL distributions

Specify the intended distribution exactly:

```powershell
...\setup-deepseek-harness-wsl.ps1 -Action install -Distribution Ubuntu-24.04 -AcceptPrerelease -Yes
```

The installer ignores Docker Desktop's internal distributions and never changes your default distro. If more than one normal distribution exists, it stops and requires `-Distribution`; it does not guess.

### Node resolves to Windows

Inside WSL, these should resolve to Linux paths and `linux`:

```bash
type -a node npm dsh
node -p process.platform
```

Paths under `/mnt/c`, `/mnt/e`, or ending in `.exe`/`.cmd` are not accepted as the managed Linux Node installation.

### npm cannot write `/usr/lib/node_modules`

Ubuntu's system Node may be perfectly usable while its default npm global prefix is `/usr`, which a normal Linux user cannot modify. This is not a reason to use `sudo npm install --global`.

Run status or preview with this Skill. The output should show the effective prefix, global root, writability, bin-path status, and package residue. During install/update, the helper preserves an existing writable user prefix; otherwise it selects `~/.local`, exports `NPM_CONFIG_PREFIX` for the managed npm process, adds `~/.local/bin` to the current `PATH`, and persists a marked block in `~/.profile` after backing it up.

```bash
npm prefix --global
npm root --global
command -v dsh
```

Do not fix this by changing ownership under `/usr`, running npm as root, or deleting a suspected partial package directory. If a package directory exists but npm reports no installed version, the helper reports it. Residue under an unwritable system prefix is left untouched; residue inside the selected user prefix is offered to npm's verified exact-version install for reconciliation.

### WSL network differs from Windows

Test DNS and HTTPS from inside the selected distribution. Windows connectivity does not prove WSL connectivity. This project will not disable TLS checks or rewrite DNS, proxy, VPN, firewall, `/etc/wsl.conf`, or `.wslconfig` automatically.

If package metadata and `npm ping` work but one dependency tarball such as `*.tgz` times out, those results are not contradictory: metadata and tarballs are separate HTTP requests and may take different network/cache paths. The installer retries only the already verified exact Harness version, with bounded per-process settings. It reports a tarball timeout separately and leaves the official registry, TLS checks, and cache protections intact.

For a more patient retry without changing persistent npm/pnpm configuration:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action install -FetchRetries 6 -FetchTimeoutSeconds 600 -NetworkConcurrency 4 -DownloadAttempts 3 -AcceptPrerelease -Yes
```

Do not use `npm cache clean --force`, an unofficial mirror, `strict-ssl=false`, or `curl -k`. Switching to pnpm is an installation-policy choice, not a guarantee of a different network route to the same registry tarballs.

The lower concurrency example is generic and optional. It does not detect, configure, or assume a particular VPN product.

### `node-pty` or node-gyp cannot compile

Harness currently reaches `node-pty` through its official dependency tree. On Ubuntu, node-pty/node-gyp may need `make`, Python 3, GCC, and G++. The default `-NativeBuildTools auto` checks these only when the target Harness version differs from the installed version, refreshes the apt index, and offers only the missing prerequisite packages—never a full `apt upgrade`.

If sudo needs a password but the Agent process is non-interactive, the helper stops and prints the exact command to run inside that WSL distribution. It does not silently relaunch the installer as root.

### `dsh --help` appears stuck

Developer-preview CLI behavior can change. Verification uses a timeout around `dsh --version` and does not kill unrelated Node processes.

If status says `installed; absent from this non-login shell PATH`, the package is present. Windows-launched `wsl <command>` does not necessarily load the same profile as a new Linux login shell. The helper verifies the exact managed `dsh` path directly and does not source the user's whole profile.

New installs record the managed prefix and bin directory in the helper's user-only state file. Status consults that record; for older installs, it can recognize the helper's standard `~/.local` package location. The installer does not add parallel prefix/PATH definitions to `.bashrc` and `.npmrc`, which could create conflicting sources of truth.

`wsl.exe -d <Distro> -- dsh` directly launches a process and is not guaranteed to read any shell startup file. For Windows-side automation, use this Skill's status/launcher path or the reported absolute Linux executable; do not keep adding startup-file entries to make a direct process launch behave like a login shell.

## Uninstall

Remove only Harness from the selected Linux package-manager location:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action uninstall -Yes
```

Removing Node.js, user settings, a WSL distribution, or WSL itself is intentionally outside this command's scope.

## Sources

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
- [DeepSeek Harness native Windows implementation note](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-08-01-windows-pwsh-default.md)
- [DeepSeek Harness source development prerequisites](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/development.md)
- [DeepSeek per-session agent measurements](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/architecture/2026-08-03-per-session-agent-presets.md)
- [DeepSeek large-session restore measurements](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/architecture/2026-08-05-large-session-jsonl-restore-pipeline.md)
- [Harness CLI behavior reference](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.md)
- [DeepSeek V4 technical report](https://arxiv.org/html/2606.19348v1)
- [Microsoft: Install WSL](https://learn.microsoft.com/windows/wsl/install)
- [Microsoft: Advanced WSL settings and current defaults](https://learn.microsoft.com/windows/wsl/wsl-config)
- [Microsoft: Manage WSL disk space](https://learn.microsoft.com/windows/wsl/disk-space)
- [Microsoft: Basic WSL commands and shutdown scope](https://learn.microsoft.com/windows/wsl/basic-commands)
- [Microsoft: Working across Windows and Linux filesystems](https://learn.microsoft.com/windows/wsl/filesystems)
- [npm install documentation](https://docs.npmjs.com/cli/commands/npm-install/)
- [npm configuration: fetch retries and timeouts](https://docs.npmjs.com/cli/using-npm/config/)
- [pnpm setup and global bin behavior](https://pnpm.io/cli/setup)
- [pnpm request settings](https://pnpm.io/settings#request-settings)
- [node-pty Linux build dependencies](https://github.com/microsoft/node-pty#dependencies)
- [node-gyp Unix prerequisites](https://github.com/nodejs/node-gyp#on-unix)

## License

[MIT](LICENSE)

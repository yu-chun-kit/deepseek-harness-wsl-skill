# DeepSeek Harness on WSL — Codex Skill and Installer

A community-maintained Codex skill and resumable PowerShell installer for running the **official [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)** inside WSL2 on Windows.

It installs the official npm package, `@deepseek-ai/dsh`, into Linux—not a fork, wrapper model, or similarly named third-party harness.

> [!IMPORTANT]
> This is an unofficial community project. DeepSeek Harness itself is currently a developer preview and may introduce breaking changes. This repository does not claim that DeepSeek-V4-Pro is proven to be overfit to Harness, or that Linux makes the model intrinsically smarter.

## 中文摘要

這個 repo 提供一個可交給 agent 使用的 Skill，以及一個從 Windows 執行的安裝器。它會自動偵測 WSL2、選擇既有 Ubuntu、在 WSL 內準備 Linux Node.js、確認 npm global prefix 可由一般使用者寫入，核對 npm 套件是否指向 DeepSeek 官方 repo，然後安裝解析後的**精確版本**。

WSL2 的定位是「相容性優先」：讓 Windows 使用者更接近 DeepSeek 技術報告披露的 `bash + file-edit` code-agent 評測形態。這不是 DeepSeek 官方的 Windows/WSL 效能結論，也沒有公開的嚴格 A/B 測試證明模型在 Linux 上本質更強。

## Why WSL?

DeepSeek's V4 technical report describes code-agent evaluation with a minimal tool set consisting of Bash and a file-edit tool. The public Harness minimal preset similarly uses persistent Bash and `str_replace_editor`.

Native Windows remains supported by Harness. WSL2 is recommended here because it gives Windows users Linux paths, permissions, signals, shell behavior, and common SWE/terminal tooling. It is a reproducibility and compatibility choice—not a model inference optimization.

There is also an important timeline distinction: the public minimal preset landed after the V4 technical report. It is reasonable to say that the public preset aligns with the disclosed internal evaluation shape; it is not reasonable to claim that the model was trained against today's public preset.

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

At the time this project was authored, npm's official `latest` tag still resolved to an RC build, which is why the example explicitly includes `-AcceptPrerelease`. Remove that switch when `latest` resolves to a stable release.

### Fresh Windows installation is resumable, not magically reboot-free

If WSL or Ubuntu is not installed, the same command starts the official Windows WSL installation flow. Windows may require an administrator terminal and a reboot. Ubuntu may then require one local first-run to create the Linux username and password.

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
| `-Action uninstall` | Remove only the npm package; preserve data, Node, distro, and WSL |
| `-Distribution <name>` | Use one exact installed WSL distribution |
| `-Channel latest\|next` | Select an npm dist-tag before exact-version resolution |
| `-PackageVersion <semver>` | Install one exact version |
| `-AcceptPrerelease` | Explicitly allow RC/beta versions |
| `-Yes` | Accept the displayed package/prerequisite changes |
| `-WhatIf` | Preview mutations; metadata checks may still use the network |
| `-SkipNodeInstall` | Require a compatible existing Linux Node.js |
| `-InstallWslIfMissing:$false` | Refuse to add WSL/distro automatically |

## Support and validation matrix

| Environment | Status |
|---|---|
| Windows 11 x64 + current WSL2 + Ubuntu 24.04 | PowerShell parsing, Bash parsing, status path, root boundary, and dry-run package verification tested |
| Existing Ubuntu WSL2 with Linux Node.js 24 | Status and exact-version npm metadata dry-run tested |
| System Node under `/usr` with an unwritable npm global prefix | User-owned prefix selection dry-run and isolated profile-persistence regression-tested |
| Fresh WSL install across administrator/reboot/first-run boundaries | Designed as a resumable flow; not automatically reboot-tested |
| Windows 10 2004+ / ARM64 / non-Ubuntu distributions | Expected to require environment-specific validation; not claimed as tested |

Static validation includes the Skill Creator validator. The scripts intentionally have no live Harness installation or paid API smoke test in their repository test path.

When compatible Linux Node/npm is absent, the first `-WhatIf` output is a phase-one preview. It lists prerequisite, pinned nvm, and profile changes but cannot resolve the exact npm target yet. Run the same preview again after Node is available to inspect registry, repository, integrity, and exact package-version metadata.

## What the installer changes

Depending on the starting state, it may:

- add Ubuntu 24.04 through the official `wsl --install` command;
- install missing Ubuntu `git`, `curl`, and CA certificates;
- clone a pinned nvm Git tag, verify its expected commit, and install the current Node.js LTS for the Linux user;
- add one marked nvm loader block to `~/.profile`, after backing it up;
- when the effective npm global prefix is not user-writable, create `~/.local` and add one marked `NPM_CONFIG_PREFIX`/`PATH` block to `~/.profile`, after backing it up;
- install an exact `@deepseek-ai/dsh` version into that user's Linux npm prefix;
- write a version-only rollback record under `~/.local/state/deepseek-harness-wsl/`.

It does **not** change the default distro, convert WSL1, edit `.wslconfig`, alter VPN/DNS/firewall settings, expose the Web UI beyond localhost, store API keys, modify a project, delete Harness data, or unregister a distribution.

## Secrets and permissions

- Never paste a DeepSeek API key into an agent conversation or command-line argument.
- Never commit `.credentials.yaml`, `.env`, or shell history containing credentials.
- Harness sessions default to a workspace-write permission preset. Choose the workspace deliberately and review tool approvals.
- API authentication and paid model calls are separate from installation verification. This project does not send a paid smoke-test request automatically.

## Troubleshooting

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

### `dsh --help` appears stuck

Developer-preview CLI behavior can change. Verification uses a timeout around `dsh --version` and does not kill unrelated Node processes.

## Uninstall

Remove only Harness from the selected Linux npm prefix:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\deepseek-harness-wsl\scripts\setup-deepseek-harness-wsl.ps1 -Action uninstall -Yes
```

Removing Node.js, user settings, a WSL distribution, or WSL itself is intentionally outside this command's scope.

## Sources

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
- [Harness CLI behavior reference](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.md)
- [DeepSeek V4 technical report](https://arxiv.org/html/2606.19348v1)
- [Microsoft: Install WSL](https://learn.microsoft.com/windows/wsl/install)
- [Microsoft: Working across Windows and Linux filesystems](https://learn.microsoft.com/windows/wsl/filesystems)
- [npm install documentation](https://docs.npmjs.com/cli/commands/npm-install/)

## License

[MIT](LICENSE)

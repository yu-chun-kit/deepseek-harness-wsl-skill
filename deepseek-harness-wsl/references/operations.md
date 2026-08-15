# Operational guide

## State transitions

1. Inspect without mutation.
2. If WSL is missing, install WSL and an Ubuntu LTS distribution from an elevated PowerShell. Stop at any reboot boundary.
3. Let the user complete the distribution's first-run username and password prompt.
4. Re-run the installer as the normal Windows user.
5. Install Linux prerequisites with `sudo` only when missing. Refresh the apt package index before installing; do not run a full distribution upgrade.
6. Install Node under the Linux user's home through the pinned nvm Git tag.
7. Inspect `npm prefix --global`, `npm root --global`, writability, `PATH`, and possible partial package residue. Preserve a writable user prefix; otherwise select `~/.local` and persist it without sudo.
8. Select `auto|npm|pnpm`. Preserve a recorded manager; otherwise `auto` uses an existing usable Linux pnpm and falls back to npm. It never accepts a Windows executable exposed under `/mnt/*` and never installs pnpm automatically.
9. Resolve the official npm registry channel to an exact version and verify metadata. If the exact version will change, preflight the `node-pty` native build requirements (`make`, Python 3, GCC, G++), unless explicitly skipped.
10. Install the exact version without `sudo`, using bounded fetch retries, concurrency, and exact-install attempts.
11. Verify versions, provenance, platform, package-manager global location, package path, and the exact managed `dsh` executable even when a non-login shell omits its bin directory from `PATH`.

The helper is idempotent. Re-running it reuses the selected distribution and existing compatible Linux Node installation.

## PowerShell parameters

- `-Action status|install|update|uninstall`
- `-Distribution <name>`: require an exact installed distribution name.
- `-Channel latest|next`: resolve an npm dist-tag; defaults to `latest`.
- `-PackageManager auto|npm|pnpm`: preserve the recorded manager, otherwise prefer an existing usable Linux pnpm and fall back to npm.
- `-PackageVersion <semver>`: bypass the channel and request an exact version.
- `-FetchRetries 0..10`: package-manager fetch retries; defaults to 4 and applies only to the launched process.
- `-FetchTimeoutSeconds 30..900`: per-request timeout; defaults to 300 seconds and is not persisted.
- `-NetworkConcurrency 1..50`: maximum registry concurrency for this run; defaults to npm's normal 15. Lower values are an opt-in for unstable links.
- `-DownloadAttempts 1..3`: maximum attempts to install the same verified exact version; defaults to 2.
- `-NativeBuildTools auto|skip`: preflight/install missing Ubuntu native build prerequisites, or explicitly accept the risk of skipping them.
- `-AcceptPrerelease`: required when the resolved version contains a prerelease suffix.
- `-Yes`: accept the displayed exact-version change and prerequisite installation.
- `-InstallWslIfMissing:$false`: inspect without enabling/installing WSL.
- `-SkipNodeInstall`: fail instead of installing Linux Node when it is missing or incompatible.
- `-WhatIf`: report planned mutations. Network metadata checks may still occur.

## Files changed

- An Ubuntu distribution may be added by `wsl --install`.
- Missing `git`, `curl`, CA certificates, `build-essential`, and Python 3 may be installed through Ubuntu apt after refreshing its package index.
- nvm is cloned at a pinned tag into the Linux user's home if compatible Linux Node is unavailable.
- A marked nvm loader block may be appended to `~/.profile` after creating a backup.
- When a system npm prefix such as `/usr` is not user-writable, `~/.local` is created and a marked `NPM_CONFIG_PREFIX`/`PATH` block may be appended to `~/.profile` after creating a backup. Existing writable user prefixes are preserved.
- `@deepseek-ai/dsh` is installed into the selected user-writable Linux npm global prefix.
- A version, package-manager, managed-prefix/bin rollback record is written with user-only permissions under `~/.local/state/deepseek-harness-wsl/`.

The helper does not modify Windows networking, `.wslconfig`, the default distribution, project files, Harness credentials, or API keys.

Even when pnpm performs the global install, the helper uses npm bundled with the required Linux Node.js installation to resolve and verify official registry metadata. An existing pnpm is an install-manager option, not a replacement for the Node/npm identity check.

## Recovery

- Reboot requested: reboot manually, finish distro first-run, then rerun the same command.
- Existing distro opens as root and never shows first-run: treat it as an imported/headless distro. With explicit user approval, create a normal account interactively as root, add it to `sudo`, then use `wsl --manage <Distro> --set-default-user <User>` on WSL versions that support it. Verify with `wsl -d <Distro> -- id`; do not replace `wsl.conf` or guess a username. If `--manage` is unavailable, stop and link to the distribution-specific Microsoft recovery guidance.
- Multiple distributions: rerun with `-Distribution`.
- Phase-one dry-run with Node absent: it can show planned prerequisites/nvm/profile changes but cannot resolve npm metadata yet. Rerun `-WhatIf` after Linux Node/npm exists to see the exact package target.
- npm reports `EACCES` under `/usr/lib/node_modules`: rerun the current Skill entry point. It must show `/usr` as unwritable, select `~/.local`, persist its bin path, and retry without sudo. Do not recursively `chown` `/usr` or run npm as root.
- `~/.npmrc` names a user prefix but effective npm prefix remains `/usr`: do not assume the file won precedence. Let the helper use `NPM_CONFIG_PREFIX` for the managed process and persist it only when the effective prefix is not writable.
- Package directory exists but `npm list --global` has no version: report it as partial residue. Leave residue in an unwritable system prefix untouched; let an exact-version install attempt reconciliation only inside the selected user prefix. Do not delete either directory automatically.
- Prerelease rejected: inspect the resolved version and rerun with `-AcceptPrerelease` only if intended.
- Update regression: read the rollback record and use `-PackageVersion` with the prior exact version.
- VPN/DNS failure: test DNS and HTTPS from inside the selected distribution; report the failure without rewriting WSL or Windows network configuration.
- Registry metadata and `npm ping` work but a `.tgz` times out: treat metadata and tarball delivery as separate checks. The helper retries only the verified exact version with bounded settings. If all attempts fail, inspect WSL DNS/TLS/proxy routing and rerun; do not use an unofficial mirror, `strict-ssl=false`, `curl -k`, `npm cache clean --force`, or assume pnpm uses a different network path.
- Native `node-pty` build fails: rerun with `-NativeBuildTools auto`. If sudo needs a password and the agent has no interactive terminal, run the printed `apt-get update`/install command inside the selected WSL distro, then resume. Do not silently switch the whole installer to root.
- `dsh` is installed but a Windows-launched WSL command says it is absent from `PATH`: verify the exact npm/pnpm global bin path. The status action reports and tests that executable directly without sourcing arbitrary profile code; a new login shell should consume the marked profile block.
- Older managed state has no prefix/bin fields: status may use the helper's standard `~/.local` package path as a read-only compatibility fallback. Do not compensate by appending duplicate blocks to `.bashrc`, `.profile`, and `.npmrc`; keep the helper's marked `.profile` block as the single shell-persistence owner.
- Explicit pnpm is rejected: ensure `command -v pnpm` is a Linux path, `pnpm bin --global` is inside the Linux user's home and writable, then rerun. `auto` safely falls back to npm and does not bootstrap pnpm.

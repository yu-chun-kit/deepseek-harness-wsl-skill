---
name: deepseek-harness-wsl
description: Install, update, inspect, repair, or remove the official DeepSeek Harness npm package inside WSL2 on a Windows host, and optionally manage experimental first-request-anchored variants of its Standard, Code/PTC, and Cordis presets. Use when a user wants DeepSeek Harness or its Bash-based minimal agent preset on Windows through Ubuntu/WSL, wants a reproducible Linux-compatible setup, asks about Minimal-like behavior in other modes, needs to resume a WSL installation after reboot or distro first-run, or needs to verify package identity, Node provenance, versions, paths, and update/rollback boundaries.
---

# DeepSeek Harness on WSL

Set up the official `@deepseek-ai/dsh` package inside a selected WSL2 distribution. Treat this as a community deployment skill, not an official DeepSeek skill or a model-performance guarantee.

Resolve every relative resource path against this skill directory. Run the provided PowerShell entry point from the skill directory or pass its absolute path; do not assume the user's project contains `scripts/`.

## Apply the workflow

1. Read [operations.md](references/operations.md) before changing the host. Read [evidence-boundaries.md](references/evidence-boundaries.md) before explaining minimal mode, Linux, WSL, overfitting, or a claimed training bug. Read [anchored-presets.md](references/anchored-presets.md) before installing or discussing Minimal-like behavior in another preset. Read [resources.md](references/resources.md) when WSL is absent or the user asks about RAM, CPU, disk, startup impact, or concurrent sessions.
2. Inspect Windows build, `wsl --status`, `wsl --version`, and `wsl --list --verbose`. Reuse an initialized WSL2 distribution when possible. If multiple non-Docker distributions exist, require an explicit selection. Do not change the default distribution or convert WSL1 automatically.
3. When no usable WSL distribution exists, do not install one by default. Report host RAM/CPU/system-drive free space and offer two honest choices: native Windows with the official Node/npm package, or this WSL2 Bash-compatibility path. Explain the Ubuntu virtual disk, Linux account, possible elevation/reboot, and support burden. Require explicit `-InstallWslIfMissing:$true` for the latter. Do not present WSL as required or silently convert a status request into platform installation.
4. Offer the relevant choices before mutation: exact distribution, `auto|npm|pnpm`, `latest|next|exact version`, native build-tools preflight, and normal or more patient bounded download settings. Use `auto`, `latest`, build-tools `auto`, four fetch retries, a 300-second request timeout, npm's normal 15 connections, and two exact-install attempts when the user does not care. `auto` preserves the package manager recorded by an earlier managed install; for a fresh install it uses an existing usable Linux pnpm and otherwise npm. Never treat a Windows pnpm under `/mnt/*` as usable.
5. Run the status action first:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-deepseek-harness-wsl.ps1 -Action status
   ```

6. Preview installation when the user has not already requested installation explicitly:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -WhatIf
   ```

   If WSL is absent and the user chose the WSL path, add `-InstallWslIfMissing:$true` to this preview. Without that explicit opt-in, the preview must stop after explaining the native Windows and WSL choices.

7. Install after confirming the selected distribution, exact package version, package manager, download policy, prerelease status, and possible WSL/reboot boundary:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -Yes
   ```

   Omit `-AcceptPrerelease` once the resolved official `latest` version is stable. Use `-Distribution <exact-name>` when more than one non-Docker distribution exists.

8. If Windows requests a reboot, stop and give the printed resume command. Never reboot automatically. If Ubuntu requests initial username/password creation, ask the user to complete that first-run locally, then rerun the same command. If an existing/imported distro has only root and no first-run UI, follow the explicit recovery procedure in [operations.md](references/operations.md); never invent or silently configure an account.
9. Verify that WSL reports version 2, `node -p process.platform` reports `linux`, executables do not resolve under `/mnt/*`, the selected package manager's global location is user-writable and on `PATH`, the installed package version matches the resolved exact version, and `dsh --version` exits within the script timeout.
10. Start the Web UI only from a workspace the user chose. Prefer a Linux filesystem path such as `~/projects/...` for Linux-heavy agent work. Do not concatenate untrusted paths into `bash -lc`; pass variable paths positionally when automating.
11. Tell the user to enter the DeepSeek API key directly in **Settings → Models**. Never request the key in chat, put it on a command line, echo it, or write it into the repository. Explain that official Harness stores it in `$DSH_HOME/.credentials.yaml` and returns only a redacted descriptor to the UI.
12. Select **极简模式 / Minimal** when creating a Web session if the user wants the two-tool preset. Do not present `minimal` as a separate CLI entry mode.

## Optional anchored presets

Use anchored presets only when the user explicitly wants to experiment with Minimal-aligned first-request conditions while retaining a broader later tool catalog. They are community-generated preset copies, not official DeepSeek modes and not part of the normal Harness installation.

1. Inspect and preview first, with the exact distribution:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage-anchored-presets.ps1 -Action status -Distribution <name> -Mode all
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage-anchored-presets.ps1 -Action install -Distribution <name> -Mode all -WhatIf
   ```

2. Explain that the first request uses the fixed Minimal persona, one platform shell plus `read`, a 1024-token output cap, and no automatic skill/workspace digest. After the first durable tool call or assistant reply, the selected preset's complete tool catalog returns. This is Minimal-aligned, not identical to official Minimal's persistent Bash plus `str_replace_editor`.
3. State the evidence tiers: Anchored Standard has two published runs on one private frozen task; Anchored Code/PTC and Anchored Cordis are unbenchmarked extrapolations. Cordis also loses its specialized system persona, so recommend it only for controlled comparison.
4. Install only after the user accepts those limits:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage-anchored-presets.ps1 -Action install -Distribution <name> -Mode all -Yes
   ```

5. Fully restart Harness and use a blank session. Never switch an existing session into an anchored preset. After a Harness update, run `-Action status`; if the official source hash changed, review and use `-Action update` to regenerate.
6. Do not edit shipped presets or `node_modules`. The helper writes only managed copies under `$DSH_HOME/.agent-presets/anchored-*`, refuses unowned collisions, and removes only copies carrying its ownership manifest.

## Preserve boundaries

- Use only `https://registry.npmjs.org/` unless the user explicitly requires a trusted enterprise registry.
- Resolve a channel to an exact version, show current-to-target, verify the npm repository URL, then install the exact version. Do not use blind scheduled updates.
- Keep TLS verification and npm integrity checks enabled. Never use `curl | bash`, `sudo npm -g`, `--force`, `curl -k`, or `strict-ssl=false`.
- Distinguish official usage modes: DeepSeek documents npm/npx for running the published CLI and pnpm for a source checkout and profile plugin management. Do not claim that pnpm is mandatory for the published package. Do not install pnpm automatically merely because `auto` was selected.
- When metadata/ping succeeds but a `.tgz` request times out, classify it as a WSL-to-registry transport failure. Retry only the same verified exact version within the selected bounds. Do not clear the cache forcibly, change registries, disable TLS, or promise that switching npm/pnpm will fix the network path.
- Preflight `make`, Python 3, GCC, and G++ before a changed Harness version is installed because its `node-pty` dependency may compile through node-gyp. On Ubuntu, offer only the missing `build-essential`/`python3` packages after `apt-get update`; never run a full upgrade. If sudo requires a password in a non-interactive agent process, stop with a local WSL resume command. Do not bypass that boundary with `wsl -u root` for package installation.
- Treat a system Node at `/usr/bin/node` as valid, but never write npm global packages into an unwritable `/usr` prefix. Let the helper select and persist a user-owned `~/.local` prefix; do not fix npm `EACCES` with sudo or recursive ownership changes.
- Report a package directory that exists without a package-manager-installed version as possible partial residue. Do not delete it automatically; retry the verified exact-version install and stop for review if the selected manager cannot reconcile it.
- Do not edit `.wslconfig`, `wsl.conf`, DNS, VPN, proxy, firewall, default distro, or global WSL networking. Diagnose and report instead.
- Do not call `2GB` an official or generally sufficient Harness memory recommendation. DeepSeek publishes no supported RAM minimum or per-session sizing formula. Explain that `.wslconfig` limits are global to all WSL2 distributions and can constrain unrelated Docker/Linux work. Never create, read out, merge, or overwrite that file automatically.
- Never unregister a distribution, delete a VHD/home/config, run a full `apt upgrade`, recursively change `/mnt/*` permissions, or stop unrelated Node processes.
- Treat uninstalling Harness, removing Node, removing a distro, and disabling WSL as separate operations. The provided uninstall removes only the selected manager's Harness package and preserves user data.
- Separate installation success, Web UI startup, API authentication, and paid model smoke tests. Never incur API cost without explicit opt-in.
- Do not source an arbitrary user profile merely to verify `dsh`. Resolve the managed npm/pnpm bin path directly, report when only a non-login shell PATH is missing it, and execute the exact verified path for the version check.
- Keep the marked `.profile` block and the helper-owned state record as the only persistence sources. Do not add duplicate prefix/PATH settings to `.bashrc` or `.npmrc` merely to make a non-login status command pass.

## Update and roll back

Run `-Action update -AcceptPrerelease -Yes` to resolve and install the current exact release. The helper records the prior and target versions without secrets under the Linux user's local state directory. To roll back, rerun with `-PackageVersion <previous-exact-version> -AcceptPrerelease -Yes` when applicable.

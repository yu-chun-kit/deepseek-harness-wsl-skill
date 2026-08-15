---
name: deepseek-harness-wsl
description: Install, update, inspect, repair, or remove the official DeepSeek Harness npm package inside WSL2 on a Windows host. Use when a user wants DeepSeek Harness or its Bash-based minimal agent preset on Windows through Ubuntu/WSL, wants a reproducible Linux-compatible setup, needs to resume a WSL installation after reboot or distro first-run, or needs to verify package identity, Node provenance, versions, paths, and update/rollback boundaries.
---

# DeepSeek Harness on WSL

Set up the official `@deepseek-ai/dsh` package inside a selected WSL2 distribution. Treat this as a community deployment skill, not an official DeepSeek skill or a model-performance guarantee.

Resolve every relative resource path against this skill directory. Run the provided PowerShell entry point from the skill directory or pass its absolute path; do not assume the user's project contains `scripts/`.

## Apply the workflow

1. Read [operations.md](references/operations.md) before changing the host. Read [evidence-boundaries.md](references/evidence-boundaries.md) before explaining minimal mode, Linux, WSL, or overfitting claims.
2. Inspect Windows build, `wsl --status`, `wsl --version`, and `wsl --list --verbose`. Reuse an initialized WSL2 distribution when possible. If multiple non-Docker distributions exist, require an explicit selection. Do not change the default distribution or convert WSL1 automatically.
3. Run the status action first:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-deepseek-harness-wsl.ps1 -Action status
   ```

4. Preview installation when the user has not already requested installation explicitly:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -WhatIf
   ```

5. Install after confirming the selected distribution, exact npm version, prerelease status, and possible WSL/reboot boundary:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-deepseek-harness-wsl.ps1 -Action install -AcceptPrerelease -Yes
   ```

   Omit `-AcceptPrerelease` once the resolved official `latest` version is stable. Use `-Distribution <exact-name>` when more than one non-Docker distribution exists.

6. If Windows requests a reboot, stop and give the printed resume command. Never reboot automatically. If Ubuntu requests initial username/password creation, ask the user to complete that first-run locally, then rerun the same command. If an existing/imported distro has only root and no first-run UI, follow the explicit recovery procedure in [operations.md](references/operations.md); never invent or silently configure an account.
7. Verify that WSL reports version 2, `node -p process.platform` reports `linux`, executables do not resolve under `/mnt/*`, the installed package version matches the resolved exact version, and `dsh --version` exits within the script timeout.
8. Start the Web UI only from a workspace the user chose. Prefer a Linux filesystem path such as `~/projects/...` for Linux-heavy agent work. Do not concatenate untrusted paths into `bash -lc`; pass variable paths positionally when automating.
9. Tell the user to enter the DeepSeek API key directly in **Settings → Models**. Never request the key in chat, put it on a command line, echo it, or write it into the repository. Explain that official Harness stores it in `$DSH_HOME/.credentials.yaml` and returns only a redacted descriptor to the UI.
10. Select **极简模式 / Minimal** when creating a Web session if the user wants the two-tool preset. Do not present `minimal` as a separate CLI entry mode.

## Preserve boundaries

- Use only `https://registry.npmjs.org/` unless the user explicitly requires a trusted enterprise registry.
- Resolve a channel to an exact version, show current-to-target, verify the npm repository URL, then install the exact version. Do not use blind scheduled updates.
- Keep TLS verification and npm integrity checks enabled. Never use `curl | bash`, `sudo npm -g`, `--force`, `curl -k`, or `strict-ssl=false`.
- Do not edit `.wslconfig`, `wsl.conf`, DNS, VPN, proxy, firewall, default distro, or global WSL networking. Diagnose and report instead.
- Never unregister a distribution, delete a VHD/home/config, run a full `apt upgrade`, recursively change `/mnt/*` permissions, or stop unrelated Node processes.
- Treat uninstalling Harness, removing Node, removing a distro, and disabling WSL as separate operations. The provided uninstall removes only the npm package and preserves user data.
- Separate installation success, Web UI startup, API authentication, and paid model smoke tests. Never incur API cost without explicit opt-in.

## Update and roll back

Run `-Action update -AcceptPrerelease -Yes` to resolve and install the current exact release. The helper records the prior and target versions without secrets under the Linux user's local state directory. To roll back, rerun with `-PackageVersion <previous-exact-version> -AcceptPrerelease -Yes` when applicable.

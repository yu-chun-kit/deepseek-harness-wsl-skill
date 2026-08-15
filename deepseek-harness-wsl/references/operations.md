# Operational guide

## State transitions

1. Inspect without mutation.
2. If WSL is missing, install WSL and an Ubuntu LTS distribution from an elevated PowerShell. Stop at any reboot boundary.
3. Let the user complete the distribution's first-run username and password prompt.
4. Re-run the installer as the normal Windows user.
5. Install Linux prerequisites with `sudo` only when missing.
6. Install Node under the Linux user's home through the pinned nvm Git tag.
7. Inspect `npm prefix --global`, `npm root --global`, writability, `PATH`, and possible partial package residue. Preserve a writable user prefix; otherwise select `~/.local` and persist it without sudo.
8. Resolve the official npm channel to an exact version, verify metadata, and install that version without `sudo`.
9. Verify versions, provenance, platform, prefix, package path, and executable paths.

The helper is idempotent. Re-running it reuses the selected distribution and existing compatible Linux Node installation.

## PowerShell parameters

- `-Action status|install|update|uninstall`
- `-Distribution <name>`: require an exact installed distribution name.
- `-Channel latest|next`: resolve an npm dist-tag; defaults to `latest`.
- `-PackageVersion <semver>`: bypass the channel and request an exact version.
- `-AcceptPrerelease`: required when the resolved version contains a prerelease suffix.
- `-Yes`: accept the displayed exact-version change and prerequisite installation.
- `-InstallWslIfMissing:$false`: inspect without enabling/installing WSL.
- `-SkipNodeInstall`: fail instead of installing Linux Node when it is missing or incompatible.
- `-WhatIf`: report planned mutations. Network metadata checks may still occur.

## Files changed

- An Ubuntu distribution may be added by `wsl --install`.
- Missing `git`, `curl`, and CA certificates may be installed through Ubuntu apt.
- nvm is cloned at a pinned tag into the Linux user's home if compatible Linux Node is unavailable.
- A marked nvm loader block may be appended to `~/.profile` after creating a backup.
- When a system npm prefix such as `/usr` is not user-writable, `~/.local` is created and a marked `NPM_CONFIG_PREFIX`/`PATH` block may be appended to `~/.profile` after creating a backup. Existing writable user prefixes are preserved.
- `@deepseek-ai/dsh` is installed into the selected user-writable Linux npm global prefix.
- A version-only rollback record is written under `~/.local/state/deepseek-harness-wsl/`.

The helper does not modify Windows networking, `.wslconfig`, the default distribution, project files, Harness credentials, or API keys.

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

# WSL resource and beginner decision guide

Read this reference only when WSL is absent or the user asks about startup, RAM, CPU, disk use, `.wslconfig`, or simultaneous sessions.

## Facts to report

- Native Windows support exists in official Harness. WSL2 is this project's Bash-compatibility path, not a universal prerequisite.
- Microsoft documents the WSL2 VM default memory limit as 50% of Windows RAM, processors as all logical processors, and swap as 25% of Windows RAM rounded up to the nearest GB. A limit is not an eager reservation at Windows boot.
- Current WSL settings document a 60-second `vmIdleTimeout` default on Windows 11 and an experimental `autoMemoryReclaim` setting for cached memory. WSL starts when invoked and manages the VM lifecycle automatically. Open handles, settings, and idle management affect observed state; a Linux background service alone does not guarantee that the VM stays running. Inspect `wsl --list --running` rather than promise that it is stopped.
- `%USERPROFILE%\.wslconfig` applies across all WSL2 distributions. Microsoft recommends WSL Settings for changes. Applying changes may require the VM to stop; `wsl --shutdown` terminates every running distribution.
- Each WSL2 distribution uses a dynamically expanding virtual disk. Do not delete or manipulate `ext4.vhdx` directly. Use Microsoft's current disk-space guidance for the installed WSL version.
- DeepSeek has not published a supported Harness RAM minimum, per-session usage, or concurrent-session formula. The cloud model weights are not loaded into local WSL; local usage comes from Harness, shells, builds, tests, language servers, and other agent subprocesses.
- Official implementation notes measured about 1.31 MB per live standard agent and 57.8 MB for 50 such agents in one preset-composition test, but a different 1,307,073-event session restore reached about 1,060 MiB peak RSS after optimization. Treat both only as implementation profiles. They exclude arbitrary agent-launched work and do not define a 2 GiB recommendation.

## Decision flow

1. If a suitable WSL2 distribution already exists, show current status and reuse it after approval.
2. If WSL is absent, show host total/available RAM, logical CPU count, system-drive free space, and whether a global `.wslconfig` exists.
3. Offer native Windows for the smallest platform change and WSL2 for Linux/Bash compatibility. Do not disparage either option or promise model-quality gains.
4. If the user chooses WSL2, preview with `-InstallWslIfMissing:$true -WhatIf`; then require elevation for the live platform install and stop at reboot/account-creation boundaries.
5. Do not create a resource cap automatically. If the user separately asks to tune WSL, observe the real workload first and explain that any cap affects every WSL2 distribution.

## Claims to avoid

- "WSL always starts with Windows" or "WSL never runs in the background."
- "WSL immediately consumes 50% of RAM."
- "2GB is recommended/sufficient for Harness" or "N chats require N × memory."
- "The virtual disk can only shrink through diskpart."
- "WSL is required because DeepSeek runs better on Linux."

## Primary sources

- [DeepSeek Harness repository](https://github.com/deepseek-ai/deepseek-harness)
- [DeepSeek per-session preset implementation measurements](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/architecture/2026-08-03-per-session-agent-presets.md)
- [DeepSeek large-session restore implementation measurements](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/architecture/2026-08-05-large-session-jsonl-restore-pipeline.md)
- [DeepSeek source development prerequisites](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/development.md)
- [Microsoft WSL installation](https://learn.microsoft.com/windows/wsl/install)
- [Microsoft advanced WSL settings](https://learn.microsoft.com/windows/wsl/wsl-config)
- [Microsoft WSL basic commands](https://learn.microsoft.com/windows/wsl/basic-commands)
- [Microsoft WSL disk-space management](https://learn.microsoft.com/windows/wsl/disk-space)

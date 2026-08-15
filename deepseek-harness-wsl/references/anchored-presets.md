# Experimental anchored presets

## What the experiment changes

The helper generates new user presets named `anchored-standard`, `anchored-code`, and `anchored-cordis`. It copies the matching preset from the user's exact installed official Harness package, then adds a first-request gate:

- complete system persona: `You are a helpful software engineer assistant.`;
- first request: one platform shell (`bash` in WSL) plus `read`;
- first request output cap: 1024 tokens;
- first request: suppress automatic `agent-instructions` and `skill-catalog` messages;
- after the first durable `tool/call` or `assistant/message`: expose the copied preset's complete tool catalog and normal automatic context.

This is not identical to official Minimal. Minimal exposes persistent Bash plus `str_replace_editor`, has no compaction, and stays minimal for the whole session. The anchored variants use the normal preset's shell/filesystem implementations and change catalog once.

## Why use a script instead of a prompt

A user prompt cannot control the API-visible tool schema, the first-request output budget, or automatic Harness context injection. The effect under investigation spans all of those surfaces. The script creates separate presets so official files remain untouched and Harness upgrades do not silently overwrite the experiment.

## Evidence tiers

- **Official:** DeepSeek documents Minimal as the owner of a fixed RL-oriented composition. It does not call this a training bug.
- **Community reproduction:** Anchored Standard reported 98 and 99 on two runs of one private frozen engineering task. That supports a first-request scaffold hypothesis only for that setup.
- **Extrapolation:** Anchored Code/PTC and Anchored Cordis have no published score. Cordis's original specialized system persona is not restored after promotion; its tools and composition skill return, but its original authoring instructions do not. Treat it as a diagnostic variant, not a recommended default.

Do not claim universal performance improvement, a different hidden checkpoint, or a confirmed training bug.

## Commands

Use an explicit WSL distribution whenever more than one is installed:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage-anchored-presets.ps1 -Action status -Distribution Ubuntu -Mode all
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage-anchored-presets.ps1 -Action install -Distribution Ubuntu -Mode all -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage-anchored-presets.ps1 -Action install -Distribution Ubuntu -Mode all -Yes
```

`-Mode` accepts `standard`, `code`, `cordis`, or `all`. Prefer `standard` first because it is the only variant with published anchored results.

After a Harness update:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage-anchored-presets.ps1 -Action status -Distribution Ubuntu -Mode all
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage-anchored-presets.ps1 -Action update -Distribution Ubuntu -Mode all -WhatIf
```

The status compares the current official source composition with the hash recorded at generation time. The generator refuses unknown persona/tool shapes instead of attempting a loose text rewrite.

Remove only the managed copies:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\manage-anchored-presets.ps1 -Action uninstall -Distribution Ubuntu -Mode all -Yes
```

The helper refuses to overwrite or remove a same-named directory without its ownership manifest. It does not edit official presets, sessions, credentials, models, or workspaces.

## Session use

Fully restart `dsh web`, create a blank session, then select an anchored preset. Do not switch an existing session from another preset because durable session events determine whether the bootstrap phase has already promoted.

No API call is required to install or inspect these presets. Any performance comparison consumes model tokens and must be a separate, explicit choice.

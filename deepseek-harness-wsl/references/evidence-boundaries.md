# Evidence and claim boundaries

## What is established

- DeepSeek Harness is developed by DeepSeek AI and published as `@deepseek-ai/dsh` from the `deepseek-ai/deepseek-harness` repository.
- Harness is in developer preview and its maintainers warn of compatibility-breaking changes.
- DeepSeek's V4 technical report describes an internal code-agent evaluation framework with a minimal tool set: one Bash tool and one file-edit tool.
- The public Harness minimal preset uses persistent Bash plus `str_replace_editor`, with the fixed system prompt `You are a helpful software engineer assistant.`
- The public minimal preset was added after the V4 technical report. It aligns with the previously disclosed evaluation shape; it was not the public repository preset used during earlier model training.
- Native Windows support exists. WSL is a compatibility-oriented path for reproducing Linux/Bash tool semantics, not the only supported platform.
- DeepSeek's public Harness documentation does not publish a supported RAM minimum, a per-session memory figure, or a concurrent-session sizing formula.
- DeepSeek's implementation note says the public Minimal preset owns a fixed RL-oriented composition: a complete fixed persona and a restricted model-facing tool surface. This establishes deliberate composition alignment, not a disclosed training bug.

## What is not established

- No official controlled experiment proves that V4 Pro is overfit to the public DeepSeek Harness minimal preset.
- No official Windows-versus-WSL/Linux comparison proves that the model is intrinsically better on Linux.
- WSL does not run the cloud model locally or accelerate its inference. It changes the local harness, shell, filesystem, and tools.
- A generic `memory=2GB` example is not a DeepSeek recommendation. WSL resource limits are global host settings, and sufficiency depends on local tools and subprocesses rather than only the number of chat tabs.
- A prompt-sensitive result alone cannot distinguish training overfit from tool-schema matching, reasoning-trace handling, sampling, context management, or shell differences.
- A community Anchored Standard experiment reported 98 and 99 on one private frozen task after using Minimal-aligned first-request conditions and then restoring Standard tools. Two runs on one task do not establish general improvement, causality, or a training defect.
- No published benchmark currently supports the generated Anchored Code/PTC or Anchored Cordis variants. They are explicit extrapolations. Cordis's specialized authoring persona is replaced by the fixed Minimal persona in the experimental copy.

Use language such as:

> WSL2 is a compatibility-first recommendation for Windows users who want an environment closer to DeepSeek's disclosed Bash-and-file-edit evaluation setup. It is an engineering recommendation, not an official performance claim.

Do not state that Linux is required, that Windows is unsupported, or that overfitting has been proven.

## Primary sources

- [DeepSeek Harness repository](https://github.com/deepseek-ai/deepseek-harness)
- [Harness CLI behavior and minimal preset](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/reference/README.md)
- [Minimal preset configuration](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/config/agent-presets/minimal/agent.cordis.yml)
- [Official Minimal RL composition implementation note](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/bug-fix/2026-08-10-minimal-preset-owns-rl-composition.md)
- [DeepSeek V4 technical report](https://arxiv.org/html/2606.19348v1)
- [Microsoft WSL installation](https://learn.microsoft.com/windows/wsl/install)
- [Microsoft WSL filesystem guidance](https://learn.microsoft.com/windows/wsl/filesystems)

## Community evidence (not primary DeepSeek evidence)

- [Anchored Standard implementation and limitations](https://github.com/xiaobright/dsh-anchored-standard/tree/6472c1c9431dcfd9072be23bff781b76fe7146c0)
- [Frozen-task evaluation repository](https://github.com/xiaobright/modeltest)

# Repository validation

Run from the repository root as the normal Linux/Windows user. Tests use frozen inputs, mock package managers and temporary homes. They do not update the installed Harness, edit live profiles, or call a model.

```powershell
wsl.exe -d Ubuntu --cd (Get-Location).Path -- bash tests/run-tests.sh
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test-beginner-guardrails.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test-wsl-distributions.ps1
```

Replace `Ubuntu` with the exact initialized WSL2 distro. From a Linux checkout, run `bash tests/run-tests.sh` directly with supported Linux Node on PATH. The runner names the public suite explicitly because this workspace can also contain untracked local integration experiments.

The Bash suite covers package-manager/provenance checks, managed state, shell escaping, bounded network failures, sudo boundaries, current channel resolution, exact official repository identity, and legacy Anchored status/refusal/removal. Node tests cover first-request gating, persona schema preservation, unknown source refusal and the release fixture hashes. The Windows suite covers WSL opt-in/resource boundaries and single-distro/exact-WSL2 selection, including both entry points.

The [upstream fixture](fixtures/upstream-0.2.0-rc.2/README.md) is release-pinned and public. Keep local recovery/session data outside the published suite. Paid behavior comparisons and live custom-profile acceptance require separate explicit work.

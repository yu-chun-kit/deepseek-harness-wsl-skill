#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$repo_root"
tests=(
  test-native-tool-provenance.sh
  test-network-timeout.sh
  test-package-manager-selection.sh
  test-pnpm-state.sh
  test-profile-escaping.sh
  test-state-record.sh
  test-sudo-boundary.sh
  test-release-channels.sh
  test-anchored-release-boundary.sh
)
for helper in deepseek-harness-wsl/scripts/*.sh; do bash -n "$helper"; done
for entry in "${tests[@]}"; do
  bash -n "tests/$entry"
  bash "tests/$entry"
done
node --test tests/test-anchored-bootstrap.mjs tests/test-anchored-generator.mjs

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="$repo_root/tests/fixtures"
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT

mkdir -p "$test_home/.local/bin" "$test_home/.local/lib/node_modules"
chmod +x "$fixture_dir/npm"

set +e
output=$(
  HOME="$test_home" \
  PATH="$fixture_dir:/usr/bin:/bin" \
  bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
    --action install \
    --package-manager npm \
    --package-version 1.2.3 \
    --fetch-retries 0 \
    --fetch-timeout-seconds 30 \
    --download-attempts 2 \
    --skip-node-install \
    --yes 2>&1
)
status=$?
set -e

[[ $status -ne 0 ]]
[[ $(grep -c 'Install attempt:' <<<"$output") -eq 2 ]]
grep -Fq 'package tarball request timed out inside WSL' <<<"$output"
grep -Fq 'Installation failed after 2 bounded attempt(s)' <<<"$output"
! grep -Eq 'strict-ssl=false|cache clean|curl -k' <<<"$output"

printf 'network-timeout regression test passed\n'

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="$repo_root/tests/fixtures"
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT

mkdir -p \
  "$test_home/bin" \
  "$test_home/.local/bin" \
  "$test_home/.local/lib/node_modules" \
  "$test_home/.local/lib/node_modules/@deepseek-ai/dsh" \
  "$test_home/.local/share/pnpm" \
  "$test_home/.local/share/pnpm/global/node_modules"
cp "$fixture_dir/npm" "$fixture_dir/pnpm" "$test_home/bin/"
chmod +x "$test_home/bin/npm" "$test_home/bin/pnpm"

output=$(
  HOME="$test_home" \
  PATH="$test_home/bin:$test_home/.local/share/pnpm:/usr/bin:/bin" \
  bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
    --action install \
    --package-manager auto \
    --package-version 1.2.3 \
    --fetch-retries 0 \
    --fetch-timeout-seconds 30 \
    --network-concurrency 4 \
    --download-attempts 1 \
    --native-build-tools skip \
    --skip-node-install \
    --dry-run
)

grep -Fq 'Package manager: pnpm (auto-selected)' <<<"$output"
grep -Fq 'Would use pnpm with 0 fetch retries' <<<"$output"
grep -Fq '4 connection(s)' <<<"$output"
grep -Fq 'Native build-tools preflight was skipped by explicit request' <<<"$output"

mkdir -p "$test_home/.local/state/deepseek-harness-wsl"
cp "$fixture_dir/last-install-npm.json" "$test_home/.local/state/deepseek-harness-wsl/last-install.json"

output=$(
  HOME="$test_home" \
  PATH="$test_home/bin:$test_home/.local/share/pnpm:/usr/bin:/bin" \
  bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
    --action install \
    --package-manager auto \
    --package-version 1.2.3 \
    --fetch-retries 0 \
    --fetch-timeout-seconds 30 \
    --download-attempts 1 \
    --skip-node-install \
    --dry-run
)

grep -Fq 'Package manager: npm (auto-selected)' <<<"$output"
grep -Fq 'Would use npm with 0 fetch retries' <<<"$output"
grep -Fq '15 connection(s)' <<<"$output"

cp "$fixture_dir/dsh" "$test_home/.local/bin/dsh"
cp "$fixture_dir/dsh-unrelated" "$test_home/bin/dsh"
cp "$fixture_dir/dsh-package.json" "$test_home/.local/lib/node_modules/@deepseek-ai/dsh/package.json"
cp "$fixture_dir/last-install-legacy.json" "$test_home/.local/state/deepseek-harness-wsl/last-install.json"
chmod +x "$test_home/.local/bin/dsh"
chmod +x "$test_home/bin/dsh"

output=$(
  HOME="$test_home" \
  PATH="$test_home/bin:/usr/bin:/bin" \
  bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
    --action status \
    --package-manager npm
)

grep -Fq "$test_home/.local/bin/dsh (installed; absent from this non-login shell PATH)" <<<"$output"
grep -Fq '1.2.3' <<<"$output"
! grep -Fq 'unrelated-dsh-should-not-run' <<<"$output"

printf 'package-manager selection regression test passed\n'

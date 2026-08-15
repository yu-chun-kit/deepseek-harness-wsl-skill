#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="$repo_root/tests/fixtures"
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT

mkdir -p "$test_home/bin" "$test_home/fake-tools"
cp "$fixture_dir/npm" "$fixture_dir/sudo" "$test_home/bin/"
chmod +x "$test_home/bin/npm" "$test_home/bin/sudo" "$fixture_dir/windows-tool.exe"
for name in make gcc g++ python3; do
  ln -s "$fixture_dir/windows-tool.exe" "$test_home/fake-tools/$name"
done

set +e
output=$(
  HOME="$test_home" \
  PATH="$test_home/fake-tools:$test_home/bin:/usr/bin:/bin" \
  bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
    --action install \
    --package-manager npm \
    --package-version 1.2.3 \
    --native-build-tools auto \
    --skip-node-install \
    --yes 2>&1
)
status=$?
set -e

[[ $status -ne 0 ]]
grep -Fq 'sudo needs an interactive password' <<<"$output"
grep -Fq 'sudo apt-get update && sudo apt-get install -y build-essential python3' <<<"$output"
! grep -Fq 'unexpected sudo invocation' <<<"$output"

printf 'sudo-boundary regression test passed\n'

#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
mkdir -p "$test_home/bin"
cp "$repo_root/tests/fixtures/npm" "$test_home/bin/npm"
chmod +x "$test_home/bin/npm"
export HOME="$test_home" PATH="$test_home/bin:/usr/bin:/bin"
helper="$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh"

for channel in latest next alpha; do
  version=$(node -e 'const fs=require("fs");const j=JSON.parse(fs.readFileSync(process.argv[1]));process.stdout.write(j.distTags[process.argv[2]])' \
    "$repo_root/tests/fixtures/upstream-0.2.0-rc.2/release.json" "$channel")
  export MOCK_NPM_TARGET_VERSION="$version"
  output=$(bash "$helper" --action update --channel "$channel" --native-build-tools skip --skip-node-install --accept-prerelease --dry-run)
  grep -Fq "Would install exact version $version" <<<"$output"
  if bash "$helper" --action update --channel "$channel" --skip-node-install --dry-run >"$test_home/rejected" 2>&1; then
    printf 'Prerelease was accepted without opt-in\n' >&2; exit 1
  fi
  grep -Fq 'is a prerelease. Re-run with -AcceptPrerelease' "$test_home/rejected"
done

export MOCK_NPM_REPOSITORY='https://github.com/deepseek-ai/deepseek-harness-unrelated.git'
if bash "$helper" --action update --accept-prerelease --skip-node-install --dry-run >"$test_home/rejected" 2>&1; then
  printf 'Lookalike repository was accepted\n' >&2; exit 1
fi
grep -Fq 'not the expected official repository' "$test_home/rejected"
printf 'release channel and repository identity regression tests passed\n'

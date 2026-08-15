#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="$repo_root/tests/fixtures"
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT

mkdir -p "$test_home/bin"
cp "$fixture_dir/npm" "$test_home/bin/npm"
chmod +x "$test_home/bin/npm"

HOME="$test_home" \
PATH="$test_home/bin:/usr/bin:/bin" \
MOCK_NPM_INSTALL_SUCCESS=1 \
bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
  --action install \
  --package-manager npm \
  --package-version 1.2.3 \
  --fetch-retries 0 \
  --fetch-timeout-seconds 30 \
  --network-concurrency 4 \
  --download-attempts 1 \
  --native-build-tools skip \
  --skip-node-install \
  --yes >/dev/null

state_file="$test_home/.local/state/deepseek-harness-wsl/last-install.json"
[[ $(stat -c '%a' "$state_file") == 600 ]]
node -e '
  const fs=require("fs");
  const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  if(j.packageManager!=="npm") process.exit(1);
  if(j.packageManagerPath!==process.argv[2]+"/bin/npm") process.exit(2);
  if(j.managedPrefix!==process.argv[2]+"/.local") process.exit(3);
  if(j.managedBin!==process.argv[2]+"/.local/bin") process.exit(4);
' "$state_file" "$test_home"

printf 'managed-state regression test passed\n'

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="$repo_root/tests/fixtures"
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
pnpm_home="$test_home/.local/share/pnpm"

mkdir -p "$test_home/bin" "$pnpm_home/global/node_modules"
cp "$fixture_dir/npm" "$test_home/bin/npm"
cp "$fixture_dir/pnpm" "$pnpm_home/pnpm"
chmod +x "$test_home/bin/npm" "$pnpm_home/pnpm"

HOME="$test_home" \
PATH="$test_home/bin:$pnpm_home:/usr/bin:/bin" \
MOCK_PNPM_INSTALL_SUCCESS=1 \
bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
  --action install \
  --package-manager pnpm \
  --package-version 1.2.3 \
  --native-build-tools skip \
  --skip-node-install \
  --yes >/dev/null

state_file="$test_home/.local/state/deepseek-harness-wsl/last-install.json"
node -e '
  const fs=require("fs");
  const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  if(j.packageManager!=="pnpm") process.exit(1);
  if(j.packageManagerPath!==process.argv[2]+"/pnpm") process.exit(2);
  if(j.managedBin!==process.argv[2]) process.exit(3);
' "$state_file" "$pnpm_home"

output=$(
  HOME="$test_home" \
  PATH="$test_home/bin:/usr/bin:/bin" \
  bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
    --action status \
    --package-manager auto
)
grep -Fq 'Package manager: pnpm (auto-selected)' <<<"$output"
grep -Fq "$pnpm_home/dsh (installed; absent from this non-login shell PATH)" <<<"$output"
grep -Fq '1.2.3' <<<"$output"

output=$(
  HOME="$test_home" \
  PATH="$test_home/bin:/usr/bin:/bin" \
  bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
    --action status \
    --package-manager pnpm
)
grep -Fq 'Package manager: pnpm' <<<"$output"
grep -Fq "$pnpm_home/dsh (installed; absent from this non-login shell PATH)" <<<"$output"

printf 'pnpm-state regression test passed\n'

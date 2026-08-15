#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="$repo_root/tests/fixtures"
test_home=$(mktemp -d)
prefix_root=$(mktemp -d)
trap 'rm -rf -- "$test_home" "$prefix_root"' EXIT
custom_prefix="$prefix_root/prefix space \$(printf-danger) [x]"

mkdir -p "$test_home/bin" "$custom_prefix/bin" "$custom_prefix/lib/node_modules"
cp "$fixture_dir/npm" "$test_home/bin/npm"
chmod +x "$test_home/bin/npm"

HOME="$test_home" \
PATH="$test_home/bin:/usr/bin:/bin" \
NPM_CONFIG_PREFIX="$custom_prefix" \
MOCK_NPM_INSTALL_SUCCESS=1 \
bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
  --action install \
  --package-manager npm \
  --package-version 1.2.3 \
  --native-build-tools skip \
  --skip-node-install \
  --yes >/dev/null

bash -n "$test_home/.profile"
resolved_path=$(
  HOME="$test_home" PATH="$test_home/bin:/usr/bin:/bin" bash -c '. "$HOME/.profile"; printf "%s" "$PATH"'
)
case ":$resolved_path:" in
  *":$custom_prefix/bin:"*) ;;
  *) exit 1 ;;
esac
[[ $(grep -c '# >>> deepseek-harness-wsl npm prefix >>>' "$test_home/.profile") -eq 1 ]]

cp "$fixture_dir/dsh" "$custom_prefix/bin/dsh"
chmod +x "$custom_prefix/bin/dsh"
output=$(
  HOME="$test_home" PATH="$test_home/bin:/usr/bin:/bin" \
  bash "$repo_root/deepseek-harness-wsl/scripts/setup-in-wsl.sh" \
    --action status \
    --package-manager npm
)
grep -Fq "$custom_prefix/bin/dsh (installed; absent from this non-login shell PATH)" <<<"$output"

printf 'profile-escaping regression test passed\n'

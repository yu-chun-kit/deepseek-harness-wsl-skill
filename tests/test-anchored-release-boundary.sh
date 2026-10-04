#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
package_root="$test_home/.local/lib/node_modules/@deepseek-ai/dsh"
target="$test_home/.dsh/.agent-presets/anchored-standard"
mkdir -p "$package_root" "$target"
cp "$repo_root/tests/fixtures/upstream-0.2.0-rc.2/cli-package.json" "$package_root/package.json"
printf '{"owner":"deepseek-harness-wsl-skill"}\n' >"$target/.deepseek-harness-wsl-anchor.json"
printf 'preserve until explicit removal\n' >"$target/sentinel"
export HOME="$test_home" DSH_HOME="$test_home/.dsh" PATH=/usr/bin:/bin
helper="$repo_root/deepseek-harness-wsl/scripts/manage-anchored-presets-in-wsl.sh"
output=$(bash "$helper" --action status --mode standard)
grep -Fq 'legacy source layout unavailable' <<<"$output"
grep -Fq 'legacy managed copy remains' <<<"$output"
for action in install update; do
  if bash "$helper" --action "$action" --mode standard --dry-run >"$test_home/rejected" 2>&1; then
    printf 'Bundle release was accepted for legacy generation\n' >&2; exit 1
  fi
  grep -Fq 'Anchored generation is unsupported for Harness 0.2.0-rc.2' "$test_home/rejected"
  [[ -f $target/sentinel ]]
done
bash "$helper" --action uninstall --mode standard --dry-run >/dev/null
[[ -f $target/sentinel ]]
# Removal must work even after the official package has been uninstalled.
rm -- "$package_root/package.json"
bash "$helper" --action uninstall --mode standard --yes >/dev/null
[[ ! -e $target ]]
mkdir -p "$target"
printf 'unmanaged\n' >"$target/sentinel"
if bash "$helper" --action uninstall --mode standard --yes >"$test_home/rejected" 2>&1; then
  printf 'Unmanaged preset was removed\n' >&2; exit 1
fi
[[ -f $target/sentinel ]]
printf 'anchored current-release and ownership boundary regression tests passed\n'

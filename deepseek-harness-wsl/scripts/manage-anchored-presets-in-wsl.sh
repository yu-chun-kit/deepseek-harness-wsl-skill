#!/usr/bin/env bash
set -euo pipefail

ACTION='status'
MODE='all'
ASSUME_YES=0
DRY_RUN=0
OWNER='deepseek-harness-wsl-skill'
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
GENERATOR="$SCRIPT_DIR/generate-anchored-preset.mjs"
PLUGIN="$SCRIPT_DIR/../assets/anchored-presets/anchored-tool-bootstrap.mjs"

while (($#)); do
  case "$1" in
    --action) ACTION="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --yes) ASSUME_YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

case "$ACTION" in status|install|update|uninstall) ;; *) printf 'Invalid action: %s\n' "$ACTION" >&2; exit 2 ;; esac
case "$MODE" in standard|code|cordis|all) ;; *) printf 'Invalid mode: %s\n' "$MODE" >&2; exit 2 ;; esac
if [[ $EUID -eq 0 && $ACTION != status && $DRY_RUN -eq 0 ]]; then
  printf 'Refusing to change presets as root. Run as the normal Harness Linux user.\n' >&2
  exit 3
fi
command -v node >/dev/null 2>&1 || { printf 'Linux Node.js is required. Install Harness first.\n' >&2; exit 4; }
[[ $(node -p 'process.platform' 2>/dev/null) == linux ]] || { printf 'Refusing a non-Linux Node.js runtime.\n' >&2; exit 4; }
[[ -r $GENERATOR && -r $PLUGIN ]] || { printf 'Anchored preset assets are incomplete.\n' >&2; exit 4; }

confirm() {
  ((ASSUME_YES)) && return 0
  local reply=''
  read -r -p "$1 [y/N] " reply
  [[ $reply == y || $reply == Y ]]
}

package_is_official() {
  local candidate="$1"
  [[ -r $candidate/package.json && -d $candidate/config/agent-presets ]] || return 1
  [[ $(node -e 'const p=require(process.argv[1]);process.stdout.write(p.name||"")' "$candidate/package.json" 2>/dev/null) == '@deepseek-ai/dsh' ]]
}

find_package_root() {
  local candidate='' npm_root='' pnpm_root=''
  for candidate in "$HOME/.local/lib/node_modules/@deepseek-ai/dsh"; do
    package_is_official "$candidate" && { printf '%s\n' "$candidate"; return 0; }
  done
  if command -v npm >/dev/null 2>&1; then
    npm_root=$(npm root --global 2>/dev/null || true)
    candidate="$npm_root/@deepseek-ai/dsh"
    package_is_official "$candidate" && { printf '%s\n' "$candidate"; return 0; }
  fi
  if command -v pnpm >/dev/null 2>&1; then
    pnpm_root=$(pnpm root --global 2>/dev/null || true)
    candidate="$pnpm_root/@deepseek-ai/dsh"
    package_is_official "$candidate" && { printf '%s\n' "$candidate"; return 0; }
  fi
  printf 'Could not locate the official @deepseek-ai/dsh package in this Linux user environment.\n' >&2
  return 1
}

PACKAGE_ROOT=$(find_package_root)
HARNESS_VERSION=$(node -e 'const p=require(process.argv[1]);process.stdout.write(p.version||"unknown")' "$PACKAGE_ROOT/package.json")
DSH_HOME_RESOLVED=${DSH_HOME:-"$HOME/.dsh"}
case "$DSH_HOME_RESOLVED" in /*) ;; *) printf 'DSH_HOME must be an absolute Linux path.\n' >&2; exit 4 ;; esac
case "$DSH_HOME_RESOLVED" in /mnt/*) printf 'Refusing to manage agent presets on a Windows-mounted path.\n' >&2; exit 4 ;; esac
PRESET_PARENT="$DSH_HOME_RESOLVED/.agent-presets"
MODES=(standard code cordis)
[[ $MODE == all ]] || MODES=("$MODE")

is_managed_target() {
  local target="$1" manifest="$target/.deepseek-harness-wsl-anchor.json"
  [[ -r $manifest ]] || return 1
  [[ $(node -e 'const fs=require("fs");try{const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(j.owner||"")}catch{}' "$manifest") == "$OWNER" ]]
}

source_hash() {
  node -e 'const fs=require("fs"),c=require("crypto");process.stdout.write(c.createHash("sha256").update(fs.readFileSync(process.argv[1])).digest("hex"))' "$1"
}

show_status() {
  local mode="$1" source="$PACKAGE_ROOT/config/agent-presets/$mode" target="$PRESET_PARENT/anchored-$mode"
  [[ -r $source/agent.cordis.yml ]] || { printf '%s: official source preset is missing\n' "$mode"; return; }
  if ! is_managed_target "$target"; then
    if [[ -e $target ]]; then printf '%s: unmanaged target exists; it will not be overwritten\n' "$mode"
    else printf '%s: not installed\n' "$mode"; fi
    return
  fi
  local recorded current
  recorded=$(node -e 'const fs=require("fs"),j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(j.sourceAgentCordisSha256||"")' "$target/.deepseek-harness-wsl-anchor.json")
  current=$(source_hash "$source/agent.cordis.yml")
  if [[ $recorded == "$current" ]]; then printf '%s: installed and current for Harness %s\n' "$mode" "$HARNESS_VERSION"
  else printf '%s: installed but source preset changed; run update after review\n' "$mode"; fi
}

install_one() {
  local mode="$1" source="$PACKAGE_ROOT/config/agent-presets/$mode" target="$PRESET_PARENT/anchored-$mode"
  [[ -r $source/agent.cordis.yml && -r $source/preset.yml ]] || { printf 'Official source preset is missing: %s\n' "$mode" >&2; return 1; }
  if [[ -e $target ]] && ! is_managed_target "$target"; then
    printf 'Refusing to overwrite unmanaged preset: %s\n' "$target" >&2
    return 1
  fi
  if [[ $ACTION == install && -e $target ]]; then
    printf '%s: already installed; use update to regenerate it\n' "$mode"
    return 0
  fi
  if ((DRY_RUN)); then
    printf 'Would generate anchored-%s from official Harness %s into %s\n' "$mode" "$HARNESS_VERSION" "$target"
    return 0
  fi
  mkdir -p -- "$PRESET_PARENT"
  local stage_parent stage backup
  stage_parent=$(mktemp -d "$PRESET_PARENT/.anchor-stage.XXXXXX")
  stage="$stage_parent/anchored-$mode"
  backup="$PRESET_PARENT/.anchored-$mode.backup.$$"
  node "$GENERATOR" "$source" "$stage" "$PLUGIN" "$mode" "$HARNESS_VERSION"
  if [[ -e $target ]]; then mv -- "$target" "$backup"; fi
  if ! mv -- "$stage" "$target"; then
    [[ -e $backup ]] && mv -- "$backup" "$target"
    rm -rf -- "$stage_parent"
    return 1
  fi
  rm -rf -- "$backup" "$stage_parent"
  printf '%s: generated from official Harness %s\n' "$mode" "$HARNESS_VERSION"
}

preflight_all() {
  local stage_parent mode source
  mkdir -p -- "$PRESET_PARENT"
  stage_parent=$(mktemp -d "$PRESET_PARENT/.anchor-preflight.XXXXXX")
  for mode in "${MODES[@]}"; do
    source="$PACKAGE_ROOT/config/agent-presets/$mode"
    if ! node "$GENERATOR" "$source" "$stage_parent/anchored-$mode" "$PLUGIN" "$mode" "$HARNESS_VERSION"; then
      rm -rf -- "$stage_parent"
      printf 'No preset was replaced because the complete generation preflight failed.\n' >&2
      return 1
    fi
  done
  rm -rf -- "$stage_parent"
}

uninstall_one() {
  local mode="$1" target="$PRESET_PARENT/anchored-$mode"
  if [[ ! -e $target ]]; then printf '%s: not installed\n' "$mode"; return 0; fi
  is_managed_target "$target" || { printf 'Refusing to remove unmanaged preset: %s\n' "$target" >&2; return 1; }
  if ((DRY_RUN)); then printf 'Would remove managed preset %s\n' "$target"; return 0; fi
  rm -rf -- "$target"
  printf '%s: removed; official presets and sessions were preserved\n' "$mode"
}

printf 'Harness:      @deepseek-ai/dsh@%s\n' "$HARNESS_VERSION"
printf 'Package root: %s\n' "$PACKAGE_ROOT"
printf 'Preset root:  %s\n' "$PRESET_PARENT"

case "$ACTION" in
  status) for mode in "${MODES[@]}"; do show_status "$mode"; done ;;
  install|update)
    ((DRY_RUN)) || confirm "Generate experimental anchored preset(s): ${MODES[*]}?" || { printf 'Cancelled.\n'; exit 0; }
    ((DRY_RUN)) || preflight_all
    for mode in "${MODES[@]}"; do install_one "$mode"; done
    ;;
  uninstall)
    ((DRY_RUN)) || confirm "Remove only the managed anchored preset(s): ${MODES[*]}?" || { printf 'Cancelled.\n'; exit 0; }
    for mode in "${MODES[@]}"; do uninstall_one "$mode"; done
    ;;
esac

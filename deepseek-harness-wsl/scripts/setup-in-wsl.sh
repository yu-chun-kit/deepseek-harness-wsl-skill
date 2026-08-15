#!/usr/bin/env bash
set -euo pipefail

PACKAGE='@deepseek-ai/dsh'
REGISTRY='https://registry.npmjs.org/'
OFFICIAL_REPOSITORY='github.com/deepseek-ai/deepseek-harness'
ACTION='install'
CHANNEL='latest'
PACKAGE_VERSION=''
NVM_VERSION='v0.40.6'
NVM_COMMIT='18f62ba4e8e2148383332fb1ac8b2ff1ee21a263'
ACCEPT_PRERELEASE=0
ASSUME_YES=0
SKIP_NODE_INSTALL=0
DRY_RUN=0

while (($#)); do
  case "$1" in
    --action) ACTION="$2"; shift 2 ;;
    --channel) CHANNEL="$2"; shift 2 ;;
    --package-version) PACKAGE_VERSION="$2"; shift 2 ;;
    --accept-prerelease) ACCEPT_PRERELEASE=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    --skip-node-install) SKIP_NODE_INSTALL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

case "$ACTION" in status|install|update|uninstall) ;; *) printf 'Invalid action: %s\n' "$ACTION" >&2; exit 2 ;; esac
case "$CHANNEL" in latest|next) ;; *) printf 'Invalid channel: %s\n' "$CHANNEL" >&2; exit 2 ;; esac

if [[ ${EUID} -eq 0 && $ACTION != status && $DRY_RUN -eq 0 ]]; then
  printf 'Refusing to install Harness as root. Complete distro first-run and rerun as the normal Linux user.\n' >&2
  exit 3
fi

confirm() {
  local prompt="$1"
  if ((ASSUME_YES)); then return 0; fi
  read -r -p "$prompt [y/N] " reply
  [[ $reply == y || $reply == Y ]]
}

load_nvm() {
  local nvm_dir="${NVM_DIR:-"$HOME/.nvm"}"
  local actual_nvm_commit
  if [[ -s "$nvm_dir/nvm.sh" ]]; then
    export NVM_DIR="$nvm_dir"
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
  fi
}

linux_node_is_compatible() {
  command -v node >/dev/null 2>&1 || return 1
  [[ $(node -p 'process.platform' 2>/dev/null) == linux ]] || return 1
  local node_path major
  node_path=$(command -v node)
  [[ $node_path != /mnt/* && $node_path != *.exe ]] || return 1
  major=$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null)
  ((major >= 20))
}

ensure_prerequisites() {
  local missing=()
  command -v git >/dev/null 2>&1 || missing+=(git)
  command -v curl >/dev/null 2>&1 || missing+=(curl)
  [[ -r /etc/ssl/certs/ca-certificates.crt ]] || missing+=(ca-certificates)
  ((${#missing[@]} == 0)) && return 0
  printf 'Missing Linux prerequisites: %s\n' "${missing[*]}"
  ((DRY_RUN)) && return 1
  confirm 'Install missing prerequisites with apt and sudo?' || return 1
  sudo apt-get update
  sudo apt-get install -y git curl ca-certificates
}

ensure_node() {
  load_nvm
  if linux_node_is_compatible; then
    printf 'Using Linux Node.js %s at %s\n' "$(node --version)" "$(command -v node)"
    return 0
  fi
  if ((SKIP_NODE_INSTALL)); then
    printf 'Compatible Linux Node.js 20+ was not found and installation was disabled.\n' >&2
    return 1
  fi
  if ((DRY_RUN)); then
    ensure_prerequisites || true
    printf 'Would install current Node.js LTS through pinned nvm tag %s.\n' "$NVM_VERSION"
    printf 'Would verify nvm commit %s before execution.\n' "$NVM_COMMIT"
    printf 'Would back up and append one marked nvm loader block to ~/.profile if needed.\n'
    printf 'After Linux Node/npm exists, a second preview resolves the npm channel, verifies official repository and integrity metadata, and shows the exact package version.\n'
    printf 'This is a phase-one preview; no npm target was resolved because compatible Linux Node/npm is not available yet.\n'
    return 1
  fi
  confirm "Install Node.js LTS through nvm $NVM_VERSION?" || return 1
  ensure_prerequisites

  local nvm_dir="${NVM_DIR:-"$HOME/.nvm"}"
  if [[ -e "$nvm_dir" && ! -d "$nvm_dir/.git" ]]; then
    printf '%s exists but is not an nvm Git checkout; refusing to overwrite it.\n' "$nvm_dir" >&2
    return 1
  fi
  if [[ ! -d "$nvm_dir/.git" ]]; then
    git clone --filter=blob:none https://github.com/nvm-sh/nvm.git "$nvm_dir"
  fi
  git -C "$nvm_dir" fetch --tags --prune origin
  git -C "$nvm_dir" rev-parse --verify "refs/tags/$NVM_VERSION" >/dev/null
  git -C "$nvm_dir" checkout --detach "$NVM_VERSION"
  actual_nvm_commit=$(git -C "$nvm_dir" rev-parse HEAD)
  if [[ $actual_nvm_commit != "$NVM_COMMIT" ]]; then
    printf 'Pinned nvm tag resolved to unexpected commit %s. Expected %s.\n' "$actual_nvm_commit" "$NVM_COMMIT" >&2
    return 1
  fi

  export NVM_DIR="$nvm_dir"
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use --lts

  local profile="$HOME/.profile" marker_begin='# >>> deepseek-harness-wsl nvm >>>'
  if ! grep -Fq "$marker_begin" "$profile" 2>/dev/null; then
    [[ -f "$profile" ]] && cp -p "$profile" "$profile.deepseek-harness-wsl.bak.$(date +%Y%m%d%H%M%S)"
    {
      printf '\n%s\n' "$marker_begin"
      printf 'export NVM_DIR="$HOME/.nvm"\n'
      printf '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n'
      printf '%s\n' '# <<< deepseek-harness-wsl nvm <<<'
    } >>"$profile"
  fi

  linux_node_is_compatible || { printf 'Installed Node.js failed Linux provenance checks.\n' >&2; return 1; }
}

installed_version() {
  { npm list --global "$PACKAGE" --depth=0 --json 2>/dev/null || true; } |
    node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);console.log(j.dependencies?.[process.argv[1]]?.version||"")}catch{console.log("")}})' "$PACKAGE"
}

resolve_target() {
  if [[ -n "$PACKAGE_VERSION" ]]; then
    printf '%s\n' "$PACKAGE_VERSION"
  else
    npm view "$PACKAGE" "dist-tags.$CHANNEL" --json --registry="$REGISTRY" | tr -d '"\r\n'
  fi
}

verify_metadata() {
  local version="$1" repository integrity
  repository=$(npm view "$PACKAGE@$version" repository.url --json --registry="$REGISTRY" | tr -d '"\r\n')
  integrity=$(npm view "$PACKAGE@$version" dist.integrity --json --registry="$REGISTRY" | tr -d '"\r\n')
  printf 'Registry:      %s\n' "$REGISTRY"
  printf 'Package:       %s\n' "$PACKAGE"
  printf 'Target:        %s\n' "$version"
  printf 'Repository:    %s\n' "$repository"
  printf 'Integrity:     %s\n' "$integrity"
  [[ $repository == *"$OFFICIAL_REPOSITORY"* ]] || { printf 'Package repository is not the expected official repository.\n' >&2; return 1; }
  [[ -n $integrity && $integrity != null ]] || { printf 'Package integrity metadata is missing.\n' >&2; return 1; }
}

show_status() {
  printf 'WSL kernel:    %s\n' "$(uname -r)"
  printf 'Architecture:  %s\n' "$(uname -m)"
  printf 'Linux user:    %s (uid %s)\n' "$(id -un)" "$(id -u)"
  if [[ ${EUID} -eq 0 ]]; then
    printf 'Warning:       mutations are blocked for root; finish distro user initialization first.\n'
  fi
  if command -v node >/dev/null 2>&1; then
    printf 'Node:          %s (%s, %s)\n' "$(node --version 2>/dev/null || true)" "$(command -v node)" "$(node -p process.platform 2>/dev/null || true)"
  else
    printf 'Node:          not found\n'
  fi
  load_nvm
  if command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    printf 'npm:           %s (%s)\n' "$(npm --version)" "$(command -v npm)"
    printf 'Harness:       %s\n' "$(installed_version)"
  else
    printf 'npm/Harness:   not available\n'
  fi
  if command -v dsh >/dev/null 2>&1; then
    printf 'dsh path:      %s\n' "$(command -v dsh)"
    timeout 10s dsh --version || printf 'dsh --version did not exit successfully within 10 seconds.\n'
  else
    printf 'dsh path:      not found\n'
  fi
}

if [[ $ACTION == status ]]; then
  show_status
  exit 0
fi

load_nvm
if [[ $ACTION == uninstall ]]; then
  ensure_node
  current=$(installed_version)
  if [[ -z $current ]]; then
    printf '%s is not installed in the active Linux npm prefix.\n' "$PACKAGE"
    exit 0
  fi
  printf 'Installed:     %s\n' "$current"
  ((DRY_RUN)) && { printf 'Would uninstall only %s; user data and Node.js would be preserved.\n' "$PACKAGE"; exit 0; }
  confirm "Uninstall $PACKAGE $current and preserve Harness data?" || exit 4
  npm uninstall --global "$PACKAGE" --registry="$REGISTRY"
  exit 0
fi

if ! linux_node_is_compatible; then
  ensure_node || { ((DRY_RUN)) && exit 0; exit 5; }
fi

target=$(resolve_target)
[[ -n $target && $target != null ]] || { printf 'Could not resolve an npm target version.\n' >&2; exit 6; }
verify_metadata "$target"
current=$(installed_version)
printf 'Installed:     %s\n' "${current:-not installed}"

if [[ $target == *-* ]] && ((ACCEPT_PRERELEASE == 0)); then
  printf 'Target %s is a prerelease. Re-run with -AcceptPrerelease after reviewing it.\n' "$target" >&2
  exit 7
fi

if [[ $current == "$target" ]]; then
  printf 'The requested exact version is already installed.\n'
  show_status
  exit 0
fi

if ((DRY_RUN)); then
  printf 'Would install exact version %s (current: %s).\n' "$target" "${current:-none}"
  exit 0
fi

confirm "Install exact version $PACKAGE@$target (current: ${current:-none})?" || exit 4
npm install --global "$PACKAGE@$target" --registry="$REGISTRY"

state_dir="$HOME/.local/state/deepseek-harness-wsl"
mkdir -p "$state_dir"
printf '{"previous":"%s","installed":"%s","timestamp":"%s"}\n' \
  "${current:-}" "$target" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$state_dir/last-install.json"

actual=$(installed_version)
[[ $actual == "$target" ]] || { printf 'Installed version %s does not match target %s.\n' "$actual" "$target" >&2; exit 8; }
show_status

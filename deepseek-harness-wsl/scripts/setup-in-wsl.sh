#!/usr/bin/env bash
set -euo pipefail

PACKAGE='@deepseek-ai/dsh'
REGISTRY='https://registry.npmjs.org/'
OFFICIAL_REPOSITORY='github.com/deepseek-ai/deepseek-harness'
ACTION='install'
CHANNEL='latest'
PACKAGE_VERSION=''
PACKAGE_MANAGER='auto'
SELECTED_PACKAGE_MANAGER=''
FETCH_RETRIES=4
FETCH_TIMEOUT_SECONDS=300
NETWORK_CONCURRENCY=15
DOWNLOAD_ATTEMPTS=2
NATIVE_BUILD_TOOLS='auto'
NVM_VERSION='v0.40.6'
NVM_COMMIT='18f62ba4e8e2148383332fb1ac8b2ff1ee21a263'
ACCEPT_PRERELEASE=0
ASSUME_YES=0
SKIP_NODE_INSTALL=0
DRY_RUN=0
INITIAL_PATH="$PATH"

while (($#)); do
  case "$1" in
    --action) ACTION="$2"; shift 2 ;;
    --channel) CHANNEL="$2"; shift 2 ;;
    --package-version) PACKAGE_VERSION="$2"; shift 2 ;;
    --package-manager) PACKAGE_MANAGER="$2"; shift 2 ;;
    --fetch-retries) FETCH_RETRIES="$2"; shift 2 ;;
    --fetch-timeout-seconds) FETCH_TIMEOUT_SECONDS="$2"; shift 2 ;;
    --network-concurrency) NETWORK_CONCURRENCY="$2"; shift 2 ;;
    --download-attempts) DOWNLOAD_ATTEMPTS="$2"; shift 2 ;;
    --native-build-tools) NATIVE_BUILD_TOOLS="$2"; shift 2 ;;
    --accept-prerelease) ACCEPT_PRERELEASE=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    --skip-node-install) SKIP_NODE_INSTALL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

case "$ACTION" in status|install|update|uninstall) ;; *) printf 'Invalid action: %s\n' "$ACTION" >&2; exit 2 ;; esac
case "$CHANNEL" in latest|next) ;; *) printf 'Invalid channel: %s\n' "$CHANNEL" >&2; exit 2 ;; esac
case "$PACKAGE_MANAGER" in auto|npm|pnpm) ;; *) printf 'Invalid package manager: %s\n' "$PACKAGE_MANAGER" >&2; exit 2 ;; esac
[[ $FETCH_RETRIES =~ ^([0-9]|10)$ ]] || { printf 'Fetch retries must be from 0 through 10.\n' >&2; exit 2; }
[[ $FETCH_TIMEOUT_SECONDS =~ ^[0-9]+$ ]] && ((FETCH_TIMEOUT_SECONDS >= 30 && FETCH_TIMEOUT_SECONDS <= 900)) || {
  printf 'Fetch timeout must be from 30 through 900 seconds.\n' >&2; exit 2
}
[[ $NETWORK_CONCURRENCY =~ ^[0-9]+$ ]] && ((NETWORK_CONCURRENCY >= 1 && NETWORK_CONCURRENCY <= 50)) || {
  printf 'Network concurrency must be from 1 through 50.\n' >&2; exit 2
}
[[ $DOWNLOAD_ATTEMPTS =~ ^[123]$ ]] || { printf 'Download attempts must be from 1 through 3.\n' >&2; exit 2; }
case "$NATIVE_BUILD_TOOLS" in auto|skip) ;; *) printf 'Invalid native build-tools policy: %s\n' "$NATIVE_BUILD_TOOLS" >&2; exit 2 ;; esac

export npm_config_fetch_retries="$FETCH_RETRIES"
export npm_config_fetch_timeout="$((FETCH_TIMEOUT_SECONDS * 1000))"
export npm_config_fetch_retry_mintimeout=10000
export npm_config_fetch_retry_maxtimeout=60000
export npm_config_maxsockets="$NETWORK_CONCURRENCY"

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
  if [[ -s "$nvm_dir/nvm.sh" ]]; then
    export NVM_DIR="$nvm_dir"
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
  fi
}

linux_node_is_compatible() {
  command -v node >/dev/null 2>&1 || return 1
  [[ $(node -p 'process.platform' 2>/dev/null) == linux ]] || return 1
  local node_path major minor
  node_path=$(command -v node)
  [[ $node_path != /mnt/* && $node_path != *.exe ]] || return 1
  major=$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null)
  minor=$(node -p 'Number(process.versions.node.split(".")[1])' 2>/dev/null)
  ((major == 22 && minor >= 19 || major >= 24))
}

linux_pnpm_is_usable() {
  command -v pnpm >/dev/null 2>&1 || return 1
  local pnpm_path global_bin
  pnpm_path=$(command -v pnpm)
  [[ $pnpm_path != /mnt/* && $pnpm_path != *.exe && $pnpm_path != *.cmd ]] || return 1
  pnpm --version >/dev/null 2>&1 || return 1
  global_bin=$(pnpm bin --global 2>/dev/null) || return 1
  [[ -n $global_bin && $global_bin != /mnt/* ]] || return 1
  [[ $global_bin == "$HOME" || $global_bin == "$HOME/"* ]] || return 1
  [[ ! -e $global_bin || -w $global_bin ]] || return 1
  path_contains "$global_bin" || return 1
}

select_package_manager() {
  local state_file="$HOME/.local/state/deepseek-harness-wsl/last-install.json" recorded=''
  case "$PACKAGE_MANAGER" in
    npm) SELECTED_PACKAGE_MANAGER='npm' ;;
    pnpm)
      restore_recorded_pnpm_environment
      if ! linux_pnpm_is_usable; then
        printf 'Explicit pnpm selection requires an existing Linux-native pnpm with a writable user global bin directory.\n' >&2
        printf 'Install/configure pnpm separately from its official instructions, or use -PackageManager npm/auto.\n' >&2
        return 1
      fi
      SELECTED_PACKAGE_MANAGER='pnpm'
      ;;
    auto)
      if [[ -r $state_file ]]; then
        recorded=$(node -e 'const fs=require("fs");try{const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log(j.packageManager||"npm")}catch{}' "$state_file" 2>/dev/null || true)
      fi
      if [[ $recorded == pnpm ]]; then
        restore_recorded_pnpm_environment
        if ! linux_pnpm_is_usable; then
          printf 'The previous managed install used pnpm, but that Linux pnpm global location is no longer usable.\n' >&2
          printf 'Repair pnpm or explicitly select npm after reviewing the migration; auto will not create a duplicate install.\n' >&2
          return 1
        fi
        SELECTED_PACKAGE_MANAGER='pnpm'
      elif [[ $recorded == npm ]]; then
        SELECTED_PACKAGE_MANAGER='npm'
      elif linux_pnpm_is_usable; then
        SELECTED_PACKAGE_MANAGER='pnpm'
      else
        SELECTED_PACKAGE_MANAGER='npm'
      fi
      ;;
  esac
  printf 'Package manager: %s' "$SELECTED_PACKAGE_MANAGER"
  if [[ $PACKAGE_MANAGER == auto ]]; then printf ' (auto-selected)'; fi
  printf '\n'
}

state_value() {
  local key="$1" state_file="$HOME/.local/state/deepseek-harness-wsl/last-install.json"
  [[ -r $state_file ]] || return 1
  node -e 'const fs=require("fs");try{const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));const v=j[process.argv[2]];if(typeof v==="string")process.stdout.write(v)}catch{}' \
    "$state_file" "$key" 2>/dev/null
}

restore_recorded_pnpm_environment() {
  local manager_path='' managed_bin='' candidate=''
  manager_path=$(state_value packageManagerPath || true)
  managed_bin=$(state_value managedBin || true)
  if [[ -z $manager_path ]]; then
    candidate="$HOME/.local/share/pnpm/pnpm"
    [[ -x $candidate ]] && manager_path="$candidate"
  fi
  if [[ -n $manager_path && $manager_path == "$HOME/"* && $manager_path != /mnt/* && -x $manager_path ]]; then
    path_contains "$(dirname -- "$manager_path")" || export PATH="$(dirname -- "$manager_path"):$PATH"
  fi
  if [[ -n $managed_bin && $managed_bin == "$HOME/"* && $managed_bin != /mnt/* && -d $managed_bin && -w $managed_bin ]]; then
    path_contains "$managed_bin" || export PATH="$managed_bin:$PATH"
  fi
}

restore_recorded_npm_prefix() {
  local recorded_prefix=''
  recorded_prefix=$(state_value managedPrefix || true)
  if [[ -z $recorded_prefix && -r "$HOME/.local/lib/node_modules/@deepseek-ai/dsh/package.json" ]]; then
    recorded_prefix="$HOME/.local"
  fi
  [[ -n $recorded_prefix ]] || return 0
  if [[ $recorded_prefix != /* || $recorded_prefix == /mnt/* || ! -d $recorded_prefix || ! -w $recorded_prefix ]]; then
    printf 'Ignoring recorded npm prefix that is not an existing writable Linux path: %s\n' "$recorded_prefix" >&2
    return 0
  fi
  export NPM_CONFIG_PREFIX="$recorded_prefix"
}

linux_path_is_executable() {
  local command_path="$1" resolved_path
  [[ -n $command_path && $command_path != /mnt/* && $command_path != *.exe && $command_path != *.cmd ]] || return 1
  resolved_path=$(readlink -f -- "$command_path" 2>/dev/null || true)
  [[ -n $resolved_path && $resolved_path != /mnt/* && $resolved_path != *.exe && $resolved_path != *.cmd && -x $resolved_path ]]
}

linux_command_is_usable() {
  local command_path
  command_path=$(command -v "$1" 2>/dev/null || true)
  linux_path_is_executable "$command_path"
}

ensure_prerequisites() {
  local include_native="${1:-0}" missing=() sudo_args=()
  command -v git >/dev/null 2>&1 || missing+=(git)
  command -v curl >/dev/null 2>&1 || missing+=(curl)
  [[ -r /etc/ssl/certs/ca-certificates.crt ]] || missing+=(ca-certificates)
  if [[ $include_native == 1 ]]; then
    if ! linux_command_is_usable make ||
       ! linux_command_is_usable gcc ||
       ! linux_command_is_usable g++; then
      missing+=(build-essential)
    fi
    linux_command_is_usable python3 || missing+=(python3)
  fi
  ((${#missing[@]} == 0)) && return 0
  printf 'Missing Linux prerequisite packages: %s\n' "${missing[*]}"
  if ((DRY_RUN)); then
    printf 'Would refresh the Ubuntu package index and install only these packages; no full upgrade.\n'
    return 1
  fi
  confirm 'Install missing prerequisites with apt and sudo?' || return 1
  if ! command -v sudo >/dev/null 2>&1; then
    printf 'sudo is unavailable in this distribution. Configure an initialized admin-capable Linux user, then rerun.\n' >&2
    printf 'The helper will not switch the whole installation to root.\n' >&2
    return 1
  fi
  if sudo -n true 2>/dev/null; then
    sudo_args=(-n)
  else
    if [[ -t 0 ]]; then
      sudo -v
    else
      printf 'sudo needs an interactive password. Open this WSL distribution, run:\n' >&2
      printf '  sudo apt-get update && sudo apt-get install -y' >&2
      printf ' %q' "${missing[@]}" >&2
      printf '\nThen rerun the same Skill command. The helper will not bypass this boundary with wsl -u root.\n' >&2
      return 1
    fi
  fi
  sudo "${sudo_args[@]}" apt-get update
  sudo "${sudo_args[@]}" apt-get install -y "${missing[@]}"
}

ensure_node() {
  load_nvm
  if linux_node_is_compatible; then
    printf 'Using Linux Node.js %s at %s\n' "$(node --version)" "$(command -v node)"
    return 0
  fi
  if ((SKIP_NODE_INSTALL)); then
    printf 'A Linux Node.js version in the current official source support range (22.19+ or 24+) was not found and installation was disabled.\n' >&2
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
  local actual_nvm_commit
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

npm_prefix_is_writable() {
  local prefix="$1" global_root="$2" bin_dir="$1/bin"
  if [[ $prefix == "$HOME" || $prefix == "$HOME/"* ]]; then
    [[ -w $HOME ]] || return 1
    [[ ! -e $prefix || -w $prefix ]] || return 1
    [[ ! -e $global_root || -w $global_root ]] || return 1
    return
  fi
  [[ -d $prefix && -w $prefix ]] || return 1
  [[ -d $global_root && -w $global_root ]] || return 1
  [[ -d $bin_dir && -w $bin_dir ]] || return 1
}

path_contains() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

path_value_contains() {
  local path_value="$1" candidate="$2"
  case ":$path_value:" in
    *":$candidate:"*) return 0 ;;
    *) return 1 ;;
  esac
}

persist_npm_prefix() {
  local prefix="$1" persist_prefix="$2" quoted_prefix quoted_bin
  local profile="$HOME/.profile"
  local marker_begin='# >>> deepseek-harness-wsl npm prefix >>>'
  local marker_end='# <<< deepseek-harness-wsl npm prefix <<<'
  printf -v quoted_prefix '%q' "$prefix"
  printf -v quoted_bin '%q' "$prefix/bin"

  if grep -Fq "$marker_begin" "$profile" 2>/dev/null; then
    if { grep -Fq "__dsh_managed_bin=$quoted_bin" "$profile" ||
         grep -Fq "export PATH=\"$prefix/bin:\$PATH\"" "$profile"; } &&
       { [[ $persist_prefix == 0 ]] || grep -Fq "export NPM_CONFIG_PREFIX=$quoted_prefix" "$profile" ||
         grep -Fq "export NPM_CONFIG_PREFIX=\"$prefix\"" "$profile"; }; then
      return 0
    fi
    printf 'Existing managed npm prefix block in %s does not match target %s; refusing to overwrite it.\n' "$profile" "$prefix" >&2
    return 1
  fi

  [[ -f $profile ]] && cp -p "$profile" "$profile.deepseek-harness-wsl.bak.$(date +%Y%m%d%H%M%S)"
  {
    printf '\n%s\n' "$marker_begin"
    if [[ $persist_prefix == 1 ]]; then
      printf 'export NPM_CONFIG_PREFIX=%s\n' "$quoted_prefix"
    fi
    printf '__dsh_managed_bin=%s\n' "$quoted_bin"
    printf 'case ":$PATH:" in *":${__dsh_managed_bin}:"*) ;; *) export PATH="${__dsh_managed_bin}:$PATH" ;; esac\n'
    printf 'unset __dsh_managed_bin\n'
    printf '%s\n' "$marker_end"
  } >>"$profile"
}

configure_npm_prefix() {
  local current_prefix global_root target_prefix persist_prefix=0 reason='' path_was_present=0
  local original_package_dir original_version
  current_prefix=$(npm prefix --global 2>/dev/null || true)
  global_root=$(npm root --global 2>/dev/null || true)
  [[ -n $current_prefix && -n $global_root ]] || { printf 'Unable to resolve npm global prefix/root.\n' >&2; return 1; }

  target_prefix="$current_prefix"
  path_contains "$current_prefix/bin" && path_was_present=1
  if ! npm_prefix_is_writable "$current_prefix" "$global_root"; then
    target_prefix="$HOME/.local"
    persist_prefix=1
    reason="effective npm prefix $current_prefix is not writable by $(id -un)"
    if [[ $target_prefix == "$current_prefix" ]]; then
      printf 'User npm prefix %s exists but is not writable; refusing to change ownership or use sudo.\n' "$target_prefix" >&2
      return 1
    fi
  fi
  if [[ $target_prefix == "$HOME/.local" ]]; then
    persist_prefix=1
  fi

  if [[ $target_prefix != "$current_prefix" ]]; then
    original_package_dir="$global_root/@deepseek-ai/dsh"
    original_version=$(installed_version)
    if [[ -e $original_package_dir && -z $original_version ]]; then
      printf 'Warning:       unmanaged partial residue exists in unwritable prefix: %s\n' "$original_package_dir"
      printf '               It will be left untouched while the user-owned prefix is installed.\n'
    elif [[ -n $original_version ]]; then
      printf 'Warning:       Harness %s exists in unwritable prefix %s.\n' "$original_version" "$current_prefix"
      printf '               It will be left untouched; the user-owned prefix will take precedence in PATH.\n'
    fi
  fi

  printf 'npm prefix:    %s\n' "$current_prefix"
  printf 'npm root:      %s\n' "$global_root"
  if [[ $target_prefix != "$current_prefix" ]]; then
    printf 'Managed prefix:%s (%s)\n' " $target_prefix" "$reason"
  else
    printf 'Managed prefix: %s\n' "$target_prefix"
  fi

  if ((DRY_RUN)); then
    if [[ $target_prefix != "$current_prefix" ]]; then
      printf 'Would create %s/bin and %s/lib/node_modules without sudo.\n' "$target_prefix" "$target_prefix"
    fi
    if ((persist_prefix)); then
      printf 'Would persist NPM_CONFIG_PREFIX=%s and prepend its bin directory in ~/.profile after a backup.\n' "$target_prefix"
    elif ! path_contains "$target_prefix/bin"; then
      printf 'Would prepend %s/bin in ~/.profile after a backup.\n' "$target_prefix"
    fi
    if ((persist_prefix)); then
      export NPM_CONFIG_PREFIX="$target_prefix"
    fi
    export PATH="$target_prefix/bin:$PATH"
    return 0
  fi

  if [[ $target_prefix != "$current_prefix" ]]; then
    confirm "Use user-owned npm prefix $target_prefix instead of unwritable $current_prefix?" || return 1
  fi
  mkdir -p "$target_prefix/bin" "$target_prefix/lib/node_modules"
  if ((persist_prefix)); then
    export NPM_CONFIG_PREFIX="$target_prefix"
  fi
  if ! path_contains "$target_prefix/bin"; then
    export PATH="$target_prefix/bin:$PATH"
  fi
  if ((persist_prefix)); then
    persist_npm_prefix "$target_prefix" 1
  elif ((path_was_present == 0)); then
    persist_npm_prefix "$target_prefix" 0
  fi
}

report_package_residue() {
  local package_dir version
  if [[ $SELECTED_PACKAGE_MANAGER == pnpm ]]; then
    package_dir="$(pnpm root --global)/@deepseek-ai/dsh"
  else
    package_dir="$(npm root --global)/@deepseek-ai/dsh"
  fi
  version=$(installed_version)
  if [[ -e $package_dir && -z $version ]]; then
    printf 'Warning:       package directory exists without an installed version: %s\n' "$package_dir"
    printf '               It will not be deleted automatically; an exact-version package-manager install may reconcile it.\n'
  else
    printf 'Package path:  %s (%s)\n' "$package_dir" "${version:-not installed}"
  fi
}

installed_version() {
  if [[ $SELECTED_PACKAGE_MANAGER == pnpm ]]; then
    { pnpm list --global "$PACKAGE" --depth=0 --json 2>/dev/null || true; } |
      node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{let j=JSON.parse(s);if(Array.isArray(j))j=j[0]||{};console.log(j.dependencies?.[process.argv[1]]?.version||j.devDependencies?.[process.argv[1]]?.version||"")}catch{console.log("")}})' "$PACKAGE"
  else
    { npm list --global "$PACKAGE" --depth=0 --json 2>/dev/null || true; } |
      node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const j=JSON.parse(s);console.log(j.dependencies?.[process.argv[1]]?.version||"")}catch{console.log("")}})' "$PACKAGE"
  fi
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

install_exact_version() {
  local target="$1" attempt log_file
  for ((attempt = 1; attempt <= DOWNLOAD_ATTEMPTS; attempt++)); do
    log_file=$(mktemp)
    printf 'Install attempt: %s/%s (fetch retries: %s, fetch timeout: %ss, network concurrency: %s)\n' \
      "$attempt" "$DOWNLOAD_ATTEMPTS" "$FETCH_RETRIES" "$FETCH_TIMEOUT_SECONDS" "$NETWORK_CONCURRENCY"
    if [[ $SELECTED_PACKAGE_MANAGER == pnpm ]]; then
      if pnpm add --global --save-exact "$PACKAGE@$target" --registry="$REGISTRY" \
        --fetch-retries="$FETCH_RETRIES" --fetch-timeout="$((FETCH_TIMEOUT_SECONDS * 1000))" \
        --network-concurrency="$NETWORK_CONCURRENCY" 2>&1 | tee "$log_file"; then
        rm -f "$log_file"
        return 0
      fi
    else
      if npm install --global "$PACKAGE@$target" --registry="$REGISTRY" \
        --fetch-retries="$FETCH_RETRIES" --fetch-timeout="$((FETCH_TIMEOUT_SECONDS * 1000))" \
        --maxsockets="$NETWORK_CONCURRENCY" 2>&1 | tee "$log_file"; then
        rm -f "$log_file"
        return 0
      fi
    fi
    if grep -Eqi 'request (to )?https?://[^ ]+\.tgz.*tim(ed)? out|https?://[^ ]+\.tgz.*(ETIMEDOUT|ERR_SOCKET_TIMEOUT)' "$log_file"; then
      printf 'The registry metadata was verified, but a package tarball request timed out inside WSL.\n' >&2
      printf 'TLS and the official registry remain unchanged. A package-manager switch is not guaranteed to fix this transport path.\n' >&2
    elif grep -Eqi 'ETIMEDOUT|ERR_SOCKET_TIMEOUT|socket timeout|network timeout|request.*timed out' "$log_file"; then
      printf 'A registry request timed out inside WSL; the log does not prove that the failed request was a package tarball.\n' >&2
      printf 'TLS and the official registry remain unchanged while the same verified exact version is retried.\n' >&2
    fi
    if grep -Eqi 'node-gyp|node-pty|make:.*not found|not found: make|C\+\+ compiler' "$log_file"; then
      printf 'A native Node dependency failed to build. Verify make, Python 3, GCC, and G++ in this WSL distribution.\n' >&2
      printf 'Rerun with the default -NativeBuildTools auto; do not install npm packages as root.\n' >&2
    fi
    rm -f "$log_file"
    if ((attempt < DOWNLOAD_ATTEMPTS)); then
      printf 'Retrying the same verified exact version; the previous package-manager transaction failed.\n' >&2
    fi
  done
  printf 'Installation failed after %s bounded attempt(s). Re-run after checking DNS/TLS from this WSL distribution, or increase the reviewed timeout within the supported limits.\n' "$DOWNLOAD_ATTEMPTS" >&2
  return 1
}

resolve_dsh_path() {
  local candidate='' path_candidate=''
  if [[ $SELECTED_PACKAGE_MANAGER == pnpm ]] && command -v pnpm >/dev/null 2>&1; then
    candidate="$(pnpm bin --global 2>/dev/null || true)/dsh"
  elif command -v npm >/dev/null 2>&1; then
    candidate="$(npm prefix --global 2>/dev/null || true)/bin/dsh"
  fi
  if linux_path_is_executable "$candidate"; then
    printf '%s\n' "$candidate"
    return 0
  fi
  path_candidate=$(command -v dsh 2>/dev/null || true)
  linux_path_is_executable "$path_candidate" || return 1
  printf '%s\n' "$path_candidate"
}

show_status() {
  local current_prefix global_root pnpm_bin dsh_path
  load_nvm
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
  if command -v npm >/dev/null 2>&1 && command -v node >/dev/null 2>&1; then
    if [[ -z $SELECTED_PACKAGE_MANAGER ]]; then select_package_manager || true; fi
    if [[ $SELECTED_PACKAGE_MANAGER == npm ]]; then restore_recorded_npm_prefix; fi
    printf 'npm:           %s (%s)\n' "$(npm --version)" "$(command -v npm)"
    current_prefix=$(npm prefix --global 2>/dev/null || true)
    global_root=$(npm root --global 2>/dev/null || true)
    printf 'npm prefix:    %s\n' "$current_prefix"
    printf 'npm root:      %s\n' "$global_root"
    if npm_prefix_is_writable "$current_prefix" "$global_root"; then
      printf 'npm writable:  yes\n'
    else
      printf 'npm writable:  no; install/update will use %s without sudo\n' "$HOME/.local"
    fi
    if path_contains "$current_prefix/bin"; then
      printf 'npm bin PATH:  yes\n'
    else
      printf 'npm bin PATH:  no\n'
    fi
    if [[ $SELECTED_PACKAGE_MANAGER == npm ]]; then
      printf 'Harness:       %s\n' "$(installed_version)"
      report_package_residue
    fi
  else
    printf 'npm/Harness:   not available\n'
  fi
  if [[ $SELECTED_PACKAGE_MANAGER == pnpm ]]; then
    pnpm_bin=$(pnpm bin --global 2>/dev/null || true)
    printf 'pnpm:          %s (%s)\n' "$(pnpm --version)" "$(command -v pnpm)"
    printf 'pnpm global:   %s\n' "$pnpm_bin"
    printf 'Harness:       %s\n' "$(installed_version)"
    report_package_residue
  elif command -v pnpm >/dev/null 2>&1 && ! linux_pnpm_is_usable; then
    printf 'pnpm:          found but rejected (must be Linux-native with a writable user global bin)\n'
  fi
  dsh_path=$(resolve_dsh_path 2>/dev/null || true)
  if [[ -n $dsh_path ]]; then
    printf 'dsh path:      %s' "$dsh_path"
    if ! path_value_contains "$INITIAL_PATH" "$(dirname -- "$dsh_path")"; then
      printf ' (installed; absent from this non-login shell PATH)'
    fi
    printf '\n'
    timeout 10s "$dsh_path" --version || printf 'dsh --version did not exit successfully within 10 seconds.\n'
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
  select_package_manager
  if [[ $SELECTED_PACKAGE_MANAGER == npm ]]; then configure_npm_prefix; fi
  report_package_residue
  current=$(installed_version)
  if [[ -z $current ]]; then
    printf '%s is not installed through the selected %s global location.\n' "$PACKAGE" "$SELECTED_PACKAGE_MANAGER"
    exit 0
  fi
  printf 'Installed:     %s\n' "$current"
  ((DRY_RUN)) && { printf 'Would uninstall only %s; user data and Node.js would be preserved.\n' "$PACKAGE"; exit 0; }
  confirm "Uninstall $PACKAGE $current and preserve Harness data?" || exit 4
  if [[ $SELECTED_PACKAGE_MANAGER == pnpm ]]; then
    pnpm remove --global "$PACKAGE"
  else
    npm uninstall --global "$PACKAGE" --registry="$REGISTRY"
  fi
  exit 0
fi

if ! linux_node_is_compatible; then
  ensure_node || { ((DRY_RUN)) && exit 0; exit 5; }
fi

select_package_manager
if [[ $SELECTED_PACKAGE_MANAGER == npm ]]; then configure_npm_prefix; fi
report_package_residue

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
  if ((DRY_RUN)); then
    printf 'No package-version change is needed; any prefix/PATH repair shown above remains preview-only.\n'
    exit 0
  fi
  show_status
  exit 0
fi

if [[ $NATIVE_BUILD_TOOLS == auto ]]; then
  ensure_prerequisites 1 || { ((DRY_RUN)) || exit 5; }
else
  printf 'Native build-tools preflight was skipped by explicit request; node-pty may require make, Python 3, GCC, and G++.\n'
fi

if ((DRY_RUN)); then
  printf 'Would install exact version %s (current: %s).\n' "$target" "${current:-none}"
  printf 'Would use %s with %s fetch retries, a %ss fetch timeout, %s connection(s), and at most %s install attempt(s).\n' \
    "$SELECTED_PACKAGE_MANAGER" "$FETCH_RETRIES" "$FETCH_TIMEOUT_SECONDS" "$NETWORK_CONCURRENCY" "$DOWNLOAD_ATTEMPTS"
  exit 0
fi

confirm "Install exact version $PACKAGE@$target (current: ${current:-none})?" || exit 4
install_exact_version "$target"

state_dir="$HOME/.local/state/deepseek-harness-wsl"
mkdir -p "$state_dir"
managed_prefix=''
package_manager_path=$(command -v "$SELECTED_PACKAGE_MANAGER")
if [[ $SELECTED_PACKAGE_MANAGER == npm ]]; then
  managed_prefix=$(npm prefix --global)
  managed_bin="$managed_prefix/bin"
else
  managed_bin=$(pnpm bin --global)
fi
node -e 'const fs=require("fs");const out={previous:process.argv[2],installed:process.argv[3],packageManager:process.argv[4],packageManagerPath:process.argv[5],managedPrefix:process.argv[6],managedBin:process.argv[7],timestamp:process.argv[8]};fs.writeFileSync(process.argv[1],JSON.stringify(out)+"\n",{mode:0o600});fs.chmodSync(process.argv[1],0o600)' \
  "$state_dir/last-install.json" "${current:-}" "$target" "$SELECTED_PACKAGE_MANAGER" "$package_manager_path" "$managed_prefix" "$managed_bin" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

actual=$(installed_version)
[[ $actual == "$target" ]] || { printf 'Installed version %s does not match target %s.\n' "$actual" "$target" >&2; exit 8; }
show_status

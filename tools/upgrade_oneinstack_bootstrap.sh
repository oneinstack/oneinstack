#!/bin/bash
# One-time migration helper for old OneinStack releases and shared self-upgrader.
# The archive is downloaded and verified before the installed tree is touched.

set -u

usage() {
  cat <<'EOF'
Usage: upgrade_oneinstack_bootstrap.sh --install-dir PATH

Safely upgrades a OneinStack installation using its configured mirror first,
then the current official CDN and mirror. Existing options.conf values are kept.

For controlled testing, ONEINSTACK_UPGRADE_MIRRORS may contain a space- or
comma-separated mirror list. Setting it replaces the built-in mirror list.
EOF
}

fail() {
  printf 'OneinStack upgrade failed: %s\n' "$*" >&2
  return 1
}

fetch_to_file() {
  local url="$1" destination="$2"
  if [[ "$url" == file://* ]]; then
    cp -- "${url#file://}" "$destination"
  elif command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error --connect-timeout 5 --max-time 300 \
      "$url" --output "$destination" 2>/dev/null
  elif command -v wget >/dev/null 2>&1; then
    wget -q --timeout=300 -O "$destination" "$url" 2>/dev/null
  else
    return 127
  fi
}

display_mirror() {
  printf '%s' "$1" | sed -E 's#(https?://)[^/@]+@#\1#; s/[?].*$//'
}

read_option() {
  local wanted="$1" config="$2" line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "${wanted}"=*) printf '%s' "${line#*=}"; return 0 ;;
    esac
  done < "$config"
  return 1
}

checksum_from_file() {
  awk '
    {
      name = $NF
      sub(/^\*/, "", name)
      if (name == "oneinstack.tar.gz") { print $1; exit }
      if ($1 == "MD5" && $2 == "(oneinstack.tar.gz)" && $3 == "=") { print $4; exit }
    }
  ' "$1"
}

merge_options() {
  local old_config="$1" new_config="$2" checksum="$3" output="$4"
  local line key value
  local -A preserved=() written=()

  if [ -f "$old_config" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [[ "$line" == *=* ]] || continue
      key=${line%%=*}
      value=${line#*=}
      [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
      [[ "$key" == oneinstack_dir || "$key" == oneinstack_md5 ]] && continue
      preserved["$key"]="$value"
    done < "$old_config"
  fi

  : > "$output" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == *=* ]]; then
      key=${line%%=*}
      if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        if [ "$key" = oneinstack_md5 ]; then
          printf 'oneinstack_md5=%s\n' "$checksum" >> "$output" || return 1
          written[oneinstack_md5]=1
          continue
        fi
        if [[ ${preserved[$key]+present} ]]; then
          printf '%s=%s\n' "$key" "${preserved[$key]}" >> "$output" || return 1
          written["$key"]=1
          continue
        fi
      fi
    fi
    printf '%s\n' "$line" >> "$output" || return 1
  done < "$new_config"

  for key in "${!preserved[@]}"; do
    if [[ ! ${written[$key]+present} ]]; then
      printf '%s=%s\n' "$key" "${preserved[$key]}" >> "$output" || return 1
    fi
  done
  if [[ ! ${written[oneinstack_md5]+present} ]]; then
    printf 'oneinstack_md5=%s\n' "$checksum" >> "$output" || return 1
  fi
}

validate_archive() {
  local archive="$1" listing="$2" entry normalized
  gzip -t "$archive" >/dev/null 2>&1 || return 1
  tar -tzf "$archive" > "$listing" 2>/dev/null || return 1
  [ -s "$listing" ] || return 1
  while IFS= read -r entry; do
    normalized=${entry#./}
    [[ "$normalized" == /* ]] && return 1
    [[ "/$normalized/" == *"/../"* ]] && return 1
    [[ "$normalized" == oneinstack || "$normalized" == oneinstack/* ]] || return 1
  done < "$listing"
  grep -Fxq 'oneinstack/upgrade.sh' "$listing" || grep -Fxq './oneinstack/upgrade.sh' "$listing" || return 1
  grep -Fxq 'oneinstack/options.conf' "$listing" || grep -Fxq './oneinstack/options.conf' "$listing" || return 1
  # This marker distinguishes the current package from valid but stale V2.5/V2.6 mirror archives.
  grep -Fxq 'oneinstack/tools/upgrade_oneinstack_bootstrap.sh' "$listing" || \
    grep -Fxq './oneinstack/tools/upgrade_oneinstack_bootstrap.sh' "$listing" || return 1
}

install_dir=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --install-dir)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      install_dir=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

[ "$(id -u)" -eq 0 ] || { fail 'run this command as root'; exit 1; }
[ -n "$install_dir" ] || { usage >&2; exit 2; }
[ -d "$install_dir" ] || { fail "installation directory not found: $install_dir"; exit 1; }
[ -f "$install_dir/options.conf" ] || { fail 'options.conf not found in installation directory'; exit 1; }
[ -f "$install_dir/upgrade.sh" ] || { fail 'upgrade.sh not found in installation directory'; exit 1; }
command -v tar >/dev/null 2>&1 && command -v md5sum >/dev/null 2>&1 || {
  fail 'tar and md5sum are required'; exit 1;
}
install_dir=$(cd "$install_dir" && pwd -P) || exit 1
parent_dir=$(dirname "$install_dir")
[ "$install_dir" != / ] || { fail 'refusing to replace the filesystem root'; exit 1; }
install_device=$(stat -c '%d' "$install_dir" 2>/dev/null) || { fail 'cannot inspect the installation filesystem'; exit 1; }
parent_device=$(stat -c '%d' "$parent_dir" 2>/dev/null) || { fail 'cannot inspect the parent filesystem'; exit 1; }
[ "$install_device" = "$parent_device" ] || {
  fail 'installation directory and its parent must be on the same filesystem for a safe atomic update'; exit 1;
}
current_md5=$(read_option oneinstack_md5 "$install_dir/options.conf" || true)
configured_mirror=$(read_option mirror_link "$install_dir/options.conf" || true)

declare -a mirrors=()
if [ -n "${ONEINSTACK_UPGRADE_MIRRORS:-}" ]; then
  mirror_override=${ONEINSTACK_UPGRADE_MIRRORS//,/ }
  read -r -a mirrors <<< "$mirror_override"
else
  [ -n "$configured_mirror" ] && mirrors+=("${configured_mirror%/}")
  mirrors+=("https://cdn.oneinstack.com" "https://mirrors.oneinstack.com")
fi

declare -A mirror_seen=()
declare -a unique_mirrors=()
for mirror in "${mirrors[@]}"; do
  mirror=${mirror%/}
  [ -n "$mirror" ] || continue
  if [[ ! ${mirror_seen[$mirror]+present} ]]; then
    unique_mirrors+=("$mirror")
    mirror_seen["$mirror"]=1
  fi
done
[ "${#unique_mirrors[@]}" -gt 0 ] || { fail 'no upgrade mirrors are configured'; exit 1; }
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  for mirror in "${unique_mirrors[@]}"; do
    [[ "$mirror" == file://* ]] || { fail 'curl or wget is required for non-file upgrade mirrors'; exit 1; }
  done
fi

tmp_dir=$(mktemp -d "${parent_dir}/.oneinstack-upgrade.XXXXXX") || {
  fail "cannot create a temporary directory under $parent_dir"; exit 1;
}
backup_dir=''
upgrade_committed=0
cleanup() {
  if [ -n "$backup_dir" ] && [ -d "$backup_dir" ]; then
    if [ "$upgrade_committed" -eq 1 ]; then
      rm -rf -- "$backup_dir"
    else
      if [ -f "${install_dir}/upgrade.log" ] && [ ! -f "${backup_dir}/upgrade.log" ]; then
        mv -- "${install_dir}/upgrade.log" "${backup_dir}/upgrade.log" 2>/dev/null || true
      fi
      [ -e "$install_dir" ] && rm -rf -- "$install_dir"
      if ! mv -- "$backup_dir" "$install_dir" 2>/dev/null; then
        printf 'Rollback incomplete; the original installation remains at %s\n' "$backup_dir" >&2
      fi
    fi
  fi
  [ -d "$tmp_dir" ] && rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

selected_md5=''
selected_archive=''
for mirror in "${unique_mirrors[@]}"; do
  printf 'Checking upgrade mirror: %s\n' "$(display_mirror "$mirror")"
  checksum_file="${tmp_dir}/md5sum.txt"
  archive_file="${tmp_dir}/oneinstack.tar.gz"
  rm -f "$checksum_file" "$archive_file"

  if ! fetch_to_file "${mirror}/md5sum.txt" "$checksum_file" || [ ! -s "$checksum_file" ]; then
    printf '  Mirror unavailable or checksum file is empty.\n'
    continue
  fi
  latest_md5=$(checksum_from_file "$checksum_file")
  if [[ ! "$latest_md5" =~ ^[[:xdigit:]]{32}$ ]]; then
    printf '  Mirror returned an invalid oneinstack.tar.gz checksum.\n'
    continue
  fi
  latest_md5=${latest_md5,,}

  if ! fetch_to_file "${mirror}/oneinstack.tar.gz" "$archive_file" || [ ! -s "$archive_file" ]; then
    printf '  Package download failed or returned an empty file.\n'
    continue
  fi
  actual_md5=$(md5sum "$archive_file" | awk '{print tolower($1)}')
  if [ "$actual_md5" != "$latest_md5" ]; then
    printf '  Package checksum does not match the checksum from this mirror.\n'
    continue
  fi
  if ! validate_archive "$archive_file" "${tmp_dir}/archive.list"; then
    printf '  Package is damaged, unsafe, or is an outdated OneinStack archive.\n'
    continue
  fi

  selected_md5=$latest_md5
  selected_archive=$archive_file
  break
done

if [ -z "$selected_archive" ]; then
  fail 'all mirrors failed validation; the installed files were not changed'
  exit 1
fi

if [[ "$current_md5" =~ ^[[:xdigit:]]{32}$ ]] && [ "${current_md5,,}" = "$selected_md5" ]; then
  printf 'Your OneinStack already has the latest version. (package MD5: %s)\n' "$selected_md5"
  exit 0
fi

extract_dir="${tmp_dir}/extract"
stage_dir="${tmp_dir}/stage"
mkdir -p "$extract_dir" "$stage_dir" || { fail 'cannot prepare staging directories'; exit 1; }
if ! tar -xzf "$selected_archive" -C "$extract_dir" 2>/dev/null; then
  fail 'package extraction failed; the installed files were not changed'
  exit 1
fi
[ -d "${extract_dir}/oneinstack" ] || { fail 'package has no oneinstack directory'; exit 1; }

if ! cp -a "${install_dir}/." "$stage_dir/" || ! cp -a "${extract_dir}/oneinstack/." "$stage_dir/"; then
  fail 'could not prepare the updated installation; the installed files were not changed'
  exit 1
fi
if ! merge_options "${install_dir}/options.conf" "${stage_dir}/options.conf" \
  "$selected_md5" "${tmp_dir}/options.conf"; then
  fail 'could not preserve the existing options.conf; the installed files were not changed'
  exit 1
fi
if ! cat "${tmp_dir}/options.conf" > "${stage_dir}/options.conf"; then
  fail 'could not write staged options.conf; the installed files were not changed'
  exit 1
fi

timestamp=$(date '+%Y%m%d%H%M%S')
backup_dir="${parent_dir}/.oneinstack-backup-${timestamp}-$$"
[ ! -e "$backup_dir" ] || { fail "backup path already exists: $backup_dir"; exit 1; }
if ! mv -- "$install_dir" "$backup_dir"; then
  fail 'could not move the existing installation to its rollback location'
  exit 1
fi
if ! mv -- "$stage_dir" "$install_dir"; then
  if mv -- "$backup_dir" "$install_dir" 2>/dev/null; then backup_dir=''; fi
  fail 'could not activate the staged upgrade; rollback was attempted'
  exit 1
fi
if [ ! -s "${install_dir}/options.conf" ] || [ ! -f "${install_dir}/upgrade.sh" ] || \
  [ ! -f "${install_dir}/tools/upgrade_oneinstack_bootstrap.sh" ]; then
  rm -rf -- "$install_dir"
  if mv -- "$backup_dir" "$install_dir" 2>/dev/null; then backup_dir=''; fi
  fail 'the staged installation failed its post-update check; rollback was attempted'
  exit 1
fi

# Keep the active upgrade.log inode attached to the new tree while tee is still
# writing to it from upgrade.sh during an in-place menu upgrade.
if [ -f "${backup_dir}/upgrade.log" ]; then
  rm -f "${install_dir}/upgrade.log"
  if ! mv -- "${backup_dir}/upgrade.log" "${install_dir}/upgrade.log"; then
    rm -rf -- "${install_dir}"
    if mv -- "$backup_dir" "$install_dir" 2>/dev/null; then backup_dir=''; fi
    fail 'could not retain the upgrade log; rollback was attempted'
    exit 1
  fi
  chmod 600 "${install_dir}/upgrade.log" 2>/dev/null || true
fi

upgrade_committed=1
rm -rf -- "$backup_dir"
backup_dir=''
printf 'OneinStack upgrade successful. Package MD5: %s\n' "$selected_md5"
exit 0

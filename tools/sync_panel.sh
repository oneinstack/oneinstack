#!/usr/bin/env bash
# ==============================================================================
# Script: sync_panel.sh
# Purpose: Automatically download OneinStack Panel release packages from GitHub
#          Releases into /data/wwwroot/mirrors and remove old packages.
# ==============================================================================
set -Eeuo pipefail

MIRROR_DIR="/data/wwwroot/mirrors"
TMP_DIR="${MIRROR_DIR}/.tmp_panel"
REPO="oneinstack/Oneinstack-Panel"
TAG="${1:-}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [sync_panel] $*"
}

die() {
  log "ERROR: $*" >&2
  rm -rf -- "${TMP_DIR}"
  exit 1
}

# 1. Resolve Release info via GitHub API
if [ -z "${TAG}" ]; then
  log "Tag not specified, querying GitHub API for latest release..."
  RELEASE_JSON="$(curl -fsSL --max-time 15 "https://api.github.com/repos/${REPO}/releases?per_page=1" || true)"
  TAG="$(echo "${RELEASE_JSON}" | grep -m 1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)"
  if [ -z "${TAG}" ]; then
    die "Failed to resolve latest release tag for ${REPO}"
  fi
else
  RELEASE_JSON="$(curl -fsSL --max-time 15 "https://api.github.com/repos/${REPO}/releases/tags/${TAG}" || true)"
fi

log "Target release tag: ${TAG}"

# 2. Prepare temporary directory
rm -rf -- "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
cd "${TMP_DIR}"

# Helper function to download file with retry
download_file() {
  local url="$1"
  local dest="$2"
  local downloaded=false
  log "Downloading ${dest} from ${url} ..."
  for attempt in 1 2 3 4 5; do
    if curl -fSL --connect-timeout 20 --max-time 300 --retry 2 -o "${dest}" "${url}"; then
      downloaded=true
      break
    fi
    log "Download failed (attempt ${attempt}/5), retrying in ${attempt}s..."
    sleep "${attempt}"
  done
  test "${downloaded}" = "true" || die "Failed to download ${url}"
}

# 3. Detect asset URLs
for arch in amd64 arm64; do
  target_tar="oneinstack-${arch}.tar.gz"
  target_sha="oneinstack-${arch}.tar.gz.sha256"

  # Check if modern asset name exists (oneinstack-amd64.tar.gz)
  url_tar="$(echo "${RELEASE_JSON}" | grep "browser_download_url.*oneinstack-${arch}.*tar.gz\"" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
  url_sha="$(echo "${RELEASE_JSON}" | grep "browser_download_url.*oneinstack-${arch}.*tar.gz\.sha256\"" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"

  # Fallback to legacy asset name (one-linux-amd64-*.tar.gz)
  if [ -z "${url_tar}" ]; then
    url_tar="$(echo "${RELEASE_JSON}" | grep "browser_download_url.*one-linux-${arch}.*tar.gz\"" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
  fi
  if [ -z "${url_sha}" ]; then
    url_sha="$(echo "${RELEASE_JSON}" | grep "browser_download_url.*one-linux-${arch}.*tar.gz\.sha256\"" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
  fi

  if [ -z "${url_tar}" ]; then
    url_tar="https://github.com/${REPO}/releases/download/${TAG}/${target_tar}"
  fi
  if [ -z "${url_sha}" ]; then
    url_sha="https://github.com/${REPO}/releases/download/${TAG}/${target_sha}"
  fi

  download_file "${url_tar}" "${target_tar}"
  download_file "${url_sha}" "${target_sha}"

  # 4. Verify SHA256
  expected="$(awk 'NR==1 { print $1 }' "${target_sha}")"
  actual="$(sha256sum "${target_tar}" | awk '{ print $1 }')"

  if [[ ! "${expected}" =~ ^[[:xdigit:]]{64}$ ]]; then
    die "Invalid SHA256 checksum format in ${target_sha}: ${expected}"
  fi

  if [ "${expected}" != "${actual}" ]; then
    die "SHA256 mismatch for ${target_tar}! expected: ${expected}, actual: ${actual}"
  fi
  log "Checksum verified for ${target_tar}: ${actual}"

  # Normalise .sha256 file content to point to oneinstack-${arch}.tar.gz
  echo "${actual}  ${target_tar}" > "${target_sha}"
done

# 5. Clean up old packages in mirror directory
log "Removing old packages in ${MIRROR_DIR} ..."
rm -f -- "${MIRROR_DIR}/oneinstack-amd64.tar.gz" \
         "${MIRROR_DIR}/oneinstack-amd64.tar.gz.sha256" \
         "${MIRROR_DIR}/oneinstack-arm64.tar.gz" \
         "${MIRROR_DIR}/oneinstack-arm64.tar.gz.sha256"

# 6. Atomic move to mirror directory
log "Publishing new packages to ${MIRROR_DIR} ..."
for arch in amd64 arm64; do
  mv -f "${TMP_DIR}/oneinstack-${arch}.tar.gz" "${MIRROR_DIR}/oneinstack-${arch}.tar.gz"
  mv -f "${TMP_DIR}/oneinstack-${arch}.tar.gz.sha256" "${MIRROR_DIR}/oneinstack-${arch}.tar.gz.sha256"
  chmod 644 "${MIRROR_DIR}/oneinstack-${arch}.tar.gz"*
  chown www:www "${MIRROR_DIR}/oneinstack-${arch}.tar.gz"*
done

rm -rf -- "${TMP_DIR}"

log "Panel packages synchronized successfully for tag ${TAG}!"
ls -lh "${MIRROR_DIR}/oneinstack-amd64.tar.gz"* "${MIRROR_DIR}/oneinstack-arm64.tar.gz"*

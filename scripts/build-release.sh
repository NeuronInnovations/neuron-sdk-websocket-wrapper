#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

: "${GOCACHE:=$ROOT_DIR/.gocache}"
: "${GOMODCACHE:=$ROOT_DIR/.gomodcache}"
export GOCACHE GOMODCACHE GOPRIVATE=${GOPRIVATE:-github.com/NeuronInnovations/*}

if [[ -n "${GH_TOKEN:-}" ]]; then
  git config --global url."https://${GH_TOKEN}@github.com/".insteadOf "https://github.com/"
fi

LDFLAGS=${LDFLAGS:--s -w}
GOFLAGS=${GOFLAGS:-}

log() {
  local color="\033[1;34m"
  local reset="\033[0m"
  echo -e "${color}[$(date '+%H:%M:%S')] $*${reset}"
}

warn() {
  local color="\033[1;33m"
  local reset="\033[0m"
  echo -e "${color}[$(date '+%H:%M:%S')] $*${reset}" >&2
}

declare -a ARTIFACTS=()
declare -a NOTARYTOOL_AUTH_ARGS=()

should_sign() {
  [[ -n "${SIGNING_IDENTITY:-}" ]]
}

should_notarize() {
  local flag=${NOTARIZE:-}
  flag=$(printf '%s' "$flag" | tr '[:upper:]' '[:lower:]')
  [[ "$flag" == "1" || "$flag" == "true" || "$flag" == "yes" ]]
}

require_command() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command '$cmd' not found. Aborting." >&2
    exit 1
  fi
}

sign_binary() {
  local binary_path=$1
  if ! should_sign; then
    return
  fi

  require_command codesign

  log "Signing $(basename "$binary_path")"
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$binary_path"
  log "Verifying signature"
  codesign --verify --verbose "$binary_path"
}

package_artifact() {
  local binary_path=$1
  local archive_name=$2
  local ext=$3

  local binary_basename=$(basename "$binary_path")
  local archive_path="$DIST_DIR/$archive_name.zip"

  log "Packaging ${archive_name}.zip"
  (cd "$DIST_DIR" && {
    rm -f "$archive_name.zip"
    zip -q "$archive_name.zip" "$binary_basename"
  })

  shasum -a 256 "$archive_path" > "$archive_path.sha256"
}

prepare_notary_auth() {
  NOTARYTOOL_AUTH_ARGS=()

  if [[ -n "${NOTARY_API_KEY_PATH:-}" ]]; then
    : "${NOTARY_API_KEY_ID:?NOTARY_API_KEY_ID must be set when using API key authentication}"
    : "${NOTARY_API_ISSUER_ID:?NOTARY_API_ISSUER_ID must be set when using API key authentication}"
    NOTARYTOOL_AUTH_ARGS=(
      --key "$NOTARY_API_KEY_PATH"
      --key-id "$NOTARY_API_KEY_ID"
      --issuer "$NOTARY_API_ISSUER_ID"
    )
    return 0
  fi

  if [[ -n "${APPLE_ID:-}" ]]; then
    : "${APPLE_TEAM_ID:?APPLE_TEAM_ID must be set when using Apple ID authentication}"
    : "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD must be set when using Apple ID authentication}"
    NOTARYTOOL_AUTH_ARGS=(
      --apple-id "$APPLE_ID"
      --team-id "$APPLE_TEAM_ID"
      --password "$APPLE_APP_SPECIFIC_PASSWORD"
    )
    return 0
  fi

  return 1
}

notarize_artifacts() {
  if ! should_notarize; then
    log "Skipping notarization"
    return
  fi

  require_command xcrun

  if ! prepare_notary_auth; then
    warn "Notarization requested but no valid authentication method provided; skipping."
    return
  fi

  for artifact in "${ARTIFACTS[@]}"; do
    IFS='|' read -r binary_path archive_name ext <<<"$artifact"

    if [[ ! -f "$binary_path" ]]; then
      warn "Binary $binary_path missing, skipping notarization"
      continue
    fi

    local archive_path="$DIST_DIR/$archive_name.zip"
    if [[ ! -f "$archive_path" ]]; then
      warn "Archive $archive_path missing, skipping notarization"
      continue
    fi

    local log_path="$DIST_DIR/$archive_name-notary.json"

    log "Submitting ${archive_name}.zip for notarization"
    xcrun notarytool submit "$archive_path" \
      "${NOTARYTOOL_AUTH_ARGS[@]}" \
      --wait \
      --output-format json >"$log_path"

    log "Stapling notarization ticket to $(basename "$binary_path")"
    xcrun stapler staple "$binary_path"

    log "Re-packaging ${archive_name}.zip with stapled binary"
    package_artifact "$binary_path" "$archive_name" "$ext"
  done
}

clean_old_artifacts() {
  rm -f "$DIST_DIR"/neuron-wrapper-* "$DIST_DIR"/neuron-wrapper-*.zip "$DIST_DIR"/neuron-wrapper-*.zip.sha256 2>/dev/null || true
}

build_target() {
  local goos=$1
  local goarch=$2
  local binary_name=$3
  local ext=$4
  local archive_name=$5
  local cgoflag=${6:-0}

  local output_path="$DIST_DIR/${binary_name}${ext}"
  log "Building ${binary_name}${ext} (${goos}/${goarch})"

  env \
    CGO_ENABLED=$cgoflag \
    GOOS=$goos \
    GOARCH=$goarch \
    GOFLAGS="$GOFLAGS" \
    go build \
      -trimpath \
      -ldflags "$LDFLAGS" \
      -o "$output_path" \
      "$ROOT_DIR"

  chmod +x "$output_path"

  sign_binary "$output_path"
  package_artifact "$output_path" "$archive_name" "$ext"

  ARTIFACTS+=("$output_path|$archive_name|$ext")
}

main() {
  clean_old_artifacts

  build_target darwin amd64 neuron-wrapper-darwin64 "" neuron-wrapper-darwin64
  build_target darwin arm64 neuron-wrapper-darwin-arm64 "" neuron-wrapper-darwin-arm64

  notarize_artifacts

  log "Artifacts produced in $DIST_DIR"
  ls -1 "$DIST_DIR"
}

main "$@"

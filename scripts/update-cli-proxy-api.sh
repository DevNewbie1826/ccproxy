#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OWNER_REPO="router-for-me/CLIProxyAPI"
TARGET_BINARY="$ROOT_DIR/src/Sources/Resources/cli-proxy-api"
LATEST_API_URL="https://api.github.com/repos/${OWNER_REPO}/releases/latest"

DRY_RUN=false
CLEANUP_DIR=""

cleanup() {
  if [ -n "${CLEANUP_DIR:-}" ] && [ -d "${CLEANUP_DIR}" ]; then
    rm -rf "${CLEANUP_DIR}"
  fi
}
trap cleanup EXIT

usage() {
  cat <<EOF
Usage: scripts/update-cli-proxy-api.sh [--dry-run]

Resolve the latest ${OWNER_REPO} release, download the macOS arm64
archive, verify its SHA-256 checksum, and validate the executable.

Options:
  --dry-run    Download and verify without replacing
               src/Sources/Resources/cli-proxy-api
  --help       Show this help message

Updates src/Sources/Resources/cli-proxy-api to the latest release by
default. Use --dry-run for preview and verification only.
EOF
}

resolve_latest_release() {
  local json
  json="$(curl --fail --location --silent --show-error "$LATEST_API_URL")"

  local tag_name archive_name archive_url checksums_url archive_digest

  tag_name="$(printf '%s\n' "$json" | python3 -c '
import sys, json
data = json.load(sys.stdin)
tag = data.get("tag_name", "")
if not tag:
    sys.exit(1)
print(tag)
')"

  local asset_info
  asset_info="$(printf '%s\n' "$json" | python3 -c '
import sys, json, re
data = json.load(sys.stdin)
assets = data.get("assets", [])
archive_pat = re.compile(r"^CLIProxyAPI_[^/]+_darwin_aarch64\.tar\.gz$")
archive_matches = []
checksums_matches = []
for a in assets:
    name = a.get("name", "")
    if archive_pat.match(name):
        archive_matches.append(a)
    if name == "checksums.txt":
        checksums_matches.append(a)
if len(archive_matches) != 1:
    print("ERROR:expected 1 archive,found " + str(len(archive_matches)), file=sys.stderr)
    sys.exit(1)
if len(checksums_matches) != 1:
    print("ERROR:checksums.txt not found", file=sys.stderr)
    sys.exit(1)
ar = archive_matches[0]
ck = checksums_matches[0]
print(ar["name"])
print(ar["browser_download_url"])
print(ar.get("digest", ""))
print(ck["browser_download_url"])
')"

  archive_name="$(printf '%s\n' "$asset_info" | sed -n '1p')"
  archive_url="$(printf '%s\n' "$asset_info" | sed -n '2p')"
  archive_digest="$(printf '%s\n' "$asset_info" | sed -n '3p')"
  checksums_url="$(printf '%s\n' "$asset_info" | sed -n '4p')"

  printf '%s\n' "TAG=$tag_name"
  printf '%s\n' "ARCHIVE_NAME=$archive_name"
  printf '%s\n' "ARCHIVE_URL=$archive_url"
  printf '%s\n' "ARCHIVE_DIGEST=$archive_digest"
  printf '%s\n' "CHECKSUMS_URL=$checksums_url"
}

find_executable_in_dir() {
  local dir="$1"
  local candidates=()
  while IFS= read -r -d '' f; do
    if [ -f "$f" ] && [ -x "$f" ]; then
      candidates+=("$f")
    fi
  done < <(find "$dir" -type f -perm +111 -print0 2>/dev/null)

  if [ "${#candidates[@]}" -eq 0 ]; then
    echo "ERROR:No executable candidates found in archive" >&2
    return 1
  fi
  if [ "${#candidates[@]}" -gt 1 ]; then
    echo "ERROR:Multiple executable candidates found in archive:" >&2
    for c in "${candidates[@]}"; do
      echo "  $c" >&2
    done
    return 1
  fi

  local exe="${candidates[0]}"
  local version_output
  version_output="$("$exe" --version 2>/dev/null || true)"
  if ! printf '%s\n' "$version_output" | grep -q 'CLIProxyAPI Version'; then
    echo "ERROR:Executable does not report CLIProxyAPI Version: $exe" >&2
    return 1
  fi

  printf '%s\n' "$exe"
}

main() {
  if [ $# -gt 1 ]; then
    echo "Unknown option: $*" >&2
    echo "Usage: scripts/update-cli-proxy-api.sh [--dry-run]" >&2
    exit 2
  fi

  if [ $# -eq 1 ]; then
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      --help)    usage; exit 0 ;;
      *)
        echo "Unknown option: $1" >&2
        echo "Usage: scripts/update-cli-proxy-api.sh [--dry-run]" >&2
        exit 2
        ;;
    esac
  fi

  local needed_cmds=(curl python3 shasum tar mktemp chmod)
  for cmd in "${needed_cmds[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "ERROR:Required command not found: $cmd" >&2
      exit 1
    fi
  done

  if [ "$DRY_RUN" = false ]; then
    if ! command -v make >/dev/null 2>&1; then
      echo "ERROR:Required command not found: make" >&2
      exit 1
    fi
  fi

  echo "Resolving latest ${OWNER_REPO} release..."
  local release_info
  release_info="$(resolve_latest_release)"

  local tag_name archive_name archive_url archive_digest checksums_url
  tag_name="$(printf '%s\n' "$release_info" | grep '^TAG=' | cut -d= -f2-)"
  archive_name="$(printf '%s\n' "$release_info" | grep '^ARCHIVE_NAME=' | cut -d= -f2-)"
  archive_url="$(printf '%s\n' "$release_info" | grep '^ARCHIVE_URL=' | cut -d= -f2-)"
  archive_digest="$(printf '%s\n' "$release_info" | grep '^ARCHIVE_DIGEST=' | cut -d= -f2-)"
  checksums_url="$(printf '%s\n' "$release_info" | grep '^CHECKSUMS_URL=' | cut -d= -f2-)"

  echo "Resolved CLIProxyAPI release: $tag_name"
  echo "Selected asset: $archive_name"

  CLEANUP_DIR="$(mktemp -d)"
  local tmp_dir="$CLEANUP_DIR"

  echo "Downloading $archive_name..."
  curl --fail --location --silent --show-error \
    -o "$tmp_dir/$archive_name" "$archive_url"

  echo "Downloading checksums.txt..."
  curl --fail --location --silent --show-error \
    -o "$tmp_dir/checksums.txt" "$checksums_url"

  local expected_checksum
  expected_checksum="$(grep -F "$archive_name" "$tmp_dir/checksums.txt" | awk '{print $1}')"
  if [ -z "$expected_checksum" ]; then
    echo "ERROR:$archive_name not found in checksums.txt" >&2
    exit 1
  fi

  if [ -n "$archive_digest" ]; then
    local api_checksum=""
    case "$archive_digest" in
      sha256:*) api_checksum="${archive_digest#sha256:}" ;;
    esac
    if [ -n "$api_checksum" ] && [ "$api_checksum" != "$expected_checksum" ]; then
      echo "ERROR:API digest ($api_checksum) disagrees with checksums.txt ($expected_checksum)" >&2
      exit 1
    fi
  fi

  local actual_checksum
  actual_checksum="$(shasum -a 256 "$tmp_dir/$archive_name" | awk '{print $1}')"
  if [ "$actual_checksum" != "$expected_checksum" ]; then
    echo "ERROR:Checksum mismatch: expected $expected_checksum, got $actual_checksum" >&2
    exit 1
  fi
  echo "Checksum verified: sha256:$actual_checksum"

  local extract_dir="$tmp_dir/extracted"
  mkdir -p "$extract_dir"
  tar -xzf "$tmp_dir/$archive_name" -C "$extract_dir"

  local exe_path
  exe_path="$(find_executable_in_dir "$extract_dir")"

  echo "Archive contains executable: $(basename "$exe_path")"

  if [ "$DRY_RUN" = true ]; then
    echo "Dry run complete; src/Sources/Resources/cli-proxy-api was not modified."
    exit 0
  fi

  # Update mode
  if [ ! -f "$TARGET_BINARY" ]; then
    echo "ERROR:Target binary not found: $TARGET_BINARY" >&2
    exit 1
  fi

  echo "Updating $TARGET_BINARY..."
  local staging="$TARGET_BINARY.tmp"
  cp "$exe_path" "$staging"
  chmod 755 "$staging"

  if command -v xattr >/dev/null 2>&1; then
    if xattr -p com.apple.quarantine "$staging" >/dev/null 2>&1; then
      xattr -d com.apple.quarantine "$staging" 2>/dev/null || true
    fi
  fi

  mv "$staging" "$TARGET_BINARY"

  echo "Validating updated binary..."
  local version_output
  version_output="$(make -C "$ROOT_DIR" backend-version 2>&1)" || true
  if ! printf '%s\n' "$version_output" | grep -q 'CLIProxyAPI Version'; then
    echo "ERROR:Backend validation failed" >&2
    echo "$version_output" >&2
    git -C "$ROOT_DIR" checkout -- src/Sources/Resources/cli-proxy-api
    exit 1
  fi

  echo "Updated successfully:"
  printf '%s\n' "$version_output"
}

main "$@"

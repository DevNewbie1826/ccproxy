#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/CCProxy.app.zip}"
APPCAST_PATH="${APPCAST_PATH:-$ROOT_DIR/appcast.xml}"
APP_VERSION="${APP_VERSION:?APP_VERSION is required}"
APP_BUILD_NUMBER="${APP_BUILD_NUMBER:?APP_BUILD_NUMBER is required}"
RELEASE_URL="${RELEASE_URL:?RELEASE_URL is required}"
SIGN_UPDATE="$ROOT_DIR/src/.build/artifacts/sparkle/Sparkle/bin/sign_update"

if [ ! -f "$ARCHIVE_PATH" ]; then
  echo "Archive not found: $ARCHIVE_PATH" >&2
  exit 1
fi

if [ ! -x "$SIGN_UPDATE" ]; then
  echo "sign_update not found: $SIGN_UPDATE" >&2
  exit 1
fi

SIGNATURE="$($SIGN_UPDATE -p "$ARCHIVE_PATH")"
if [ -z "$SIGNATURE" ]; then
  echo "Failed to extract sparkle:edSignature" >&2
  exit 1
fi

ARCHIVE_LENGTH="$(stat -f%z "$ARCHIVE_PATH")"

cat > "$APPCAST_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>CCProxy Changelog</title>
    <item>
      <title>Version ${APP_VERSION}</title>
      <sparkle:version>${APP_BUILD_NUMBER}</sparkle:version>
      <enclosure
        url="${RELEASE_URL}"
        sparkle:edSignature="${SIGNATURE}"
        length="${ARCHIVE_LENGTH}"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "Wrote $APPCAST_PATH"

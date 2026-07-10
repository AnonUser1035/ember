#!/usr/bin/env bash
# Packages dist/Ember.app (see build-app.sh) into a drag-to-install DMG.
# Notarization is a separate step (needs Apple Developer credentials) — see
# .github/workflows/release.yml and the README.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Ember"
APP_BUNDLE="dist/${APP_NAME}.app"
STAGING_DIR="dist/dmg-staging"
DMG_PATH="dist/${APP_NAME}.dmg"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: $APP_BUNDLE not found — run scripts/build-app.sh first" >&2
    exit 1
fi

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "==> Built $DMG_PATH"

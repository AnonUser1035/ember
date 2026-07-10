#!/usr/bin/env bash
# Assembles Ember.app from `swift build` products. There's no Xcode project
# here (see README) — this hand-builds the bundle layout Apple expects.
#
# Usage: scripts/build-app.sh [debug|release]
#
# Env vars:
#   SIGNING_IDENTITY  Codesign identity (default "-", i.e. ad-hoc). Use a
#                      real "Developer ID Application: ..." identity to
#                      notarize and distribute the app to other Macs.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIGURATION="${1:-debug}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"

APP_NAME="Ember"
BUNDLE_ID="com.neurosafetysystems.ember"
BUILD_DIR=".build/$CONFIGURATION"
APP_BUNDLE="dist/${APP_NAME}.app"

echo "==> Building ($CONFIGURATION)"
swift build -c "$CONFIGURATION"

echo "==> Assembling ${APP_BUNDLE}"
rm -rf "dist"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/Ember" "$APP_BUNDLE/Contents/MacOS/Ember"
cp "Sources/Ember/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [ -f "Resources/Ember.icns" ]; then
    cp "Resources/Ember.icns" "$APP_BUNDLE/Contents/Resources/Ember.icns"
else
    echo "warning: Resources/Ember.icns not found — run scripts/make-icons.sh first"
fi

if [ -d "Resources/MenuBar" ]; then
    cp Resources/MenuBar/*.png "$APP_BUNDLE/Contents/Resources/"
else
    echo "warning: Resources/MenuBar not found — run scripts/make-icons.sh first"
fi

echo "==> Code signing (identity: ${SIGNING_IDENTITY})"
codesign --force --options runtime --sign "$SIGNING_IDENTITY" \
    "$APP_BUNDLE"

if [ "$SIGNING_IDENTITY" = "-" ]; then
    cat <<'EOF'

NOTE: signed ad-hoc (SIGNING_IDENTITY=-). This is fine for running the app
on your own Mac, but other Macs will see a Gatekeeper warning when opening
it (right-click the app and choose Open to bypass it once). To sign for
real, set SIGNING_IDENTITY to a name from:
  security find-identity -v -p codesigning
EOF
fi

echo "==> Built ${APP_BUNDLE}"

#!/usr/bin/env bash
# Renders the SVG sources in Resources/svg/ into Resources/Ember.icns and
# the menu-bar template PNGs, using AppKit's built-in SVG renderer
# (scripts/render-icon.swift) — no rsvg-convert/Inkscape/ImageMagick needed.
set -euo pipefail
cd "$(dirname "$0")/.."

SVG_DIR="Resources/svg"
ICONSET="Resources/AppIcon.iconset"
MENUBAR_DIR="Resources/MenuBar"

rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$MENUBAR_DIR"

render() {
    swift scripts/render-icon.swift "$1" "$2" "$3"
}

# Standard .iconset sizes (see `man iconutil`)
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_16x16.png" 16
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_16x16@2x.png" 32
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_32x32.png" 32
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_32x32@2x.png" 64
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_128x128.png" 128
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_128x128@2x.png" 256
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_256x256.png" 256
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_256x256@2x.png" 512
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_512x512.png" 512
render "$SVG_DIR/ember-appicon.svg" "$ICONSET/icon_512x512@2x.png" 1024

iconutil -c icns "$ICONSET" -o Resources/Ember.icns
echo "Built Resources/Ember.icns"

# Menu-bar glyphs are rendered straight from the system's SF Symbols
# (flame.fill / flame) rather than the SVG sources above — MenuBarIcon.swift
# loads these as a template NSImage instead of using SwiftUI's
# Image(systemName:), which sidesteps a MenuBarExtra layout bug (see the
# comment there) while keeping the exact same glyph.
render_symbol() {
    swift scripts/render-symbol.swift "$1" "$2" "$3"
}

render_symbol "flame.fill" "$MENUBAR_DIR/MenuBarActiveTemplate.png" 18
render_symbol "flame.fill" "$MENUBAR_DIR/MenuBarActiveTemplate@2x.png" 36
render_symbol "flame" "$MENUBAR_DIR/MenuBarInactiveTemplate.png" 18
render_symbol "flame" "$MENUBAR_DIR/MenuBarInactiveTemplate@2x.png" 36

echo "Done. Icons written to Resources/."

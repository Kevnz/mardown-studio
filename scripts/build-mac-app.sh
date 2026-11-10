#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "==> 1/3 Building GFM + Mermaid static bundle..."
npm run build

APP_BUNDLE="$PROJECT_DIR/build/Markdown Studio.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> 2/3 Assembling macOS .app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR/web"

cp "$PROJECT_DIR/macos/Info.plist" "$CONTENTS_DIR/Info.plist"
cp -R "$PROJECT_DIR/dist/"* "$RESOURCES_DIR/web/"

echo "==> 3/3 Compiling native Swift AppKit binary..."
swiftc \
  -O \
  -framework Cocoa \
  -framework WebKit \
  -framework UniformTypeIdentifiers \
  "$PROJECT_DIR/macos/main.swift" \
  -o "$MACOS_DIR/MarkdownStudio"

codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "==> Successfully built native macOS application:"
echo "    $APP_BUNDLE"

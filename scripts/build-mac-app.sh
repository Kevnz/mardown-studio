#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "==> 1/4 Generating macOS AppIcon (.icns) & Web Favicon..."
ICON_WORK_DIR="/tmp/markdown-studio-icon-$$"
ICONSET_DIR="$ICON_WORK_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR" "$PROJECT_DIR/public"

swift "$PROJECT_DIR/macos/generate_icon.swift" "$ICON_WORK_DIR/AppIcon-1024.png"
cp "$ICON_WORK_DIR/AppIcon-1024.png" "$PROJECT_DIR/macos/AppIcon-1024.png"
sips -z 256 256 "$ICON_WORK_DIR/AppIcon-1024.png" --out "$PROJECT_DIR/public/app-icon.png" >/dev/null

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICON_WORK_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$ICON_WORK_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$PROJECT_DIR/macos/AppIcon.icns"
rm -rf "$ICON_WORK_DIR"

echo "==> 2/4 Building GFM + Mermaid static bundle..."
npm run build

APP_BUNDLE="$PROJECT_DIR/build/Markdown Studio.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> 3/4 Assembling macOS .app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR/web"

cp "$PROJECT_DIR/macos/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/macos/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp -R "$PROJECT_DIR/dist/"* "$RESOURCES_DIR/web/"

echo "==> 4/4 Compiling native Swift AppKit binary..."
swiftc \
  -O \
  -framework Cocoa \
  -framework WebKit \
  -framework UniformTypeIdentifiers \
  "$PROJECT_DIR/macos/main.swift" \
  -o "$MACOS_DIR/MarkdownStudio"

touch "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "==> Successfully built native macOS application with AppIcon:"
echo "    $APP_BUNDLE"

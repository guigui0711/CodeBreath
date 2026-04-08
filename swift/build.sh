#!/bin/bash
# Build CodeBreathNotify.app — a minimal macOS .app bundle for native notifications.
#
# Usage:
#   ./swift/build.sh            # builds to ~/.codebreath/CodeBreathNotify.app
#   ./swift/build.sh /some/path # builds to /some/path/CodeBreathNotify.app
#
# Requirements: Xcode command-line tools (swiftc)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${1:-$HOME/.codebreath}"
APP_NAME="CodeBreathNotify"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

echo "Building $APP_NAME..."

# Check for swiftc
if ! command -v swiftc &>/dev/null; then
    echo "Error: swiftc not found. Install Xcode command-line tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Create .app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile Swift source
swiftc \
    -O \
    -target "$(uname -m)-apple-macosx12.0" \
    -o "$MACOS_DIR/$APP_NAME" \
    "$SCRIPT_DIR/main.swift"

echo "Compiled binary: $MACOS_DIR/$APP_NAME"

# Write Info.plist — critical for UNUserNotificationCenter to work
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.codebreath.notify</string>
    <key>CFBundleName</key>
    <string>CodeBreath</string>
    <key>CFBundleDisplayName</key>
    <string>CodeBreath</string>
    <key>CFBundleExecutable</key>
    <string>CodeBreathNotify</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
PLIST

echo "Created Info.plist (alert-style notifications)"

# Ad-hoc code sign (required for UNUserNotificationCenter on macOS)
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null && \
    echo "Ad-hoc code signed" || \
    echo "Warning: codesign failed (notifications may not work)"

# Register with Launch Services so macOS knows about the bundle
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$APP_BUNDLE" 2>/dev/null || true

echo ""
echo "Built successfully: $APP_BUNDLE"
echo ""
echo "First run: macOS will ask for notification permission."
echo "To grant: System Settings > Notifications > CodeBreath > Allow Notifications"
echo ""
echo "Test:"
echo "  open -W -n '$APP_BUNDLE' --args --title 'Test' --body 'Hello!' --done-label 'OK' --skip-label 'Skip' --timeout 30"

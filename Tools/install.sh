#!/bin/bash
#
# Build Paragraph and replace the copy in /Applications.
#
#     Tools/install.sh
#
# Builds a universal Release binary and installs it with ditto, which preserves
# the bundle's symlinks and code signature where cp -R and zip do not. Quits a
# running Paragraph first, because replacing a bundle underneath a running
# process leaves it in an undefined state.
#
# The installed copy is never quarantined: it is built here rather than
# downloaded, so it opens without the first-launch Gatekeeper prompt that people
# downloading the release zip will see.
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DESTINATION="/Applications/Paragraph.app"

if [ "${1:-}" != "--no-build" ]; then
  echo "▸ Release build (universal)"
  xcodebuild -project Paragraph.xcodeproj -scheme Paragraph -configuration Release \
    -destination 'generic/platform=macOS' ONLY_ACTIVE_ARCH=NO build 2>&1 | tail -1
  DERIVED=$(ls -d ~/Library/Developer/Xcode/DerivedData/Paragraph-*/Build/Products/Release/Paragraph.app | head -1)
  rm -rf build/Paragraph.app
  cp -R "$DERIVED" build/Paragraph.app
fi

if pgrep -x Paragraph >/dev/null; then
  echo "▸ Quitting the running copy"
  osascript -e 'tell application "Paragraph" to quit' >/dev/null 2>&1 || pkill -x Paragraph || true
  for _ in $(seq 1 20); do
    pgrep -x Paragraph >/dev/null || break
    sleep 0.5
  done
fi

echo "▸ Installing to $DESTINATION"
rm -rf "$DESTINATION"
ditto build/Paragraph.app "$DESTINATION"

echo "▸ Verifying"
codesign --verify --deep --strict "$DESTINATION"
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$DESTINATION/Contents/Info.plist" \
  | sed 's/^/  version: /'
lipo -info "$DESTINATION/Contents/MacOS/Paragraph" | sed 's/.*are: /  architectures: /'
if xattr "$DESTINATION" 2>/dev/null | grep -q quarantine; then
  echo "  quarantined — will prompt on launch"
else
  echo "  not quarantined — opens normally"
fi

/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f "$DESTINATION"
echo "▸ Installed"

#!/bin/bash
#
# Build and package a Paragraph release.
#
#     Tools/release.sh 1.1
#
# Sets the version, runs every test, builds a universal Release binary and
# packages it as build/Paragraph-<version>.zip, verifying the archive round
# trips with its signature intact. It does not tag or publish: write the release
# notes, then
#
#     git tag -a v<version> -m "Paragraph <version>"
#     git push origin v<version>
#     gh release create v<version> build/Paragraph-<version>.zip --title "Paragraph <version>" --notes-file <notes>
#
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: Tools/release.sh <version>   e.g. Tools/release.sh 1.1" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

PROJECT=Paragraph.xcodeproj
PBXPROJ="$PROJECT/project.pbxproj"

echo "▸ Setting version to $VERSION"
BUILD=$(( $(grep -m1 -o 'CURRENT_PROJECT_VERSION = [0-9]*' "$PBXPROJ" | grep -o '[0-9]*') + 1 ))
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $VERSION/g" "$PBXPROJ"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $BUILD/g" "$PBXPROJ"
echo "  marketing $VERSION, build $BUILD"

echo "▸ Package tests"
swift test --package-path ParagraphKit 2>&1 | tail -1

echo "▸ Application tests"
xcodebuild -project "$PROJECT" -scheme Paragraph -configuration Debug test 2>&1 \
  | grep -E '^\*\* TEST (SUCCEEDED|FAILED)' || { echo "  tests failed"; exit 1; }

echo "▸ Release build (universal)"
xcodebuild -project "$PROJECT" -scheme Paragraph -configuration Release \
  -destination 'generic/platform=macOS' ONLY_ACTIVE_ARCH=NO build 2>&1 | tail -1

DERIVED=$(ls -d ~/Library/Developer/Xcode/DerivedData/Paragraph-*/Build/Products/Release/Paragraph.app | head -1)
rm -rf build/Paragraph.app
cp -R "$DERIVED" build/Paragraph.app

ZIP="build/Paragraph-$VERSION.zip"
echo "▸ Packaging $ZIP"
rm -f "$ZIP"
# ditto keeps the bundle's symlinks and code signature intact; zip does not.
ditto -c -k --sequesterRsrc --keepParent build/Paragraph.app "$ZIP"

echo "▸ Verifying the archive"
VERIFY=$(mktemp -d)
ditto -x -k "$ZIP" "$VERIFY"
codesign --verify --deep --strict "$VERIFY/Paragraph.app"
lipo -info "$VERIFY/Paragraph.app/Contents/MacOS/Paragraph" | sed 's/.*are: /  architectures: /'
otool -l "$VERIFY/Paragraph.app/Contents/MacOS/Paragraph" | grep -m1 minos | sed 's/^ */  deployment target: /'
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$VERIFY/Paragraph.app/Contents/Info.plist" | sed 's/^/  version: /'
rm -rf "$VERIFY"

echo "▸ Done: $ZIP ($(du -h "$ZIP" | cut -f1))"

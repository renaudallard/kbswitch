#!/bin/sh
set -e

APP_NAME="kbswitch"
BUILD_DIR=".build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

BIN_PATH=$(swift build -c release --arch arm64 --show-bin-path)
swift build -c release --arch arm64

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Sources/${APP_NAME}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Generate .icns from icon.png
ICONSET="${BUILD_DIR}/icon.iconset"
rm -rf "${ICONSET}"
mkdir -p "${ICONSET}"
for size in 16 32 128 256 512; do
    sips -z ${size} ${size} icon.png --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z ${double} ${double} icon.png --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" "${ICONSET}"
rm -rf "${ICONSET}"

codesign --force --sign - "${APP_BUNDLE}"

echo "Built: ${APP_BUNDLE}"

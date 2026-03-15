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

codesign --force --sign - "${APP_BUNDLE}"

echo "Built: ${APP_BUNDLE}"

#!/bin/sh

# This script is used to build the TrollMemo app and create a tipa file with Xcode.
if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION=$1

# Strip leading "v" from version if present
VERSION=${VERSION#v}

# Build using Xcode
xcodebuild clean build archive \
-scheme TrollMemo \
-project TrollMemo.xcodeproj \
-sdk iphoneos \
-destination 'generic/platform=iOS' \
-archivePath TrollMemo \
CODE_SIGNING_ALLOWED=NO | xcpretty

chmod 0644 Resources/Info.plist
cp supports/entitlements.plist TrollMemo.xcarchive/Products
cd TrollMemo.xcarchive/Products/Applications
codesign --remove-signature TrollMemo.app
cd -
cd TrollMemo.xcarchive/Products
mv Applications Payload
ldid -Sentitlements.plist Payload/TrollMemo.app
chmod 0644 Payload/TrollMemo.app/Info.plist
zip -qr TrollMemo.tipa Payload
cd -
mkdir -p packages
mv TrollMemo.xcarchive/Products/TrollMemo.tipa packages/TrollMemo+AppIntents16_$VERSION.tipa

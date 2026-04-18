#!/bin/sh

# ci_post_clone.sh
# Xcode Cloud post-clone script for Flutter iOS builds
# This runs after the repo is cloned but before the build starts

set -e

echo "=== Installing Flutter SDK ==="
# Clone Flutter SDK
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"

echo "=== Flutter Version ==="
flutter --version

echo "=== Installing Dependencies ==="
flutter pub get

echo "=== Generating iOS Build Files ==="
flutter precache --ios
flutter build ios --release --no-codesign

echo "=== Installing CocoaPods Dependencies ==="
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "=== Build Preparation Complete ==="

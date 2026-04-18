#!/bin/sh

# ci_post_clone.sh
# Xcode Cloud post-clone script for Flutter iOS builds

set -e

echo "=== Installing Flutter SDK ==="
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"

echo "=== Flutter Version ==="
flutter --version

echo "=== Precache iOS Artifacts ==="
flutter precache --ios

echo "=== Installing Dependencies ==="
cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

echo "=== Generating Flutter Build Files ==="
flutter build ios --config-only --release --no-codesign

echo "=== Installing CocoaPods ==="
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "=== Preparation Complete ==="

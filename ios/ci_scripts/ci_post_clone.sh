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

echo "=== Patching pubspec.yaml version from Xcode Cloud env ==="
cd "$CI_PRIMARY_REPOSITORY_PATH"
# pubspec.yaml on main holds a 0.0.0-dev placeholder; real version
# comes from the git tag that triggered this build, with Xcode Cloud's
# monotonic CI_BUILD_NUMBER as the build number.
if [ -n "$CI_TAG" ] && [ -n "$CI_BUILD_NUMBER" ]; then
  BUILD_NAME="${CI_TAG#v}"
  echo "Setting version to ${BUILD_NAME}+${CI_BUILD_NUMBER}"
  /usr/bin/sed -i '' -E "s/^version: .*/version: ${BUILD_NAME}+${CI_BUILD_NUMBER}/" pubspec.yaml
  grep '^version:' pubspec.yaml
else
  echo "No CI_TAG or CI_BUILD_NUMBER set — leaving placeholder version (build will be 0.0.0)."
fi

echo "=== Installing Dependencies ==="
flutter pub get

echo "=== Generating Flutter Build Files ==="
flutter build ios --config-only --release --no-codesign

echo "=== Installing CocoaPods ==="
cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
pod install

echo "=== Preparation Complete ==="

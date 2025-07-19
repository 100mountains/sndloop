#!/bin/bash
set -e

# Change to project root directory
cd "$(dirname "$0")/.."

echo "🏗️ Building SNDLOOP for all platforms..."
echo "📁 Working directory: $(pwd)"

# Clean previous builds
flutter clean
flutter pub get

# Build for web
echo "🌐 Building for web..."
flutter build web --release
echo "✅ Web build complete: build/web/"

# Build for Android
echo "🤖 Building for Android..."
flutter build apk --release
echo "✅ Android APK: build/app/outputs/flutter-apk/app-release.apk"

# Build for iOS (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Building for iOS..."
    flutter build ios --release --no-codesign
    echo "✅ iOS build complete: build/ios/iphoneos/"
fi

# Desktop builds
echo "💻 Building desktop apps..."

# macOS (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    flutter build macos --release
    echo "✅ macOS app: build/macos/Build/Products/Release/sndloop.app"
fi

# Windows (Windows/Linux with mingw)
if command -v flutter &> /dev/null; then
    if flutter config | grep -q "enable-windows-desktop: true"; then
        flutter build windows --release
        echo "✅ Windows app: build/windows/runner/Release/"
    fi
fi

# Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    flutter build linux --release
    echo "✅ Linux app: build/linux/x64/release/bundle/"
fi

echo "🎉 All available builds complete!"

#!/bin/bash

echo "🚀 Deploying SNDLOOP..."

# Build for production
./build.sh

echo "Select deployment target:"
echo "1) Web (copy to server)"
echo "2) Android (generate signed APK)"
echo "3) iOS App Store"
read -p "Choice [1-3]: " choice

case $choice in
    1)
        echo "📁 Web files ready in build/web/"
        echo "Copy contents to your web server"
        ;;
    2)
        echo "📱 For signed Android APK, you need:"
        echo "1. Create key.properties file"
        echo "2. Generate signing key"
        echo "3. Run: flutter build apk --release"
        ;;
    3)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "🍎 For App Store:"
            echo "1. Open build/ios/iphoneos/Runner.app in Xcode"
            echo "2. Archive and upload to App Store Connect"
        else
            echo "iOS deployment requires macOS"
        fi
        ;;
esac

#!/bin/bash

echo "🛠️ Starting development server..."

# Check for connected devices
flutter devices

echo "Select platform:"
echo "1) Web (Chrome)"
echo "2) Android"
echo "3) iOS (macOS only)"
read -p "Choice [1-3]: " choice

case $choice in
    1)
        flutter run -d chrome
        ;;
    2)
        flutter run -d android
        ;;
    3)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            flutter run -d ios
        else
            echo "iOS requires macOS"
        fi
        ;;
    *)
        echo "Running on first available device..."
        flutter run
        ;;
esac

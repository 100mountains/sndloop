#!/bin/bash
set -e

echo "🚀 Setting up SNDLOOP Flutter development environment..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "📱 Installing Flutter..."
    cd ~/
    git clone https://github.com/flutter/flutter.git -b stable
    echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
    source ~/.zshrc
fi

# Install dependencies
echo "📦 Installing dependencies..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    brew install --cask android-studio
    brew install cocoapods
else
    # Ubuntu
    sudo apt update
    sudo apt install -y curl git unzip xz-utils zip libglu1-mesa
fi

# Accept Android licenses
flutter doctor --android-licenses

# Enable desktop platforms
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop  
flutter config --enable-linux-desktop

# Create the project
echo "🎵 Creating SNDLOOP Flutter app..."
flutter create sndloop
cd sndloop

# Add dependencies to pubspec.yaml
cat << 'EOF' >> pubspec.yaml

dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  shared_preferences: ^2.2.2
  provider: ^6.1.1
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  json_serializable: ^6.7.1
  build_runner: ^2.4.7
EOF

# Install packages
flutter pub get

echo "✅ Setup complete! Run ./build.sh to build the app."

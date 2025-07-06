#!/bin/bash

# Build and Run MirrorBot Script
# This script builds the MirrorBot project and launches the app

set -e  # Exit on any error

echo "🔨 Building MirrorBot..."

# Build the project
xcodebuild -project MirrorBot.xcodeproj -scheme MirrorBot -configuration Debug build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find the built app (exclude Index.noindex paths)
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "MirrorBot.app" -path "*/Build/Products/Debug/*" ! -path "*/Index.noindex/*" 2>/dev/null | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "🚀 Launching MirrorBot from: $APP_PATH"
        open "$APP_PATH"
    else
        echo "❌ Could not find built MirrorBot.app"
        exit 1
    fi
else
    echo "❌ Build failed!"
    exit 1
fi
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MirrorBot is a SwiftUI-based macOS application that uses ScreenCaptureKit to capture and interact with iPhone Mirroring windows. The project is built with Xcode and uses Swift's modern concurrency features.

## Common Development Commands

### Building and Running
- Open the project in Xcode: `open MirrorBot.xcodeproj`
- Build from command line: `xcodebuild -project MirrorBot.xcodeproj -scheme MirrorBot -configuration Debug build`
- Run tests: `xcodebuild test -project MirrorBot.xcodeproj -scheme MirrorBot -destination 'platform=macOS'`

### Testing
- Unit tests are located in `MirrorBotTests/` and use the Swift Testing framework
- UI tests are in `MirrorBotUITests/`
- Run specific test: `xcodebuild test -project MirrorBot.xcodeproj -scheme MirrorBot -destination 'platform=macOS' -only-testing:MirrorBotTests/TestName`

## Architecture

### Core Components

1. **MirrorBotApp.swift**: Main app entry point using SwiftUI's `@main` attribute
2. **ContentView.swift**: Primary SwiftUI view (currently minimal with placeholder content)
3. **ScreenCaptureManager.swift**: Core functionality for capturing iPhone Mirroring windows
   - Uses `SCShareableContent` to enumerate available windows
   - Identifies iPhone Mirroring windows by title or bundle identifier
   - Captures screenshots using `SCScreenshotManager`
   - Implements async/await pattern for screen capture operations

### Key Technologies
- SwiftUI for UI framework
- ScreenCaptureKit for screen capture functionality
- Combine for reactive programming (ObservableObject pattern)
- Swift Testing framework for unit tests

### Screen Capture Logic
The `ScreenCaptureManager` class contains the core logic for:
- Finding iPhone Mirroring windows by searching for "iPhone" in window titles or "MirrorDisplay" in bundle identifiers
- Configuring capture settings (dimensions, audio capture disabled)
- Performing asynchronous image capture with error handling

## Development Notes

- The project uses modern Swift concurrency (async/await)
- Screen capture requires appropriate macOS permissions
- The app targets macOS and uses ScreenCaptureKit which requires macOS 12.3+
- All screen capture operations are performed asynchronously to avoid blocking the UI
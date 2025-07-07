//
//  ControlsView.swift
//  MirrorBot
//
//  Created by Leo on 7/7/25.
//

import SwiftUI
import ScreenCaptureKit

struct ControlsView: View {
    @ObservedObject var screenCaptureManager: ScreenCaptureManager
    @Binding var clickX: String
    @Binding var clickY: String
    @Binding var swipeIntensity: String
    @Binding var swipeMultiplier: String
    @Binding var textToType: String
    @Binding var addCRLF: Bool
    
    var body: some View {
        VStack {
            Text("🎮 Controls")
                .font(.headline)
                .padding(.bottom, 5)
            
            VStack(alignment: .leading, spacing: 10) {
                // Click Controls
                Group {
                    Text("Click Position:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("X:")
                        TextField("X", text: $clickX)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                        
                        Text("Y:")
                        TextField("Y", text: $clickY)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                    }
                    
                    Button(" Activate iPhone Window") {
                        Task {
                            guard let iPhoneWindow = screenCaptureManager.iPhoneWindow else { return }
                            
                            // First, activate the iPhone Mirroring window
                            await activateIPhoneMirrorWindow(iPhoneWindow)
                        }
                    }
                    
                    HStack {
                        Button("🖱️ Simulate Click") {
                            Task {
                                await simulateClick()
                            }
                        }
                        .disabled(clickX.isEmpty || clickY.isEmpty)
                        
                        Button("🔄 Reset") {
                            clickX = ""
                            clickY = ""
                        }
                    }
                }
                
                Divider()
                
                // Swipe Controls
                Group {
                    Text("Swipe Controls:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("Intensity:")
                        TextField("100", text: $swipeIntensity)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                        
                        Text("Multiplier:")
                        TextField("4", text: $swipeMultiplier)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                    }
                    
                    VStack(spacing: 5) {
                        Button("⬆️ Swipe Up") {
                            Task {
                                await simulateSwipe(direction: .up)
                            }
                        }
                        
                        HStack {
                            Button("⬅️ Swipe Left") {
                                Task {
                                    await simulateSwipe(direction: .left)
                                }
                            }
                            
                            Button("➡️ Swipe Right") {
                                Task {
                                    await simulateSwipe(direction: .right)
                                }
                            }
                        }
                        
                        Button("⬇️ Swipe Down") {
                            Task {
                                await simulateSwipe(direction: .down)
                            }
                        }
                        
                        // Command buttons
                        HStack(spacing: 5) {
                            Button("⌘1") {
                                Task {
                                    await simulateCommand1()
                                }
                            }
                            .frame(width: 30, height: 30)
                            .font(.caption2)
                            
                            Button("⌘2") {
                                Task {
                                    await simulateCommand2()
                                }
                            }
                            .frame(width: 30, height: 30)
                            .font(.caption2)
                            
                            Button("⌘3") {
                                Task {
                                    await simulateCommand3()
                                }
                            }
                            .frame(width: 30, height: 30)
                            .font(.caption2)
                        }
                    }
                }
                
                Divider()
                
                // Text Input Controls
                Group {
                    Text("Text Input:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    TextField("Text to type", text: $textToType)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Add CR/LF", isOn: $addCRLF)
                        .font(.caption)
                    
                    Button("⌨️ Type Text") {
                        Task {
                            await simulateTextInput()
                        }
                    }
                    .disabled(textToType.isEmpty)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
        }
        .frame(width: 200)
    }
    
    // MARK: - iPhone Window Activation
    private func activateIPhoneMirrorWindow(_ window: SCWindow) async {
        // Try multiple approaches to ensure iPhone Mirroring becomes the active app
        
        // Method 1: Use AppleScript to activate the iPhone Mirroring application
        let script1 = """
        tell application "iPhone Mirroring"
            activate
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script1) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if error == nil {
                print("✅ Successfully activated iPhone Mirroring app")
                return
            } else {
                print("⚠️ Method 1 failed: \(error?.description ?? "unknown error")")
            }
        }
        
        // Method 2: Use System Events to set frontmost
        let script2 = """
        tell application "System Events"
            set frontmost of (first process whose name contains "iPhone Mirroring" or name contains "MirrorDisplay") to true
        end tell
        """
        
        if let appleScript2 = NSAppleScript(source: script2) {
            var error: NSDictionary?
            appleScript2.executeAndReturnError(&error)
            if error == nil {
                print("✅ Successfully set iPhone Mirroring as frontmost")
            } else {
                print("⚠️ Method 2 failed: \(error?.description ?? "unknown error")")
            }
        }
        
        // Method 3: Try to click on the window to bring it to front
        let windowFrame = window.frame
        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        
        // Single click to ensure window is active
        if let clickEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: windowCenter, mouseButton: .left) {
            clickEvent.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        if let releaseEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: windowCenter, mouseButton: .left) {
            releaseEvent.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Control Functions
    private func simulateClick() async {
        guard let x = Int(clickX), let y = Int(clickY),
              let iPhoneWindow = screenCaptureManager.iPhoneWindow else { return }
        
        // First, activate the iPhone Mirroring window
        await activateIPhoneMirrorWindow(iPhoneWindow)
        
        // Small delay to ensure window is active
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Convert relative coordinates to absolute screen coordinates
        let iPhoneFrame = screenCaptureManager.windowFrame
        let absoluteX = iPhoneFrame.minX + CGFloat(x)
        let absoluteY = iPhoneFrame.minY + CGFloat(y)
        
        // Create and post click event
        let clickLocation = CGPoint(x: absoluteX, y: absoluteY)
        
        // Move cursor to click location first
        CGWarpMouseCursorPosition(clickLocation)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Create mouse down event
        if let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseDownEvent.post(tap: .cghidEventTap)
        }
        
        // Brief pause between down and up
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Create mouse up event
        if let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseUpEvent.post(tap: .cghidEventTap)
        }
        
        print("📱 Simulated click at (\(x), \(y)) -> absolute (\(absoluteX), \(absoluteY))")
    }
    
    enum SwipeDirection {
        case up, down, left, right
    }
    
    private func simulateSwipe(direction: SwipeDirection) async {
        guard let iPhoneWindow = screenCaptureManager.iPhoneWindow else { return }
        
        // First, activate the iPhone Mirroring window
        await activateIPhoneMirrorWindow(iPhoneWindow)
        
        // Small delay to ensure window is active
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        let iPhoneFrame = screenCaptureManager.windowFrame
        let centerX = iPhoneFrame.midX
        let centerY = iPhoneFrame.midY
        
        // Get swipe parameters
        let intensity = Int(swipeIntensity) ?? 100
        let multiplier = Int(swipeMultiplier) ?? 4
        let distance = CGFloat(intensity)
        
        var startPoint: CGPoint
        var endPoint: CGPoint
        
        switch direction {
        case .up:
            startPoint = CGPoint(x: centerX, y: centerY + distance)
            endPoint = CGPoint(x: centerX, y: centerY - distance)
        case .down:
            startPoint = CGPoint(x: centerX, y: centerY - distance)
            endPoint = CGPoint(x: centerX, y: centerY + distance)
        case .left:
            startPoint = CGPoint(x: centerX + distance, y: centerY)
            endPoint = CGPoint(x: centerX - distance, y: centerY)
        case .right:
            startPoint = CGPoint(x: centerX - distance, y: centerY)
            endPoint = CGPoint(x: centerX + distance, y: centerY)
        }
        
        // Move to start position
        CGWarpMouseCursorPosition(startPoint)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Mouse down
        if let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left) {
            mouseDownEvent.post(tap: .cghidEventTap)
        }
        
        // Perform swipe in steps for smooth movement
        let steps = 10 * multiplier
        for i in 1...steps {
            let progress = CGFloat(i) / CGFloat(steps)
            let currentX = startPoint.x + (endPoint.x - startPoint.x) * progress
            let currentY = startPoint.y + (endPoint.y - startPoint.y) * progress
            let currentPoint = CGPoint(x: currentX, y: currentY)
            
            CGWarpMouseCursorPosition(currentPoint)
            
            if let mouseDragEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: currentPoint, mouseButton: .left) {
                mouseDragEvent.post(tap: .cghidEventTap)
            }
            
            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms between steps
        }
        
        // Mouse up at end position
        if let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left) {
            mouseUpEvent.post(tap: .cghidEventTap)
        }
        
        print("📱 Simulated \(direction) swipe with intensity \(intensity) and multiplier \(multiplier)")
    }
    
    private func simulateCommand1() async {
        guard let iPhoneWindow = screenCaptureManager.iPhoneWindow else { return }
        await activateIPhoneMirrorWindow(iPhoneWindow)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        if let cmdKeyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x12, keyDown: true) { // Key code for 1
            cmdKeyEvent.flags = .maskCommand
            cmdKeyEvent.post(tap: .cghidEventTap)
        }
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        if let cmdKeyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x12, keyDown: false) {
            cmdKeyUpEvent.post(tap: .cghidEventTap)
        }
        
        print("📱 Simulated ⌘1")
    }
    
    private func simulateCommand2() async {
        guard let iPhoneWindow = screenCaptureManager.iPhoneWindow else { return }
        await activateIPhoneMirrorWindow(iPhoneWindow)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        if let cmdKeyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x13, keyDown: true) { // Key code for 2
            cmdKeyEvent.flags = .maskCommand
            cmdKeyEvent.post(tap: .cghidEventTap)
        }
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        if let cmdKeyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x13, keyDown: false) {
            cmdKeyUpEvent.post(tap: .cghidEventTap)
        }
        
        print("📱 Simulated ⌘2")
    }
    
    private func simulateCommand3() async {
        guard let iPhoneWindow = screenCaptureManager.iPhoneWindow else { return }
        await activateIPhoneMirrorWindow(iPhoneWindow)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        if let cmdKeyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x14, keyDown: true) { // Key code for 3
            cmdKeyEvent.flags = .maskCommand
            cmdKeyEvent.post(tap: .cghidEventTap)
        }
        
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        if let cmdKeyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x14, keyDown: false) {
            cmdKeyUpEvent.post(tap: .cghidEventTap)
        }
        
        print("📱 Simulated ⌘3")
    }
    
    private func simulateTextInput() async {
        guard let iPhoneWindow = screenCaptureManager.iPhoneWindow else { return }
        await activateIPhoneMirrorWindow(iPhoneWindow)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Type each character
        for char in textToType {
            if let keyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                keyEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [UniChar(char.unicodeScalars.first?.value ?? 0)])
                keyEvent.post(tap: .cghidEventTap)
            }
            
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms between characters
            
            if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                keyUpEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [UniChar(char.unicodeScalars.first?.value ?? 0)])
                keyUpEvent.post(tap: .cghidEventTap)
            }
        }
        
        // Add CR/LF if requested
        if addCRLF {
            if let enterEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x24, keyDown: true) { // Return key
                enterEvent.post(tap: .cghidEventTap)
            }
            
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            if let enterUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x24, keyDown: false) {
                enterUpEvent.post(tap: .cghidEventTap)
            }
        }
        
        print("📱 Simulated text input: '\(textToType)'\(addCRLF ? " + Enter" : "")")
    }
}

#Preview {
    ControlsView(
        screenCaptureManager: ScreenCaptureManager(),
        clickX: .constant("100"),
        clickY: .constant("200"),
        swipeIntensity: .constant("100"),
        swipeMultiplier: .constant("4"),
        textToType: .constant("Hello"),
        addCRLF: .constant(false)
    )
}

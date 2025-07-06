//
//  ContentView.swift
//  MirrorBot
//
//  Created by Leo on 7/6/25.
//

import SwiftUI
import ScreenCaptureKit
import Vision

struct ContentView: View {
    @StateObject private var screenCaptureManager = ScreenCaptureManager()
    @State private var capturedImage: NSImage?
    @State private var isCapturing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var clickX = ""
    @State private var clickY = ""
    @State private var apiKey = ""
    @State private var apiResponse = ""
    @State private var isAnalyzing = false
    @State private var showingApiKeyAlert = false
    @State private var swipeIntensity = "100"
    @State private var swipeMultiplier = "4"
    
    var body: some View {
        HStack {
            // Left side - Screenshot display
            VStack {
                if let image = capturedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 300)
                        .border(Color.gray, width: 1)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 300)
                        .overlay(
                            Text("Searching for iPhone Mirroring window...")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        )
                }
                
                HStack {
                    Button("Capture iPhone Mirror") {
                        Task {
                            isCapturing = true
                            capturedImage = await screenCaptureManager.captureIPhoneMirrorWindow()
                            isCapturing = false
                        }
                    }
                    .disabled(isCapturing)
                    
                    Button("📸 Analyze") {
                        Task {
                            await analyzeScreenshot()
                        }
                    }
                    .disabled(isAnalyzing)
                    
                    Button("📱 Scan Pages") {
                        Task {
                            await scanAllPages()
                        }
                    }
                    .disabled(isAnalyzing)
                }
                .padding(.top, 10)
                
                if isCapturing {
                    ProgressView("Capturing...")
                        .padding()
                }
                
                if isAnalyzing {
                    ProgressView("Analyzing...")
                        .padding()
                }
            }
            
            Divider()
                .padding(.horizontal)
            
            // Right side - Controls
            VStack {
                VStack {
                    Text("Click Simulation")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
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
                    
                    HStack {
                        Button("Click") {
                            Task {
                                await simulateClick()
                            }
                        }
                        .disabled(clickX.isEmpty || clickY.isEmpty)
                        
                        Button("Double Click") {
                            Task {
                                await simulateDoubleClick()
                            }
                        }
                        .disabled(clickX.isEmpty || clickY.isEmpty)
                    }
                    .padding(.top, 5)
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                VStack {
                    Text("Swipe/Scroll")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    HStack {
                        Button("⬆️") {
                            Task {
                                await simulateSwipe(direction: .up)
                            }
                        }
                        .frame(width: 40, height: 30)
                        
                        Button("⬇️") {
                            Task {
                                await simulateSwipe(direction: .down)
                            }
                        }
                        .frame(width: 40, height: 30)
                    }
                    
                    VStack {
                        HStack {
                            Text("Int:")
                            TextField("100", text: $swipeIntensity)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 50)
                            
                            Text("×")
                            TextField("4", text: $swipeMultiplier)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 30)
                        }
                        .font(.caption)
                        
                        HStack {
                            Button("⬅️") {
                                Task {
                                    await simulateSwipe(direction: .left)
                                }
                            }
                            .frame(width: 40, height: 30)
                            
                            Button("➡️") {
                                Task {
                                    await simulateSwipe(direction: .right)
                                }
                            }
                            .frame(width: 40, height: 30)
                        }
                    }
                }
                
                Spacer()
            }
            .frame(width: 200)
            
            // Far right - AI Response
            if !apiResponse.isEmpty {
                Divider()
                    .padding(.horizontal)
                
                VStack {
                    Text("AI Analysis")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    ScrollView {
                        Text(apiResponse)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                    .frame(width: 250, height: 300)
                }
            }
        }
        .padding()
        .onAppear {
            Task {
                let window = await screenCaptureManager.findIPhoneMirrorWindow()
                if window == nil {
                    alertMessage = "No iPhone Mirroring window found. Please ensure iPhone Mirroring is active."
                    showingAlert = true
                } else {
                    // Position window to the right of iPhone Mirroring window
                    if let nsWindow = NSApplication.shared.windows.first {
                        let iPhoneFrame = screenCaptureManager.windowFrame
                        let newX = iPhoneFrame.maxX + 10 // 10px gap
                        let newY = iPhoneFrame.minY
                        
                        nsWindow.setFrame(
                            NSRect(
                                x: newX,
                                y: newY,
                                width: iPhoneFrame.width,
                                height: iPhoneFrame.height
                            ),
                            display: true
                        )
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("Exit") {
                NSApplication.shared.terminate(nil)
            }
        } message: {
            Text(alertMessage)
        }
        .alert("API Key Required", isPresented: $showingApiKeyAlert) {
            SecureField("Enter Anthropic API Key", text: $apiKey)
            Button("Save") {
                saveApiKey()
            }
            Button("Cancel") { }
        } message: {
            Text("Please enter your Anthropic API key to use AI analysis.")
        }
        .onAppear {
            loadApiKey()
        }
    }
    
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
        
        // Mouse down event
        if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseDown.post(tap: .cghidEventTap)
        }
        
        // Small delay
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Mouse up event
        if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }
    }
    
    private func simulateDoubleClick() async {
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
        
        let clickLocation = CGPoint(x: absoluteX, y: absoluteY)
        
        // Move cursor to click location first
        CGWarpMouseCursorPosition(clickLocation)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // First click
        if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseDown.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }
        
        // Short delay between clicks
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Second click
        if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseDown.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }
    }
    
    enum SwipeDirection {
        case up, down, left, right
    }
    
    private func simulateSwipe(direction: SwipeDirection) async {
        // Play system beep
        NSSound.beep()
        
        let iPhoneFrame = screenCaptureManager.windowFrame
        let centerX = iPhoneFrame.midX
        let centerY = iPhoneFrame.midY
        let centerPoint = CGPoint(x: centerX, y: centerY)
        
        if direction == .left || direction == .right {
            // Use working L2/R2 approach: wheelCount 2, horizontal in wheel2
            let intensity = Int32(swipeIntensity) ?? 100
            let multiplier = Int(swipeMultiplier) ?? 2
            var deltaX: Int32 = 0
            
            switch direction {
            case .left:
                deltaX = intensity
            case .right:
                deltaX = -intensity
            default:
                return
            }
            
            // Send scroll events based on multiplier
            for _ in 0..<multiplier {
                if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                           units: .pixel,
                                           wheelCount: 2,
                                           wheel1: 0,
                                           wheel2: deltaX,
                                           wheel3: 0) {
                    // Don't set location to avoid any cursor interference
                    scrollEvent.post(tap: .cghidEventTap)
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay between events
            }
            
        } else {
            // Use scroll events for up/down (content scrolling)
            var deltaY: Double = 0
            
            switch direction {
            case .up:
                deltaY = 50.0
            case .down:
                deltaY = -50.0
            default:
                return
            }
            
            for _ in 0..<5 {
                if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                           units: .pixel,
                                           wheelCount: 1,
                                           wheel1: Int32(deltaY),
                                           wheel2: 0,
                                           wheel3: 0) {
                    // Don't set location to avoid any cursor interference
                    scrollEvent.post(tap: .cghidEventTap)
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms between events
            }
        }
    }
    
    private func testSwipeLeft(type: Int) async {
        // 2 second delay + beep
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        NSSound.beep()
        
        let iPhoneFrame = screenCaptureManager.windowFrame
        let centerPoint = CGPoint(x: iPhoneFrame.midX, y: iPhoneFrame.midY)
        
        // Only L2: wheelCount 2, horizontal in wheel2, single event
        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                   units: .pixel,
                                   wheelCount: 2,
                                   wheel1: 0,
                                   wheel2: 100,
                                   wheel3: 0) {
            scrollEvent.location = centerPoint
            scrollEvent.post(tap: .cghidEventTap)
        }
    }
    
    private func testSwipeRight(type: Int) async {
        // 2 second delay + beep
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        NSSound.beep()
        
        let iPhoneFrame = screenCaptureManager.windowFrame
        let centerPoint = CGPoint(x: iPhoneFrame.midX, y: iPhoneFrame.midY)
        
        // Only R2: wheelCount 2, horizontal in wheel2, single event
        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                   units: .pixel,
                                   wheelCount: 2,
                                   wheel1: 0,
                                   wheel2: -100,
                                   wheel3: 0) {
            scrollEvent.location = centerPoint
            scrollEvent.post(tap: .cghidEventTap)
        }
    }
    
    private func activateIPhoneMirrorWindow(_ window: SCWindow) async {
        // Get the window number from SCWindow
        let windowNumber = window.windowID
        
        // Use AppleScript to activate the window
        let script = """
        tell application "System Events"
            set frontmost of (first process whose name contains "iPhone Mirroring" or name contains "MirrorDisplay") to true
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(nil)
        }
    }
    
    private func loadApiKey() {
        if let keyData = Keychain.load(key: "anthropic_api_key") {
            apiKey = String(data: keyData, encoding: .utf8) ?? ""
        }
    }
    
    private func saveApiKey() {
        Keychain.save(key: "anthropic_api_key", data: apiKey.data(using: .utf8) ?? Data())
    }
    
    private func analyzeScreenshot() async {
        if apiKey.isEmpty {
            showingApiKeyAlert = true
            return
        }
        
        isAnalyzing = true
        apiResponse = ""
        
        // Capture screenshot
        guard let image = await screenCaptureManager.captureIPhoneMirrorWindow() else {
            apiResponse = "Failed to capture screenshot"
            isAnalyzing = false
            return
        }
        
        // Convert to base64
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            apiResponse = "Failed to process image"
            isAnalyzing = false
            return
        }
        
        let base64Image = pngData.base64EncodedString()
        
        // Send to Anthropic API
        do {
            let response = try await sendToAnthropicAPI(base64Image: base64Image)
            apiResponse = response
        } catch {
            apiResponse = "API Error: \(error.localizedDescription)"
        }
        
        isAnalyzing = false
    }
    
    private func scanAllPages() async {
        isAnalyzing = true
        apiResponse = "Preparing scan - going to home screen..."
        
        // Alternative approach: Swipe left multiple times to get to first page
        // This is more reliable than Command+1
        for i in 1...10 {
            await simulateSwipe(direction: .left)
            apiResponse = "Going to first page... (\(i)/10)"
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second between swipes
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second final delay
        
        apiResponse = "Starting page scan from home screen..."
        
        var pageNumber = 1
        var lastImage: NSImage? = nil
        let maxPages = 20 // Safety limit
        
        while pageNumber <= maxPages {
            // Take screenshot
            guard let screenshot = await screenCaptureManager.captureIPhoneMirrorWindow() else {
                apiResponse = "Failed to capture screenshot on page \(pageNumber)"
                break
            }
            
            // Save screenshot
            let fileName = "iPhone_Page_\(String(format: "%02d", pageNumber)).png"
            if await saveImageToDownloads(screenshot, fileName: fileName) {
                apiResponse = "Saved page \(pageNumber) - \(fileName)"
            }
            
            // Check for "App Library" text using Vision
            if await detectAppLibrary(in: screenshot) {
                apiResponse = "✅ Found App Library on page \(pageNumber)! Scan complete."
                break
            }
            
            // Check for similar images (duplicate page detection)
            if let lastImg = lastImage, await imagesAreSimilar(lastImg, screenshot) {
                apiResponse = "📱 Reached end (similar page detected) on page \(pageNumber)"
                break
            }
            lastImage = screenshot
            
            // Swipe right to next page
            if pageNumber < maxPages {
                await simulateSwipe(direction: .right)
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay between pages
            }
            
            pageNumber += 1
        }
        
        if pageNumber > maxPages {
            apiResponse = "⚠️ Reached maximum pages (\(maxPages)) - scan stopped"
        }
        
        isAnalyzing = false
    }
    
    private func saveImageToDownloads(_ image: NSImage, fileName: String) async -> Bool {
        // Get the CGImage directly from NSImage for maximum quality
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to get CGImage from NSImage")
            return false
        }
        
        // Create bitmap rep directly from CGImage to preserve quality
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        
        // Use maximum quality PNG settings
        let pngProperties: [NSBitmapImageRep.PropertyKey: Any] = [
            .interlaced: false
        ]
        
        guard let pngData = bitmap.representation(using: .png, properties: pngProperties) else {
            print("Failed to create PNG data")
            return false
        }
        
        // Try to get the real user Downloads folder
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let downloadsPath = homeDirectory.appendingPathComponent("Downloads")
        let fileURL = downloadsPath.appendingPathComponent(fileName)
        
        do {
            try pngData.write(to: fileURL)
            print("Saved: \(fileURL.path) (\(pngData.count) bytes)")
            return true
        } catch {
            print("Error saving image to \(fileURL.path): \(error)")
            
            // Fallback: save to desktop
            let desktopPath = homeDirectory.appendingPathComponent("Desktop")
            let fallbackURL = desktopPath.appendingPathComponent(fileName)
            
            do {
                try pngData.write(to: fallbackURL)
                print("Fallback saved to Desktop: \(fallbackURL.path) (\(pngData.count) bytes)")
                return true
            } catch {
                print("Error saving to desktop: \(error)")
                return false
            }
        }
    }
    
    private func detectAppLibrary(in image: NSImage) async -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: false)
                    return
                }
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let text = topCandidate.string.lowercased()
                    
                    if text.contains("app library") || text.contains("app library") {
                        continuation.resume(returning: true)
                        return
                    }
                }
                continuation.resume(returning: false)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func imagesAreSimilar(_ image1: NSImage, _ image2: NSImage) async -> Bool {
        // Convert images to comparable format
        guard let cgImage1 = image1.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cgImage2 = image2.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        
        // Simple size check first
        if cgImage1.width != cgImage2.width || cgImage1.height != cgImage2.height {
            return false
        }
        
        // For now, let's disable duplicate detection and rely only on "App Library" text detection
        // This prevents false positives from hash collisions
        return false
    }
    
    private func simulateKeyPress(key: CGKeyCode, modifiers: CGEventFlags = []) async {
        // Try AppleScript approach for better compatibility
        let script = """
        tell application "System Events"
            key code 18 using command down
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
    
    private func sendToAnthropicAPI(base64Image: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30.0
        
        let payload: [String: Any] = [
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/png",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "What do you see on this screenshot of iPhone and which functions you can recognize here?"
                        ]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request: \(error.localizedDescription)"])
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check HTTP response
        if let httpResponse = response as? HTTPURLResponse {
            print("HTTP Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMessage)"])
            }
        }
        
        // Parse response
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let error = jsonResponse?["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "API Error: \(message)"])
            }
            
            if let content = jsonResponse?["content"] as? [[String: Any]],
               let firstContent = content.first,
               let text = firstContent["text"] as? String {
                return text
            }
            
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        } catch {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(error.localizedDescription)"])
        }
    }
}

// Keychain helper
struct Keychain {
    static func save(key: String, data: Data) {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            return dataTypeRef as! Data?
        } else {
            return nil
        }
    }
}

#Preview {
    ContentView()
}

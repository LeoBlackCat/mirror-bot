//
//  ContentView.swift
//  MirrorBot
//
//  Created by Leo on 7/6/25.
//

import SwiftUI
import ScreenCaptureKit
import Vision
import Foundation

class APILogger {
    static let shared = APILogger()
    private let logFileURL: URL
    
    private init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let downloadsPath = homeDirectory.appendingPathComponent("Downloads")
        logFileURL = downloadsPath.appendingPathComponent("MirrorBot_API_Log.txt")
        
        // Create initial log entry
        let header = "=== MirrorBot API Log Started at \(Date()) ===\n\n"
        try? header.write(to: logFileURL, atomically: true, encoding: .utf8)
    }
    
    func logRequest(appName: String, prompt: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logEntry = """
        [\(timestamp)] 🔍 REQUEST for app: \(appName)
        Prompt: \(prompt)
        
        """
        appendToLog(logEntry)
        print("📝 Logged API request for \(appName)")
    }
    
    func logResponse(appName: String, response: String, httpStatus: Int) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logEntry = """
        [\(timestamp)] 🤖 RESPONSE for app: \(appName) (HTTP \(httpStatus))
        Response: \(response)
        
        """
        appendToLog(logEntry)
        print("📝 Logged API response for \(appName)")
    }
    
    func logError(appName: String, error: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logEntry = """
        [\(timestamp)] ❌ ERROR for app: \(appName)
        Error: \(error)
        
        """
        appendToLog(logEntry)
        print("📝 Logged API error for \(appName)")
    }
    
    func logCoordinates(appName: String, coordinates: (x: Int, y: Int)?) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let coordString = coordinates != nil ? "(\(coordinates!.x), \(coordinates!.y))" : "not found"
        let logEntry = """
        [\(timestamp)] 📍 COORDINATES for app: \(appName)
        Parsed: \(coordString)
        
        """
        appendToLog(logEntry)
        print("📝 Logged coordinates for \(appName): \(coordString)")
    }
    
    private func appendToLog(_ content: String) {
        if let data = content.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

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
    @State private var targetAppName = "Instagram"
    @State private var openaiApiKey = ""
    @State private var useOpenAI = true // Use OpenAI by default
    @State private var showingOpenAIKeyAlert = false
    
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
                    
                    VStack {
                        HStack {
                            Text("App:")
                            TextField("Instagram", text: $targetAppName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                        }
                        .font(.caption)
                        
                        Button("📱 Scan & Find App") {
                            Task {
                                await scanAndFindApp()
                            }
                        }
                        .disabled(isAnalyzing)
                    }
                    
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
                
                Divider()
                    .padding(.vertical, 10)
                
                VStack {
                    Text("AI Provider")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    VStack {
                        HStack {
                            Button(useOpenAI ? "● OpenAI" : "○ OpenAI") {
                                useOpenAI = true
                            }
                            .foregroundColor(useOpenAI ? .blue : .secondary)
                            
                            Button(!useOpenAI ? "● Claude" : "○ Claude") {
                                useOpenAI = false
                            }
                            .foregroundColor(!useOpenAI ? .blue : .secondary)
                        }
                        .font(.caption)
                        
                        Button("⚙️ Keys") {
                            if useOpenAI {
                                showingOpenAIKeyAlert = true
                            } else {
                                showingApiKeyAlert = true
                            }
                        }
                        .font(.caption)
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
        .alert("Anthropic API Key Required", isPresented: $showingApiKeyAlert) {
            SecureField("Enter Anthropic API Key", text: $apiKey)
            Button("Save") {
                saveApiKey()
            }
            Button("Cancel") { }
        } message: {
            Text("Please enter your Anthropic API key to use Claude analysis.")
        }
        .alert("OpenAI API Key Required", isPresented: $showingOpenAIKeyAlert) {
            SecureField("Enter OpenAI API Key", text: $openaiApiKey)
            Button("Save") {
                saveOpenAIApiKey()
            }
            Button("Cancel") { }
        } message: {
            Text("Please enter your OpenAI API key to use GPT-4 Vision analysis.")
        }
        .onAppear {
            loadApiKey()
            loadOpenAIApiKey()
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
    
    private func loadOpenAIApiKey() {
        if let keyData = Keychain.load(key: "openai_api_key") {
            openaiApiKey = String(data: keyData, encoding: .utf8) ?? ""
        }
    }
    
    private func saveOpenAIApiKey() {
        Keychain.save(key: "openai_api_key", data: openaiApiKey.data(using: .utf8) ?? Data())
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
        
        var results: [String] = []
        
        while pageNumber <= maxPages {
            // Take screenshot
            guard let screenshot = await screenCaptureManager.captureIPhoneMirrorWindow() else {
                apiResponse = "Failed to capture screenshot on page \(pageNumber)"
                break
            }
            
            // Save screenshot
            let fileName = "iPhone_Page_\(String(format: "%02d", pageNumber)).png"
            await saveImageToDownloads(screenshot, fileName: fileName)
            
            // Analyze apps on this page (skip first page and App Library page)
            if pageNumber > 1 {
                apiResponse = "Analyzing apps on page \(pageNumber-1)..."
                let appNames = await extractAppNames(from: screenshot)
                if !appNames.isEmpty {
                    results.append("Page \(pageNumber-1): \(appNames.joined(separator: ", "))")
                } else {
                    results.append("Page \(pageNumber-1): No apps detected")
                }
                
                // Update display with current results
                apiResponse = results.joined(separator: "\n\n")
            }
            
            // Check for "App Library" text using Vision
            if await detectAppLibrary(in: screenshot) {
                apiResponse = results.joined(separator: "\n\n") + "\n\n✅ Scan complete - Found App Library!"
                break
            }
            
            // Check for similar images (duplicate page detection)
            if let lastImg = lastImage, await imagesAreSimilar(lastImg, screenshot) {
                apiResponse = results.joined(separator: "\n\n") + "\n\n📱 Scan complete - Reached end"
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
            apiResponse = results.joined(separator: "\n\n") + "\n\n⚠️ Reached maximum pages (\(maxPages))"
        }
        
        isAnalyzing = false
    }
    
    private func scanAndFindApp() async {
        print("🔍 Starting scan to find app: \(targetAppName)")
        isAnalyzing = true
        apiResponse = "Preparing scan - going to home screen..."
        
        // Go to first page
        for i in 1...10 {
            await simulateSwipe(direction: .left)
            apiResponse = "Going to first page... (\(i)/10)"
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        apiResponse = "Scanning pages to find \(targetAppName)..."
        print("📱 Starting page-by-page scan")
        
        var pageNumber = 1
        var lastImage: NSImage? = nil
        let maxPages = 20
        var results: [String] = []
        var foundAppImage: NSImage? = nil
        var foundOnPage = 0
        
        while pageNumber <= maxPages {
            print("📸 Capturing page \(pageNumber)")
            
            guard let screenshot = await screenCaptureManager.captureIPhoneMirrorWindow() else {
                print("❌ Failed to capture screenshot on page \(pageNumber)")
                apiResponse = "Failed to capture screenshot on page \(pageNumber)"
                break
            }
            
            // Save screenshot
            let fileName = "iPhone_Page_\(String(format: "%02d", pageNumber)).png"
            await saveImageToDownloads(screenshot, fileName: fileName)
            
            // Analyze apps on this page (skip first page and App Library page)
            if pageNumber > 1 {
                print("🔍 Analyzing apps on page \(pageNumber-1)")
                apiResponse = "Analyzing apps on page \(pageNumber-1)..."
                let appNames = await extractAppNames(from: screenshot)
                
                if !appNames.isEmpty {
                    results.append("Page \(pageNumber-1): \(appNames.joined(separator: ", "))")
                    print("📋 Found apps: \(appNames.joined(separator: ", "))")
                    
                    // Check if target app is found in this page
                    if appNames.contains(where: { $0.lowercased().contains(targetAppName.lowercased()) }) {
                        print("🎯 Found \(targetAppName) on page \(pageNumber-1)!")
                        foundAppImage = screenshot
                        foundOnPage = pageNumber-1
                        apiResponse = results.joined(separator: "\n\n") + "\n\n🎯 Found \(targetAppName) on page \(foundOnPage)! Analyzing position..."
                        
                        // Send to Anthropic to find coordinates
                        await findAppCoordinates(image: screenshot, appName: targetAppName, pageNumber: foundOnPage)
                        isAnalyzing = false
                        return
                    }
                } else {
                    results.append("Page \(pageNumber-1): No apps detected")
                    print("❌ No apps detected on page \(pageNumber-1)")
                }
                
                apiResponse = results.joined(separator: "\n\n")
            }
            
            // Check for App Library
            if await detectAppLibrary(in: screenshot) {
                print("📚 Found App Library on page \(pageNumber)")
                apiResponse = results.joined(separator: "\n\n") + "\n\n❌ App \(targetAppName) not found in any pages"
                break
            }
            
            // Check for duplicates
            if let lastImg = lastImage, await imagesAreSimilar(lastImg, screenshot) {
                print("🔄 Reached duplicate page, ending scan")
                apiResponse = results.joined(separator: "\n\n") + "\n\n❌ App \(targetAppName) not found in any pages"
                break
            }
            lastImage = screenshot
            
            // Swipe to next page
            if pageNumber < maxPages {
                print("➡️ Swiping to next page")
                await simulateSwipe(direction: .right)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            
            pageNumber += 1
        }
        
        if pageNumber > maxPages {
            print("⚠️ Reached maximum pages without finding \(targetAppName)")
            apiResponse = results.joined(separator: "\n\n") + "\n\n⚠️ Reached maximum pages - \(targetAppName) not found"
        }
        
        isAnalyzing = false
    }
    
    private func findAppCoordinates(image: NSImage, appName: String, pageNumber: Int) async {
        let provider = useOpenAI ? "OpenAI GPT-4 Vision" : "Anthropic Claude"
        print("🤖 Sending screenshot to \(provider) to find \(appName) coordinates")
        
        if useOpenAI && openaiApiKey.isEmpty {
            print("❌ No OpenAI API key found")
            showingOpenAIKeyAlert = true
            return
        } else if !useOpenAI && apiKey.isEmpty {
            print("❌ No Anthropic API key found")
            showingApiKeyAlert = true
            return
        }
        
        // Log original image dimensions
        print("📐 Original NSImage size: \(image.size.width) × \(image.size.height)")
        
        // Convert to base64
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("❌ Failed to process image for API")
            apiResponse += "\n\n❌ Failed to process image for coordinate detection"
            return
        }
        
        // Log actual bitmap dimensions
        print("📐 Bitmap dimensions: \(bitmap.pixelsWide) × \(bitmap.pixelsHigh) pixels")
        print("📦 PNG data size: \(pngData.count) bytes")
        
        let base64Image = pngData.base64EncodedString()
        
        do {
            let response: String
            if useOpenAI {
                response = try await sendOpenAIVisionRequest(base64Image: base64Image, appName: appName, imageWidth: bitmap.pixelsWide, imageHeight: bitmap.pixelsHigh)
            } else {
                response = try await sendAnthropicRequest(base64Image: base64Image, appName: appName, imageWidth: bitmap.pixelsWide, imageHeight: bitmap.pixelsHigh)
            }
            print("🤖 \(provider) response: \(response)")
            
            // Parse coordinates from response
            if let coordinates = parseCoordinates(from: response) {
                print("📍 Parsed coordinates: x=\(coordinates.x), y=\(coordinates.y)")
                APILogger.shared.logCoordinates(appName: appName, coordinates: coordinates)
                apiResponse += "\n\n📍 Found \(appName) at coordinates (\(coordinates.x), \(coordinates.y))"
                
                // Simulate double click with actual image dimensions
                await simulateDoubleClickAtCoordinates(x: coordinates.x, y: coordinates.y, imageWidth: bitmap.pixelsWide, imageHeight: bitmap.pixelsHigh)
            } else {
                print("❌ Could not parse coordinates from response")
                APILogger.shared.logCoordinates(appName: appName, coordinates: nil)
                apiResponse += "\n\n❌ Could not detect \(appName) coordinates in image"
            }
        } catch {
            print("❌ API Error: \(error.localizedDescription)")
            APILogger.shared.logError(appName: appName, error: error.localizedDescription)
            apiResponse += "\n\n❌ API Error: \(error.localizedDescription)"
        }
    }
    
    private func parseCoordinates(from response: String) -> (x: Int, y: Int)? {
        // Look for patterns like (x,y) or x=123, y=456
        let patterns = [
            #"\((\d+),\s*(\d+)\)"#,  // (123, 456)
            #"x[=:]\s*(\d+)[,\s]+y[=:]\s*(\d+)"#,  // x=123, y=456 or x:123 y:456
            #"(\d+)[,\s]+(\d+)"#  // 123, 456
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: response.utf16.count)
                if let match = regex.firstMatch(in: response, options: [], range: range) {
                    if match.numberOfRanges >= 3 {
                        let xRange = match.range(at: 1)
                        let yRange = match.range(at: 2)
                        
                        if let xString = Range(xRange, in: response),
                           let yString = Range(yRange, in: response),
                           let x = Int(response[xString]),
                           let y = Int(response[yString]) {
                            return (x: x, y: y)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func simulateDoubleClickAtCoordinates(x: Int, y: Int, imageWidth: Int, imageHeight: Int) async {
        print("🖱️ Simulating double click at image coordinates (\(x), \(y))")
        
        guard let iPhoneWindow = screenCaptureManager.iPhoneWindow else {
            print("❌ No iPhone window found")
            return
        }
        
        // Get the current window frame directly from the window object (fresh)
        let iPhoneFrame = iPhoneWindow.frame
        
        // Activate iPhone Mirroring window properly
        print("🔄 Activating iPhone Mirroring window...")
        await activateIPhoneMirrorWindow(iPhoneWindow)
        try? await Task.sleep(nanoseconds: 500_000_000) // Wait longer for window activation
        
        // Also try to bring window to front using window ID
        let windowID = iPhoneWindow.windowID
        print("📱 iPhone window ID: \(windowID)")
        
        // Alternative activation method - click on window first to ensure it's active
        let windowCenter = CGPoint(
            x: iPhoneFrame.minX + iPhoneFrame.width / 2,
            y: iPhoneFrame.minY + iPhoneFrame.height / 2
        )
        print("🎯 Clicking window center first: (\(windowCenter.x), \(windowCenter.y))")
        
        // Single click to activate window
        CGWarpMouseCursorPosition(windowCenter)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        if let activateClick = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: windowCenter, mouseButton: .left) {
            activateClick.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        if let activateRelease = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: windowCenter, mouseButton: .left) {
            activateRelease.post(tap: .cghidEventTap)
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000) // Wait for window to become active
        
        // Also update our stored frame
        await MainActor.run {
            screenCaptureManager.windowFrame = iPhoneFrame
        }
        print("📱 iPhone window frame: \(iPhoneFrame)")
        print("📍 Window origin: (\(iPhoneFrame.minX), \(iPhoneFrame.minY))")
        print("📏 Window size: \(iPhoneFrame.width) × \(iPhoneFrame.height)")
        print("🎯 Window spans: X=\(iPhoneFrame.minX) to \(iPhoneFrame.minX + iPhoneFrame.width), Y=\(iPhoneFrame.minY) to \(iPhoneFrame.minY + iPhoneFrame.height)")
        
        // Get screen information for debugging
        print("🖥️ All screens:")
        for (index, screen) in NSScreen.screens.enumerated() {
            print("   Screen \(index): frame=\(screen.frame), visible=\(screen.visibleFrame)")
        }
        if let screen = NSScreen.main {
            print("🖥️ Main screen frame: \(screen.frame)")
            print("🖥️ Main screen visible frame: \(screen.visibleFrame)")
        }
        
        // Try to find the actual window using NSWindow if possible
        print("🔍 Searching for iPhone Mirroring window in NSApplication...")
        for window in NSApplication.shared.windows {
            let title = window.title
            if title.contains("iPhone") || title.contains("Mirror") {
                print("   Found NSWindow: '\(title)' at frame: \(window.frame)")
            }
        }
        
        // Check if the SCWindow frame makes sense
        var correctedFrame = iPhoneFrame
        if iPhoneFrame.minX < -100 || iPhoneFrame.minX > 2000 {
            print("⚠️ WARNING: SCWindow frame looks suspicious: \(iPhoneFrame)")
            print("   This suggests the window coordinates might be wrong")
            
            // Try to get real window position using AppleScript
            print("🍎 Getting iPhone Mirroring window position via AppleScript...")
            if let realPosition = getIPhoneMirroringWindowPosition() {
                print("🍎 AppleScript found iPhone window at: \(realPosition)")
                correctedFrame = CGRect(
                    x: realPosition.x, 
                    y: realPosition.y, 
                    width: iPhoneFrame.width, 
                    height: iPhoneFrame.height
                )
                print("🔧 Using AppleScript corrected frame: \(correctedFrame)")
            } else {
                print("🍎 AppleScript failed, using manual override...")
                correctedFrame = CGRect(x: 600, y: 150, width: 430, height: 942)
                print("🔧 Corrected frame: \(correctedFrame)")
            }
        }
        
        // Scale coordinates from actual image size to window size
        let actualImageWidth = CGFloat(imageWidth)
        let actualImageHeight = CGFloat(imageHeight)
        let windowWidth = correctedFrame.width
        let windowHeight = correctedFrame.height
        
        print("🖼️ Image dimensions: \(actualImageWidth) × \(actualImageHeight)")
        print("🪟 Window dimensions: \(windowWidth) × \(windowHeight)")
        
        let scaleX = windowWidth / actualImageWidth
        let scaleY = windowHeight / actualImageHeight
        
        let scaledX = CGFloat(x) * scaleX
        let scaledY = CGFloat(y) * scaleY
        
        print("📏 Scale factors: X=\(scaleX), Y=\(scaleY)")
        print("📍 Scaled coordinates: (\(scaledX), \(scaledY))")
        
        // Check if coordinates make sense
        print("🤔 Debugging coordinate calculation:")
        print("   Image coords from Claude: (\(x), \(y))")
        print("   Scaled to window: (\(scaledX), \(scaledY))")
        print("   Window origin: (\(correctedFrame.minX), \(correctedFrame.minY))")
        
        // Convert to absolute screen coordinates
        let absoluteX = correctedFrame.minX + scaledX
        let absoluteY = correctedFrame.minY + scaledY
        
        print("   Final absolute: (\(absoluteX), \(absoluteY))")
        
        let clickLocation = CGPoint(x: absoluteX, y: absoluteY)
        print("🖱️ Final absolute click location: (\(absoluteX), \(absoluteY))")
        
        // Verify coordinates are within window bounds
        let windowMaxX = correctedFrame.minX + correctedFrame.width
        let windowMaxY = correctedFrame.minY + correctedFrame.height
        
        if absoluteX < correctedFrame.minX || absoluteX > windowMaxX ||
           absoluteY < correctedFrame.minY || absoluteY > windowMaxY {
            print("⚠️ WARNING: Click coordinates are outside iPhone window bounds!")
            print("   Window bounds: (\(correctedFrame.minX), \(correctedFrame.minY)) to (\(windowMaxX), \(windowMaxY))")
            print("   Calculated click: (\(absoluteX), \(absoluteY))")
        } else {
            print("✅ Click coordinates are within window bounds")
        }
        
        // Move cursor to click location and pause for visual verification
        print("🎯 Moving cursor to click location...")
        NSSound.beep() // Beep when moving cursor
        CGWarpMouseCursorPosition(clickLocation)
        
        // Wait longer so you can see where the cursor moved
        print("⏱️ Pausing 2 seconds so you can see cursor position...")
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        print("🖱️ Starting double click...")
        NSSound.beep() // Beep before clicking
        
        // First click
        if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseDown.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }
        
        // Short delay between clicks
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        // Second click
        if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseDown.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: clickLocation, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }
        
        NSSound.beep() // Beep after clicking
        print("✅ Double click completed at scaled coordinates (\(Int(scaledX)), \(Int(scaledY)))")
        apiResponse += "\n\n✅ Double-clicked \(targetAppName) at scaled coordinates (\(Int(scaledX)), \(Int(scaledY)))"
    }
    
    private func getIPhoneMirroringWindowPosition() -> CGPoint? {
        let script = """
        tell application "System Events"
            tell application process "iPhone Mirroring"
                get position of front window
            end tell
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            
            if let error = error {
                print("🍎 AppleScript error: \(error)")
                return nil
            }
            
            if let resultString = result.stringValue {
                print("🍎 AppleScript result: \(resultString)")
                
                // Parse result like "{123, 456}" or "123, 456"
                let cleaned = resultString.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
                let components = cleaned.components(separatedBy: ",")
                
                if components.count >= 2,
                   let x = Double(components[0].trimmingCharacters(in: .whitespaces)),
                   let y = Double(components[1].trimmingCharacters(in: .whitespaces)) {
                    return CGPoint(x: x, y: y)
                }
            }
        }
        
        return nil
    }
    
    private func sendOpenAIVisionRequest(base64Image: String, appName: String, imageWidth: Int, imageHeight: Int) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openaiApiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        let promptText = """
        This is a \(imageWidth) × \(imageHeight) pixel iPhone screenshot. Find the \(appName) app icon.

        Return the exact center pixel coordinates as (x,y) where:
        - x: horizontal position (0-\(imageWidth), left to right)  
        - y: vertical position (0-\(imageHeight), top to bottom)
        - (0,0) = top-left corner

        Format: (x,y) only, or 'not found' if not visible.
        """
        
        // Log the request
        APILogger.shared.logRequest(appName: appName, prompt: promptText)
        
        let payload: [String: Any] = [
            "model": "gpt-4o", // GPT-4 with vision
            "max_tokens": 300,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": promptText
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64Image)"
                            ]
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
        
        var httpStatus = 0
        if let httpResponse = response as? HTTPURLResponse {
            httpStatus = httpResponse.statusCode
            print("🌐 OpenAI HTTP Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                APILogger.shared.logError(appName: appName, error: "HTTP \(httpResponse.statusCode): \(errorMessage)")
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMessage)"])
            }
        }
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let error = jsonResponse?["error"] as? [String: Any],
               let message = error["message"] as? String {
                APILogger.shared.logError(appName: appName, error: "API Error: \(message)")
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "API Error: \(message)"])
            }
            
            if let choices = jsonResponse?["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                APILogger.shared.logResponse(appName: appName, response: content, httpStatus: httpStatus)
                return content
            }
            
            APILogger.shared.logError(appName: appName, error: "Invalid response format")
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        } catch {
            APILogger.shared.logError(appName: appName, error: "Failed to parse response: \(error.localizedDescription)")
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(error.localizedDescription)"])
        }
    }
    
    private func sendAnthropicRequest(base64Image: String, appName: String, imageWidth: Int, imageHeight: Int) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30.0
        
//        let promptText = "There's a screenshot of iPhone screen. I'm looking for the app \(appName). Is there such an app? If so, please return the (x,y) coordinates of the main icon of this app. Only respond with the coordinates in format (x,y) or 'not found'."
        
        let promptText = """
        This is a \(imageWidth) × \(imageHeight) pixel iPhone screenshot. Find the \(appName) app icon (purple square with white camera icon).

        The \(appName) icon is located in the app grid area, NOT in the dock at the bottom.

        Return the pixel coordinates of the CENTER of the purple \(appName) icon itself (not the text label below it).

        Coordinates should be:
        - x: horizontal position (0-\(imageWidth), left to right)  
        - y: vertical position (0-\(imageHeight), top to bottom)
        - (0,0) = top-left corner

        Format: (x,y) only
        """;
        
//        let promptText = """
//        In this \(imageWidth) × \(imageHeight) iPhone screenshot, find the \(appName) purple icon and give me ONLY the coordinates in format (x,y).
//        
//        Do not show your work or calculations. Just the coordinates.
//        """

        
        // Log the request
        APILogger.shared.logRequest(appName: appName, prompt: promptText)
        
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
                            "text": promptText
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
        
        var httpStatus = 0
        if let httpResponse = response as? HTTPURLResponse {
            httpStatus = httpResponse.statusCode
            print("🌐 API HTTP Status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                APILogger.shared.logError(appName: appName, error: "HTTP \(httpResponse.statusCode): \(errorMessage)")
                throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMessage)"])
            }
        }
        
        do {
            let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let error = jsonResponse?["error"] as? [String: Any],
               let message = error["message"] as? String {
                APILogger.shared.logError(appName: appName, error: "API Error: \(message)")
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "API Error: \(message)"])
            }
            
            if let content = jsonResponse?["content"] as? [[String: Any]],
               let firstContent = content.first,
               let text = firstContent["text"] as? String {
                APILogger.shared.logResponse(appName: appName, response: text, httpStatus: httpStatus)
                return text
            }
            
            APILogger.shared.logError(appName: appName, error: "Invalid response format")
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        } catch {
            APILogger.shared.logError(appName: appName, error: "Failed to parse response: \(error.localizedDescription)")
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(error.localizedDescription)"])
        }
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
    
    private func extractAppNames(from image: NSImage) async -> [String] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                var appNames: [String] = []
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Filter out common non-app text and short strings
                    if !text.isEmpty && 
                       text.count >= 2 && 
                       text.count <= 25 && 
                       !text.contains("•") &&
                       !text.lowercased().contains("app library") &&
                       !text.contains("AM") &&
                       !text.contains("PM") &&
                       !text.matches("[0-9]{1,2}:[0-9]{2}") &&
                       !text.matches("^[0-9]+$") &&
                       topCandidate.confidence > 0.3 {
                        appNames.append(text)
                    }
                }
                
                // Remove duplicates and sort
                let uniqueAppNames = Array(Set(appNames)).sorted()
                continuation.resume(returning: uniqueAppNames)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
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

extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil
    }
}

#Preview {
    ContentView()
}

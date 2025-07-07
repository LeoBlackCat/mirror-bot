//
//  AITaskView.swift
//  MirrorBot
//
//  Created by Leo on 7/7/25.
//

import SwiftUI

struct AITaskView: View {
    @ObservedObject var screenCaptureManager: ScreenCaptureManager
    @Binding var aiTaskDescription: String
    @Binding var claudeApiKey: String
    @Binding var showingClaudeKeyAlert: Bool
    @State private var testImage: NSImage?
    @State private var showingTestResults = false
    @State private var testResults = ""
    
    var body: some View {
        VStack {
            Text("🤖 AI Task Automation")
                .font(.headline)
                .padding(.bottom, 5)
            
            VStack(alignment: .leading, spacing: 10) {
                // API Key Section
                Text("Claude API Key:")
                    .font(.caption)
                SecureField("Enter Claude API Key", text: $claudeApiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Task Description Section
                Text("Task Description:")
                    .font(.caption)
                TextField("e.g., Open Instagram and like the first post", text: $aiTaskDescription)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Main Control Buttons
                HStack {
                    Button("🚀 Start Task") {
                        if claudeApiKey.isEmpty {
                            showingClaudeKeyAlert = true
                        } else {
                            Task {
                                await screenCaptureManager.startTask(description: aiTaskDescription, apiKey: claudeApiKey)
                            }
                        }
                    }
                    .disabled(screenCaptureManager.isTaskRunning || aiTaskDescription.isEmpty)
                    
                    Button("⏸️ Pause") {
                        screenCaptureManager.pauseTask()
                    }
                    .disabled(!screenCaptureManager.isTaskRunning || screenCaptureManager.isTaskPaused)
                    
                    Button("▶️ Resume") {
                        screenCaptureManager.resumeTask()
                    }
                    .disabled(!screenCaptureManager.isTaskRunning || !screenCaptureManager.isTaskPaused)
                    
                    Button("🛑 Cancel") {
                        screenCaptureManager.cancelTask()
                    }
                    .disabled(!screenCaptureManager.isTaskRunning)
                }
                
                // Test Section
                Divider()
                
                Text("🧪 Test AI Functions")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    Button("📸 Test Cursor Overlay") {
                        Task {
                            await testCursorOverlay()
                        }
                    }
                    
                    Button("📏 Test Compression") {
                        Task {
                            await testImageCompression()
                        }
                    }
                    
                    Button("🖼️ Manual Screenshot") {
                        Task {
                            await takeManualScreenshot()
                        }
                    }
                }
                .font(.caption)
                
                // Test Results
                if showingTestResults {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Test Results:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        ScrollView {
                            Text(testResults)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 60)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                // Test Image Display
                if let testImage = testImage {
                    VStack {
                        Text("Test Image:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Image(nsImage: testImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 200)
                            .border(Color.gray, width: 1)
                    }
                }
                
                // Status Section
                VStack(alignment: .leading, spacing: 5) {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(screenCaptureManager.taskStatus)
                        .font(.caption)
                        .foregroundColor(screenCaptureManager.isTaskRunning ? .green : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                
                if screenCaptureManager.isTaskRunning {
                    ProgressView("Task in progress...")
                        .padding(.top, 5)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
        }
        .frame(width: 320)
    }
    
    private func testCursorOverlay() async {
        testResults = "Testing cursor overlay..."
        showingTestResults = true
        
        guard let screenshot = await screenCaptureManager.captureWithCursorOverlay() else {
            testResults = "❌ Failed to capture screenshot with cursor overlay"
            return
        }
        
        testImage = screenshot
        testResults = "✅ Successfully captured screenshot with cursor overlay\nCursor position: \(screenCaptureManager.currentCursorPosition)"
    }
    
    private func testImageCompression() async {
        testResults = "Testing image compression..."
        showingTestResults = true
        
        guard let screenshot = await screenCaptureManager.captureIPhoneMirrorWindow() else {
            testResults = "❌ Failed to capture screenshot for compression test"
            return
        }
        
        let originalSize = screenshot.tiffRepresentation?.count ?? 0
        
        guard let compressedData = screenCaptureManager.compressImage(screenshot) else {
            testResults = "❌ Failed to compress image"
            return
        }
        
        let compressedSize = compressedData.count
        let compressionRatio = Double(compressedSize) / Double(originalSize)
        
        testResults = """
        ✅ Image compression test successful
        Original size: \(ByteCountFormatter.string(fromByteCount: Int64(originalSize), countStyle: .memory))
        Compressed size: \(ByteCountFormatter.string(fromByteCount: Int64(compressedSize), countStyle: .memory))
        Compression ratio: \(String(format: "%.2f", compressionRatio))
        """
    }
    
    private func takeManualScreenshot() async {
        testResults = "Taking manual screenshot..."
        showingTestResults = true
        
        guard let screenshot = await screenCaptureManager.captureIPhoneMirrorWindow() else {
            testResults = "❌ Failed to capture manual screenshot"
            return
        }
        
        testImage = screenshot
        testResults = "✅ Manual screenshot captured successfully\nSize: \(Int(screenshot.size.width))x\(Int(screenshot.size.height))"
    }
}

#Preview {
    AITaskView(
        screenCaptureManager: ScreenCaptureManager(),
        aiTaskDescription: .constant("Test task"),
        claudeApiKey: .constant(""),
        showingClaudeKeyAlert: .constant(false)
    )
}
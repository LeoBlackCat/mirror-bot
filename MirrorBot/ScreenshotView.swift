//
//  ScreenshotView.swift
//  MirrorBot
//
//  Created by Leo on 7/7/25.
//

import SwiftUI

struct ScreenshotView: View {
    @ObservedObject var screenCaptureManager: ScreenCaptureManager
    @Binding var capturedImage: NSImage?
    @Binding var isCapturing: Bool
    @Binding var isAnalyzing: Bool
    @Binding var targetAppName: String
    
    let onAnalyze: () async -> Void
    let onDetectContours: () async -> Void
    let onScanAndFindApp: () async -> Void
    
    var body: some View {
        VStack {
            // Screenshot Display
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
            
            // Control Buttons
            VStack(spacing: 8) {
                HStack {
                    Button("📱 Capture iPhone Mirror") {
                        Task {
                            isCapturing = true
                            capturedImage = await screenCaptureManager.captureIPhoneMirrorWindow()
                            isCapturing = false
                        }
                    }
                    .disabled(isCapturing)
                    
                    Button("🎯 Capture + Cursor") {
                        Task {
                            isCapturing = true
                            capturedImage = await screenCaptureManager.captureWithCursorOverlay()
                            isCapturing = false
                        }
                    }
                    .disabled(isCapturing)
                }
                
                HStack {
                    Button("📸 Analyze") {
                        Task {
                            await onAnalyze()
                        }
                    }
                    .disabled(isAnalyzing)
                    
                    Button("🔍 Contours") {
                        Task {
                            await onDetectContours()
                        }
                    }
                    .disabled(isAnalyzing)
                }
                
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
                            await onScanAndFindApp()
                        }
                    }
                    .disabled(isAnalyzing)
                }
            }
            .padding(.top, 10)
            
            // Status Indicators
            if isCapturing {
                ProgressView("Capturing...")
                    .padding()
            }
            
            if isAnalyzing {
                ProgressView("Analyzing...")
                    .padding()
            }
        }
    }
}

#Preview {
    ScreenshotView(
        screenCaptureManager: ScreenCaptureManager(),
        capturedImage: .constant(nil),
        isCapturing: .constant(false),
        isAnalyzing: .constant(false),
        targetAppName: .constant("Instagram"),
        onAnalyze: { },
        onDetectContours: { },
        onScanAndFindApp: { }
    )
}
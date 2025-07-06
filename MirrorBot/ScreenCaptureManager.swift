//
//  ScreenCaptureManager.swift
//  MirrorBot
//
//  Created by Leo on 7/6/25.
//

import SwiftUI
import Combine
import ScreenCaptureKit

class ScreenCaptureManager: ObservableObject {
    @Published var iPhoneWindow: SCWindow?
    @Published var windowFrame: CGRect = .zero
    
    func findIPhoneMirrorWindow() async -> SCWindow? {
        do {
            // Get available content
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            
            // Find iPhone Mirroring window
            let window = content.windows.first { window in
                (window.title?.contains("iPhone Mirroring") == true) ||
                (window.owningApplication?.bundleIdentifier.contains("MirrorDisplay") == true)
            }
            
            if let window = window {
                await MainActor.run {
                    self.iPhoneWindow = window
                    self.windowFrame = window.frame
                }
            }
            
            return window
        } catch {
            print("Error finding iPhone Mirroring window: \(error)")
            return nil
        }
    }
    
    func captureIPhoneMirrorWindow() async -> NSImage? {
        guard let window = iPhoneWindow else { return nil }
        
        do {
            
            // Create capture configuration with maximum quality
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width)
            config.height = Int(window.frame.height)
            config.capturesAudio = false
            config.pixelFormat = kCVPixelFormatType_32BGRA // High quality pixel format
            config.colorSpaceName = CGColorSpace.displayP3 // Wide color gamut
            config.scalesToFit = false // Don't scale, preserve original resolution
            config.showsCursor = false // Hide cursor in screenshots!
            
            // Capture the window
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            
            return NSImage(cgImage: image, size: window.frame.size)
            
        } catch {
            print("Screen capture error: \(error)")
            return nil
        }
    }
}


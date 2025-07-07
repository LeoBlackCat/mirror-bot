//
//  ScreenCaptureManager.swift
//  MirrorBot
//
//  Created by Leo on 7/6/25.
//

import SwiftUI
import Combine
import ScreenCaptureKit
import Foundation
import AppKit

// MARK: - AI Command Protocol
protocol AICommand {
    var type: AICommandType { get }
    var parameters: [String: Any] { get }
}

enum AICommandType: String, CaseIterable {
    case moveCursor = "move_cursor"
    case clickCursor = "click_cursor"
    case done = "done"
}

struct MoveCursorCommand: AICommand {
    let type: AICommandType = .moveCursor
    let direction: String
    let distance: Int
    
    var parameters: [String: Any] {
        return ["direction": direction, "distance": distance]
    }
}

struct ClickCursorCommand: AICommand {
    let type: AICommandType = .clickCursor
    var parameters: [String: Any] { return [:] }
}

struct DoneCommand: AICommand {
    let type: AICommandType = .done
    let status: String
    let reason: String
    
    var parameters: [String: Any] {
        return ["status": status, "reason": reason]
    }
}

// MARK: - AI Response Models
struct AIResponse {
    let message: String
    let commands: [AICommand]
    let stopReason: String?
}

class ScreenCaptureManager: ObservableObject {
    @Published var iPhoneWindow: SCWindow?
    @Published var windowFrame: CGRect = .zero
    @Published var isTaskRunning = false
    @Published var isTaskPaused = false
    @Published var taskStatus = "Ready"
    @Published var currentCursorPosition: CGPoint = .zero
    
    // AI Configuration
    private var claudeAPIKey: String = ""
    private var claudeModel: String = "claude-3-5-sonnet-20240620"
    private var maxTokens: Int = 2048
    private var temperature: Double = 0.7
    private var maxMessages: Int = 20
    
    // Task Management
    private var conversation: [[String: Any]] = []
    private var taskDescription: String = ""
    private var isTaskCancelled = false
    
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
    
    // MARK: - Cursor Overlay Functions
    func drawCursorOverlay(on image: NSImage, at position: CGPoint) -> NSImage? {
        let size = image.size
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(size.width),
                                   pixelsHigh: Int(size.height),
                                   bitsPerSample: 8,
                                   samplesPerPixel: 4,
                                   hasAlpha: true,
                                   isPlanar: false,
                                   colorSpaceName: .calibratedRGB,
                                   bytesPerRow: 0,
                                   bitsPerPixel: 0)
        
        guard let imageRep = rep else { return nil }
        
        let ctx = NSGraphicsContext(bitmapImageRep: imageRep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        
        // Draw the original image
        image.draw(in: NSRect(origin: .zero, size: size))
        
        // Draw cursor overlay
        let cursorRadius: CGFloat = 10
        let cursorColor = NSColor.red
        
        // Draw circle
        let circleRect = NSRect(x: position.x - cursorRadius,
                               y: position.y - cursorRadius,
                               width: cursorRadius * 2,
                               height: cursorRadius * 2)
        
        cursorColor.setStroke()
        let circlePath = NSBezierPath(ovalIn: circleRect)
        circlePath.lineWidth = 2.0
        circlePath.stroke()
        
        // Draw crosshairs
        let lineLength: CGFloat = 20
        let horizontalLine = NSBezierPath()
        horizontalLine.move(to: CGPoint(x: position.x - lineLength, y: position.y))
        horizontalLine.line(to: CGPoint(x: position.x + lineLength, y: position.y))
        horizontalLine.lineWidth = 2.0
        horizontalLine.stroke()
        
        let verticalLine = NSBezierPath()
        verticalLine.move(to: CGPoint(x: position.x, y: position.y - lineLength))
        verticalLine.line(to: CGPoint(x: position.x, y: position.y + lineLength))
        verticalLine.lineWidth = 2.0
        verticalLine.stroke()
        
        NSGraphicsContext.restoreGraphicsState()
        
        let resultImage = NSImage(size: size)
        resultImage.addRepresentation(imageRep)
        return resultImage
    }
    
    func captureWithCursorOverlay() async -> NSImage? {
        guard let capturedImage = await captureIPhoneMirrorWindow() else { return nil }
        
        // Get current cursor position
        let cursorPosition = NSEvent.mouseLocation
        await MainActor.run {
            self.currentCursorPosition = cursorPosition
        }
        
        // Convert cursor position to image coordinates
        let imagePosition = CGPoint(x: cursorPosition.x - windowFrame.minX,
                                   y: cursorPosition.y - windowFrame.minY)
        
        return drawCursorOverlay(on: capturedImage, at: imagePosition)
    }
    
    // MARK: - Image Compression Functions
    func compressImage(_ image: NSImage, maxSize: Int = 5 * 1024 * 1024, initialQuality: CGFloat = 0.95) -> Data? {
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData) else { return nil }
        
        var quality = initialQuality
        var compressedData: Data?
        
        repeat {
            let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: quality]
            compressedData = bitmap.representation(using: .jpeg, properties: properties)
            
            if let data = compressedData, data.count <= maxSize {
                break
            }
            
            quality *= 0.9
        } while quality > 0.1
        
        return compressedData
    }
    
    func imageToBase64(_ image: NSImage) -> String? {
        guard let compressedData = compressImage(image) else { return nil }
        return compressedData.base64EncodedString()
    }
    
    // MARK: - AI Integration Functions
    func sendToClaudeAI(_ image: NSImage, task: String, toolResults: [[String: Any]]? = nil) async -> AIResponse? {
        guard !claudeAPIKey.isEmpty else {
            print("Claude API key not set")
            return nil
        }
        
        if conversation.count >= maxMessages {
            await MainActor.run {
                self.taskStatus = "Conversation exceeded maximum length"
            }
            return nil
        }
        
        guard let base64Image = imageToBase64(image) else {
            print("Failed to convert image to base64")
            return nil
        }
        
        let systemPrompt = """
        You are an AI assistant specialized in guiding users through simulated touch operations on an iPhone screen. Your task is to interpret screen images and then provide precise movement and click instructions to complete specific tasks.

        Device Information:
        - Device: iPhone (displayed on a macOS screen)

        Cursor Representation:
        - The cursor is drawn on the screenshot as a red circle with crosshairs.
        - The center of this red circle with crosshairs represents the exact cursor position.

        Guiding Principles:
        1. Use the provided tools to interact with the device.
        2. Carefully analyze the provided screenshots, noting the current pointer position (represented by the red circle with crosshairs) and interface elements.
        3. Break down complex tasks into multiple small steps, using one tool at a time.
        4. Provide step-by-step movement and click instructions, using relative positions and distances when possible.
        5. Use the "done" tool when the task is completed or cannot be completed.
        6. If at any stage you find that the task cannot be completed, explain why and use the "done" tool.

        Initial Steps:
        1. Locate the iPhone screen within the provided screenshot.
        2. If the iPhone screen is not found, use the "done" tool to fail the task immediately.
        3. If the iPhone screen is found, gradually move the cursor (red circle with crosshairs) to the bottom left corner of the iPhone screen.
        4. Once at the bottom left corner, proceed with the remaining steps of the task.

        Analysis and Response Process:
        For each screenshot provided, you must:
        1. Think step-by-step and analyze every part of the image. Provide this analysis in <thinking> tags.
        2. Identify the current state of the task and any progress made.
        3. Consider the available tools and which one would be most appropriate for the next step.
        4. Provide your final suggestion for the next action in <action> tags.

        Remember:
        1. You have perfect vision and pay great attention to detail, which makes you an expert at analyzing screenshots and providing precise instructions.
        2. Use relative positions and distances when providing instructions, as the exact resolution may vary between iPhone models.
        3. Prioritize safe and conservative actions.
        4. Break down complex tasks into multiple small steps, providing only the next most appropriate step each time.
        5. Assume that each new screenshot provided is the result of executing your previous instructions.
        6. Always keep the initial task description in mind, ensuring that all actions are moving towards completing that task.
        7. Be as precise as possible, using relative measurements and descriptions of UI elements when applicable.
        8. The entire macOS screen will be provided in screenshots, so you need to identify the iPhone screen within it.
        9. Always refer to the cursor position using the red circle with crosshairs in your analysis and instructions.
        """
        
        var content: [[String: Any]] = []
        
        if let toolResults = toolResults {
            content.append(contentsOf: toolResults)
            content.append([
                "type": "text",
                "text": "Here's the latest screenshot after running the tool(s) for the task: \(task)\nCurrent cursor position: \(currentCursorPosition). The cursor is represented by a red circle with crosshairs on the screenshot.\nPlease analyze the image and suggest the next action."
            ])
        } else {
            content.append([
                "type": "text", 
                "text": "Here's the initial screenshot for the task: \(task)\nCurrent cursor position: \(currentCursorPosition). The cursor is represented by a red circle with crosshairs on the screenshot.\nPlease analyze the image and suggest the next action."
            ])
        }
        
        content.append([
            "type": "image",
            "source": [
                "type": "base64",
                "media_type": "image/jpeg",
                "data": base64Image
            ]
        ])
        
        let tools = [
            [
                "name": "move_cursor",
                "description": "Move the cursor in a specified direction by a certain distance",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "direction": [
                            "type": "string",
                            "enum": ["up", "down", "left", "right"]
                        ],
                        "distance": [
                            "type": "integer",
                            "description": "Distance to move in pixels"
                        ]
                    ],
                    "required": ["direction", "distance"]
                ]
            ],
            [
                "name": "click_cursor",
                "description": "Perform a click at the current cursor position",
                "input_schema": [
                    "type": "object",
                    "properties": [:]
                ]
            ],
            [
                "name": "done",
                "description": "Indicate that the task is completed or cannot be completed",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "status": [
                            "type": "string",
                            "enum": ["completed", "failed"],
                            "description": "Whether the task was completed successfully or failed"
                        ],
                        "reason": [
                            "type": "string",
                            "description": "Reason for completing or not completing the task"
                        ]
                    ],
                    "required": ["status", "reason"]
                ]
            ]
        ]
        
        let message: [String: Any] = [
            "role": "user",
            "content": content
        ]
        
        conversation.append(message)
        
        let requestBody: [String: Any] = [
            "model": claudeModel,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "system": systemPrompt,
            "tools": tools,
            "messages": conversation
        ]
        
        return await performClaudeAPIRequest(requestBody: requestBody)
    }
    
    private func performClaudeAPIRequest(requestBody: [String: Any]) async -> AIResponse? {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return parseClaudeResponse(json)
            }
        } catch {
            print("Claude API request failed: \(error)")
        }
        
        return nil
    }
    
    private func parseClaudeResponse(_ json: [String: Any]) -> AIResponse? {
        guard let content = json["content"] as? [[String: Any]] else { return nil }
        
        var commands: [AICommand] = []
        var message = ""
        
        for item in content {
            if let type = item["type"] as? String {
                if type == "text", let text = item["text"] as? String {
                    message += text
                } else if type == "tool_use",
                          let name = item["name"] as? String,
                          let input = item["input"] as? [String: Any] {
                    
                    switch name {
                    case "move_cursor":
                        if let direction = input["direction"] as? String,
                           let distance = input["distance"] as? Int {
                            commands.append(MoveCursorCommand(direction: direction, distance: distance))
                        }
                    case "click_cursor":
                        commands.append(ClickCursorCommand())
                    case "done":
                        if let status = input["status"] as? String,
                           let reason = input["reason"] as? String {
                            commands.append(DoneCommand(status: status, reason: reason))
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        let stopReason = json["stop_reason"] as? String
        return AIResponse(message: message, commands: commands, stopReason: stopReason)
    }
    
    // MARK: - Task Management Functions
    func startTask(description: String, apiKey: String) async {
        guard !isTaskRunning else { return }
        
        await MainActor.run {
            self.taskDescription = description
            self.claudeAPIKey = apiKey
            self.isTaskRunning = true
            self.isTaskCancelled = false
            self.isTaskPaused = false
            self.taskStatus = "Starting task..."
            self.conversation = []
        }
        
        await runTaskLoop()
    }
    
    func pauseTask() {
        isTaskPaused = true
        taskStatus = "Task paused"
    }
    
    func resumeTask() {
        isTaskPaused = false
        taskStatus = "Task resumed"
    }
    
    func cancelTask() {
        isTaskCancelled = true
        isTaskRunning = false
        taskStatus = "Task cancelled"
    }
    
    private func runTaskLoop() async {
        await MainActor.run {
            self.taskStatus = "Capturing initial screenshot..."
        }
        
        guard let screenshot = await captureWithCursorOverlay() else {
            await MainActor.run {
                self.taskStatus = "Failed to capture screenshot"
                self.isTaskRunning = false
            }
            return
        }
        
        await MainActor.run {
            self.taskStatus = "Analyzing screenshot..."
        }
        
        var response = await sendToClaudeAI(screenshot, task: taskDescription)
        
        while !isTaskCancelled && isTaskRunning {
            // Handle pause
            while isTaskPaused && !isTaskCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            if isTaskCancelled { break }
            
            guard let aiResponse = response else {
                await MainActor.run {
                    self.taskStatus = "Failed to get AI response"
                    self.isTaskRunning = false
                }
                return
            }
            
            await MainActor.run {
                self.taskStatus = "Processing AI response..."
            }
            
            // Execute commands
            var toolResults: [[String: Any]] = []
            
            for command in aiResponse.commands {
                if command.type == .done {
                    if let doneCmd = command as? DoneCommand {
                        await MainActor.run {
                            self.taskStatus = "Task \(doneCmd.status): \(doneCmd.reason)"
                            self.isTaskRunning = false
                        }
                        return
                    }
                }
                
                let result = await executeCommand(command)
                toolResults.append([
                    "type": "tool_result",
                    "tool_use_id": UUID().uuidString,
                    "content": [["type": "text", "text": result]]
                ])
            }
            
            // Capture new screenshot and send to AI
            if !toolResults.isEmpty {
                await MainActor.run {
                    self.taskStatus = "Capturing new screenshot..."
                }
                
                guard let newScreenshot = await captureWithCursorOverlay() else {
                    await MainActor.run {
                        self.taskStatus = "Failed to capture new screenshot"
                        self.isTaskRunning = false
                    }
                    return
                }
                
                await MainActor.run {
                    self.taskStatus = "Analyzing new screenshot..."
                }
                
                response = await sendToClaudeAI(newScreenshot, task: taskDescription, toolResults: toolResults)
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        }
        
        if isTaskCancelled {
            await MainActor.run {
                self.taskStatus = "Task cancelled by user"
                self.isTaskRunning = false
            }
        }
    }
    
    private func executeCommand(_ command: AICommand) async -> String {
        switch command.type {
        case .moveCursor:
            if let moveCmd = command as? MoveCursorCommand {
                return await moveCursor(direction: moveCmd.direction, distance: moveCmd.distance)
            }
        case .clickCursor:
            return await clickCursor()
        case .done:
            return "Task completed"
        }
        return "Unknown command"
    }
    
    private func moveCursor(direction: String, distance: Int) async -> String {
        let currentPosition = NSEvent.mouseLocation
        var newPosition = currentPosition
        
        switch direction {
        case "right":
            newPosition.x += CGFloat(distance)
        case "left":
            newPosition.x -= CGFloat(distance)
        case "down":
            newPosition.y -= CGFloat(distance) // Y is flipped in screen coordinates
        case "up":
            newPosition.y += CGFloat(distance)
        default:
            return "Invalid direction"
        }
        
        // Move cursor using CGWarpMouseCursorPosition
        CGWarpMouseCursorPosition(newPosition)
        
        await MainActor.run {
            self.currentCursorPosition = newPosition
        }
        
        return "Cursor moved \(direction) by \(distance) pixels"
    }
    
    private func clickCursor() async -> String {
        let currentPosition = NSEvent.mouseLocation
        
        // Create and post mouse down event
        if let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, 
                                       mouseCursorPosition: currentPosition, mouseButton: .left) {
            mouseDownEvent.post(tap: .cghidEventTap)
        }
        
        // Create and post mouse up event
        if let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, 
                                     mouseCursorPosition: currentPosition, mouseButton: .left) {
            mouseUpEvent.post(tap: .cghidEventTap)
        }
        
        return "Click performed at \(currentPosition)"
    }
}


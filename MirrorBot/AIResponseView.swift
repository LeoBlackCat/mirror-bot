//
//  AIResponseView.swift
//  MirrorBot
//
//  Created by Leo on 7/7/25.
//

import SwiftUI

struct AIResponseView: View {
    @Binding var apiResponse: String
    @Binding var apiKey: String
    @Binding var openaiApiKey: String
    @Binding var useOpenAI: Bool
    @Binding var showingApiKeyAlert: Bool
    @Binding var showingOpenAIKeyAlert: Bool
    
    var body: some View {
        VStack {
            Text("🤖 AI Analysis")
                .font(.headline)
                .padding(.bottom, 5)
            
            VStack(alignment: .leading, spacing: 10) {
                // API Configuration
                HStack {
                    Text("API:")
                    Picker("API", selection: $useOpenAI) {
                        Text("Claude").tag(false)
                        Text("OpenAI").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 120)
                }
                
                // API Key Fields
                VStack(alignment: .leading, spacing: 5) {
                    if useOpenAI {
                        Text("OpenAI API Key:")
                            .font(.caption)
                        SecureField("Enter OpenAI API Key", text: $openaiApiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text("Claude API Key:")
                            .font(.caption)
                        SecureField("Enter Claude API Key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // API Key Status
                HStack {
                    Image(systemName: useOpenAI ? 
                          (openaiApiKey.isEmpty ? "xmark.circle" : "checkmark.circle") :
                          (apiKey.isEmpty ? "xmark.circle" : "checkmark.circle"))
                        .foregroundColor(useOpenAI ? 
                                        (openaiApiKey.isEmpty ? .red : .green) :
                                        (apiKey.isEmpty ? .red : .green))
                    
                    Text(useOpenAI ? 
                         (openaiApiKey.isEmpty ? "No OpenAI key" : "OpenAI key set") :
                         (apiKey.isEmpty ? "No Claude key" : "Claude key set"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Test API Connection
                Button("🧪 Test API Connection") {
                    if useOpenAI {
                        if openaiApiKey.isEmpty {
                            showingOpenAIKeyAlert = true
                        } else {
                            // Test OpenAI connection
                        }
                    } else {
                        if apiKey.isEmpty {
                            showingApiKeyAlert = true
                        } else {
                            // Test Claude connection
                        }
                    }
                }
                .font(.caption)
                
                Divider()
                
                // Response Display
                if !apiResponse.isEmpty {
                    Text("Analysis Result:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        Text(apiResponse)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                    .frame(height: 200)
                    
                    Button("🗑️ Clear Response") {
                        apiResponse = ""
                    }
                    .font(.caption)
                } else {
                    Text("No analysis results yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
        }
        .frame(width: 250)
    }
}

#Preview {
    AIResponseView(
        apiResponse: .constant("Sample AI response here..."),
        apiKey: .constant(""),
        openaiApiKey: .constant(""),
        useOpenAI: .constant(true),
        showingApiKeyAlert: .constant(false),
        showingOpenAIKeyAlert: .constant(false)
    )
}
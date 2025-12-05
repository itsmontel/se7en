import SwiftUI

struct SupportView: View {
    @State private var selectedTopic = "General"
    @State private var message = ""
    @State private var email = ""
    @State private var includeDiagnostics = true
    @State private var showSuccessMessage = false
    
    let supportTopics = [
        "General",
        "Billing & Payments",
        "Technical Issues",
        "Feature Request",
        "Account & Privacy",
        "App Limits & Monitoring"
    ]
    
    var body: some View {
        ScrollView {
            HStack {
                Spacer()
                VStack(spacing: 24) {
                    // Simple header matching settings style
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Contact Support")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("We're here to help")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                    // Contact Form - Simple settings style
                    SettingsGroup(title: "Contact Information") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Email Address")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                            
                            TextField("your.email@example.com", text: $email)
                                .textFieldStyle(PlainTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .font(.system(size: 16))
                                .foregroundColor(.textPrimary)
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Topic")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                            
                            Menu {
                                ForEach(supportTopics, id: \.self) { topic in
                                    Button(topic) {
                                        selectedTopic = topic
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedTopic)
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Message")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                            
                            TextEditor(text: $message)
                                .frame(minHeight: 120)
                                .font(.system(size: 16))
                                .foregroundColor(.textPrimary)
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        SettingToggle(
                            isOn: $includeDiagnostics,
                            icon: "info.circle.fill",
                            color: .blue,
                            title: "Include diagnostic information",
                            subtitle: "Helps us troubleshoot issues faster"
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Send Button
                    Button(action: sendMessage) {
                        HStack {
                            if showSuccessMessage {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                            
                            Text(showSuccessMessage ? "Message Sent!" : "Send Message")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isFormValid ? Color.primary : Color.gray.opacity(0.3))
                        .cornerRadius(16)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 800 : .infinity)
                Spacer()
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Support")
                    .font(.system(size: 34, weight: .bold))
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !message.isEmpty && email.contains("@")
    }
    
    private func sendMessage() {
        // Show success message (in production, this would send to backend)
        withAnimation(.spring()) {
            showSuccessMessage = true
        }
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring()) {
                showSuccessMessage = false
                message = ""
                email = ""
                selectedTopic = "General"
            }
        }
        
        // Trigger haptic feedback
        HapticFeedback.success.trigger()
    }
}

#Preview {
    NavigationView {
        SupportView()
    }
}


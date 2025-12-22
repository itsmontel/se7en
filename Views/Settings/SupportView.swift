import SwiftUI

struct SupportView: View {
    @State private var message = ""
    @State private var email = ""
    @State private var showSuccessMessage = false
    
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                // Simple header
                VStack(alignment: .leading, spacing: 8) {
                        Text("Contact Support")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                    Text("We're here to help with any questions or issues")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                // Simple Contact Form
                SettingsGroup(title: "Send us a message") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                            
                            TextField("your.email@example.com", text: $email)
                                .textFieldStyle(PlainTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .font(.system(size: 16))
                                .foregroundColor(.textPrimary)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Message")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                            
                            TextEditor(text: $message)
                                .frame(minHeight: 150)
                                .font(.system(size: 16))
                                .foregroundColor(.textPrimary)
                                .padding(12)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(12)
                        }
                        }
                        .padding(.vertical, 8)
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


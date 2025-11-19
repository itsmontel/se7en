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
            VStack(spacing: 20) {
                // Header Card
                VStack(spacing: 12) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("How can we help?")
                        .font(.title2.bold())
                        .foregroundColor(.textPrimary)
                    
                    Text("Our team typically responds within 24 hours")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(20)
                
                // Contact Form
                VStack(alignment: .leading, spacing: 16) {
                    Text("Contact Information")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Address")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.textPrimary)
                        
                        TextField("your.email@example.com", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Topic")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.textPrimary)
                        
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
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.textPrimary)
                        
                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color.cardBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Diagnostics Toggle
                    HStack {
                        Toggle("Include diagnostic information", isOn: $includeDiagnostics)
                            .font(.subheadline)
                    }
                    
                    if includeDiagnostics {
                        Text("This helps us troubleshoot issues more quickly. No personal data is included.")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .padding(.top, -8)
                    }
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(20)
                
                Spacer()
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("support")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            // Fixed Send Button
            VStack(spacing: 0) {
                Divider()
                
                Button(action: sendMessage) {
                    HStack {
                        if showSuccessMessage {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        
                        Text(showSuccessMessage ? "Message Sent!" : "Send Message")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        Group {
                            if isFormValid {
                                LinearGradient(
                                    colors: showSuccessMessage ? [.green, .green.opacity(0.8)] : [.primary, .secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                    )
                    .cornerRadius(16)
                }
                .disabled(!isFormValid)
                .padding()
                .background(Color.appBackground)
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !message.isEmpty && email.contains("@")
    }
    
    private func sendMessage() {
        // Simulate sending message
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


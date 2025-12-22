import SwiftUI
import Foundation

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case russian = "ru"
    case hindi = "hi"
    case turkish = "tr"
    case dutch = "nl"
    case polish = "pl"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .arabic: return "العربية"
        case .russian: return "Русский"
        case .hindi: return "हिन्दी"
        case .turkish: return "Türkçe"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        }
    }
    
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .arabic: return "العربية"
        case .russian: return "Русский"
        case .hindi: return "हिन्दी"
        case .turkish: return "Türkçe"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .arabic: return "🇸🇦"
        case .russian: return "🇷🇺"
        case .hindi: return "🇮🇳"
        case .turkish: return "🇹🇷"
        case .dutch: return "🇳🇱"
        case .polish: return "🇵🇱"
        }
    }
}

// MARK: - Language Manager

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            UserDefaults.standard.synchronize()
            applyLanguage()
        }
    }
    
    private init() {
        // Load saved language or default to device language
        if let savedLanguageCode = UserDefaults.standard.string(forKey: "app_language"),
           let savedLanguage = AppLanguage(rawValue: savedLanguageCode) {
            self.currentLanguage = savedLanguage
        } else {
            // Try to match device language
            let deviceLanguage = Locale.current.languageCode ?? "en"
            self.currentLanguage = AppLanguage(rawValue: deviceLanguage) ?? .english
        }
        applyLanguage()
    }
    
    private func applyLanguage() {
        // Set app language (this would work with proper localization setup)
        // For now, we just store the preference
        // In a full implementation, you'd use Bundle.setLanguage() or similar
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
    }
}


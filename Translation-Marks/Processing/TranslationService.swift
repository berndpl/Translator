//
//  TranslationService.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import Foundation
import NaturalLanguage
import Translation

struct TranslationPair {
    let original: String
    let translated: String
}

class TranslationService {
    private let defaultSourceLanguage: NLLanguage = .japanese
    
    func detectLanguage(text: String) async -> NLLanguage? {
        return NLLanguageRecognizer.dominantLanguage(for: text)
    }
    
    func translateToEnglish(text: String, from sourceLanguage: NLLanguage? = nil) async -> String? {
        let source = sourceLanguage ?? defaultSourceLanguage
        
        // Skip translation if source is already English
        guard source != .english else {
            return text
        }
        
        // Convert NLLanguage to Locale.Language
        guard let sourceLang = convertNLLanguageToLocaleLanguage(source),
              let targetLang = convertNLLanguageToLocaleLanguage(.english) else {
            print("⚠️ Could not convert language codes for translation")
            return text
        }
        
        // Create translation session with installedSource and target
        let session = TranslationSession(installedSource: sourceLang, target: targetLang)
        
        // Perform translation using TranslationSession
        // The translate method is async and returns a TranslationSession.Response
        do {
            let response = try await session.translate(text)
            let translatedText = response.targetText
            print("✅ Translated: '\(text)' -> '\(translatedText)'")
            return translatedText
        } catch {
            print("❌ Translation error: \(error.localizedDescription)")
            return text // Return original on error
        }
    }
    
    private func convertNLLanguageToLocaleLanguage(_ nlLanguage: NLLanguage) -> Locale.Language? {
        // Map NLLanguage to Locale.Language
        // TranslationSession uses Locale.Language objects
        switch nlLanguage {
        case .japanese:
            return Locale.Language(identifier: "ja")
        case .english:
            return Locale.Language(identifier: "en")
        case .korean:
            return Locale.Language(identifier: "ko")
        case .spanish:
            return Locale.Language(identifier: "es")
        case .french:
            return Locale.Language(identifier: "fr")
        case .german:
            return Locale.Language(identifier: "de")
        case .italian:
            return Locale.Language(identifier: "it")
        case .portuguese:
            return Locale.Language(identifier: "pt")
        case .russian:
            return Locale.Language(identifier: "ru")
        case .arabic:
            return Locale.Language(identifier: "ar")
        case .dutch:
            return Locale.Language(identifier: "nl")
        case .polish:
            return Locale.Language(identifier: "pl")
        case .turkish:
            return Locale.Language(identifier: "tr")
        case .swedish:
            return Locale.Language(identifier: "sv")
        case .danish:
            return Locale.Language(identifier: "da")
        case .norwegian:
            return Locale.Language(identifier: "no")
        case .finnish:
            return Locale.Language(identifier: "fi")
        case .czech:
            return Locale.Language(identifier: "cs")
        case .hungarian:
            return Locale.Language(identifier: "hu")
        case .romanian:
            return Locale.Language(identifier: "ro")
        case .indonesian:
            return Locale.Language(identifier: "id")
        case .thai:
            return Locale.Language(identifier: "th")
        case .vietnamese:
            return Locale.Language(identifier: "vi")
        case .hindi:
            return Locale.Language(identifier: "hi")
        default:
            // Try to find Chinese variants
            let rawValue = nlLanguage.rawValue.lowercased()
            if rawValue.contains("chinese") || rawValue.contains("zh") {
                return Locale.Language(identifier: "zh")
            }
            print("⚠️ Unsupported language for Translation framework: \(nlLanguage.rawValue)")
            return nil
        }
    }
    
    
    func translateRegions(_ regions: [TextRegion], from sourceLanguage: NLLanguage? = nil) async -> [TranslationPair] {
        let source = sourceLanguage ?? defaultSourceLanguage
        
        var pairs: [TranslationPair] = []
        
        for region in regions {
            if let translated = await translateToEnglish(text: region.text, from: source) {
                pairs.append(TranslationPair(original: region.text, translated: translated))
            } else {
                // If translation fails, use original text
                pairs.append(TranslationPair(original: region.text, translated: region.text))
            }
        }
        
        return pairs
    }
}


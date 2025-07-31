//
//  TranslationService.swift
//  BookReader
//
//  Translation and dictionary service for word lookup
//

import Foundation
import UIKit

class TranslationService {
    static let shared = TranslationService()
    private init() {}
    
    // MARK: - Dictionary Lookup
    func lookupDefinition(for word: String, completion: @escaping (Result<WordDefinition, Error>) -> Void) {
        // Use Apple's built-in dictionary service
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
        
        // First try local dictionary
        if let definition = getLocalDefinition(for: cleanWord) {
            completion(.success(definition))
            return
        }
        
        // Fallback to online dictionary API
        fetchOnlineDefinition(for: cleanWord, completion: completion)
    }
    
    private func getLocalDefinition(for word: String) -> WordDefinition? {
        // For now, skip local dictionary and go directly to online API
        // Apple's dictionary API is private and not available
        return nil
    }
    
    private func fetchOnlineDefinition(for word: String, completion: @escaping (Result<WordDefinition, Error>) -> Void) {
        // Free Dictionary API
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)") else {
            completion(.failure(TranslationError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(TranslationError.noData))
                return
            }
            
            do {
                let dictionaryResponse = try JSONDecoder().decode([DictionaryAPIResponse].self, from: data)
                if let firstEntry = dictionaryResponse.first {
                    let definition = self.parseDefinition(from: firstEntry)
                    completion(.success(definition))
                } else {
                    completion(.failure(TranslationError.noDefinitionFound))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Translation
    func translateText(_ text: String, to targetLanguage: String, completion: @escaping (Result<Translation, Error>) -> Void) {
        // Use Google Translate API (free tier has limits)
        let apiKey = "YOUR_GOOGLE_TRANSLATE_API_KEY" // Replace with actual key
        
        guard !apiKey.isEmpty && apiKey != "YOUR_GOOGLE_TRANSLATE_API_KEY" else {
            // Fallback to Apple's built-in translation if available
            attemptAppleTranslation(text, to: targetLanguage, completion: completion)
            return
        }
        
        guard let url = URL(string: "https://translation.googleapis.com/language/translate/v2?key=\(apiKey)") else {
            completion(.failure(TranslationError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "q": text,
            "target": targetLanguage,
            "format": "text"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(TranslationError.noData))
                return
            }
            
            do {
                let translationResponse = try JSONDecoder().decode(GoogleTranslateResponse.self, from: data)
                if let translatedText = translationResponse.data.translations.first?.translatedText {
                    let translation = Translation(
                        originalText: text,
                        translatedText: translatedText,
                        sourceLanguage: "auto",
                        targetLanguage: targetLanguage
                    )
                    completion(.success(translation))
                } else {
                    completion(.failure(TranslationError.noTranslationFound))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func attemptAppleTranslation(_ text: String, to targetLanguage: String, completion: @escaping (Result<Translation, Error>) -> Void) {
        // For now, return an error since Apple's translation API is private
        completion(.failure(TranslationError.translationNotAvailable))
    }
    
    // MARK: - Helper Methods
    private func parseDefinition(from response: DictionaryAPIResponse) -> WordDefinition {
        var definitions: [String] = []
        var partOfSpeech: String?
        var pronunciation: String?
        var examples: [String] = []
        
        for meaning in response.meanings {
            if partOfSpeech == nil {
                partOfSpeech = meaning.partOfSpeech
            }
            
            for definition in meaning.definitions {
                definitions.append(definition.definition)
                if let example = definition.example {
                    examples.append(example)
                }
            }
        }
        
        // Get pronunciation
        for phonetic in response.phonetics {
            if let phoneticText = phonetic.text {
                pronunciation = phoneticText
                break
            }
        }
        
        return WordDefinition(
            word: response.word,
            pronunciation: pronunciation,
            definitions: definitions,
            partOfSpeech: partOfSpeech,
            examples: examples,
            etymology: nil
        )
    }
}

// MARK: - Models
struct WordDefinition {
    let word: String
    let pronunciation: String?
    let definitions: [String]
    let partOfSpeech: String?
    let examples: [String]
    let etymology: String?
}

struct Translation {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
}

// MARK: - API Response Models
struct DictionaryAPIResponse: Codable {
    let word: String
    let phonetics: [Phonetic]
    let meanings: [Meaning]
}

struct Phonetic: Codable {
    let text: String?
    let audio: String?
}

struct Meaning: Codable {
    let partOfSpeech: String
    let definitions: [Definition]
}

struct Definition: Codable {
    let definition: String
    let example: String?
    let synonyms: [String]?
    let antonyms: [String]?
}

struct GoogleTranslateResponse: Codable {
    let data: TranslateData
}

struct TranslateData: Codable {
    let translations: [TranslationResult]
}

struct TranslationResult: Codable {
    let translatedText: String
    let detectedSourceLanguage: String?
}

// MARK: - Errors
enum TranslationError: LocalizedError {
    case invalidURL
    case noData
    case noDefinitionFound
    case noTranslationFound
    case translationNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .noDefinitionFound:
            return "No definition found"
        case .noTranslationFound:
            return "No translation found"
        case .translationNotAvailable:
            return "Translation service not available"
        }
    }
}
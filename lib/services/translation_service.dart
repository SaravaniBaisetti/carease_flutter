import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class TranslationService {
  // API Key shared with the AI assistant
  static const String _apiKey = 'AIzaSyAJ9kBIX2hwHwh7-LGe4cx3oNlZmVpju_0';
  
  // The list of supported language codes as per main.dart
  final List<String> targetLocales = ['en', 'hi', 'te', 'ta', 'bn', 'mr', 'ur'];

  /// Translates a given text into all supported locales using Gemini for contextual transliteration.
  Future<Map<String, String>> translateToAllLocales(String text) async {
    if (text.trim().isEmpty) return {};

    final Map<String, String> translations = {};
    for (var locale in targetLocales) {
      translations[locale] = text; // Pre-fill fallback
    }
    
    try {
      final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: _apiKey);
      final prompt = '''
You are a highly accurate medical translator. Your task is to translate the following string into a JSON map of localized strings.
Input string to translate: "\$text"

Target Language Codes: 'en', 'hi', 'te', 'ta', 'bn', 'mr', 'ur'

IMPORTANT RULES:
1. Translate instructions and normal verbs/adjectives naturally into the target language.
2. DO NOT TRANSLATE PROPER NOUNS OR MEDICINE BRANDS (like "Dolo", "Paracetamol"). TRANSLITERATE them phonetically into the target script (e.g. Dolo should sound like Dolo in the target language script, NOT the word for "fraud").
3. Output ONLY a raw, pure JSON object without markdown formatting (no ```), where keys are the 7 language codes and values are the text strings.
''';
      final response = await model.generateContent([Content.text(prompt)]);
      final rawText = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '';
      
      final Map<String, dynamic> decoded = jsonDecode(rawText);
      for (var locale in targetLocales) {
        if (decoded.containsKey(locale)) {
          translations[locale] = decoded[locale].toString();
        }
      }
    } catch (e) {
      // If everything fails, it just returns the pre-filled English defaults
    }
    
    return translations;
  }
}

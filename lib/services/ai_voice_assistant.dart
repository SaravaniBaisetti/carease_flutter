import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';

/// Enhanced AI Voice Assistant with robust native language support,
/// better voice selection, haptic feedback, and reliability improvements.
class AIVoiceAssistant {
  static final AIVoiceAssistant _instance = AIVoiceAssistant._internal();
  factory AIVoiceAssistant() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  
  bool _isSttInitialized = false;
  bool _isTtsInitialized = false;
  bool _isSpeaking = false;
  String _currentLanguage = 'en';
  
  // Completer for TTS completion tracking (works on web unlike awaitSpeakCompletion)
  Completer<void>? _speakCompleter;

  bool get isNotListening => _speechToText.isNotListening;
  bool get isListening => _speechToText.isListening;
  bool get isSttInitialized => _isSttInitialized;
  bool get isSpeaking => _isSpeaking;

  AIVoiceAssistant._internal() {
    _initTts();
    _initStt();
  }

  /// TTS locale mapping
  static const Map<String, String> _ttsLocaleMap = {
    'en': 'en-US',
    'hi': 'hi-IN',
    'te': 'te-IN',
    'ta': 'ta-IN',
    'bn': 'bn-IN',
    'mr': 'mr-IN',
    'ur': 'ur-IN',
  };

  /// STT locale mapping
  static const Map<String, String> _sttLocaleMap = {
    'en': 'en_US',
    'hi': 'hi_IN',
    'te': 'te_IN',
    'ta': 'ta_IN',
    'bn': 'bn_IN',
    'mr': 'mr_IN',
    'ur': 'ur_IN',
  };

  Future<void> _initTts() async {
    try {
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS: Completed speaking');
        _isSpeaking = false;
        _speakCompleter?.complete();
        _speakCompleter = null;
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _isSpeaking = false;
        _speakCompleter?.complete();
        _speakCompleter = null;
      });

      _flutterTts.setCancelHandler(() {
        debugPrint('TTS: Cancelled');
        _isSpeaking = false;
        _speakCompleter?.complete();
        _speakCompleter = null;
      });

      // Web-specific: try to set awaitSpeakCompletion 
      try {
        await _flutterTts.awaitSpeakCompletion(true);
      } catch (_) {
        debugPrint('TTS: awaitSpeakCompletion not supported, using fallback');
      }

      _isTtsInitialized = true;
      debugPrint('TTS initialized successfully');
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }
  }

  Future<void> _initStt() async {
    try {
      _isSttInitialized = await _speechToText.initialize(
        onError: (val) {
          debugPrint('STT Error: ${val.errorMsg}');
        },
        onStatus: (val) {
          debugPrint('STT Status: $val');
        },
      );
      
      if (_isSttInitialized) {
        final locales = await _speechToText.locales();
        debugPrint('STT available locales: ${locales.map((l) => l.localeId).join(', ')}');
      }
    } catch (e) {
      debugPrint('STT Init Error: $e');
    }
  }

  /// Configure TTS for a specific language
  Future<void> _configureTtsForLanguage(String languageCode) async {
    if (_currentLanguage == languageCode && _isTtsInitialized) return;
    
    final ttsLocale = _ttsLocaleMap[languageCode] ?? 'en-US';
    
    try {
      await _flutterTts.setLanguage(ttsLocale);
      _currentLanguage = languageCode;
      debugPrint('TTS language set to: $ttsLocale');
    } catch (e) {
      debugPrint('TTS language config error: $e');
    }
  }

  /// Stop TTS and STT
  Future<void> stopAll() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    _speakCompleter?.complete();
    _speakCompleter = null;
    await stopListening();
  }

  /// Speak text in the specified language
  /// Returns a Future that completes when speaking is done
  Future<void> speak(String text, String languageCode) async {
    if (text.isEmpty) return;
    
    // Stop any ongoing speech first
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
    }
    
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    
    await _configureTtsForLanguage(languageCode);
    
    // Create a completer to track when TTS finishes
    _speakCompleter = Completer<void>();
    _isSpeaking = true;
    
    try {
      debugPrint('TTS: Speaking "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS Speak Error: $e');
      _isSpeaking = false;
      _speakCompleter?.complete();
      _speakCompleter = null;
    }
  }

  /// Wait until TTS finishes speaking (works reliably on web)
  Future<void> awaitSpeakCompletion() async {
    if (!_isSpeaking || _speakCompleter == null) return;
    
    try {
      // Wait for the completer OR timeout after 30 seconds
      await _speakCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('TTS: Timeout waiting for completion');
          _isSpeaking = false;
        },
      );
    } catch (e) {
      debugPrint('TTS await error: $e');
    }
    
    _isSpeaking = false;
    
    // Small delay to ensure TTS audio fully stops before STT starts
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    _speakCompleter?.complete();
    _speakCompleter = null;
  }

  /// Listen for voice commands with native language support
  Future<void> listenForCommand({
    required Function(String text) onResult,
    VoidCallback? onDone,
    required String languageCode,
  }) async {
    if (!_isSttInitialized) {
      await _initStt();
    }

    if (!_isSttInitialized) {
      debugPrint('Cannot listen — STT not initialized or permission denied');
      onDone?.call();
      return;
    }

    // CRITICAL: Stop TTS completely and wait before starting STT
    if (_isSpeaking) {
      await stopSpeaking();
      await Future.delayed(const Duration(milliseconds: 600));
    }

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final sttLocale = _sttLocaleMap[languageCode] ?? 'en_US';
    debugPrint('Starting STT with locale: $sttLocale');

    try {
      await _speechToText.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
          if (result.finalResult) {
            debugPrint('STT Final: ${result.recognizedWords}');
            try { HapticFeedback.selectionClick(); } catch (_) {}
            onDone?.call();
          }
        },
        localeId: sttLocale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('STT Listen Error: $e');
      onDone?.call();
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  /// Check if a specific language is available for STT
  Future<bool> isLanguageAvailable(String languageCode) async {
    if (!_isSttInitialized) return false;
    
    final locales = await _speechToText.locales();
    return locales.any((l) => l.localeId.startsWith(languageCode));
  }

  /// Get list of available speech recognition languages
  Future<List<String>> getAvailableLanguages() async {
    if (!_isSttInitialized) return [];
    
    final locales = await _speechToText.locales();
    return locales.map((l) => l.localeId).toList();
  }
}

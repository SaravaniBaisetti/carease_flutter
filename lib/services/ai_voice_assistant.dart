import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AIVoiceAssistant {
  static final AIVoiceAssistant _instance = AIVoiceAssistant._internal();
  factory AIVoiceAssistant() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  
  bool _isSttInitialized = false;
  VoidCallback? _onSttDone;
  bool _resultHandled = false;

  bool get isNotListening => _speechToText.isNotListening;
  bool get isSttInitialized => _isSttInitialized;

  AIVoiceAssistant._internal() {
    _initTts();
    _initStt();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    // Automatically use the native TTS engine with good default voices
  }

  Future<void> _initStt() async {
    try {
      _isSttInitialized = await _speechToText.initialize(
        onError: (val) {
          debugPrint('STT Error: $val');
          if (!_resultHandled && _onSttDone != null) {
            _onSttDone!();
            _onSttDone = null;
          }
        },
        onStatus: (val) {
          debugPrint('STT Status: $val');
          if (val == 'done' || val == 'notListening') {
            if (!_resultHandled && _onSttDone != null) {
              _onSttDone!();
              _onSttDone = null;
            }
          }
        },
      );
    } catch (e) {
      debugPrint("STT Init Error: $e");
    }
  }

  /// Stop TTS or STT if they are running
  Future<void> stopAll() async {
    await _flutterTts.stop();
    await stopListening();
  }

  /// Speaks text in the specified locale. E.g., locale = "hi_IN"
  Future<void> speak(String text, String languageCode) async {
    // Attempt to map exact simple language code to TTS locale formats
    String ttsLocale = 'en-US';
    switch (languageCode) {
      case 'hi': ttsLocale = 'hi-IN'; break;
      case 'te': ttsLocale = 'te-IN'; break;
      case 'ta': ttsLocale = 'ta-IN'; break;
      case 'bn': ttsLocale = 'bn-IN'; break;
      case 'mr': ttsLocale = 'mr-IN'; break;
      case 'ur': ttsLocale = 'ur-IN'; break;
      case 'en': ttsLocale = 'en-US'; break;
    }

    try {
      await _flutterTts.setLanguage(ttsLocale);
      // Ignoring isLanguageAvailable check on Web as it handles it natively without boolean errors.
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS Error: $e");
    }
  }

  /// Waits until the TTS engine completely finishes speaking
  Future<void> awaitSpeakCompletion() async {
     await _flutterTts.awaitSpeakCompletion(true);
  }

  /// Listen for voice commands
  Future<void> listenForCommand({
    required Function(String text) onResult,
    VoidCallback? onDone,
    required String languageCode,
  }) async {
    _onSttDone = onDone;
    _resultHandled = false;

    if (!_isSttInitialized) {
      await _initStt();
    }

    if (_isSttInitialized) {
      String sttLocale = 'en-US';
      switch (languageCode) {
        case 'hi': sttLocale = 'hi-IN'; break;
        case 'te': sttLocale = 'te-IN'; break;
        case 'ta': sttLocale = 'ta-IN'; break;
        case 'bn': sttLocale = 'bn-IN'; break;
        case 'mr': sttLocale = 'mr-IN'; break;
        case 'ur': sttLocale = 'ur-IN'; break;
        case 'en': sttLocale = 'en-US'; break;
      }

      await _speechToText.listen(
        onResult: (result) {
          _resultHandled = true;
          onResult(result.recognizedWords);
          if (result.finalResult) {
            _onSttDone = null;
          }
        },
        localeId: sttLocale,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    } else {
      debugPrint("Cannot listen, STT not initialized or permission denied.");
    }
  }

  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }
}

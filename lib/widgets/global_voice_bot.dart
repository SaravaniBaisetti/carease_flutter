import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ai_voice_assistant.dart';
import '../services/gemini_assistant_service.dart';
import '../services/intent_parser.dart';

class GlobalVoiceBot {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context, {
    required String clusterId, 
    required String languageCode, 
    required String elderName, 
    required Function() onTriggerSos,
    required Function() onOpenTasks,
    required Function() onOpenMedicines,
  }) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _VoiceBotWidget(
        clusterId: clusterId,
        languageCode: languageCode,
        elderName: elderName,
        onTriggerSos: onTriggerSos,
        onOpenTasks: onOpenTasks,
        onOpenMedicines: onOpenMedicines,
        onClose: hide,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    AIVoiceAssistant().stopAll();
  }
}

enum VoiceState { idle, listening, thinking, speaking }

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class _VoiceBotWidget extends StatefulWidget {
  final String clusterId;
  final String languageCode;
  final String elderName;
  final Function() onTriggerSos;
  final Function() onOpenTasks;
  final Function() onOpenMedicines;
  final VoidCallback onClose;

  const _VoiceBotWidget({
    required this.clusterId,
    required this.languageCode,
    required this.elderName,
    required this.onTriggerSos,
    required this.onOpenTasks,
    required this.onOpenMedicines,
    required this.onClose,
  });

  @override
  State<_VoiceBotWidget> createState() => _VoiceBotWidgetState();
}

class _VoiceBotWidgetState extends State<_VoiceBotWidget> with TickerProviderStateMixin {
  GeminiAssistantService? _geminiService;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  VoiceState _currentState = VoiceState.idle;
  String _liveTranscript = "";
  String _currentAiResponse = "";
  final List<_ChatMessage> _messages = [];
  bool _isSessionActive = true;
  bool _showChat = false;
  bool _geminiReady = false;

  // Floating orb position
  double _top = 100;
  double _left = 20;

  // ─── LOCALIZED STRINGS ─────────────────────────────────────
  
  /// Immediate local responses for commands (no Gemini needed)
  Map<String, String> get _localResponses {
    switch (widget.languageCode) {
      case 'hi': return {
        'sos': 'SOS भेज रहा हूँ! आपकी मदद आ रही है।',
        'tasks': 'आपकी कार्य सूची खोल रहा हूँ।',
        'medicines': 'आपकी दवाइयों की सूची खोल रहा हूँ।',
        'greeting': 'नमस्ते! मैं आपकी CareEase सहायक हूँ। बोलिए, मैं सुन रही हूँ।',
        'not_understood': 'माफ़ कीजिए, मुझे समझ नहीं आया। फिर से बोलिए।',
        'listening': 'सुन रही हूँ...',
        'thinking': 'सोच रही हूँ...',
        'speaking': 'बोल रही हूँ...',
        'idle': 'बोलने के लिए दबाएं',
      };
      case 'te': return {
        'sos': 'SOS పంపుతున్నాను! సహాయం వస్తుంది.',
        'tasks': 'మీ పనుల జాబితా తెరుస్తున్నాను.',
        'medicines': 'మీ మందుల జాబితా తెరుస్తున్నాను.',
        'greeting': 'నమస్కారం! నేను మీ CareEase సహాయకురాలిని. చెప్పండి, వింటున్నాను.',
        'not_understood': 'క్షమించండి, నాకు అర్థం కాలేదు. మళ్ళీ చెప్పండి.',
        'listening': 'వింటున్నాను...',
        'thinking': 'ఆలోచిస్తున్నాను...',
        'speaking': 'చెబుతున్నాను...',
        'idle': 'మాట్లాడటానికి నొక్కండి',
      };
      case 'ta': return {
        'sos': 'SOS அனுப்புகிறேன்! உதவி வருகிறது.',
        'tasks': 'உங்கள் பணிகள் பட்டியலைத் திறக்கிறேன்.',
        'medicines': 'உங்கள் மருந்துகள் பட்டியலைத் திறக்கிறேன்.',
        'greeting': 'வணக்கம்! நான் உங்கள் CareEase உதவியாளர். சொல்லுங்கள், கேட்கிறேன்.',
        'not_understood': 'மன்னிக்கவும், புரியவில்லை. மீண்டும் சொல்லுங்கள்.',
        'listening': 'கேட்கிறேன்...',
        'thinking': 'நினைக்கிறேன்...',
        'speaking': 'சொல்கிறேன்...',
        'idle': 'பேச தட்டவும்',
      };
      case 'bn': return {
        'sos': 'SOS পাঠাচ্ছি! সাহায্য আসছে.',
        'tasks': 'আপনার কাজের তালিকা খুলছি.',
        'medicines': 'আপনার ওষুধের তালিকা খুলছি.',
        'greeting': 'নমস্কার! আমি আপনার CareEase সহায়ক। বলুন, শুনছি.',
        'not_understood': 'দুঃখিত, বুঝতে পারিনি। আবার বলুন.',
        'listening': 'শুনছি...',
        'thinking': 'ভাবছি...',
        'speaking': 'বলছি...',
        'idle': 'বলতে চাপুন',
      };
      case 'mr': return {
        'sos': 'SOS पाठवतोय! मदत येतेय.',
        'tasks': 'तुमची कामांची यादी उघडतोय.',
        'medicines': 'तुमच्या औषधांची यादी उघडतोय.',
        'greeting': 'नमस्कार! मी तुमचा CareEase सहाय्यक आहे. बोला, ऐकतोय.',
        'not_understood': 'माफ करा, समजलं नाही. पुन्हा सांगा.',
        'listening': 'ऐकतोय...',
        'thinking': 'विचार करतोय...',
        'speaking': 'बोलतोय...',
        'idle': 'बोलायला दाबा',
      };
      case 'ur': return {
        'sos': 'SOS بھیج رہا ہوں! مدد آ رہی ہے۔',
        'tasks': 'آپ کے کاموں کی فہرست کھول رہا ہوں۔',
        'medicines': 'آپ کی دوائیوں کی فہرست کھول رہا ہوں۔',
        'greeting': 'السلام علیکم! میں آپ کا CareEase معاون ہوں۔ بولیے، سن رہا ہوں۔',
        'not_understood': 'معذرت، سمجھ نہیں آیا۔ دوبارہ بولیے۔',
        'listening': '...سن رہا ہوں',
        'thinking': '...سوچ رہا ہوں',
        'speaking': '...بول رہا ہوں',
        'idle': 'بولنے کے لیے دبائیں',
      };
      default: return {
        'sos': 'Sending SOS! Help is on the way.',
        'tasks': 'Opening your tasks list.',
        'medicines': 'Opening your medicines list.',
        'greeting': 'Hello! I am your CareEase assistant. Go ahead, I am listening.',
        'not_understood': 'Sorry, I did not understand. Please say that again.',
        'listening': 'Listening...',
        'thinking': 'Thinking...',
        'speaking': 'Speaking...',
        'idle': 'Tap to speak',
      };
    }
  }

  Map<String, String> get _chipLabels {
    switch (widget.languageCode) {
      case 'hi': return {'medicines': '💊 दवाइयाँ', 'tasks': '📋 कार्य', 'sos': '🆘 SOS'};
      case 'te': return {'medicines': '💊 మందులు', 'tasks': '📋 పనులు', 'sos': '🆘 SOS'};
      case 'ta': return {'medicines': '💊 மருந்துகள்', 'tasks': '📋 பணிகள்', 'sos': '🆘 SOS'};
      case 'bn': return {'medicines': '💊 ওষুধ', 'tasks': '📋 কাজ', 'sos': '🆘 SOS'};
      case 'mr': return {'medicines': '💊 औषधे', 'tasks': '📋 कामे', 'sos': '🆘 SOS'};
      case 'ur': return {'medicines': '💊 دوائیاں', 'tasks': '📋 کام', 'sos': '🆘 SOS'};
      default: return {'medicines': '💊 Medicines', 'tasks': '📋 Tasks', 'sos': '🆘 SOS'};
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize Gemini in background (non-blocking)
    _initGeminiInBackground();
    
    // Start speaking immediately with local greeting (no Gemini needed!)
    Future.delayed(const Duration(milliseconds: 400), _speakLocalGreeting);
  }

  @override
  void dispose() {
    _isSessionActive = false;
    _textController.dispose();
    _scrollController.dispose();
    AIVoiceAssistant().stopAll();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Initialize Gemini in background (don't block UI)
  Future<void> _initGeminiInBackground() async {
    try {
      _geminiService = GeminiAssistantService(
        clusterId: widget.clusterId,
        elderName: widget.elderName,
        languageCode: widget.languageCode,
        onTriggerSos: widget.onTriggerSos,
        onOpenTasks: widget.onOpenTasks,
        onOpenMedicines: widget.onOpenMedicines,
      );
      await _geminiService!.initialize();
      _geminiReady = true;
      debugPrint('VoiceBot: Gemini ready!');
    } catch (e) {
      debugPrint('VoiceBot: Gemini init failed (will use local mode): $e');
      _geminiReady = false;
    }
  }

  /// Speak a local greeting immediately (works without Gemini!)
  Future<void> _speakLocalGreeting() async {
    if (!mounted || !_isSessionActive) return;
    
    // If Gemini is ready, use it for a warm, dynamic greeting
    if (_geminiReady && _geminiService != null) {
      setState(() => _currentState = VoiceState.thinking);
      final dynamicGreeting = await _geminiService!.initConversation();
      setState(() {
        _currentAiResponse = dynamicGreeting;
        _messages.add(_ChatMessage(text: dynamicGreeting, isUser: false));
        _currentState = VoiceState.speaking;
      });
      await AIVoiceAssistant().speak(dynamicGreeting, widget.languageCode);
    } else {
      // Fallback to local greeting if Gemini is slow or offline
      final greeting = _localResponses['greeting']!;
      setState(() {
        _currentAiResponse = greeting;
        _messages.add(_ChatMessage(text: greeting, isUser: false));
        _currentState = VoiceState.speaking;
      });
      await AIVoiceAssistant().speak(greeting, widget.languageCode);
    }

    await AIVoiceAssistant().awaitSpeakCompletion();
    if (!mounted || !_isSessionActive) return;
    _startListening();
  }

  /// Start voice listening
  Future<void> _startListening() async {
    if (!mounted || !_isSessionActive) return;
    if (_currentState == VoiceState.speaking) {
      await AIVoiceAssistant().stopSpeaking();
    }

    setState(() {
      _currentState = VoiceState.listening;
      _liveTranscript = "";
    });

    await AIVoiceAssistant().listenForCommand(
      languageCode: widget.languageCode,
      onResult: (text) {
        if (mounted) {
          setState(() => _liveTranscript = text);
        }
      },
      onDone: () {
        if (mounted && _isSessionActive) {
          final text = _liveTranscript.trim();
          if (text.isNotEmpty) {
            _processUserMessage(text);
          } else {
            setState(() => _currentState = VoiceState.idle);
          }
        }
      },
    );

    // Fallback if STT unavailable
    if (!AIVoiceAssistant().isSttInitialized) {
      debugPrint('VoiceBot: STT not available, going idle');
      if (mounted) setState(() => _currentState = VoiceState.idle);
    }
  }

  /// CORE: Process user message — LOCAL INTENT FIRST, then Gemini
  Future<void> _processUserMessage(String text) async {
    if (!mounted || !_isSessionActive || text.trim().isEmpty) return;

    debugPrint('VoiceBot: Processing: "$text"');

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _currentState = VoiceState.thinking;
      _liveTranscript = "";
      _currentAiResponse = "";
    });
    _scrollToBottom();

    // ──── STEP 1: Try LOCAL intent parsing ONLY for very short commands ────
    final wordCount = text.split(' ').length;
    final intent = wordCount <= 3 ? IntentParser.parseDashboardCommand(text) : 'unknown';
    debugPrint('VoiceBot: Local intent (words: $wordCount): $intent');

    if (intent == 'trigger_sos') {
      await _handleLocalCommand('sos', () => widget.onTriggerSos());
      return;
    }
    if (intent == 'read_tasks') {
      await _handleLocalCommand('tasks', () => widget.onOpenTasks());
      return;
    }
    if (intent == 'read_medicines') {
      await _handleLocalCommand('medicines', () => widget.onOpenMedicines());
      return;
    }

    // ──── STEP 2: Try Gemini for general conversation ────
    if (_geminiReady && _geminiService != null) {
      try {
        final aiReply = await _geminiService!.sendMessage(text);
        if (!_isSessionActive || !mounted) return;
        
        await _speakResponse(aiReply);
      } catch (e) {
        debugPrint('VoiceBot: Gemini error: $e');
        await _speakResponse(_localResponses['not_understood']!);
      }
    } else {
      // Gemini not ready — use local fallback
      await _speakResponse(_localResponses['not_understood']!);
    }
  }

  /// Handle a locally-detected command
  Future<void> _handleLocalCommand(String commandKey, Function() action) async {
    final response = _localResponses[commandKey]!;
    
    setState(() {
      _currentAiResponse = response;
      _messages.add(_ChatMessage(text: response, isUser: false));
      _currentState = VoiceState.speaking;
    });
    _scrollToBottom();

    // Speak the confirmation
    await AIVoiceAssistant().speak(response, widget.languageCode);
    
    // Execute the action after a short delay so the user hears the confirmation
    await Future.delayed(const Duration(milliseconds: 800));
    action();
    
    await AIVoiceAssistant().awaitSpeakCompletion();
    if (mounted) setState(() => _currentState = VoiceState.idle);
  }

  /// Speak a response and auto-listen again
  Future<void> _speakResponse(String text) async {
    if (!mounted || !_isSessionActive) return;
    
    setState(() {
      _currentAiResponse = text;
      _messages.add(_ChatMessage(text: text, isUser: false));
      _currentState = VoiceState.speaking;
    });
    _scrollToBottom();

    await AIVoiceAssistant().speak(text, widget.languageCode);
    await AIVoiceAssistant().awaitSpeakCompletion();

    if (!mounted || !_isSessionActive) return;

    // Auto-listen again (continuous conversation)
    _startListening();
  }

  /// Handle text input
  void _handleTextSubmit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    
    if (_currentState == VoiceState.speaking) AIVoiceAssistant().stopSpeaking();
    if (_currentState == VoiceState.listening) AIVoiceAssistant().stopListening();
    
    _processUserMessage(text);
  }

  /// Handle quick action chip tap
  void _handleChipTap(String action) {
    if (_currentState == VoiceState.speaking) AIVoiceAssistant().stopSpeaking();
    if (_currentState == VoiceState.listening) AIVoiceAssistant().stopListening();

    if (action == 'sos') {
      setState(() {
        _messages.add(_ChatMessage(text: 'SOS', isUser: true));
      });
      _handleLocalCommand('sos', () => widget.onTriggerSos());
    } else if (action == 'tasks') {
      setState(() {
        _messages.add(_ChatMessage(text: _chipLabels['tasks']!, isUser: true));
      });
      _handleLocalCommand('tasks', () => widget.onOpenTasks());
    } else if (action == 'medicines') {
      setState(() {
        _messages.add(_ChatMessage(text: _chipLabels['medicines']!, isUser: true));
      });
      _handleLocalCommand('medicines', () => widget.onOpenMedicines());
    }
  }

  // ─── ORB TAP ─────────────────────────────────────────────

  void _onOrbTap() {
    switch (_currentState) {
      case VoiceState.idle:
        _startListening();
        break;
      case VoiceState.listening:
        AIVoiceAssistant().stopListening();
        final text = _liveTranscript.trim();
        if (text.isNotEmpty) {
          _processUserMessage(text);
        } else {
          setState(() => _currentState = VoiceState.idle);
        }
        break;
      case VoiceState.speaking:
        AIVoiceAssistant().stopSpeaking();
        setState(() => _currentState = VoiceState.idle);
        break;
      case VoiceState.thinking:
        break;
    }
  }

  Color _getStatusColor() {
    switch (_currentState) {
      case VoiceState.listening: return const Color(0xFF00C6FB);
      case VoiceState.thinking: return const Color(0xFFFE5196);
      case VoiceState.speaking: return const Color(0xFF00E676);
      case VoiceState.idle: return Colors.white60;
    }
  }

  String get _statusText => _localResponses[_currentState.name] ?? '';

  // ─── FLOATING ORB UI ──────────────────────────────────────

  Widget _buildFloatingOrb() {
    return Positioned(
      top: _top,
      left: _left,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() { _top += d.delta.dy; _left += d.delta.dx; }),
        onPanEnd: (d) {
          final sw = MediaQuery.of(context).size.width;
          final sh = MediaQuery.of(context).size.height;
          setState(() {
            _left = _left > sw / 2 ? sw - 110 : 10;
            _top = _top.clamp(50, sh - 200).toDouble();
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speech bubble (AI response)
            if (_currentAiResponse.isNotEmpty && _currentState == VoiceState.speaking)
              Container(
                width: 230,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12)],
                ),
                child: Text(
                  _currentAiResponse,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ).animate().fade().slideY(begin: 0.2, duration: 300.ms),

            // Live transcript
            if (_liveTranscript.isNotEmpty && _currentState == VoiceState.listening)
              Container(
                width: 200,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00C6FB).withOpacity(0.5)),
                ),
                child: Text(
                  _liveTranscript,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Status label
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_geminiReady && _currentState == VoiceState.idle)
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    ),
                  Text(
                    _statusText,
                    style: TextStyle(color: _getStatusColor(), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // The orb
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _onOrbTap,
                  onLongPress: () => setState(() => _showChat = !_showChat),
                  child: _AnimatedOrb(state: _currentState),
                ),
                // Close
                Positioned(
                  top: -8, right: -8,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black87, shape: BoxShape.circle, border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                // Chat toggle
                Positioned(
                  bottom: -8, right: -8,
                  child: GestureDetector(
                    onTap: () => setState(() => _showChat = !_showChat),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB), shape: BoxShape.circle, border: Border.all(color: Colors.white30),
                      ),
                      child: Icon(
                        _showChat ? Icons.keyboard_arrow_down : Icons.chat_bubble_outline,
                        color: Colors.white, size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── EXPANDABLE CHAT PANEL ─────────────────────────────────

  Widget _buildChatPanel() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Positioned(
      bottom: bottomInset + 10,
      left: 10,
      right: 10,
      child: Container(
        height: 420,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A).withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _getStatusColor().withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20),
            BoxShadow(color: _getStatusColor().withOpacity(0.1), blurRadius: 30, spreadRadius: 2),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    _MiniOrb(state: _currentState),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CareEase AI', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          Row(
                            children: [
                              Text(_statusText, style: TextStyle(color: _getStatusColor(), fontSize: 12)),
                              if (_geminiReady)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('AI', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 24),
                      onPressed: () => setState(() => _showChat = false),
                    ),
                  ],
                ),
              ),

              // Quick action chips
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  children: _chipLabels.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => _handleChipTap(e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: e.key == 'sos' ? Colors.red.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: e.key == 'sos' ? Colors.red.withOpacity(0.4) : Colors.white12),
                        ),
                        child: Text(e.value, style: TextStyle(
                          color: e.key == 'sos' ? Colors.redAccent : Colors.white70,
                          fontSize: 13, fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                  )).toList(),
                ),
              ),

              // Messages list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg = _messages[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        left: msg.isUser ? 40 : 0,
                        right: msg.isUser ? 0 : 40,
                        bottom: 6,
                      ),
                      child: Align(
                        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: msg.isUser
                                ? const Color(0xFF2563EB).withOpacity(0.7)
                                : Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
                        ),
                      ),
                    ).animate().fade(duration: 200.ms);
                  },
                ),
              ),

              // Text input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: const Color(0xFF1A1A2E),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: widget.languageCode == 'hi' ? 'यहाँ टाइप करें...' :
                                     widget.languageCode == 'te' ? 'ఇక్కడ టైప్ చేయండి...' :
                                     widget.languageCode == 'ta' ? 'இங்கே டைப் செய்யவும்...' :
                                     'Type here...',
                            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onSubmitted: (_) => _handleTextSubmit(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _onOrbTap,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor().withOpacity(0.8),
                        ),
                        child: Icon(
                          _currentState == VoiceState.listening ? Icons.stop :
                          _currentState == VoiceState.speaking ? Icons.stop :
                          Icons.mic,
                          color: Colors.white, size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().slideY(begin: 0.3, duration: 350.ms, curve: Curves.easeOutCubic).fade(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (_showChat)
            GestureDetector(
              onTap: () => setState(() => _showChat = false),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
          _buildFloatingOrb(),
          if (_showChat) _buildChatPanel(),
        ],
      ),
    );
  }
}


// ─── ANIMATED ORB WIDGET ────────────────────────────────────

class _AnimatedOrb extends StatefulWidget {
  final VoiceState state;
  const _AnimatedOrb({required this.state});

  @override
  State<_AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<_AnimatedOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    Color baseColor;
    Color altColor;
    
    switch (widget.state) {
      case VoiceState.idle:
        baseColor = Colors.grey.shade600;
        altColor = Colors.grey.shade800;
        break;
      case VoiceState.listening:
        baseColor = const Color(0xFF00C6FB);
        altColor = const Color(0xFF005BEA);
        break;
      case VoiceState.thinking:
        baseColor = const Color(0xFFF77062);
        altColor = const Color(0xFFFE5196);
        break;
      case VoiceState.speaking:
        baseColor = const Color(0xFF00E676);
        altColor = const Color(0xFF1DE9B6);
        break;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final breathe = widget.state == VoiceState.speaking || widget.state == VoiceState.listening 
            ? 1.0 + 0.1 * math.sin(_controller.value * 2 * math.pi) 
            : 1.0;

        return Transform.scale(
          scale: breathe,
          child: SizedBox(
            width: 90, height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _controller.value * 2 * math.pi,
                  child: Container(
                    width: 80, height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [baseColor.withOpacity(0.6), altColor.withOpacity(0.6)]),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(50), topRight: Radius.circular(40),
                        bottomLeft: Radius.circular(60), bottomRight: Radius.circular(45),
                      ),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: -_controller.value * 2 * math.pi + 1,
                  child: Container(
                    width: 88, height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [altColor.withOpacity(0.8), baseColor.withOpacity(0.8)]),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(45), topRight: Radius.circular(60),
                        bottomLeft: Radius.circular(40), bottomRight: Radius.circular(50),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [baseColor, altColor, baseColor]),
                    boxShadow: [BoxShadow(color: baseColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 4)],
                  ),
                  child: Center(
                    child: Icon(
                      widget.state == VoiceState.listening ? Icons.mic :
                      widget.state == VoiceState.speaking ? Icons.graphic_eq :
                      widget.state == VoiceState.thinking ? Icons.psychology :
                      Icons.smart_toy,
                      color: Colors.white, size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _MiniOrb extends StatefulWidget {
  final VoiceState state;
  const _MiniOrb({required this.state});

  @override
  State<_MiniOrb> createState() => _MiniOrbState();
}

class _MiniOrbState extends State<_MiniOrb> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.state == VoiceState.listening ? const Color(0xFF00C6FB) :
                  widget.state == VoiceState.thinking ? const Color(0xFFFE5196) :
                  widget.state == VoiceState.speaking ? const Color(0xFF00E676) :
                  Colors.grey.shade600;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final s = widget.state != VoiceState.idle ? 1.0 + 0.1 * math.sin(_c.value * 2 * math.pi) : 1.0;
        return Transform.scale(
          scale: s,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [color, color.withOpacity(0.5), color],
                transform: GradientRotation(_c.value * 2 * math.pi),
              ),
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)],
            ),
            child: Icon(
              widget.state == VoiceState.listening ? Icons.mic :
              widget.state == VoiceState.speaking ? Icons.graphic_eq :
              Icons.smart_toy,
              color: Colors.white, size: 16,
            ),
          ),
        );
      },
    );
  }
}

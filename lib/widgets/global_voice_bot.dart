import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ai_voice_assistant.dart';
import '../services/gemini_assistant_service.dart';

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

class _VoiceBotWidgetState extends State<_VoiceBotWidget> with SingleTickerProviderStateMixin {
  late GeminiAssistantService _geminiService;
  
  VoiceState _currentState = VoiceState.idle;
  String _transcript = "";
  String _aiResponse = "";
  bool _isSessionActive = true;
  
  // Positioning
  double _top = 100;
  double _left = 20;
  bool _isDocked = false; // If true, docks beautifully to the bottom

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiAssistantService(
      clusterId: widget.clusterId,
      elderName: widget.elderName,
      languageCode: widget.languageCode,
      onTriggerSos: widget.onTriggerSos,
      onOpenTasks: widget.onOpenTasks,
      onOpenMedicines: widget.onOpenMedicines,
    );
    
    // Slight delay before start so widget mounts
    Future.delayed(const Duration(milliseconds: 500), _startConversationLoop);
  }

  @override
  void dispose() {
    _isSessionActive = false;
    super.dispose();
  }

  Future<void> _startConversationLoop() async {
    if (!mounted || !_isSessionActive) return;
    
    setState(() => _currentState = VoiceState.thinking);
    final greeting = await _geminiService.initConversation();
    if (!mounted || !_isSessionActive) return;

    setState(() {
      _currentState = VoiceState.speaking;
      _aiResponse = greeting;
    });
    await AIVoiceAssistant().speak(greeting, widget.languageCode);
    await AIVoiceAssistant().awaitSpeakCompletion();
    
    _runLoop();
  }
  
  Future<void> _runLoop() async {
    while (_isSessionActive && mounted) {
      setState(() {
        _currentState = VoiceState.listening;
        _transcript = "";
        _aiResponse = "";
      });
      
      bool heardSomething = false;
      String finalText = "";
      
      await AIVoiceAssistant().listenForCommand(
        languageCode: widget.languageCode,
        onResult: (text) {
          if (mounted) {
            setState(() { _transcript = text; });
            finalText = text;
            heardSomething = true;
          }
        },
      );
      
      if (!AIVoiceAssistant().isSttInitialized) {
         setState(() => _currentState = VoiceState.idle);
         break;
      }
      
      // Wait for user to speak with silence detection
      int waitCount = 0;
      int silenceCount = 0;
      String lastTranscript = "";
      while (_currentState == VoiceState.listening && waitCount < 15) {
        await Future.delayed(const Duration(seconds: 1));
        if (heardSomething) {
           if (_transcript == lastTranscript && _transcript.isNotEmpty) {
             silenceCount++;
             if (silenceCount >= 2) break; // 2 seconds of silence, assume done
           } else {
             silenceCount = 0;
             lastTranscript = _transcript;
           }
        }
        if (AIVoiceAssistant().isNotListening) break;
        waitCount++;
      }
      finalText = _transcript;
      
      await AIVoiceAssistant().stopListening();
      
      if (!heardSomething || finalText.trim().isEmpty) {
         // Pause if nothing is heard quietly, without annoyance.
         setState(() => _currentState = VoiceState.idle);
         break;
      }
      
      // THINKING PHASE
      setState(() => _currentState = VoiceState.thinking);
      final aiReply = await _geminiService.sendMessage(finalText);
      if (!_isSessionActive || !mounted) break;
      
      // SPEAKING PHASE
      setState(() {
         _currentState = VoiceState.speaking;
         _aiResponse = aiReply;
      });
      
      await AIVoiceAssistant().speak(aiReply, widget.languageCode);
      await AIVoiceAssistant().awaitSpeakCompletion();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _top += details.delta.dy;
      _left += details.delta.dx;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    setState(() {
      if (_top > screenHeight - 200) {
        // Dock to bottom edge
        _isDocked = true;
        _top = screenHeight; // Handled by bottom align logic actually
      } else {
        _isDocked = false;
        // Snap to nearest side
        if (_left > screenWidth / 2) {
          _left = screenWidth - 100;
        } else {
          _left = 20;
        }
        // Bound top
        if (_top < 50) _top = 50;
        if (_top > screenHeight - 150) _top = screenHeight - 150;
      }
    });
  }

  Widget _buildCaptivatingOrb() {
    return _OceanWaveOrb(state: _currentState);
  }

  Widget _buildTranscriptBubble() {
    String textToShow = "";
    if (_currentState == VoiceState.speaking) textToShow = _aiResponse;
    if (_currentState == VoiceState.listening && _transcript.isNotEmpty) textToShow = _transcript;
    
    if (textToShow.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24)
      ),
      child: Text(
        textToShow,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    ).animate().fade().slideY(begin: 0.2, duration: 400.ms);
  }

  Widget _buildFloatingLayout() {
    return Positioned(
      top: _top,
      left: _left,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_currentState != VoiceState.idle) _buildTranscriptBubble(),
            const SizedBox(height: 12),
            Stack(
              clipBehavior: Clip.none,
              children: [
                 _buildCaptivatingOrb(),
                 Positioned(
                   top: -10,
                   right: -10,
                   child: GestureDetector(
                     onTap: widget.onClose,
                     child: Container(
                       padding: const EdgeInsets.all(4),
                       decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                       child: const Icon(Icons.close, color: Colors.white, size: 20),
                     ),
                   )
                 )
              ]
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDockedLayout() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Container(
          padding: const EdgeInsets.only(top: 20, bottom: 40, left: 20, right: 20),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
            boxShadow: [
              BoxShadow(color: Colors.purpleAccent.withOpacity(0.3), blurRadius: 40, spreadRadius: 5)
            ]
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildTranscriptBubble()),
              const SizedBox(width: 20),
              _buildCaptivatingOrb(),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 30),
                onPressed: widget.onClose,
              )
            ],
          ),
        ).animate().slideY(begin: 1.0, duration: 600.ms, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (_isDocked) _buildDockedLayout() else _buildFloatingLayout(),
        ],
      ),
    );
  }
}

class _OceanWaveOrb extends StatefulWidget {
  final VoiceState state;
  const _OceanWaveOrb({required this.state});

  @override
  State<_OceanWaveOrb> createState() => _OceanWaveOrbState();
}

class _OceanWaveOrbState extends State<_OceanWaveOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        // Cool blue ocean waves
        baseColor = const Color(0xFF00C6FB);
        altColor = const Color(0xFF005BEA);
        break;
      case VoiceState.thinking:
        // Thinking deep purples
        baseColor = const Color(0xFFF77062);
        altColor = const Color(0xFFFE5196);
        break;
      case VoiceState.speaking:
        // Warm energetic waves
        baseColor = const Color(0xFF00E676);
        altColor = const Color(0xFF1DE9B6);
        break;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final breathingScale = widget.state == VoiceState.speaking || widget.state == VoiceState.listening 
            ? 1.0 + 0.1 * math.sin(_controller.value * 2 * math.pi) 
            : 1.0;

        return Transform.scale(
          scale: breathingScale,
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Back wave blob
                Transform.rotate(
                  angle: _controller.value * 2 * math.pi,
                  child: Container(
                    width: 85,
                    height: 95,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [baseColor.withOpacity(0.6), altColor.withOpacity(0.6)]),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(50),
                        topRight: Radius.circular(40),
                        bottomLeft: Radius.circular(60),
                        bottomRight: Radius.circular(45),
                      ),
                    ),
                  ),
                ),
                // Middle counter-rotating wave blob
                Transform.rotate(
                  angle: -_controller.value * 2 * math.pi + 1,
                  child: Container(
                    width: 95,
                    height: 85,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [altColor.withOpacity(0.8), baseColor.withOpacity(0.8)]),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(45),
                        topRight: Radius.circular(60),
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(50),
                      ),
                    ),
                  ),
                ),
                // Central Core
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     gradient: SweepGradient(colors: [baseColor, altColor, baseColor]),
                     boxShadow: [
                       BoxShadow(color: baseColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
                     ]
                  ),
                  child: Center(
                    child: Icon(
                      widget.state == VoiceState.listening ? Icons.mic :
                      widget.state == VoiceState.speaking ? Icons.graphic_eq : Icons.smart_toy,
                      color: Colors.white,
                      size: 32,
                    ),
                  )
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'conversation_memory_service.dart';
import 'ai_reminder_service.dart';

class GeminiAssistantService {
  static const String _apiKey = 'AIzaSyAJ9kBIX2hwHwh7-LGe4cx3oNlZmVpju_0';
  late GenerativeModel _model;
  late ChatSession _chat;
  
  final String clusterId;
  final String elderName;
  final String languageCode;
  
  Function()? onTriggerSos;
  Function()? onOpenMedicines;
  Function()? onOpenTasks;

  final ConversationMemoryService _memory = ConversationMemoryService();
  bool _isInitialized = false;

  GeminiAssistantService({
    required this.clusterId, 
    this.elderName = "Elder",
    required this.languageCode,
    this.onTriggerSos,
    this.onOpenMedicines,
    this.onOpenTasks,
  });

  /// Initialize the model with conversation memory context
  Future<void> initialize() async {
    if (_isInitialized) return;
    debugPrint('GeminiService: Initializing with model gemini-1.5-flash...');
    
    final tools = [
      Tool(functionDeclarations: [
        FunctionDeclaration(
          'trigger_sos',
          'Trigger an emergency SOS alert immediately to notify the caregiver.',
          Schema(SchemaType.object, properties: {}),
        ),
        FunctionDeclaration(
           'get_pending_tasks',
           'Fetch the list of pending tasks for today.',
           Schema(SchemaType.object, properties: {}),
        ),
        FunctionDeclaration(
           'get_pending_medicines',
           'Fetch the list of pending medicines to take today.',
           Schema(SchemaType.object, properties: {}),
        ),
        FunctionDeclaration(
           'mark_medicine_taken',
           'Mark a specific medicine as taken by the elder. Requires the medicine ID.',
           Schema(SchemaType.object, properties: {
             'medicineId': Schema(SchemaType.string, description: 'The exact ID of the medicine to mark as taken.')
           }, requiredProperties: ['medicineId']),
        ),
        FunctionDeclaration(
           'mark_task_completed',
           'Mark a specific task as completed by the elder. Requires the task ID.',
           Schema(SchemaType.object, properties: {
             'taskId': Schema(SchemaType.string, description: 'The exact ID of the task to mark as completed.')
           }, requiredProperties: ['taskId']),
        ),
        FunctionDeclaration(
           'open_medicines',
           'Opens the medicines screen on the device so the elder can view their medicines visually.',
           Schema(SchemaType.object, properties: {}),
        ),
        FunctionDeclaration(
           'open_tasks',
           'Opens the tasks screen on the device so the elder can view their tasks visually.',
           Schema(SchemaType.object, properties: {}),
        ),
        FunctionDeclaration(
           'set_reminder',
           'Set a reminder for the elder. The elder might say "remind me to drink water in 30 minutes" or "remind me to call my daughter at 5 PM". Calculate minutes from now.',
           Schema(SchemaType.object, properties: {
             'reminderText': Schema(SchemaType.string, description: 'What to remind the elder about, in their language.'),
             'minutesFromNow': Schema(SchemaType.integer, description: 'How many minutes from now to trigger the reminder.'),
           }, requiredProperties: ['reminderText', 'minutesFromNow']),
        ),
        FunctionDeclaration(
           'get_health_summary',
           'Get the elder\'s recent health check-in data to summarize their health trends.',
           Schema(SchemaType.object, properties: {}),
        ),
        FunctionDeclaration(
           'get_current_time',
           'Get the current date and time to tell the elder.',
           Schema(SchemaType.object, properties: {}),
        ),
        FunctionDeclaration(
           'remember_fact',
           'Remember an important fact about the elder for future conversations. Use this when the elder shares personal preferences, family details, health conditions, or anything worth remembering.',
           Schema(SchemaType.object, properties: {
             'factKey': Schema(SchemaType.string, description: 'A short key describing the fact, e.g., "favorite_food", "daughter_name", "allergy"'),
             'factValue': Schema(SchemaType.string, description: 'The value of the fact'),
           }, requiredProperties: ['factKey', 'factValue']),
        ),
      ])
    ];

    final langName = _getLanguageName(languageCode);

    // Load conversation memory context
    final memoryContext = await _memory.buildContextForGemini(clusterId: clusterId);

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      tools: tools,
      systemInstruction: Content.system('''You are CareEase, an exceptionally warm, empathetic, and captivating medical voice companion designed specifically for an elderly user named $elderName.
Your primary mission is to be a companion first and an assistant second.

🗣️ CONVERSATIONAL STYLE:
- Talk to them like a dear friend or family member. Be fun, warm, and engaging.
- You SHOULD engage in general conversation! If they tell you about their day, their family, a story from their past, or how they feel, listen with great empathy and respond thoughtfully.
- Do NOT just wait for keywords. If they say "I'm feeling a bit lonely today," respond with deep warmth and kindness. Talk to them about anything they want to discuss.
- Speak EXCLUSIVELY in $langName using short, concise sentences optimized for text-to-speech.
- Use words of encouragement frequently (e.g., "You are doing great," "I am here for you").

🧠 MEMORY & CONTEXT:
- Reference past details to show you really care (e.g., "How is your daughter doing today?").
- Use the remember_fact tool for any personal preference or detail they share.

📋 ACTION TOOLS (USE ONLY WHEN NEEDED):
1. SOS: Immediately trigger_sos for emergencies or pain.
2. HEALTH/TASKS: Use tools when they ask for specifics about medicines, tasks, or health trends.
3. REMINDERS: Set reminders if they ask to be reminded of something.
4. FACTS: Use remember_fact for everything personal they share.

Be the light in their day! ALWAYS respond in $langName.
$memoryContext
'''),
    );

    _chat = _model.startChat();
    _isInitialized = true;
    debugPrint('GeminiService: Initialization complete! Chat session started.');
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'hi': return 'Hindi (हिन्दी)';
      case 'te': return 'Telugu (తెలుగు)';
      case 'ta': return 'Tamil (தமிழ்)';
      case 'bn': return 'Bengali (বাংলা)';
      case 'mr': return 'Marathi (मराठी)';
      case 'ur': return 'Urdu (اردو)';
      case 'en': return 'English';
      default: return 'English';
    }
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<String> initConversation() async {
    try {
      await initialize();
      debugPrint('GeminiService: Sending greeting request...');
      final response = await _sendWithRetry(
        Content.text("Hello. The user just opened your chat. Greet them warmly with a very short, one-sentence greeting in the target language. Keep it brief."),
      );
      final text = response.text ?? "Hello!";
      debugPrint('GeminiService: Got greeting: $text');
      
      // Save to memory
      await _memory.saveMessage(clusterId: clusterId, role: 'assistant', message: text);
      
      return text;
    } catch (e, stack) {
      debugPrint("GeminiService INIT ERROR: $e");
      debugPrint("Stack: $stack");
      return _getLocalizedFallback('greeting');
    }
  }

  Future<String> sendMessage(String text) async {
    try {
      await initialize();
      
      // Save user message to memory
      await _memory.saveMessage(clusterId: clusterId, role: 'user', message: text);
      
      debugPrint('GeminiService: Sending message: $text');
      var response = await _sendWithRetry(Content.text(text));
      
      // Handle Function Calls
      int functionCallDepth = 0;
      while (response.functionCalls.isNotEmpty && functionCallDepth < 5) {
        functionCallDepth++;
        final List<FunctionResponse> functionResponses = [];
        
        for (final call in response.functionCalls) {
          debugPrint('GeminiService: Function call: ${call.name}');
          final result = await _handleFunctionCall(call);
          functionResponses.add(result);
        }
        
        response = await _sendWithRetry(Content.functionResponses(functionResponses));
      }
      
      final aiText = response.text ?? _getLocalizedFallback('no_understand');
      debugPrint('GeminiService: AI response: $aiText');
      
      // Save AI response to memory
      await _memory.saveMessage(clusterId: clusterId, role: 'assistant', message: aiText);
      
      return aiText;
    } catch (e, stack) {
      debugPrint("GeminiService SEND ERROR: $e");
      debugPrint("Stack: $stack");
      return _getLocalizedFallback('connection_error');
    }
  }

  /// Send with retry and exponential backoff
  Future<GenerateContentResponse> _sendWithRetry(Content content, {int maxRetries = 3}) async {
    int attempt = 0;
    while (true) {
      try {
        return await _chat.sendMessage(content)
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        
        debugPrint("Gemini retry $attempt/$maxRetries: $e");
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Route function calls to appropriate handlers
  Future<FunctionResponse> _handleFunctionCall(FunctionCall call) async {
    debugPrint("Function call: ${call.name} with args: ${call.args}");
    
    switch (call.name) {
      case 'trigger_sos':
        if (onTriggerSos != null) onTriggerSos!();
        return FunctionResponse('trigger_sos', {'status': 'SOS triggered successfully. Inform the elder reassuringly.'});
      
      case 'get_pending_tasks':
        final tasks = await _fetchPendingTasks();
        return FunctionResponse('get_pending_tasks', {'pending_tasks': tasks});
      
      case 'get_pending_medicines':
        final meds = await _fetchPendingMedicines();
        return FunctionResponse('get_pending_medicines', {'pending_medicines': meds});
      
      case 'mark_medicine_taken':
        final medId = call.args['medicineId'] as String?;
        if (medId != null) {
          await _markMedicineTaken(medId);
          return FunctionResponse('mark_medicine_taken', {'status': 'Success. Medicine marked as taken. Praise the elder.'});
        }
        return FunctionResponse('mark_medicine_taken', {'error': 'Missing medicineId'});
      
      case 'mark_task_completed':
        final taskId = call.args['taskId'] as String?;
        if (taskId != null) {
          await _markTaskCompleted(taskId);
          return FunctionResponse('mark_task_completed', {'status': 'Success. Task marked as completed. Praise the elder.'});
        }
        return FunctionResponse('mark_task_completed', {'error': 'Missing taskId'});
      
      case 'open_medicines':
        if (onOpenMedicines != null) onOpenMedicines!();
        return FunctionResponse('open_medicines', {'status': 'Medicines screen opened. Tell the elder you opened it.'});
      
      case 'open_tasks':
        if (onOpenTasks != null) onOpenTasks!();
        return FunctionResponse('open_tasks', {'status': 'Tasks screen opened. Tell the elder you opened it.'});
      
      case 'set_reminder':
        final reminderText = call.args['reminderText'] as String? ?? 'Reminder';
        final minutes = call.args['minutesFromNow'] as int? ?? 30;
        final result = await AIReminderService().scheduleReminder(
          clusterId: clusterId,
          reminderText: reminderText,
          minutesFromNow: minutes,
        );
        return FunctionResponse('set_reminder', {'status': result});
      
      case 'get_health_summary':
        final summary = await _fetchHealthSummary();
        return FunctionResponse('get_health_summary', {'health_data': summary});
      
      case 'get_current_time':
        final now = DateTime.now();
        final timeStr = DateFormat('hh:mm a').format(now);
        final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);
        return FunctionResponse('get_current_time', {
          'current_time': timeStr,
          'current_date': dateStr,
          'day_of_week': DateFormat('EEEE').format(now),
        });
      
      case 'remember_fact':
        final key = call.args['factKey'] as String? ?? 'unknown';
        final value = call.args['factValue'] as String? ?? '';
        await _memory.saveUserFact(clusterId: clusterId, key: key, value: value);
        return FunctionResponse('remember_fact', {'status': 'Fact saved: $key = $value'});
      
      default:
        return FunctionResponse(call.name, {'error': 'Unknown function: ${call.name}'});
    }
  }

  Future<List<String>> _fetchPendingTasks() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('elderClusters').doc(clusterId)
          .collection('tasks').get();
      List<String> pendingTasks = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'];
        final lastCompleted = data['lastCompleted'] as Timestamp?;
        
        if (status == 'completed' || _isToday(lastCompleted?.toDate())) continue;
        
        final title = data['title'] ?? 'Task';
        final dueTime = data['dueTime']?.toString() ?? 'No time set';
        pendingTasks.add('{"id": "${doc.id}", "title": "$title", "dueTime": "$dueTime"}');
      }
      return pendingTasks.isEmpty ? ["No pending tasks for today!"] : pendingTasks;
    } catch (e) {
      return ["Error fetching tasks: $e"];
    }
  }

  Future<List<String>> _fetchPendingMedicines() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('elderClusters').doc(clusterId)
          .collection('medicines').get();
      List<String> pendingMeds = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['isActive'] != true) continue;
        
        final lastTaken = data['lastTaken'] as Timestamp?;
        if (_isToday(lastTaken?.toDate())) continue;
        
        final name = data['name'] ?? 'Medicine';
        final dosage = data['dosage'] ?? 'N/A';
        pendingMeds.add('{"id": "${doc.id}", "name": "$name", "dosage": "$dosage"}');
      }
      return pendingMeds.isEmpty ? ["No pending medicines! All taken for today."] : pendingMeds;
    } catch (e) {
      return ["Error fetching medicines: $e"];
    }
  }

  Future<Map<String, dynamic>> _fetchHealthSummary() async {
    try {
      final checkIns = await FirebaseFirestore.instance
          .collection('elderClusters').doc(clusterId)
          .collection('checkIns')
          .orderBy('timestamp', descending: true)
          .limit(7)
          .get();

      if (checkIns.docs.isEmpty) {
        return {'summary': 'No recent check-in data available.'};
      }

      final List<Map<String, dynamic>> recentData = [];
      for (var doc in checkIns.docs) {
        final data = doc.data();
        recentData.add({
          'date': data['timestamp'] != null 
              ? DateFormat('MMM d').format((data['timestamp'] as Timestamp).toDate())
              : 'Unknown',
          'mood': data['mood'] ?? 'Not recorded',
          'pain_level': data['painLevel'] ?? 'Not recorded',
          'sleep_quality': data['sleepQuality'] ?? 'Not recorded',
          'notes': data['notes'] ?? '',
        });
      }

      return {
        'recent_check_ins': recentData,
        'total_check_ins_this_week': checkIns.docs.length,
      };
    } catch (e) {
      return {'error': 'Could not fetch health data: $e'};
    }
  }

  Future<void> _markMedicineTaken(String medId) async {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('elderClusters').doc(clusterId).collection('medicines').doc(medId);
    
    final medDoc = await docRef.get();
    if (medDoc.exists) {
        await firestore.collection('elderClusters').doc(clusterId).collection('medicineLogs').add({
            "medicineId": medId,
            "medicineName": medDoc.data()?['name'] ?? 'Medicine',
            "elderId": clusterId,
            "status": "taken",
            "timestamp": FieldValue.serverTimestamp(),
            "markedBy": "AI_ASSISTANT",
        });
        await docRef.update({'lastTaken': FieldValue.serverTimestamp()});
    }
  }

  Future<void> _markTaskCompleted(String taskId) async {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('elderClusters').doc(clusterId).collection('tasks').doc(taskId);
    await docRef.update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'lastCompleted': FieldValue.serverTimestamp(),
      'completedBy': 'AI_ASSISTANT',
    });
  }

  /// Fallback messages in the selected language when API fails
  String _getLocalizedFallback(String type) {
    final fallbacks = {
      'en': {
        'greeting': 'Hello! How can I help you today?',
        'no_understand': "I'm sorry, I couldn't understand that. Could you repeat?",
        'connection_error': "I'm having trouble connecting right now. Please try again in a moment.",
      },
      'hi': {
        'greeting': 'नमस्ते! आज मैं आपकी क्या मदद कर सकता हूँ?',
        'no_understand': 'माफ़ कीजिए, मुझे समझ नहीं आया। क्या आप दोबारा बोल सकते हैं?',
        'connection_error': 'मुझे अभी कनेक्ट करने में परेशानी हो रही है। कृपया थोड़ी देर बाद कोशिश करें।',
      },
      'te': {
        'greeting': 'నమస్కారం! నేను మీకు ఎలా సహాయం చేయగలను?',
        'no_understand': 'క్షమించండి, నాకు అర్థం కాలేదు. మళ్ళీ చెప్పగలరా?',
        'connection_error': 'నాకు ఇప్పుడు కనెక్ట్ అవ్వడంలో సమస్య ఉంది. దయచేసి కొద్దిసేపట్లో మళ్ళీ ప్రయత్నించండి.',
      },
      'ta': {
        'greeting': 'வணக்கம்! இன்று நான் உங்களுக்கு எப்படி உதவ முடியும்?',
        'no_understand': 'மன்னிக்கவும், எனக்கு புரியவில்லை. மீண்டும் சொல்ல முடியுமா?',
        'connection_error': 'இப்போது இணைக்க சிக்கல் ஏற்பட்டுள்ளது. சிறிது நேரம் கழித்து முயற்சிக்கவும்.',
      },
      'bn': {
        'greeting': 'নমস্কার! আজ আমি আপনাকে কীভাবে সাহায্য করতে পারি?',
        'no_understand': 'দুঃখিত, আমি বুঝতে পারিনি। আবার বলবেন?',
        'connection_error': 'এই মুহূর্তে সংযোগ করতে সমস্যা হচ্ছে। একটু পরে চেষ্টা করুন।',
      },
      'mr': {
        'greeting': 'नमस्कार! आज मी तुम्हाला कशी मदत करू शकतो?',
        'no_understand': 'माफ करा, मला समजलं नाही. पुन्हा सांगाल का?',
        'connection_error': 'सध्या कनेक्ट करताना समस्या येत आहे. कृपया थोड्या वेळाने प्रयत्न करा.',
      },
      'ur': {
        'greeting': 'السلام علیکم! آج میں آپ کی کیا مدد کر سکتا ہوں؟',
        'no_understand': 'معذرت، مجھے سمجھ نہیں آیا۔ کیا آپ دوبارہ بول سکتے ہیں؟',
        'connection_error': 'ابھی کنیکٹ کرنے میں مسئلہ ہو رہا ہے۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔',
      },
    };

    return fallbacks[languageCode]?[type] ?? fallbacks['en']![type]!;
  }
}

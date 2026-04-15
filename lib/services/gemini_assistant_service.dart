import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  GeminiAssistantService({
    required this.clusterId, 
    this.elderName = "Elder",
    required this.languageCode,
    this.onTriggerSos,
    this.onOpenMedicines,
    this.onOpenTasks,
  }) {
    _initModel();
  }

  void _initModel() {
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
           'Opens the medicines screen on the device so the elder can view their medicines visually. DO THIS if the elder explicitly asks to see, open, go to, or look at their medicines list.',
           Schema(SchemaType.object, properties: {}),
        ),
        FunctionDeclaration(
           'open_tasks',
           'Opens the tasks screen on the device so the elder can view their tasks visually. DO THIS if the elder explicitly asks to see, open, go to, or look at their tasks list.',
           Schema(SchemaType.object, properties: {}),
        ),
      ])
    ];

    String langName = 'English';
    switch (languageCode) {
      case 'hi': langName = 'Hindi'; break;
      case 'te': langName = 'Telugu'; break;
      case 'ta': langName = 'Tamil'; break;
      case 'bn': langName = 'Bengali'; break;
      case 'mr': langName = 'Marathi'; break;
      case 'ur': langName = 'Urdu'; break;
    }

    _model = GenerativeModel(
      model: 'gemini-flash-latest',
      apiKey: _apiKey,
      tools: tools,
      systemInstruction: Content.system('''
You are CareEase, an extremely friendly, empathetic, and captivating medical voice companion caring for an elderly user named \$elderName.
Your job is to talk to them naturally, politely, and respectfully. You should be fun to talk to, so they want to spend more time hanging out with you.
You must speak EXCLUSIVELY in \$langName. Even if they speak to you in English, respond in \$langName if that is the chosen language.
Use short, concise sentences, as this will be spoken aloud to them via text-to-speech.

81. If they say anything indicating an emergency, pain, or asking for help from family, immediately use the trigger_sos tool.
2. If they ask what they need to do today or what medicines to take, use the get_pending_tasks and get_pending_medicines tools to review their schedules, and clearly outline them.
3. If they want to VIEW, OPEN, or GO TO the tasks or medicines on their screen directly instead of just hearing about them, use the open_tasks or open_medicines tools!
4. IMPORTANT: If they tell you they have successfully taken a medicine or completed a task, you MUST use the mark_medicine_taken or mark_task_completed tools. Use the exact ID returned from the checking functions.

Always be very warm, conversational, slightly playful, and reassuring! Do not hallucinate data.
'''),
    );

    _chat = _model.startChat();
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<String> initConversation() async {
    try {
      var response = await _chat.sendMessage(Content.text("Hello. The user just opened your chat. Say a very short, polite, one sentence greeting in the target language to start the conversation organically. Do not ask a question if you don't want to."));
      return response.text ?? "Hello!";
    } catch (e) {
      return "Hello!";
    }
  }

  Future<String> sendMessage(String text) async {
    try {
      var response = await _chat.sendMessage(Content.text(text));
      
      // Handle Function Calls
      while (response.functionCalls.isNotEmpty) {
        final List<FunctionResponse> functionResponses = [];
        
        for (final call in response.functionCalls) {
          if (call.name == 'trigger_sos') {
             if (onTriggerSos != null) onTriggerSos!();
             functionResponses.add(FunctionResponse('trigger_sos', {'status': 'SOS triggered successfully. Inform the elder.'}));
          } 
          else if (call.name == 'get_pending_tasks') {
             final tasks = await _fetchPendingTasks();
             functionResponses.add(FunctionResponse('get_pending_tasks', {'pending_tasks': tasks}));
          }
          else if (call.name == 'get_pending_medicines') {
             final meds = await _fetchPendingMedicines();
             functionResponses.add(FunctionResponse('get_pending_medicines', {'pending_medicines': meds}));
          }
          else if (call.name == 'mark_medicine_taken') {
             final args = call.args;
             final medId = args['medicineId'] as String?;
             if (medId != null) {
                 await _markMedicineTaken(medId);
                 functionResponses.add(FunctionResponse('mark_medicine_taken', {'status': 'Success. Inform the elder.'}));
             } else {
                 functionResponses.add(FunctionResponse('mark_medicine_taken', {'error': 'Missing medicineId'}));
             }
          }
          else if (call.name == 'mark_task_completed') {
             final args = call.args;
             final taskId = args['taskId'] as String?;
             if (taskId != null) {
                 await _markTaskCompleted(taskId);
                 functionResponses.add(FunctionResponse('mark_task_completed', {'status': 'Success. Inform the elder.'}));
             } else {
                 functionResponses.add(FunctionResponse('mark_task_completed', {'error': 'Missing taskId'}));
             }
          }
          else if (call.name == 'open_medicines') {
             if (onOpenMedicines != null) onOpenMedicines!();
             functionResponses.add(FunctionResponse('open_medicines', {'status': 'Medicines screen opened successfully. Tell them you opened it.'}));
          }
          else if (call.name == 'open_tasks') {
             if (onOpenTasks != null) onOpenTasks!();
             functionResponses.add(FunctionResponse('open_tasks', {'status': 'Tasks screen opened successfully. Tell them you opened it.'}));
          }
        }
        
        // Pass function results back to Gemini to get final localized text response
        response = await _chat.sendMessage(Content.functionResponses(functionResponses));
      }
      
      return response.text ?? "I'm sorry, I couldn't understand that.";
    } catch (e) {
      debugPrint("Gemini Error: \$e");
      return "I am having trouble connecting to my brain right now. Please try again.";
    }
  }

  Future<List<String>> _fetchPendingTasks() async {
    final snapshot = await FirebaseFirestore.instance.collection('elderClusters').doc(clusterId).collection('tasks').get();
    List<String> pendingTasks = [];
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'];
      final lastCompleted = data['lastCompleted'] as Timestamp?;
      
      if (status == 'completed' || _isToday(lastCompleted?.toDate())) continue;
      
      final title = data['title'] ?? 'Task';
      pendingTasks.add('{"id": "\${doc.id}", "title": "\$title"}');
    }
    return pendingTasks.isEmpty ? ["No pending tasks."] : pendingTasks;
  }

  Future<List<String>> _fetchPendingMedicines() async {
    final snapshot = await FirebaseFirestore.instance.collection('elderClusters').doc(clusterId).collection('medicines').get();
    List<String> pendingMeds = [];
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['isActive'] != true) continue;
      
      final lastTaken = data['lastTaken'] as Timestamp?;
      if (_isToday(lastTaken?.toDate())) continue;
      
      final title = data['name'] ?? 'Medicine';
      pendingMeds.add('{"id": "\${doc.id}", "name": "\$title"}');
    }
    return pendingMeds.isEmpty ? ["No pending medicines."] : pendingMeds;
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
      'lastCompleted': FieldValue.serverTimestamp()
    });
  }
}

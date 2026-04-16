import 'package:flutter/foundation.dart';

/// Persistent conversation memory service.
/// Uses in-memory storage for web compatibility.
/// On native platforms (Android/iOS), you can upgrade this to sqflite.
class ConversationMemoryService {
  static final ConversationMemoryService _instance = ConversationMemoryService._internal();
  factory ConversationMemoryService() => _instance;
  ConversationMemoryService._internal();

  // In-memory storage (works on ALL platforms including web)
  final Map<String, List<Map<String, dynamic>>> _conversations = {};
  final Map<String, Map<String, String>> _userFacts = {};
  final Map<String, List<Map<String, dynamic>>> _reminders = {};
  int _nextReminderId = 1;

  /// Save a message to conversation history
  Future<void> saveMessage({
    required String clusterId,
    required String role, // 'user' or 'assistant'
    required String message,
  }) async {
    _conversations.putIfAbsent(clusterId, () => []);
    _conversations[clusterId]!.add({
      'role': role,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Keep only last 50 messages per cluster
    if (_conversations[clusterId]!.length > 50) {
      _conversations[clusterId] = _conversations[clusterId]!
          .sublist(_conversations[clusterId]!.length - 50);
    }
  }

  /// Get recent conversation history for context injection
  Future<List<Map<String, dynamic>>> getRecentHistory({
    required String clusterId,
    int limit = 15,
  }) async {
    final msgs = _conversations[clusterId] ?? [];
    if (msgs.length <= limit) return List.from(msgs);
    return msgs.sublist(msgs.length - limit);
  }

  /// Build a context summary string from recent history for Gemini
  Future<String> buildContextForGemini({required String clusterId}) async {
    final history = await getRecentHistory(clusterId: clusterId, limit: 10);
    if (history.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('--- PREVIOUS CONVERSATION CONTEXT ---');
    
    for (final msg in history) {
      final role = msg['role'] == 'user' ? 'Elder' : 'You (CareEase)';
      buffer.writeln('$role: ${msg['message']}');
    }
    
    buffer.writeln('--- END OF CONTEXT ---');

    // Also include learned facts
    final facts = _userFacts[clusterId];
    if (facts != null && facts.isNotEmpty) {
      buffer.writeln('--- THINGS YOU KNOW ABOUT THIS ELDER ---');
      for (final entry in facts.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
      buffer.writeln('--- END OF FACTS ---');
    }

    return buffer.toString();
  }

  /// Save a fact about the user
  Future<void> saveUserFact({
    required String clusterId,
    required String key,
    required String value,
  }) async {
    _userFacts.putIfAbsent(clusterId, () => {});
    _userFacts[clusterId]![key] = value;
    debugPrint('Saved user fact: $key = $value');
  }

  /// Get all facts for a user
  Future<List<Map<String, dynamic>>> getUserFacts({required String clusterId}) async {
    final facts = _userFacts[clusterId];
    if (facts == null) return [];
    return facts.entries.map((e) => {'fact_key': e.key, 'fact_value': e.value}).toList();
  }

  /// Save a reminder
  Future<int> saveReminder({
    required String clusterId,
    required String reminderText,
    required DateTime scheduledTime,
  }) async {
    _reminders.putIfAbsent(clusterId, () => []);
    final id = _nextReminderId++;
    _reminders[clusterId]!.add({
      'id': id,
      'reminder_text': reminderText,
      'scheduled_time': scheduledTime.millisecondsSinceEpoch,
      'is_completed': false,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  /// Get pending reminders
  Future<List<Map<String, dynamic>>> getPendingReminders({required String clusterId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (_reminders[clusterId] ?? [])
        .where((r) => r['is_completed'] == false && r['scheduled_time'] > now)
        .toList();
  }

  /// Mark reminder as completed
  Future<void> completeReminder(int reminderId) async {
    for (final clusterReminders in _reminders.values) {
      for (final r in clusterReminders) {
        if (r['id'] == reminderId) {
          r['is_completed'] = true;
          return;
        }
      }
    }
  }

  /// Clear all data for a cluster
  Future<void> clearClusterData(String clusterId) async {
    _conversations.remove(clusterId);
    _userFacts.remove(clusterId);
    _reminders.remove(clusterId);
  }
}

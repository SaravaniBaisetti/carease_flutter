import 'package:flutter/foundation.dart';
import 'package:careasen/services/notification_service.dart';
import 'package:careasen/services/conversation_memory_service.dart';

/// Service for AI-triggered reminders.
/// When the AI uses the `set_reminder` function call, this service
/// schedules a local notification and persists it in SQLite.
class AIReminderService {
  static final AIReminderService _instance = AIReminderService._internal();
  factory AIReminderService() => _instance;
  AIReminderService._internal();

  /// Schedule a reminder from the AI assistant
  /// Returns a human-readable confirmation message
  Future<String> scheduleReminder({
    required String clusterId,
    required String reminderText,
    required int minutesFromNow,
  }) async {
    try {
      final scheduledTime = DateTime.now().add(Duration(minutes: minutesFromNow));
      
      // Save to SQLite for persistence
      final reminderId = await ConversationMemoryService().saveReminder(
        clusterId: clusterId,
        reminderText: reminderText,
        scheduledTime: scheduledTime,
      );

      // Schedule local notification
      await NotificationService().scheduleAlarm(
        id: 'ai_reminder_$reminderId'.hashCode,
        title: '🔔 CareEase Reminder',
        body: reminderText,
        scheduledTime: scheduledTime,
        payload: 'reminder|$clusterId|$reminderId|0',
      );

      debugPrint('AI Reminder scheduled: "$reminderText" in $minutesFromNow minutes');
      return 'Reminder set successfully for ${_formatTime(scheduledTime)}';
    } catch (e) {
      debugPrint('Error scheduling AI reminder: $e');
      return 'Failed to set reminder: $e';
    }
  }

  /// Cancel a pending reminder
  Future<void> cancelReminder(int reminderId) async {
    await NotificationService().cancelAlarm('ai_reminder_$reminderId'.hashCode);
    await ConversationMemoryService().completeReminder(reminderId);
  }

  /// Get all pending reminders for display
  Future<List<Map<String, dynamic>>> getPendingReminders(String clusterId) async {
    return await ConversationMemoryService().getPendingReminders(clusterId: clusterId);
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

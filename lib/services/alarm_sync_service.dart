import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'package:intl/intl.dart';

class AlarmSyncService {
  final String clusterId;
  StreamSubscription? _medicineSub;
  StreamSubscription? _taskSub;

  AlarmSyncService({required this.clusterId});

  void startSync() {
    debugPrint("Starting AlarmSyncService for cluster $clusterId");

    // Listen to Medicines
    _medicineSub = FirebaseFirestore.instance
        .collection('elderClusters')
        .doc(clusterId)
        .collection('medicines')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _processMedicines(snapshot.docs);
    });

    // Listen to Tasks
    _taskSub = FirebaseFirestore.instance
        .collection('elderClusters')
        .doc(clusterId)
        .collection('tasks')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      _processTasks(snapshot.docs);
    });
  }

  void stopSync() {
    _medicineSub?.cancel();
    _taskSub?.cancel();
  }

  Future<void> _processMedicines(List<QueryDocumentSnapshot> docs) async {
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timeSlots = List<String>.from(data['timeSlots'] ?? []);
      final snoozeCount = data['snoozeCount'] ?? 0;
      final medName = data['name'] ?? 'Medicine';

      // We need to verify if it was already taken today
      final lastTaken = data['lastTaken'] as Timestamp?;
      if (_isToday(lastTaken?.toDate())) continue;

      for (var timeStr in timeSlots) {
        final parsedTime = _parseTime(timeStr);
        if (parsedTime == null) continue;

        // If time has passed today and not snoozed, skip
        if (parsedTime.isBefore(DateTime.now()) && snoozeCount == 0) continue;

        final alarmId = "${doc.id}_$timeStr".hashCode;
        
        DateTime scheduledTime = parsedTime;
        if (snoozeCount > 0) {
          // If in snooze state, it expects to ring in 5 mins from last action
          // Since our NotificationService sets an exact 5 min alarm on snooze, here we just skip overriding it
          // Or we can let it be handled entirely by the background isolate.
          // To be safe against app re-opens, we don't clobber the snooze.
          continue; 
        }

        await NotificationService().scheduleAlarm(
          id: alarmId,
          title: "Medicine Reminder",
          body: "Time to take $medName!",
          scheduledTime: scheduledTime,
          payload: "medicine|$clusterId|${doc.id}|$snoozeCount",
        );
      }
    }
  }

  Future<void> _processTasks(List<QueryDocumentSnapshot> docs) async {
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dueTimeStr = data['dueTime'];
      if (dueTimeStr == null || dueTimeStr.toString().isEmpty) continue;

      final snoozeCount = data['snoozeCount'] ?? 0;
      final title = data['title'] ?? 'Task';

      final parsedTime = _parseTime(dueTimeStr.toString());
      if (parsedTime == null) continue;

      if (parsedTime.isBefore(DateTime.now()) && snoozeCount == 0) continue;

      final alarmId = "${doc.id}_task".hashCode;

      if (snoozeCount > 0) {
        continue; // handled by snooze isolate
      }

      await NotificationService().scheduleAlarm(
        id: alarmId,
        title: "Task Reminder",
        body: "$title is due now!",
        scheduledTime: parsedTime,
        payload: "task|$clusterId|${doc.id}|$snoozeCount",
      );
    }
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  DateTime? _parseTime(String timeStr) {
    try {
      // timeStr should be like "08:00" or "14:30"
      final parts = timeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
      if (parts.length < 2) return null;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      debugPrint("Error parsing time $timeStr: $e");
      return null;
    }
  }
}

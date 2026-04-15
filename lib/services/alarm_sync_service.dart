import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'package:intl/intl.dart';

class AlarmSyncService {
  final String clusterId;
  final Function(String type, String clusterId, String docId, Map<String, dynamic> data)? onRingTriggered;

  StreamSubscription? _medicineSub;
  StreamSubscription? _taskSub;
  Timer? _pollingTimer;

  final Set<int> _activeMedAlarmIds = {};
  final Set<int> _activeTaskAlarmIds = {};

  List<QueryDocumentSnapshot> _cachedMedDocs = [];
  List<QueryDocumentSnapshot> _cachedTaskDocs = [];
  DateTime? _lastRingTime;

  AlarmSyncService({required this.clusterId, this.onRingTriggered});

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
      _cachedMedDocs = snapshot.docs;
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
      _cachedTaskDocs = snapshot.docs;
      _processTasks(snapshot.docs);
    });

    _startPolling();
  }

  void stopSync() {
    _medicineSub?.cancel();
    _taskSub?.cancel();
    _pollingTimer?.cancel();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      // Anti-spam: wait at least 50 seconds between distinct rings
      if (_lastRingTime != null && now.difference(_lastRingTime!).inSeconds < 50) return;

      // Check tasks
      for (var doc in _cachedTaskDocs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] != 'pending') continue;
        
        if (!_isScheduledForToday(data, 'single')) continue;
        final lastCompleted = data['lastCompleted'] as Timestamp?;
        if (_isToday(lastCompleted?.toDate())) continue;
        
        final snoozedUntil = data['snoozedUntil'] as Timestamp?;
        final parsedTime = _parseDynamicTime(data['dueTime']);
        if (parsedTime == null) continue;

        final targetTime = snoozedUntil != null ? snoozedUntil.toDate() : parsedTime;
        
        if (_isTimeWithinWindow(now, targetTime)) {
          _lastRingTime = now;
          onRingTriggered?.call('task', clusterId, doc.id, data);
          return;
        }
      }

      // Check medicines
      for (var doc in _cachedMedDocs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!_isScheduledForToday(data, 'daily')) continue;
        
        final lastTaken = data['lastTaken'] as Timestamp?;
        if (_isToday(lastTaken?.toDate())) continue;

        final snoozedUntil = data['snoozedUntil'] as Timestamp?;
        final timeSlots = data['timeSlots'] as List<dynamic>? ?? [];
        
        if (snoozedUntil != null) {
           if (_isTimeWithinWindow(now, snoozedUntil.toDate())) {
             _lastRingTime = now;
             onRingTriggered?.call('medicine', clusterId, doc.id, data);
             return;
           }
        } else {
           for (var ts in timeSlots) {
             final parsedTime = _parseDynamicTime(ts);
             if (parsedTime != null && _isTimeWithinWindow(now, parsedTime)) {
               _lastRingTime = now;
               onRingTriggered?.call('medicine', clusterId, doc.id, data);
               return;
             }
           }
        }
      }
    });
  }

  bool _isTimeWithinWindow(DateTime now, DateTime target) {
    // A 5 minute rolling window: if target time passed within the last 5 minutes and wasn't acknowledged!
    final difference = now.difference(target).inSeconds;
    return difference >= 0 && difference < 300; 
  }

  Future<void> _processMedicines(List<QueryDocumentSnapshot> docs) async {
    final Set<int> currentMedIds = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      if (!_isScheduledForToday(data, 'daily')) continue;

      final timeSlots = data['timeSlots'] as List<dynamic>? ?? [];
      final snoozeCount = data['snoozeCount'] ?? 0;
      final snoozedUntil = data['snoozedUntil'] as Timestamp?;
      final medName = data['name'] ?? 'Medicine';

      final lastTaken = data['lastTaken'] as Timestamp?;
      if (_isToday(lastTaken?.toDate())) continue;

      if (snoozedUntil != null) {
         // Actively schedule the EXACT fallback native OS alarm for 5 mins in the future!
         final targetTime = snoozedUntil.toDate();
         if (targetTime.isBefore(DateTime.now())) continue;

         final alarmId = "${doc.id}_snooze".hashCode;
         currentMedIds.add(alarmId);
         
         await NotificationService().scheduleAlarm(
            id: alarmId,
            title: "Snoozed: $medName",
            body: "Take your medicine now!",
            scheduledTime: targetTime,
            payload: "medicine|$clusterId|${doc.id}|$snoozeCount",
         );
      } else {
         for (var timeData in timeSlots) {
           final parsedTime = _parseDynamicTime(timeData);
           if (parsedTime == null) continue;
           if (parsedTime.isBefore(DateTime.now())) continue;

           final alarmId = "${doc.id}_${timeData.toString()}".hashCode;
           currentMedIds.add(alarmId);
           
           await NotificationService().scheduleAlarm(
             id: alarmId,
             title: "Medicine Reminder",
             body: "Time to take $medName!",
             scheduledTime: parsedTime,
             payload: "medicine|$clusterId|${doc.id}|$snoozeCount",
           );
         }
      }
    }

    // Cancel old alarms
    final toCancel = _activeMedAlarmIds.difference(currentMedIds);
    for (int id in toCancel) {
      await NotificationService().cancelAlarm(id);
    }
    _activeMedAlarmIds.clear();
    _activeMedAlarmIds.addAll(currentMedIds);
  }

  Future<void> _processTasks(List<QueryDocumentSnapshot> docs) async {
    final Set<int> currentTaskIds = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      if (!_isScheduledForToday(data, 'single')) continue;
      
      final lastCompleted = data['lastCompleted'] as Timestamp?;
      if (_isToday(lastCompleted?.toDate())) continue;

      final dueTimeData = data['dueTime'];
      if (dueTimeData == null || dueTimeData.toString().isEmpty) continue;

      final snoozeCount = data['snoozeCount'] ?? 0;
      final snoozedUntil = data['snoozedUntil'] as Timestamp?;
      final title = data['title'] ?? 'Task';

      if (snoozedUntil != null) {
         final targetTime = snoozedUntil.toDate();
         if (targetTime.isBefore(DateTime.now())) continue; 

         final alarmId = "${doc.id}_snooze".hashCode;
         currentTaskIds.add(alarmId);
         
         await NotificationService().scheduleAlarm(
            id: alarmId,
            title: "Snoozed: $title",
            body: "$title is due now!",
            scheduledTime: targetTime,
            payload: "task|$clusterId|${doc.id}|$snoozeCount",
         );
      } else {
         final parsedTime = _parseDynamicTime(dueTimeData);
         if (parsedTime == null) continue;
         if (parsedTime.isBefore(DateTime.now())) continue;

         final alarmId = "${doc.id}_task".hashCode;
         currentTaskIds.add(alarmId);

         await NotificationService().scheduleAlarm(
           id: alarmId,
           title: "Task Reminder",
           body: "$title is due now!",
           scheduledTime: parsedTime,
           payload: "task|$clusterId|${doc.id}|$snoozeCount",
         );
      }
    }

    final toCancel = _activeTaskAlarmIds.difference(currentTaskIds);
    for (int id in toCancel) {
      await NotificationService().cancelAlarm(id);
    }
    _activeTaskAlarmIds.clear();
    _activeTaskAlarmIds.addAll(currentTaskIds);
  }

  bool _isScheduledForToday(Map<String, dynamic> data, String defaultRecType) {
    final recType = data['recurrenceType'] ?? defaultRecType;
    if (recType == 'specific_days') {
      final recDays = data['selectedDays'] as List<dynamic>? ?? [];
      final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final todayStr = weekDays[DateTime.now().weekday - 1];
      return recDays.contains(todayStr);
    }
    return true; // daily or single
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  DateTime? _parseTime(String timeStr) {
    try {
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

  DateTime? _parseDynamicTime(dynamic timeData) {
    if (timeData is Timestamp) {
      final dt = timeData.toDate();
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, dt.hour, dt.minute);
    } else if (timeData is String) {
      return _parseTime(timeData);
    }
    return null;
  }
}

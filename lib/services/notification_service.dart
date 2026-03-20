import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse notificationResponse) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    // If we're isolated, we must initialize Firebase
    await Firebase.initializeApp();
  }
  
  await NotificationService._handleAction(notificationResponse);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Ignore iOS/macOS for now as this is Android focused
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint("Notification Tapped in Foreground: ${response.payload}");
        await _handleAction(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Request permissions on Android 13+
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    // If time is in the past, don't schedule
    if (scheduledTime.isBefore(DateTime.now())) return;

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'careasen_alarms',
      'CareEase Alarms',
      channelDescription: 'Notifications for Medications and Tasks',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true, // Acts like a real alarm appearing on top
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT: Rings continuously until dismissed!
      color: Colors.redAccent,
      playSound: true,
      actions: [
        AndroidNotificationAction('snooze', 'Snooze (5m)'),
        AndroidNotificationAction('done', 'Mark as Done'),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzTime,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelAlarm(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAllAlarms() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // --- Static handler for Snooze / Done ---
  static Future<void> _handleAction(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // payload format: type|clusterId|docId|snoozeCount
    final parts = payload.split('|');
    if (parts.length != 4) return;

    final type = parts[0]; // "task" or "medicine"
    final clusterId = parts[1];
    final docId = parts[2];
    final currentSnoozeCount = int.tryParse(parts[3]) ?? 0;

    final firestore = FirebaseFirestore.instance;
    final docRef = firestore
        .collection('elderClusters')
        .doc(clusterId)
        .collection(type == 'medicine' ? 'medicines' : 'tasks')
        .doc(docId);

    if (response.actionId == 'done' || response.actionId == null) {
      // Mark as done
      if (type == 'task') {
        await docRef.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Log medicine taken
        final medDoc = await docRef.get();
        if (medDoc.exists) {
            await firestore.collection('elderClusters').doc(clusterId).collection('medicineLogs').add({
                "medicineId": docId,
                "medicineName": medDoc.data()?['name'] ?? 'Medicine',
                "elderId": clusterId, // approximated
                "status": "taken",
                "timestamp": FieldValue.serverTimestamp(),
            });
            // Update lastTaken to prevent re-alarming today
            await docRef.update({'lastTaken': FieldValue.serverTimestamp()});
        }
      }
    } else if (response.actionId == 'snooze') {
      final int newSnoozeCount = currentSnoozeCount + 1;
      
      if (newSnoozeCount > 3) {
        // Max snoozes reached -> Create Alert for Caregiver!
        await firestore.collection('elderClusters').doc(clusterId).collection('alerts').add({
          "type": type == 'medicine' ? "MISSED_MEDICATION" : "MISSED_TASK",
          "triggeredBy": "SYSTEM_SNOOZE_LIMIT",
          "timestamp": FieldValue.serverTimestamp(),
          "resolved": false,
          "resolvedBy": null,
          "description": "Elder missed or snoozed ${type == 'medicine' ? 'medicine' : 'task'} more than 3 times."
        });
        
        // Reset snooze count so it stops scheduling locally
        await docRef.update({'snoozeCount': 0, 'status': 'missed'});
      } else {
        // Update snooze count
        await docRef.update({'snoozeCount': newSnoozeCount});
        
        // Schedule next alarm in 5 minutes!
        await NotificationService().scheduleAlarm(
            id: docId.hashCode,
            title: "$type Snoozed",
            body: "Reminder in 5 minutes!",
            scheduledTime: DateTime.now().add(const Duration(minutes: 5)),
            payload: "$type|$clusterId|$docId|$newSnoozeCount",
        );
      }
    }
  }
}

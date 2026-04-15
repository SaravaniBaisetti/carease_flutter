import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_account.dart';

class PushNotificationService {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  /// Triggers a Firebase Cloud Messaging push notification to all caregivers and family members
  /// for a specific cluster. Completely replaces the Firebase Cloud Function.
  static Future<void> triggerAlertNotification(String clusterId, String alertType, {String elderName = "Your Elder"}) async {
    try {
      final accountCredentials = ServiceAccountCredentials.fromJson(ServiceAccount.serviceAccountJson);
      
      // Get an authenticated HTTP client
      final client = await clientViaServiceAccount(accountCredentials, _scopes);

      // 1. Fetch Cluster details from Firestore
      final firestore = FirebaseFirestore.instance;
      final clusterDoc = await firestore.collection('elderClusters').doc(clusterId).get();
      if (!clusterDoc.exists) return;
      
      final clusterData = clusterDoc.data()!;
      final primaryCaregiverId = clusterData['primaryCaregiverId'] as String?;
      final familyMembers = (clusterData['familyMembers'] as List<dynamic>?)?.cast<String>() ?? [];
      
      // Get elder name if available in the document, else fall back to the provided name
      String finalElderName = elderName;
      if (clusterData.containsKey('elderName') && clusterData['elderName'].toString().isNotEmpty) {
          finalElderName = clusterData['elderName'];
      }
      
      // 2. Gather UIDs to notify (Primary Caregiver + Family)
      final Set<String> uidsToNotify = {};
      if (primaryCaregiverId != null && primaryCaregiverId.isNotEmpty) {
        uidsToNotify.add(primaryCaregiverId);
      }
      uidsToNotify.addAll(familyMembers);
      
      if (uidsToNotify.isEmpty) {
        debugPrint("No caregivers or family members found to notify.");
        return;
      }
      
      // 3. Fetch FCM Tokens for all those UIDs
      List<String> tokens = [];
      for (String uid in uidsToNotify) {
        final userDoc = await firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
           final userTokens = (userDoc.data()!['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [];
           tokens.addAll(userTokens);
        }
      }
      
      if (tokens.isEmpty) {
        debugPrint("No FCM tokens found for contacts.");
        return;
      }
      
      // 4. Determine Notification Content
      String title = "🚨 EMERGENCY SOS";
      String body = "\$finalElderName has triggered an SOS alert! Tap to view live location.";
      
      if (alertType == "CALL_REQUEST") {
        title = "📞 Incoming Call Request";
        body = "\$finalElderName is trying to call you. Please call them back immediately.";
      } else if (alertType == "MISSED_MEDICATION") {
        title = "⚠️ Missed Medication";
        body = "\$finalElderName snoozed their medication too many times. Please check in on them.";
      } else if (alertType == "MISSED_TASK") {
        title = "⚠️ Missed Task";
        body = "\$finalElderName has missed a scheduled task.";
      }
      
      final accountMap = jsonDecode(ServiceAccount.serviceAccountJson);
      final projectId = accountMap['project_id'];
      final targetUrl = Uri.parse('https://fcm.googleapis.com/v1/projects/\$projectId/messages:send');

      // 5. Send FCM Multicast (FCM HTTP v1 requires looping for individual tokens using HTTP)
      for (String token in tokens) {
        final messagePayload = {
          "message": {
            "token": token,
            "notification": {
              "title": title,
              "body": body,
            },
            "data": {
               "clusterId": clusterId,
               "alertType": alertType,
            },
            "android": {
              "priority": "high",
            },
            "apns": {
              "payload": {
                "aps": {
                  "sound": "default",
                }
              }
            }
          }
        };
        
        final response = await client.post(
          targetUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(messagePayload),
        );
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint("Successfully sent push notification to \$token");
        } else {
            debugPrint("Failed to send push notification: \${response.body}");
        }
      }
      
      // Close HTTP client
      client.close();
      
    } catch (e) {
      debugPrint("Error sending SOS notification: \$e");
    }
  }
}

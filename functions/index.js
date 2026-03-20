const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.onAlertCreated = onDocumentCreated(
  "elderClusters/{clusterId}/alerts/{alertId}",
  async (event) => {
    const alertData = event.data.data();
    if (!alertData) return;

    const clusterId = event.params.clusterId;
    const db = admin.firestore();

    try {
      // 1. Fetch Cluster details
      const clusterDoc = await db.collection("elderClusters").doc(clusterId).get();
      if (!clusterDoc.exists) return;
      const clusterData = clusterDoc.data();

      // Ensure we display elder name securely
      const elderName = clusterData.elderName || "Your Elder";
      const primaryCaregiverId = clusterData.primaryCaregiverId;
      const familyMembers = clusterData.familyMembers || [];

      // 2. Gather UIDs to notify (Caregiver + Family)
      const uidsToNotify = new Set();
      if (primaryCaregiverId) uidsToNotify.add(primaryCaregiverId);
      familyMembers.forEach(uid => uidsToNotify.add(uid));

      if (uidsToNotify.size === 0) {
        console.log("No caregivers or family members found to notify.");
        return;
      }

      // 3. Fetch FCM Tokens
      const tokens = [];
      const userPromises = Array.from(uidsToNotify).map(uid => 
        db.collection("users").doc(uid).get()
      );
      
      const userDocs = await Promise.all(userPromises);
      userDocs.forEach(doc => {
        if (doc.exists) {
          const fcmTokens = doc.data().fcmTokens || [];
          tokens.push(...fcmTokens);
        }
      });

      if (tokens.length === 0) {
        console.log("No FCM tokens found for contacts.");
        return;
      }

      // 4. Determine Notification Content
      let title = "🚨 EMERGENCY SOS";
      let body = `${elderName} has triggered an SOS alert! Tap to view live location.`;

      if (alertData.type === "MISSED_MEDICATION") {
        title = "⚠️ Missed Medication";
        body = `${elderName} snoozed their medication too many times. Please check in on them.`;
      } else if (alertData.type === "MISSED_TASK") {
        title = "⚠️ Missed Task";
        body = `${elderName} has missed a scheduled task.`;
      }

      // 5. Send FCM Multicast
      const message = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          clusterId: clusterId,
          alertId: event.params.alertId,
        },
        tokens: tokens,
        android: {
          priority: "high",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            }
          }
        }
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Successfully sent ${response.successCount} messages. Failed: ${response.failureCount}`);
      
    } catch (e) {
      console.error("Error sending SOS notification:", e);
    }
  }
);

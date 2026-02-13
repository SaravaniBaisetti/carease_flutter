import firebase_admin
from firebase_admin import credentials, firestore
import datetime

# ==============================
# INITIALIZE FIREBASE
# ==============================

cred = credentials.Certificate("firebaseServiceKey_careasenew.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

now = datetime.datetime.now()

# ==============================
# DEFINE IDS
# ==============================

cluster_id = "cluster_123"

caregiver_uid = "caregiver_uid_1"
elder_uid = "elder_uid_1"
nurse_uid = "nurse_uid_1"
family_uid_1 = "family_uid_1"
family_uid_2 = "family_uid_2"

# ==============================
# USERS
# ==============================

users_ref = db.collection("users")

users_data = {
    caregiver_uid: {"name": "Sarvani", "role": "caregiver"},
    elder_uid: {"name": "Elder Bob", "role": "elder"},
    nurse_uid: {"name": "Nurse Alice", "role": "nurse"},
    family_uid_1: {"name": "Family Member 1", "role": "family"},
    family_uid_2: {"name": "Family Member 2", "role": "family"},
}

for uid, data in users_data.items():
    users_ref.document(uid).set({
        "name": data["name"],
        "email": f"{uid}@example.com",
        "phone": "+91xxxx",
        "role": data["role"],
        "elderClusterId": cluster_id,
        "createdAt": now,
        "profileImageUrl": "",
        "isActive": True
    })

print("✅ Users created")

# ==============================
# ELDER CLUSTER
# ==============================

db.collection("elderClusters").document(cluster_id).set({
    "elderId": elder_uid,
    "primaryCaregiverId": caregiver_uid,
    "nurseId": nurse_uid,
    "familyMembers": [family_uid_1, family_uid_2],
    "createdAt": now,
    "status": "active"
})

print("✅ Elder cluster created")

# ==============================
# CLUSTER MEMBERS (SCALABLE)
# ==============================

cluster_members = db.collection("clusterMembers")

for uid, data in users_data.items():
    cluster_members.document(f"{cluster_id}_{uid}").set({
        "clusterId": cluster_id,
        "userId": uid,
        "role": data["role"]
    })

print("✅ clusterMembers created")

# ==============================
# MEDICINES
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("medicines").document("medicine_1").set({
        "name": "Paracetamol",
        "dosage": "500mg",
        "frequency": "2 times daily",
        "timeSlots": ["08:00", "20:00"],
        "createdBy": caregiver_uid,
        "isActive": True,
        "createdAt": now
    })

print("✅ Medicine added")

# ==============================
# MEDICINE LOGS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("medicineLogs").document("log_1").set({
        "medicineId": "medicine_1",
        "scheduledTime": now,
        "takenAt": None,
        "status": "missed",
        "confirmedBy": None,
        "autoDetected": True,
        "createdAt": now
    })

print("✅ MedicineLogs added")

# ==============================
# APPOINTMENTS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("appointments").document("appointment_1").set({
        "doctorName": "Dr. Rao",
        "specialization": "General Physician",
        "hospital": "Apollo",
        "dateTime": now,
        "createdBy": caregiver_uid,
        "assignedCaregiver": caregiver_uid,
        "status": "upcoming",
        "appointmentSummary": "Routine checkup",
        "appointmentDetails": {
            "symptomsDiscussed": "Headache",
            "diagnosis": "Mild Viral",
            "prescriptionChanges": "Rest + Medication",
            "doctorNotes": "Hydrate well"
        },
        "createdAt": now,
        "updatedAt": now
    })

print("✅ Appointment added")

# ==============================
# TASKS + CAREGIVER TASK PROJECTION
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("tasks").document("task_1").set({
        "title": "Morning Walk",
        "assignedTo": caregiver_uid,
        "status": "pending",
        "dueTime": now,
        "createdBy": caregiver_uid,
        "clusterId": cluster_id,
        "createdAt": now
    })

db.collection("caregiverTasks").document("task_1").set({
    "caregiverId": caregiver_uid,
    "clusterId": cluster_id,
    "title": "Morning Walk",
    "status": "pending",
    "dueTime": now,
    "createdAt": now
})

print("✅ Tasks added")

# ==============================
# ALERTS + ESCALATION LOGS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("alerts").document("alert_1").set({
        "type": "SOS",
        "triggeredBy": elder_uid,
        "timestamp": now,
        "resolved": False,
        "resolvedBy": None
    })

db.collection("elderClusters").document(cluster_id) \
    .collection("escalationLogs").document("esc_1").set({
        "alertId": "alert_1",
        "level": 1,
        "escalatedTo": caregiver_uid,
        "escalatedAt": now,
        "acknowledged": False
    })

print("✅ Alerts + Escalation logs added")

# ==============================
# ACTIVITY LOGS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("activityLogs").document("activity_1").set({
        "type": "app_open",
        "triggeredBy": elder_uid,
        "timestamp": now
    })

print("✅ ActivityLogs added")

# ==============================
# AUDIT LOGS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("auditLogs").document("audit_1").set({
        "actionType": "task_created",
        "performedBy": caregiver_uid,
        "role": "caregiver",
        "timestamp": now,
        "referenceId": "task_1"
    })

print("✅ AuditLogs added")

# ==============================
# DAILY SUMMARY
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("dailySummaries").document("2026-02-12").set({
        "medicinesTaken": 1,
        "medicinesMissed": 1,
        "tasksCompleted": 0,
        "generatedAt": now
    })

print("✅ Daily summary added")

# ==============================
# VOICE COMMAND LOGS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("voiceCommandLogs").document("voice_1").set({
        "command": "Call caregiver",
        "interpretedIntent": "call_primary_caregiver",
        "confidenceScore": 0.93,
        "executed": True,
        "timestamp": now
    })

print("✅ Voice command logs added")

# ==============================
# NOTIFICATIONS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("notifications").document("notif_1").set({
        "type": "medicine_reminder",
        "recipientUid": caregiver_uid,
        "sentAt": now,
        "delivered": True,
        "read": False
    })

print("✅ Notifications added")

# ==============================
# HEALTH METRICS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("healthMetrics").document("metric_1").set({
        "type": "blood_pressure",
        "value": "120/80",
        "recordedBy": nurse_uid,
        "recordedAt": now
    })

print("✅ Health metrics added")

# ==============================
# CONFIG COLLECTIONS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("inactivityConfig").document("settings").set({
        "inactivityThresholdMinutes": 180,
        "autoEscalationEnabled": True
    })

db.collection("elderClusters").document(cluster_id) \
    .collection("escalationConfig").document("settings").set({
        "level1DelayMinutes": 5,
        "level2DelayMinutes": 10,
        "level3DelayMinutes": 20
    })

print("✅ Configurations added")

# ==============================
# CHECKINS
# ==============================

db.collection("elderClusters").document(cluster_id) \
    .collection("checkins").document("checkin_1").set({
        "mood": "good",
        "notes": "Feeling fine",
        "submittedAt": now
    })

print("✅ Check-in added")

print("\n🔥 FULL MVP Firestore structure successfully created!")

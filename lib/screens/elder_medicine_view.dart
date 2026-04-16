import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_colors.dart';
import 'elder_dashboard.dart';

class ElderMedicineView extends StatefulWidget {
  final String clusterId;

  const ElderMedicineView({super.key, required this.clusterId});

  @override
  State<ElderMedicineView> createState() => _ElderMedicineViewState();
}

class _ElderMedicineViewState extends State<ElderMedicineView> {
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _logMedicine(String medicineId, String medicineName, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('medicineLogs')
          .add({
        "medicineId": medicineId,
        "medicineName": medicineName,
        "elderId": user!.uid,
        "status": status, // "taken" or "skipped"
        "timestamp": FieldValue.serverTimestamp(),
      });
      
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('medicines')
          .doc(medicineId)
          .update({
        'lastTaken': FieldValue.serverTimestamp(),
        'lastStatus': status,
        'snoozeCount': 0,
        'snoozedUntil': FieldValue.delete(),
      });

      if (status == 'skipped') {
        await FirebaseFirestore.instance.collection('elderClusters').doc(widget.clusterId).collection('alerts').add({
           "type": "MISSED_MEDICATION",
           "triggeredBy": widget.clusterId,
           "timestamp": FieldValue.serverTimestamp(),
           "resolved": false,
           "resolvedBy": null,
           "description": "Elder specifically skipped medicine '$medicineName'."
        });
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ElderDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('failed_log_medicine')} ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(tr('my_medicines_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('elderClusters')
            .doc(widget.clusterId)
            .collection('medicines')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allMedicines = snapshot.data?.docs ?? [];
          
          final medicines = allMedicines.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final recType = data['recurrenceType'] ?? 'daily';
            final recDays = data['selectedDays'] as List<dynamic>? ?? [];
            if (recType == 'specific_days') {
              final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final todayStr = weekDays[DateTime.now().weekday - 1];
              return recDays.contains(todayStr);
            }
            return true;
          }).toList();

          if (medicines.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.health_and_safety, size: 80, color: Colors.blueAccent),
                  ).animate().scale(curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  Text(
                    tr('no_medicines_scheduled'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ).animate().fade(delay: 200.ms).slideY(),
                  const SizedBox(height: 8),
                  Text(
                    tr('all_caught_up_meds'),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ).animate().fade(delay: 300.ms).slideY(),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: medicines.length,
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              final medId = medicines[index].id;
              final medData = medicines[index].data() as Map<String, dynamic>;
              final locale = context.locale.languageCode;
              
              // Helper to convert 24h/Timestamp to 12h for UI display
              String formatTime(dynamic timeData) {
                if (timeData is Timestamp) {
                  return TimeOfDay.fromDateTime(timeData.toDate()).format(context);
                } else if (timeData is String) {
                  try {
                    final parts = timeData.split(':');
                    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])).format(context);
                  } catch(e) { return timeData; }
                }
                return timeData.toString();
              }
              
              final timeSlots = (medData['timeSlots'] as List<dynamic>?)?.map((t) => formatTime(t)).join(', ') ?? tr('no_slots');
              final medName = (medData['nameTranslations'] as Map<String, dynamic>?)?[locale] ?? medData['name'] ?? tr('unknown_medicine');
              final dosageTx = (medData['dosageTranslations'] as Map<String, dynamic>?)?[locale] ?? medData['dosage'] ?? tr('not_applicable');
              
              final snoozedUntil = medData['snoozedUntil'] as Timestamp?;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.medication_liquid_rounded, color: Colors.blueAccent, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  medName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text('${tr('dosage_prefix')}$dosageTx', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
                              ]
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_filled, color: Colors.grey.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(timeSlots, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                            ),
                          ],
                        ),
                      ),
                      if (snoozedUntil != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                          child: StreamBuilder(
                            stream: Stream.periodic(const Duration(seconds: 1)),
                            builder: (context, snapshot) {
                              final remaining = snoozedUntil.toDate().difference(DateTime.now());
                              if (remaining.isNegative) {
                                return Text(tr('ringing_soon'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                              }
                              final m = remaining.inMinutes;
                              final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer, color: Colors.deepOrange, size: 20),
                                  const SizedBox(width: 8),
                                  Text('${tr('snooze_timer_prefix')}$m:$s', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _logMedicine(medId, medName, 'taken'),
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(tr('took_it_btn'), style: const TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.oliveGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _logMedicine(medId, medName, 'skipped'),
                              icon: const Icon(Icons.cancel_outlined),
                              label: Text(tr('skipped_btn'), style: const TextStyle(fontSize: 16)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.redAccent, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ).animate().fade(duration: 400.ms).slideX(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }
}


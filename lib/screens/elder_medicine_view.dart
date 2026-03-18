import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged \$medicineName as \$status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log medicine: \${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('My Medicines', style: TextStyle(fontWeight: FontWeight.bold)),
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
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final medicines = snapshot.data?.docs ?? [];

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
                  const Text(
                    'No medicines scheduled',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ).animate().fade(delay: 200.ms).slideY(),
                  const SizedBox(height: 8),
                  const Text(
                    'You are all caught up!',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
              final timeSlots = (medData['timeSlots'] as List<dynamic>?)?.join(', ') ?? 'No slots';
              final medName = medData['name'] ?? 'Unknown Medicine';

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
                                Text('Dosage: ${medData["dosage"] ?? "N/A"}', style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
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
                            Text(timeSlots, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _logMedicine(medId, medName, 'taken'),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Took It', style: TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
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
                              label: const Text('Skipped', style: TextStyle(fontSize: 16)),
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


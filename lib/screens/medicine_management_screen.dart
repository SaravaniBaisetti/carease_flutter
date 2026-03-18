import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicineManagementScreen extends StatefulWidget {
  final String clusterId;

  const MedicineManagementScreen({super.key, required this.clusterId});

  @override
  State<MedicineManagementScreen> createState() => _MedicineManagementScreenState();
}

class _MedicineManagementScreenState extends State<MedicineManagementScreen> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _timeSlotsController = TextEditingController(); // e.g. "08:00, 20:00"

  bool isAdding = false;

  Future<void> _addMedicine() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => isAdding = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Parse time slots by comma
      List<String> timeSlots = _timeSlotsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('medicines')
          .add({
        "name": _nameController.text.trim(),
        "dosage": _dosageController.text.trim(),
        "frequency": _frequencyController.text.trim(),
        "timeSlots": timeSlots,
        "createdBy": user!.uid,
        "isActive": true,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine added successfully!')),
        );
        _nameController.clear();
        _dosageController.clear();
        _frequencyController.clear();
        _timeSlotsController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add medicine: \${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => isAdding = false);
  }

  void _showAddMedicineDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Medicine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Medicine Name (e.g., Paracetamol)'),
                ),
                TextField(
                  controller: _dosageController,
                  decoration: const InputDecoration(labelText: 'Dosage (e.g., 500mg)'),
                ),
                TextField(
                  controller: _frequencyController,
                  decoration: const InputDecoration(labelText: 'Frequency (e.g., 2 times daily)'),
                ),
                TextField(
                  controller: _timeSlotsController,
                  decoration: const InputDecoration(labelText: 'Time Slots (comma separated, e.g., 08:00, 20:00)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addMedicine();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Medicines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddMedicineDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('elderClusters')
            .doc(widget.clusterId)
            .collection('medicines')
            .orderBy('createdAt', descending: true)
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
            return const Center(
              child: Text(
                'No medicines added yet.\\nTap + to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: medicines.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final medData = medicines[index].data() as Map<String, dynamic>;
              final timeSlots = (medData['timeSlots'] as List<dynamic>?)?.join(', ') ?? 'No slots';
              
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.medication, color: Colors.blue, size: 36),
                  title: Text(medData['name'] ?? 'Unknown Medicine', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dosage: ${medData["dosage"] ?? "N/A"}'),
                      Text('Frequency: ${medData["frequency"] ?? "N/A"}'),
                      Text('Times: \$timeSlots'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      // Confirm delete
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Medicine?'),
                          content: const Text('Are you sure you want to remove this medicine from the schedule?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true), 
                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await FirebaseFirestore.instance
                            .collection('elderClusters')
                            .doc(widget.clusterId)
                            .collection('medicines')
                            .doc(medicines[index].id)
                            .delete();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicine deleted')));
                          }
                        } catch(e) {
                          if(mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
                          }
                        }
                      }
                    },
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMedicineDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
    );
  }
}

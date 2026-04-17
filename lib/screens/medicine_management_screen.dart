import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/translation_service.dart';

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
  List<String> _selectedTimeSlots = [];

  String _recurrenceType = 'daily';
  List<String> _selectedDays = [];
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool isAdding = false;

  Future<void> _addMedicine() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => isAdding = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final translationService = TranslationService();

      final now = DateTime.now();
      final List<Timestamp> tsList = _selectedTimeSlots.map((ts) {
        final parts = ts.split(':');
        return Timestamp.fromDate(DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1])));
      }).toList();

      final nameTranslations = await translationService.translateToAllLocales(_nameController.text.trim());
      final dosageTranslations = await translationService.translateToAllLocales(_dosageController.text.trim());
      final frequencyTranslations = await translationService.translateToAllLocales(_frequencyController.text.trim());

      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('medicines')
          .add({
        "name": _nameController.text.trim(),
        "nameTranslations": nameTranslations,
        "dosage": _dosageController.text.trim(),
        "dosageTranslations": dosageTranslations,
        "frequency": _frequencyController.text.trim(),
        "frequencyTranslations": frequencyTranslations,
        "timeSlots": tsList,
        "recurrenceType": _recurrenceType,
        "selectedDays": _selectedDays,
        "createdBy": user!.uid,
        "isActive": true,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('medicine_added_success'))),
        );
        _nameController.clear();
        _dosageController.clear();
        _frequencyController.clear();
        _selectedTimeSlots.clear();
        _recurrenceType = 'daily';
        _selectedDays.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('failed_to_add_medicine')} ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => isAdding = false);
  }

  void _addTimeSlot(StateSetter setDialogState) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final String timeStr = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      if (!_selectedTimeSlots.contains(timeStr)) {
        setDialogState(() {
          _selectedTimeSlots.add(timeStr);
        });
      }
    }
  }

  void _showAddMedicineDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
          title: Text(tr('add_new_medicine_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: tr('med_name_label')),
                ),
                TextField(
                  controller: _dosageController,
                  decoration: InputDecoration(labelText: tr('dosage_label')),
                ),
                TextField(
                  controller: _frequencyController,
                  decoration: InputDecoration(labelText: tr('frequency_label')),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _recurrenceType,
                  decoration: InputDecoration(labelText: tr('recurrence_label')),
                  items: [
                    DropdownMenuItem(value: 'daily', child: Text(tr('recurrence_daily'))),
                    DropdownMenuItem(value: 'specific_days', child: Text(tr('recurrence_specific_days'))),
                    DropdownMenuItem(value: 'single', child: Text(tr('recurrence_single'))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        _recurrenceType = val;
                      });
                    }
                  },
                ),
                if (_recurrenceType == 'specific_days') ...[
                  const SizedBox(height: 16),
                  Text(tr('select_days_label'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: _weekDays.map((day) {
                      final isSelected = _selectedDays.contains(day);
                      return FilterChip(
                        label: Text(tr('day_$day')),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              _selectedDays.add(day);
                            } else {
                              _selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Text(tr('time_slots_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: _selectedTimeSlots.map((ts) => Chip(
                    label: Text(ts),
                    onDeleted: () {
                      setDialogState(() {
                        _selectedTimeSlots.remove(ts);
                      });
                    },
                  )).toList(),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addTimeSlot(setDialogState),
                  icon: const Icon(Icons.add_alarm),
                  label: Text(tr('add_time_slot_btn')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addMedicine();
              },
              child: Text(tr('save_btn')),
            ),
          ],
        );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('manage_medicines_title')),
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final medicines = snapshot.data?.docs ?? [];

          if (medicines.isEmpty) {
            return Center(
              child: Text(
                tr('no_medicines_added'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: medicines.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final medData = medicines[index].data() as Map<String, dynamic>;
              final locale = context.locale.languageCode;
              
              final nameTx = (medData['nameTranslations'] as Map<String, dynamic>?)?[locale] ?? medData['name'] ?? tr('unknown_medicine');
              final dosageTx = (medData['dosageTranslations'] as Map<String, dynamic>?)?[locale] ?? medData['dosage'] ?? 'N/A';
              final frequencyTx = (medData['frequencyTranslations'] as Map<String, dynamic>?)?[locale] ?? medData['frequency'] ?? 'N/A';
              
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
              final recType = medData['recurrenceType'] ?? 'daily';
              final recDays = (medData['selectedDays'] as List<dynamic>?)?.join(', ') ?? '';
              
              String recurrenceText = tr('recurrence_$recType');
              if (recType == 'specific_days' && recDays.isNotEmpty) {
                 recurrenceText += ' ($recDays)';
              }

              final lastStatus = medData['lastStatus'];
              final lastTaken = medData['lastTaken'] as Timestamp?;
              final snoozedUntil = medData['snoozedUntil'] as Timestamp?;
              final snoozeCount = medData['snoozeCount'] ?? 0;
              
              bool isToday(DateTime? date) {
                if (date == null) return false;
                final now = DateTime.now();
                return date.year == now.year && date.month == now.month && date.day == now.day;
              }
              
              bool isSnoozedActive = snoozedUntil != null && snoozedUntil.toDate().isAfter(DateTime.now());
              
              String statusText = tr('pending');
              Color statusColor = Colors.grey.shade700;
              IconData statusIcon = Icons.pending_actions;
              
              if (isSnoozedActive) {
                 statusText = '${tr('snoozed_until')} ${TimeOfDay.fromDateTime(snoozedUntil.toDate()).format(context)} ($snoozeCount/3)';
                 statusColor = Colors.orange;
                 statusIcon = Icons.snooze;
              } else if (lastStatus != null && isToday(lastTaken?.toDate())) {
                 final timeStr = lastTaken != null ? TimeOfDay.fromDateTime(lastTaken.toDate()).format(context) : '';
                 if (lastStatus == 'taken') {
                    statusText = '${tr('taken_at')} $timeStr';
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                 } else if (lastStatus == 'skipped') {
                    statusText = '${tr('skipped_at')} $timeStr';
                    statusColor = Colors.red;
                    statusIcon = Icons.cancel;
                 } else {
                    statusText = '$lastStatus at $timeStr';
                    statusColor = Colors.deepOrange;
                    statusIcon = Icons.info;
                 }
              }
              
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.medication, color: Colors.blue, size: 36),
                  title: Text(nameTx, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${tr('dosage_prefix')} $dosageTx'),
                      Text('${tr('frequency_prefix')} $frequencyTx'),
                      Text('${tr('recurrence_prefix')} $recurrenceText'),
                      Text('${tr('times_prefix')} $timeSlots'),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                             Icon(statusIcon, color: statusColor, size: 16),
                             const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${tr('status_prefix')} $statusText',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      // Confirm delete
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(tr('delete_medicine_title')),
                          content: Text(tr('delete_medicine_desc')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true), 
                              child: Text(tr('delete_btn'), style: const TextStyle(color: Colors.white)),
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
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('medicine_deleted'))));
                          }
                        } catch(e) {
                          if(mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

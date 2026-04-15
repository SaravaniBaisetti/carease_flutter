import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/translation_service.dart';

class TaskManagementScreen extends StatefulWidget {
  final String clusterId;

  const TaskManagementScreen({super.key, required this.clusterId});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueTimeController = TextEditingController();
  DateTime? _selectedDueDateTime;
  
  String _recurrenceType = 'single';
  List<String> _selectedDays = [];
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool isAdding = false;

  Future<void> _addTask() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => isAdding = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final translationService = TranslationService();
      
      final titleTranslations = await translationService.translateToAllLocales(_titleController.text.trim());
      final descriptionText = _descriptionController.text.trim();
      final descriptionTranslations = await translationService.translateToAllLocales(descriptionText);

      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('tasks')
          .add({
        "title": _titleController.text.trim(),
        "titleTranslations": titleTranslations,
        "description": descriptionText,
        "descriptionTranslations": descriptionTranslations,
        "dueTime": _selectedDueDateTime != null ? Timestamp.fromDate(_selectedDueDateTime!) : (_dueTimeController.text.trim().isEmpty ? null : _dueTimeController.text.trim()),
        "status": "pending",
        "recurrenceType": _recurrenceType,
        "selectedDays": _selectedDays,
        "createdBy": user!.uid,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('task_added_success'))),
        );
        _titleController.clear();
        _descriptionController.clear();
        _dueTimeController.clear();
        _selectedDueDateTime = null;
        _recurrenceType = 'single';
        _selectedDays.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('failed_to_add_task')} ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => isAdding = false);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        _selectedDueDateTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        // format as HH:mm zero padded for proper sorting and parsing
        final hr = picked.hour.toString().padLeft(2, '0');
        final mn = picked.minute.toString().padLeft(2, '0');
        _dueTimeController.text = "$hr:$mn";
      });
    }
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
          title: Text(tr('assign_new_task_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: tr('task_title_label')),
                ),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(labelText: tr('description_label')),
                  maxLines: 3,
                ),
                TextField(
                  controller: _dueTimeController,
                  readOnly: true,
                  onTap: () => _selectTime(context),
                  decoration: InputDecoration(
                    labelText: tr('due_time_label'),
                    suffixIcon: const Icon(Icons.access_time),
                  ),
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
                _addTask();
              },
              child: Text(tr('assign_task_btn')),
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
        title: Text(tr('manage_tasks_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            onPressed: _showAddTaskDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('elderClusters')
            .doc(widget.clusterId)
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data?.docs ?? [];

          if (tasks.isEmpty) {
            return Center(
              child: Text(
                tr('no_tasks_assigned'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: tasks.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final taskData = tasks[index].data() as Map<String, dynamic>;
              final locale = context.locale.languageCode;
              
              final titleTx = (taskData['titleTranslations'] as Map<String, dynamic>?)?[locale] ?? taskData['title'] ?? tr('unknown_task');
              final descTx = (taskData['descriptionTranslations'] as Map<String, dynamic>?)?[locale] ?? taskData['description'] ?? '';

              final isCompleted = taskData['status'] == 'completed';
              final isMissed = taskData['status'] == 'missed';
              
              String dueTimeDisplay = 'No Time';
              if (taskData['dueTime'] is Timestamp) {
                final dt = (taskData['dueTime'] as Timestamp).toDate();
                dueTimeDisplay = TimeOfDay.fromDateTime(dt).format(context);
              } else if (taskData['dueTime'] != null) {
                dueTimeDisplay = taskData['dueTime'].toString(); // fallback for old data
              }

              final recType = taskData['recurrenceType'] ?? 'single';
              final recDays = (taskData['selectedDays'] as List<dynamic>?)?.join(', ') ?? '';
              
              String recurrenceText = tr('recurrence_$recType');
              if (recType == 'specific_days' && recDays.isNotEmpty) {
                 recurrenceText += ' ($recDays)';
              }
              
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: Icon(
                    isCompleted ? Icons.check_circle : (isMissed ? Icons.cancel : Icons.pending_actions), 
                    color: isCompleted ? Colors.green : (isMissed ? Colors.red : Colors.orange), 
                    size: 32
                  ),
                  title: Text(titleTx, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (taskData['dueTime'] != null)
                        Text('⏰ ${tr('due_prefix')} $dueTimeDisplay', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        
                      Text('${tr('recurrence_prefix')} $recurrenceText'),
                        
                      if (isMissed)
                        Text(tr('status_missed'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      if (isCompleted && taskData['lastStatus'] != null)
                        Text('${tr('status_colon')} ${taskData['lastStatus']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),

                      if (descTx.toString().isNotEmpty)
                        Text(descTx),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                        .collection('elderClusters')
                        .doc(widget.clusterId)
                        .collection('tasks')
                        .doc(tasks[index].id)
                        .delete();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        icon: const Icon(Icons.add),
        label: Text(tr('assign_task_btn')),
      ),
    );
  }
}

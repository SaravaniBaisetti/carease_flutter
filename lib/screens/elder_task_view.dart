import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_colors.dart';

class ElderTaskView extends StatefulWidget {
  final String clusterId;

  const ElderTaskView({super.key, required this.clusterId});

  @override
  State<ElderTaskView> createState() => _ElderTaskViewState();
}

class _ElderTaskViewState extends State<ElderTaskView> {
  Future<void> _completeTask(String taskId, String recurrenceType) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (recurrenceType == 'single') {
        updateData["status"] = "completed";
      }
      
      updateData["lastCompleted"] = FieldValue.serverTimestamp();
      updateData["completedAt"] = FieldValue.serverTimestamp(); // keep for history

      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('tasks')
          .doc(taskId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('task_marked_done'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('failed_update_task')} ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(tr('my_daily_tasks_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
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

          final allTasks = snapshot.data?.docs ?? [];
          
          final tasks = allTasks.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final recType = data['recurrenceType'] ?? 'single';
            final recDays = data['selectedDays'] as List<dynamic>? ?? [];
            if (recType == 'specific_days') {
              final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final todayStr = weekDays[DateTime.now().weekday - 1];
              return recDays.contains(todayStr);
            }
            return true;
          }).toList();

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.done_all_rounded, size: 80, color: Colors.green),
                  ).animate().scale(curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  Text(
                    tr('all_caught_up_tasks'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ).animate().fade(delay: 200.ms).slideY(),
                  const SizedBox(height: 8),
                  Text(
                    tr('no_tasks_assigned'),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ).animate().fade(delay: 300.ms).slideY(),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: tasks.length,
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              final taskId = tasks[index].id;
              final taskData = tasks[index].data() as Map<String, dynamic>;
              final locale = context.locale.languageCode;
              
              final titleTx = (taskData['titleTranslations'] as Map<String, dynamic>?)?[locale] ?? taskData['title'] ?? tr('unknown_task');
              final descTx = (taskData['descriptionTranslations'] as Map<String, dynamic>?)?[locale] ?? taskData['description'] ?? '';
              
              final recType = taskData['recurrenceType'] ?? 'single';
              final lastCompleted = taskData['lastCompleted'] as Timestamp?;
              
              bool isToday(DateTime? date) {
                if (date == null) return false;
                final now = DateTime.now();
                return date.year == now.year && date.month == now.month && date.day == now.day;
              }

              final isCompleted = taskData['status'] == 'completed' || isToday(lastCompleted?.toDate());
              
              String displayTime = '';
              final dueTimeData = taskData['dueTime'];
              if (dueTimeData is Timestamp) {
                displayTime = TimeOfDay.fromDateTime(dueTimeData.toDate()).format(context);
              } else if (dueTimeData is String && dueTimeData.isNotEmpty) {
                try {
                  final parts = dueTimeData.split(':');
                  displayTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])).format(context);
                } catch(e) { displayTime = dueTimeData; }
              }
              final snoozedUntil = taskData['snoozedUntil'] as Timestamp?;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.grey.shade100 : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: isCompleted ? null : Border.all(color: Colors.green.withOpacity(0.3), width: 2),
                  boxShadow: isCompleted ? [] : [
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
                          Icon(
                            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, 
                            color: isCompleted ? Colors.green : Colors.grey.shade600, 
                            size: 32
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              titleTx,
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 20,
                                decoration: isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                                color: isCompleted ? Colors.grey : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (displayTime.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                  Text(
                                    displayTime, 
                                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (snoozedUntil != null && !isCompleted) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0),
                          child: StreamBuilder(
                            stream: Stream.periodic(const Duration(seconds: 1)),
                            builder: (context, snapshot) {
                              final remaining = snoozedUntil.toDate().difference(DateTime.now());
                              if (remaining.isNegative) {
                                return Text(tr('ringing_soon'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                              }
                              final m = remaining.inMinutes;
                              final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
                              return Text('⏳ ${tr('snooze_timer_prefix')}$m:$s', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold));
                            },
                          ),
                        ),
                      ],
                      if (descTx.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0),
                          child: Text(
                            descTx, 
                            style: TextStyle(
                              fontSize: 16,
                              color: isCompleted ? Colors.grey : Colors.black87,
                              height: 1.4,
                            )
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (!isCompleted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _completeTask(taskId, recType),
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(tr('mark_as_done_btn'), style: const TextStyle(fontSize: 18)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.oliveGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16)
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(tr('completed'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
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


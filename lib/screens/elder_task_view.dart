import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ElderTaskView extends StatefulWidget {
  final String clusterId;

  const ElderTaskView({super.key, required this.clusterId});

  @override
  State<ElderTaskView> createState() => _ElderTaskViewState();
}

class _ElderTaskViewState extends State<ElderTaskView> {
  Future<void> _completeTask(String taskId) async {
    try {
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('tasks')
          .doc(taskId)
          .update({
        "status": "completed",
        "completedAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task marked as Done! Great job!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: \${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('My Daily Tasks', style: TextStyle(fontWeight: FontWeight.bold)),
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
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data?.docs ?? [];

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
                  const Text(
                    'All caught up!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ).animate().fade(delay: 200.ms).slideY(),
                  const SizedBox(height: 8),
                  const Text(
                    'No tasks assigned right now.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
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
              final isCompleted = taskData['status'] == 'completed';

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
                              taskData['title'] ?? 'Unknown Task',
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
                      if (taskData['dueTime'] != null && taskData['dueTime'].toString().isNotEmpty) ...[
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
                                  taskData['dueTime'], 
                                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (taskData['description'] != null && taskData['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 48.0),
                          child: Text(
                            taskData['description'], 
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
                            onPressed: () => _completeTask(taskId),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Mark as Done', style: TextStyle(fontSize: 18)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
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
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, color: Colors.green),
                              SizedBox(width: 8),
                              Text("Completed", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
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


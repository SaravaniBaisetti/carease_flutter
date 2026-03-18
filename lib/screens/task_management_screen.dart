import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskManagementScreen extends StatefulWidget {
  final String clusterId;

  const TaskManagementScreen({super.key, required this.clusterId});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueTimeController = TextEditingController(); // e.g., "09:00" or "14:30"
  bool isAdding = false;

  Future<void> _addTask() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => isAdding = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('tasks')
          .add({
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "dueTime": _dueTimeController.text.trim().isEmpty ? null : _dueTimeController.text.trim(),
        "status": "pending",
        "createdBy": user!.uid,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added successfully!')),
        );
        _titleController.clear();
        _descriptionController.clear();
        _dueTimeController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add task: \${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => isAdding = false);
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Task Title (ex. Doctor Visit)'),
                ),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                TextField(
                  controller: _dueTimeController,
                  decoration: const InputDecoration(labelText: 'Due Time (ex. 09:00 or 14:30)'),
                  keyboardType: TextInputType.datetime,
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
                _addTask();
              },
              child: const Text('Assign Task'),
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
        title: const Text('Manage Tasks'),
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
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data?.docs ?? [];

          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                'No tasks assigned.\\nTap + to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: tasks.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final taskData = tasks[index].data() as Map<String, dynamic>;
              final isCompleted = taskData['status'] == 'completed';
              
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: Icon(
                    isCompleted ? Icons.check_circle : Icons.pending_actions, 
                    color: isCompleted ? Colors.green : Colors.orange, 
                    size: 32
                  ),
                  title: Text(taskData['title'] ?? 'Unknown Task', style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (taskData['dueTime'] != null)
                        Text('⏰ ${taskData['dueTime']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      if (taskData['description'] != null && taskData['description'].toString().isNotEmpty)
                        Text(taskData['description']),
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
        label: const Text('Assign Task'),
      ),
    );
  }
}

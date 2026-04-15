import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

class CheckinHistoryScreen extends StatefulWidget {
  final String clusterId;
  final String elderName;

  const CheckinHistoryScreen({
    super.key,
    required this.clusterId,
    required this.elderName,
  });

  @override
  State<CheckinHistoryScreen> createState() => _CheckinHistoryScreenState();
}

class _CheckinHistoryScreenState extends State<CheckinHistoryScreen> {
  // Helper to map mood strings to emojis and colors
  Map<String, dynamic> _getMoodData(String mood) {
    switch (mood) {
      case 'Great':
        return {'emoji': '😊', 'color': Colors.green};
      case 'Okay':
        return {'emoji': '😐', 'color': Colors.orange};
      case 'Not Well':
        return {'emoji': '🤕', 'color': Colors.red};
      default:
        return {'emoji': '❓', 'color': Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('${widget.elderName}${tr('checkin_history_title')}'),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('elderClusters')
            .doc(widget.clusterId)
            .collection('healthLogs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data?.docs ?? [];

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade400).animate().scale(),
                  const SizedBox(height: 16),
                  Text(
                    tr('no_checkin_history'),
                    style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
                  ).animate().fade(delay: 200.ms),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;
              final moodStr = data['mood'] ?? 'Unknown';
              final details = data['details']?.toString();
              
              final timestamp = data['timestamp'] as Timestamp?;
              final timeString = timestamp != null 
                  ? DateFormat('MMM d, yyyy • h:mm a').format(timestamp.toDate()) 
                  : tr('unknown_date');

              final moodData = _getMoodData(moodStr);
              final emoji = moodData['emoji'] as String;
              final color = moodData['color'] as MaterialColor;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 32)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  moodStr, 
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.shade800),
                                ),
                                Text(
                                  timeString, 
                                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (details != null && details.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                details,
                                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Text(
                                tr('no_extra_details'),
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0, delay: (index * 50).ms);
            },
          );
        },
      ),
    );
  }
}

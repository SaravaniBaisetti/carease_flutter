import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'sos_map_screen.dart';

class AlertsDashboard extends StatefulWidget {
  final String clusterId;

  const AlertsDashboard({super.key, required this.clusterId});

  @override
  State<AlertsDashboard> createState() => _AlertsDashboardState();
}

class _AlertsDashboardState extends State<AlertsDashboard> {
  
  Future<void> _resolveAlert(String alertId) async {
    try {
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('alerts')
          .doc(alertId)
          .update({
        "resolved": true,
      });
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert marked as resolved.')),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve alert: \${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Active Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('elderClusters')
            .doc(widget.clusterId)
            .collection('alerts')
            .where('resolved', isEqualTo: false) // Only show active alerts
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: \${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data?.docs ?? [];

          if (alerts.isEmpty) {
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
                    child: const Icon(Icons.check_circle, size: 80, color: Colors.green),
                  ).animate().scale(curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  const Text(
                    'All clear!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ).animate().fade(delay: 200.ms).slideY(),
                  const SizedBox(height: 8),
                  const Text(
                    'There are no active alerts right now.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ).animate().fade(delay: 300.ms).slideY(),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: alerts.length,
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              final alertId = alerts[index].id;
              final alertData = alerts[index].data() as Map<String, dynamic>;
              
              final type = alertData['type'] ?? 'Unknown Alert';
              final timestamp = alertData['timestamp'] as Timestamp?;
              final timeString = timestamp != null 
                  ? DateFormat('MMM d, h:mm a').format(timestamp.toDate()) 
                  : 'Unknown time';
              
              bool isSOS = type == 'SOS';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isSOS ? Colors.redAccent.withOpacity(0.5) : Colors.orangeAccent.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: isSOS ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSOS ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSOS ? Icons.warning_amber_rounded : Icons.notifications_active,
                              color: isSOS ? Colors.redAccent : Colors.orangeAccent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.replaceAll('_', ' ') + ' Alert', 
                                  style: TextStyle(
                                    fontSize: 20, 
                                    fontWeight: FontWeight.bold,
                                    color: isSOS ? Colors.red.shade900 : Colors.orange.shade900
                                  )
                                ),
                                const SizedBox(height: 4),
                                Text(timeString, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              alertData['description'] ?? 'Triggered By UID: ${alertData["triggeredBy"] ?? "System"}', 
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 16)
                            ),
                            if (alertData['location'] != null) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${alertData["location"]["latitude"].toStringAsFixed(4)}, ${alertData["location"]["longitude"].toStringAsFixed(4)}',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => SosMapScreen(
                                      clusterId: widget.clusterId,
                                      elderName: 'Elder', // Ideally fetch from profile
                                      alertId: alertId,
                                      isLive: alertData['liveLocationActive'] == true,
                                    )),
                                  );
                                },
                                icon: const Icon(Icons.map),
                                label: const Text("View on Map"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isSOS ? Colors.red.shade700 : Colors.orange.shade700,
                                ),
                              )
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _resolveAlert(alertId),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("Mark as Resolved", style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSOS ? Colors.redAccent : Colors.orangeAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
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


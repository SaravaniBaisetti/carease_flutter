import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
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
          SnackBar(content: Text(tr('alert_resolved_toast'))),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('failed_resolve_alert')} ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          title: Text(tr('alerts_center_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          bottom: TabBar(
            tabs: [
              Tab(text: tr('tab_active')),
              Tab(text: tr('tab_history')),
            ],
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('elderClusters')
              .doc(widget.clusterId)
              .collection('alerts')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allAlerts = snapshot.data?.docs ?? [];
            final activeAlerts = allAlerts.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data != null && data['resolved'] != true;
            }).toList();
            
            final historyAlerts = allAlerts.where((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              return data != null && data['resolved'] == true;
            }).toList();

            return TabBarView(
              children: [
                _buildAlertsList(activeAlerts, isActive: true),
                _buildAlertsList(historyAlerts, isActive: false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAlertsList(List<QueryDocumentSnapshot> alerts, {required bool isActive}) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.check_circle : Icons.history, 
                size: 80, 
                color: isActive ? Colors.green : Colors.grey
              ),
            ).animate().scale(curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              isActive ? tr('all_clear') : tr('no_history'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ).animate().fade(delay: 200.ms).slideY(),
            const SizedBox(height: 8),
            Text(
              isActive ? tr('no_active_alerts_desc') : tr('no_resolved_alerts_desc'),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
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
        
        final type = alertData['type'] ?? tr('unknown_alert');
        final timestamp = alertData['timestamp'] as Timestamp?;
        final timeString = timestamp != null 
            ? DateFormat('MMM d, h:mm a').format(timestamp.toDate()) 
            : tr('unknown_time');
        
        bool isSOS = type == 'SOS';
        final displayType = type.replaceAll('_', ' ');
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isActive 
                  ? (isSOS ? Colors.redAccent.withOpacity(0.5) : Colors.orangeAccent.withOpacity(0.5))
                  : Colors.grey.withOpacity(0.3), 
              width: 2
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: isSOS ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ] : []
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive 
                            ? (isSOS ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1))
                            : Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSOS ? Icons.warning_amber_rounded : Icons.notifications_active,
                        color: isActive 
                            ? (isSOS ? Colors.redAccent : Colors.orangeAccent)
                            : Colors.grey.shade600,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayType + (isActive ? tr('alert_suffix') : tr('resolved_suffix')), 
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold,
                              color: isActive 
                                  ? (isSOS ? Colors.red.shade900 : Colors.orange.shade900)
                                  : Colors.grey.shade800
                            )
                          ),
                          const SizedBox(height: 4),
                          Text(timeString, style: TextStyle(color: isActive ? Colors.grey : Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.grey.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(16)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        alertData['description'] ?? '${tr('triggered_by_uid')} ${alertData["triggeredBy"] ?? tr('system_user')}', 
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
                                isLive: alertData['liveLocationActive'] == true && isActive,
                              )),
                            );
                          },
                          icon: const Icon(Icons.map),
                          label: Text(tr('view_on_map')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isActive ? (isSOS ? Colors.red.shade700 : Colors.orange.shade700) : Colors.grey.shade700,
                          ),
                        )
                      ],
                    ],
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _resolveAlert(alertId),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(tr('mark_as_resolved'), style: const TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSOS ? Colors.redAccent : Colors.orangeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
        ).animate().fade(duration: 400.ms).slideX(begin: 0.1, end: 0);
      },
    );
  }
}


import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'medicine_management_screen.dart';
import 'task_management_screen.dart';
import 'alerts_dashboard.dart';

class ElderDetailScreen extends StatefulWidget {
  final String clusterId;
  final String elderName;

  const ElderDetailScreen({
    super.key,
    required this.clusterId,
    required this.elderName,
  });

  @override
  State<ElderDetailScreen> createState() => _ElderDetailScreenState();
}

class _ElderDetailScreenState extends State<ElderDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? elderProfile;
  bool isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadElderProfile();
  }

  Future<void> _loadElderProfile() async {
    try {
      // First get the cluster to find the elderId
      final clusterDoc = await FirebaseFirestore.instance.collection('elderClusters').doc(widget.clusterId).get();
      final elderId = clusterDoc.data()?['elderId'];

      if (elderId != null) {
        // Fetch elder profile
        final profileDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(elderId)
            .collection('profile')
            .doc(elderId)
            .get();

        if (profileDoc.exists && mounted) {
          setState(() {
            elderProfile = profileDoc.data();
            isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading elder profile: $e');
    } finally {
      if (mounted) setState(() => isLoadingProfile = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.elderName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Tasks"),
            Tab(text: "Medicines"),
            Tab(text: "Alerts"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Overview
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.primary, Colors.teal.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Colors.teal),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.elderName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            if (!isLoadingProfile && elderProfile != null) ...[
                              const SizedBox(height: 4),
                              Text("${elderProfile!['age']} yrs • Blood: ${elderProfile!['bloodGroup']}", style: const TextStyle(color: Colors.white70)),
                              Text("Wt: ${elderProfile!['weight']} • Ht: ${elderProfile!['height']}", style: const TextStyle(color: Colors.white70)),
                            ]
                          ],
                        ),
                      )
                    ],
                  ),
                ).animate().fade().slideY(begin: 0.1),

                const SizedBox(height: 20),
                
                // Medical Info
                if (!isLoadingProfile && elderProfile != null) ...[
                  const Text("Medical Conditions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(elderProfile!['medicalConditions']?.toString().isNotEmpty == true 
                          ? elderProfile!['medicalConditions'] 
                          : "No conditions listed."),
                    ),
                  ).animate().fade(delay: 100.ms),
                  
                  const SizedBox(height: 20),
                  const Text("Emergency Medications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(elderProfile!['emergencyMedication']?.toString().isNotEmpty == true 
                          ? elderProfile!['emergencyMedication'] 
                          : "No emergency medications listed."),
                    ),
                  ).animate().fade(delay: 200.ms),
                ],

                const SizedBox(height: 20),
                // Daily Check-in info
                const Text("Latest Health Check-in", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('elderClusters')
                      .doc(widget.clusterId)
                      .collection('healthLogs')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("No check-ins yet.")));
                    }
                    var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                    String moodEmoji = "😐";
                    if (data['mood'] == 'Great') moodEmoji = "😁";
                    if (data['mood'] == 'Poor') moodEmoji = "😞";

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(moodEmoji, style: const TextStyle(fontSize: 40)),
                            const SizedBox(width: 16),
                            Expanded(child: Text(data['notes']?.toString().isNotEmpty == true ? data['notes'] : "No notes provided.")),
                          ],
                        ),
                      ),
                    );
                  },
                ).animate().fade(delay: 300.ms),
              ],
            ),
          ),
          
          // Tab 2: Tasks
          TaskManagementScreen(clusterId: widget.clusterId),
          
          // Tab 3: Medicines
          MedicineManagementScreen(clusterId: widget.clusterId),
          
          // Tab 4: Alerts
          AlertsDashboard(clusterId: widget.clusterId),
        ],
      ),
    );
  }
}

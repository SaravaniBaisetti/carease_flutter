import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'elder_detail_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class FamilyDashboard extends StatefulWidget {
  const FamilyDashboard({super.key});

  @override
  State<FamilyDashboard> createState() => _FamilyDashboardState();
}

class _FamilyDashboardState extends State<FamilyDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  List<String> clusterIds = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      final data = userDoc.data();
      if (data != null) {
        final ids = data['clusterIds'];
        if (ids is List) {
          clusterIds = List<String>.from(ids);
        }
      }
    } catch (e) {
      debugPrint('Error loading family dashboard: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showJoinClusterDialog() {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Follow an Elder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter the Cluster Invite Code to join their care network.'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isEmpty) return;
              
              Navigator.pop(context);
              setState(() => isLoading = true);
              
              try {
                final clusterId = codeController.text.trim();
                final clusterDoc = await FirebaseFirestore.instance.collection('elderClusters').doc(clusterId).get();
                
                if (!clusterDoc.exists) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Invite Code.')));
                   setState(() => isLoading = false);
                   return;
                }
                
                // Add family member to cluster
                await FirebaseFirestore.instance.collection('elderClusters').doc(clusterId).update({
                  'familyMembers': FieldValue.arrayUnion([user!.uid]),
                });
                
                // Add cluster to user doc
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                  'clusterIds': FieldValue.arrayUnion([clusterId]),
                });
                
                _loadData(); // reload
              } catch (e) {
                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error joining: $e')));
                 setState(() => isLoading = false);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.family_restroom, color: Colors.blue.shade800),
            const SizedBox(width: 8),
            const Text("Family Overview", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen(role: 'family')))
                .then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showJoinClusterDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Follow Elder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade800,
      ).animate().slideY(begin: 1.0, duration: 600.ms),
      body: clusterIds.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.health_and_safety, size: 80, color: Colors.blue.shade300).animate().scale(),
                  const SizedBox(height: 16),
                  Text("You aren't following any elders.", style: TextStyle(fontSize: 18, color: Colors.grey.shade700)).animate().fade(delay: 200.ms),
                  const SizedBox(height: 8),
                  Text("Tap 'Follow Elder' to join a cluster.", style: TextStyle(color: Colors.grey.shade600)).animate().fade(delay: 300.ms),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: clusterIds.length,
                itemBuilder: (context, index) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('elderClusters').doc(clusterIds[index]).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
                      
                      final clusterData = snapshot.data!.data() as Map<String, dynamic>?;
                      if (!snapshot.data!.exists || clusterData == null) {
                        return const SizedBox.shrink(); // Invalid cluster
                      }
                      
                      final elderId = clusterData['elderId'];
                      final clusterId = snapshot.data!.id;

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(elderId).collection('profile').doc(elderId).get(),
                        builder: (context, profileSnapshot) {
                          String elderName = "Loading...";
                          if (profileSnapshot.connectionState == ConnectionState.done) {
                            elderName = (profileSnapshot.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Elder Profiles Missing';
                          }

                          return _buildElderCard(context, clusterId, elderName, elderId)
                            .animate().fade(duration: 400.ms, delay: (index * 100).ms).slideX(begin: 0.1);
                        },
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildElderCard(BuildContext context, String clusterId, String elderName, String elderId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ElderDetailScreen(clusterId: clusterId, elderName: elderName),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.person, color: Colors.blue.shade800, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(elderName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        // Get active SOS status
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('elderClusters')
                              .doc(clusterId)
                              .collection('alerts')
                              .where('resolved', isEqualTo: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Text('Checking safety...', style: TextStyle(color: Colors.grey));
                            
                            if (snapshot.data!.docs.isNotEmpty) {
                              return Row(
                                children: [
                                  const Icon(Icons.warning, color: Colors.red, size: 16),
                                  const SizedBox(width: 4),
                                  Text("${snapshot.data!.docs.length} Active Alert(s)!", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Icon(Icons.safety_check, color: Colors.green.shade600, size: 16),
                                const SizedBox(width: 4),
                                Text("Safe & Secure", style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold)),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.blue.shade300, size: 32),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Tap to view full health & care details", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                    Icon(Icons.analytics, color: Colors.blue.shade400)
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

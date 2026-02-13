import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  String? clusterId;
  Map<String, dynamic>? clusterData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCluster();
  }

  Future<void> loadCluster() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    clusterId = userDoc.data()?['elderClusterId'];

    if (clusterId != null) {
      final clusterDoc = await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(clusterId)
          .get();

      clusterData = clusterDoc.data();
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Caregiver Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Cluster ID: $clusterId"),
            const SizedBox(height: 10),
            Text("Cluster Status: ${clusterData?['status']}"),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Add Elder"),
            ),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Add Family Member"),
            ),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Manage Medicines"),
            ),
          ],
        ),
      ),
    );
  }
}

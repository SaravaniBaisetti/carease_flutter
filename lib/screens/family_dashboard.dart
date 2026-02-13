import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FamilyDashboard extends StatelessWidget {
  const FamilyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Family Dashboard"),
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
          children: [
            Text(
              "Family Monitoring Panel",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text("UID: ${user?.uid ?? "Unknown"}"),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {},
              child: const Text("View Alerts"),
            ),
            ElevatedButton(
              onPressed: () {},
              child: const Text("View Health Metrics"),
            ),
            ElevatedButton(
              onPressed: () {},
              child: const Text("View Appointments"),
            ),
          ],
        ),
      ),
    );
  }
}

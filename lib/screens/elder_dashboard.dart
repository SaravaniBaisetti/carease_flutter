import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'elder_medicine_view.dart';
import 'elder_task_view.dart';
import 'daily_check_in_screen.dart';
import 'login_screen.dart';
import 'sos_active_screen.dart';
import 'profile_screen.dart';
import '../services/alarm_sync_service.dart';

class ElderDashboard extends StatefulWidget {
  const ElderDashboard({super.key});

  @override
  State<ElderDashboard> createState() => _ElderDashboardState();
}

class _ElderDashboardState extends State<ElderDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  bool isSosLoading = false;
  String? clusterId;
  String? caregiverPhone;
  StreamSubscription<Position>? _locationSubscription;
  AlarmSyncService? _alarmSyncService;
  
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _alarmSyncService?.stopSync();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadClusterData();
  }

  Future<void> _loadClusterData() async {
     final elderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      
      final cId = elderDoc.data()?['elderClusterId'];
      
      if (cId != null) {
        // Fetch the caregiver's phone number as the primary emergency contact
        final clusterDoc = await FirebaseFirestore.instance.collection('elderClusters').doc(cId).get();
        final caregiverId = clusterDoc.data()?['primaryCaregiverId'];
        
        if (caregiverId != null) {
          final caregiverDoc = await FirebaseFirestore.instance.collection('users').doc(caregiverId).collection('profile').doc(caregiverId).get();
          if (mounted) {
            setState(() {
              caregiverPhone = caregiverDoc.data()?['phone']; 
            });
          }
        }
      }

      if (mounted) {
        setState(() {
           clusterId = cId;
        });
        
        // Start live sync of alarms once we have clusterId
        _alarmSyncService = AlarmSyncService(clusterId: cId!);
        _alarmSyncService!.startSync();
      }
  }

  Future<void> _callCaregiver() async {
    if (clusterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No cluster assigned.')));
      return;
    }
    
    // Trigger in-app call request
    try {
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(clusterId!)
          .collection('alerts')
          .add({
        "type": "CALL_REQUEST",
        "triggeredBy": user!.uid,
        "timestamp": FieldValue.serverTimestamp(),
        "resolved": false,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calling Caregiver... please wait.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call failed: $e')));
      }
    }
  }

  Future<void> triggerSOS() async {
    setState(() => isSosLoading = true);
    try {
      // 1. Check Permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) throw Exception('Location permissions are permanently denied, we cannot request permissions.');
      }

      // 2. Get Location
      Position position = await Geolocator.getCurrentPosition();

      if (clusterId == null) {
         if (mounted) throw Exception('No cluster assigned.');
      }

      // 3. Create Alert
      final alertRef = await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(clusterId)
          .collection('alerts')
          .add({
        "type": "SOS",
        "triggeredBy": user!.uid,
        "timestamp": FieldValue.serverTimestamp(),
        "resolved": false,
        "resolvedBy": null,
        "liveLocationActive": true,
        "location": {
          "latitude": position.latitude,
          "longitude": position.longitude,
        }
      });

      // 4. Write initial live location
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(clusterId)
          .collection('liveLocation')
          .doc('latest')
          .set({
        "latitude": position.latitude,
        "longitude": position.longitude,
        "timestamp": FieldValue.serverTimestamp(),
        "alertId": alertRef.id,
      });

      // 5. Start live location stream
      _locationSubscription?.cancel();
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10), // Update every 10m movement
      ).listen((Position pos) {
        FirebaseFirestore.instance
            .collection('elderClusters')
            .doc(clusterId)
            .collection('liveLocation')
            .doc('latest')
            .update({
          "latitude": pos.latitude,
          "longitude": pos.longitude,
          "timestamp": FieldValue.serverTimestamp(),
        });
      });

      // Auto-cancel stream after 30 mins as a safety measure
      Future.delayed(const Duration(minutes: 30), () {
        _locationSubscription?.cancel();
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SosActiveScreen(
              clusterId: clusterId!,
              alertId: alertRef.id,
              elderUid: user!.uid,
            ),
          ),
        ).then((_) {
          // When popping back from active screen, ensure stream stops
          _locationSubscription?.cancel();
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SOS Failed: ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => isSosLoading = false);
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: onTap == null ? Colors.grey.shade300 : color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (onTap != null)
                BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
            ]
          ),
          child: Column(
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("My Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (clusterId != null)
            IconButton(
              icon: const Icon(Icons.share, size: 28),
              tooltip: 'Share Invite Code',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: clusterId!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite Code copied to clipboard!')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.person, size: 28),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen(role: 'elder')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 28),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _callCaregiver,
        backgroundColor: Colors.teal.shade800,
        icon: const Icon(Icons.phone, color: Colors.white),
        label: const Text("Call Caregiver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ).animate().slideY(begin: 1.0, duration: 600.ms, curve: Curves.easeOutBack),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting -> Routes to Check In
              GestureDetector(
                onTap: clusterId == null ? null : () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DailyCheckInScreen(clusterId: clusterId!)));
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 2),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.favorite, size: 36, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Daily Check-in", style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text(
                              "How are you today?",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideX(),
              ),
              
              const Spacer(),
              
              // Big Breathing SOS Button
              Center(
                child: GestureDetector(
                  onTap: isSosLoading ? null : triggerSOS,
                  child: Container(
                    height: 220,
                    width: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ]
                    ),
                    child: Center(
                      child: isSosLoading 
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 4)
                        : const Text("SOS", style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1.seconds, curve: Curves.easeInOutSine),
                ),
              ).animate().fade(delay: 200.ms).scale(),
              
              const Spacer(),
              
              // Action Buttons
              Row(
                children: [
                  _buildActionButton(
                    title: "Medicines",
                    icon: Icons.medication_liquid_rounded,
                    color: Colors.blueAccent,
                    onTap: clusterId == null ? null : () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ElderMedicineView(clusterId: clusterId!)),
                      );
                    },
                  ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    title: "Tasks",
                    icon: Icons.checklist_rtl_rounded,
                    color: Colors.green,
                    onTap: clusterId == null ? null : () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ElderTaskView(clusterId: clusterId!)),
                      );
                    },
                  ).animate().fade(delay: 400.ms).slideY(begin: 0.2),
                ],
              ),
              const SizedBox(height: 80), // padding for FAB
            ],
          ),
        ),
      ),
    );
  }
}




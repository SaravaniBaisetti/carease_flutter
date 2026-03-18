import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class SosActiveScreen extends StatefulWidget {
  final String clusterId;
  final String alertId; // To mark as resolved and stop location stream
  final String elderUid;

  const SosActiveScreen({
    super.key,
    required this.clusterId,
    required this.alertId,
    required this.elderUid,
  });

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Color?> _colorAnimation;

  String emergencyMedication = '';
  String medicalConditions = '';
  String caregiverPhone = '';
  
  bool isCancelling = false;

  @override
  void initState() {
    super.initState();
    
    // Constant pulsing animation from dark red to light red
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.red[900],
      end: Colors.redAccent[400],
    ).animate(_animController);

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load profile info (medications and conditions)
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.elderUid)
          .collection('profile')
          .doc(widget.elderUid)
          .get();

      if (profileDoc.exists) {
        if (mounted) {
          setState(() {
            emergencyMedication = profileDoc.data()?['emergencyMedication'] ?? 'None specified';
            medicalConditions = profileDoc.data()?['medicalConditions'] ?? 'None specified';
          });
        }
      }

      // Find caregiver phone number
      final clusterDoc = await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .get();
      
      final caregiverId = clusterDoc.data()?['primaryCaregiverId'];
      if (caregiverId != null) {
        final caregiverDoc = await FirebaseFirestore.instance.collection('users').doc(caregiverId).get();
        if (mounted) {
          setState(() {
            caregiverPhone = caregiverDoc.data()?['phoneNumber'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading SOS active screen data: $e');
    }
  }

  Future<void> _cancelSOS() async {
    if (isCancelling) return;
    setState(() => isCancelling = true);

    try {
      // Mark alert as resolved
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('alerts')
          .doc(widget.alertId)
          .update({
        'resolved': true,
        'liveLocationActive': false,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      // The live location stream in elder_dashboard will automatically stop 
      // when it sees liveLocationActive = false or the screen pops.

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS Alert cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel SOS: $e')),
        );
        setState(() => isCancelling = false);
      }
    }
  }

  Future<void> _callCaregiver() async {
    if (caregiverPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caregiver phone number not available.')));
      return;
    }
    
    final Uri url = Uri.parse('tel:$caregiverPhone');
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open dialer for $caregiverPhone')));
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button to force user to use Cancel SOS
      child: AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return Scaffold(
            backgroundColor: _colorAnimation.value,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.white, size: 80),
                    const SizedBox(height: 16),
                    const Text(
                      "SOS ACTIVE",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Emergency services and family have been notified.\nLive location is being shared.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),

                    // Emergency Information Cards
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.vaccines, color: Colors.red),
                                SizedBox(width: 8),
                                Text("Emergency Medication", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              emergencyMedication.isEmpty ? 'Loading...' : emergencyMedication,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const Divider(height: 30, thickness: 1),
                            const Row(
                              children: [
                                Icon(Icons.medical_information, color: Colors.red),
                                SizedBox(width: 8),
                                Text("Medical Conditions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              medicalConditions.isEmpty ? 'Loading...' : medicalConditions,
                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Actions
                    SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _callCaregiver,
                        icon: const Icon(Icons.phone),
                        label: const Text("Call Caregiver", style: TextStyle(fontSize: 20)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red[900],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 60,
                      child: OutlinedButton(
                        onPressed: isCancelling ? null : _cancelSOS,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: isCancelling
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("CANCEL SOS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

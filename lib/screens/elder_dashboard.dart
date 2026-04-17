import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_colors.dart';
import '../widgets/language_picker.dart';
import '../widgets/theme_toggle_button.dart';
import 'elder_medicine_view.dart';
import 'elder_task_view.dart';
import 'daily_check_in_screen.dart';
import 'login_screen.dart';
import '../theme/app_colors.dart';
import 'sos_active_screen.dart';
import 'profile_screen.dart';
import '../services/alarm_sync_service.dart';
import 'in_app_ring_screen.dart';
import '../services/ai_voice_assistant.dart';
import '../services/push_notification_service.dart';
import '../widgets/global_voice_bot.dart';
import '../widgets/glass_container.dart';
import '../theme/app_colors.dart';
import 'dart:ui';

class ElderDashboard extends StatefulWidget {
  const ElderDashboard({super.key});

  @override
  State<ElderDashboard> createState() => _ElderDashboardState();
}

class _ElderDashboardState extends State<ElderDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return tr('good_morning');
    if (hour < 17) return tr('good_afternoon');
    return tr('good_evening');
  }
  bool isSosLoading = false;
  String? clusterId;
  String? caregiverPhone;
  String elderName = "!";
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
    elderName = user?.displayName ?? "there";
    _loadClusterData();
  }

  Future<void> _loadClusterData() async {
    final elderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final elderProfileDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('profile')
        .doc(user!.uid)
        .get();

    if (elderProfileDoc.exists && elderProfileDoc.data()!.containsKey('fullName')) {
      final name = elderProfileDoc.data()!['fullName'];
      if (name != null && name.toString().trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            elderName = name.toString().split(' ').first;
          });
        }
      }
    }

    final cId = elderDoc.data()?['elderClusterId'];

    if (cId != null) {
      final clusterDoc = await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(cId)
          .get();
      final caregiverId = clusterDoc.data()?['primaryCaregiverId'];

      if (caregiverId != null) {
        final caregiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverId)
            .collection('profile')
            .doc(caregiverId)
            .get();
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

      _alarmSyncService = AlarmSyncService(
          clusterId: cId!,
          onRingTriggered: (type, clusterId, docId, data) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => InAppRingScreen(
                          clusterId: clusterId,
                          docId: docId,
                          type: type,
                          title: data['title'] ?? data['name'] ?? 'Reminder',
                          description: data['description'] ??
                              'Dosage: ${data["dosage"] ?? "N/A"}',
                          snoozeCount: data['snoozeCount'] ?? 0,
                        )));
          });
      _alarmSyncService!.startSync();
    }
  }

  Future<void> _callCaregiver() async {
    if (clusterId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('no_cluster_assigned'))));
      return;
    }

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

      await PushNotificationService.triggerAlertNotification(
          clusterId!, "CALL_REQUEST");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('calling_caregiver')),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${tr('call_failed')} $e')));
      }
    }
  }

  Future<void> triggerSOS() async {
    setState(() => isSosLoading = true);
    try {
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
        if (mounted)
          throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition();

      if (clusterId == null) {
        if (mounted) throw Exception(tr('no_cluster_assigned'));
      }

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

      await PushNotificationService.triggerAlertNotification(clusterId!, "SOS");

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

      _locationSubscription?.cancel();
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 10),
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
          _locationSubscription?.cancel();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('sos_failed')} ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => isSosLoading = false);
  }

  Future<void> _startGeneralVoiceAssistant() async {
    if (clusterId == null) return;
    final localeCode = context.locale.languageCode;

    await AIVoiceAssistant().stopAll();

    if (mounted) {
      GlobalVoiceBot.show(
        context,
        clusterId: clusterId!,
        languageCode: localeCode,
        elderName: elderName,
        onTriggerSos: triggerSOS,
        onOpenTasks: () {
          GlobalVoiceBot.hide();
          Navigator.push(context, MaterialPageRoute(builder: (_) => ElderTaskView(clusterId: clusterId!)));
        },
        onOpenMedicines: () {
          GlobalVoiceBot.hide();
          Navigator.push(context, MaterialPageRoute(builder: (_) => ElderMedicineView(clusterId: clusterId!)));
        },
      );
    }
  }

  Widget _buildTopNav() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                const Icon(Icons.favorite_rounded, color: AppColors.oliveGreen, size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tr('my_dashboard'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LanguagePicker(),
              if (clusterId != null)
                IconButton(
                  icon: const Icon(Icons.share, size: 24, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: tr('share_invite_code'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: clusterId!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('invite_copied'))),
                    );
                  },
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.person, size: 24, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen(role: 'elder')));
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout, size: 24, color: Colors.pinkAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.pushReplacement(
                        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${_getGreeting()}, $elderName!",
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            tr('how_are_you_today'),
            style: TextStyle(
                fontSize: 18, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartDisplay() {
    return Container(
      height: 280,
      width: double.infinity,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The 3D Heart Asset
          Image.asset(
            'assets/images/3d_heart_asset.png',
            fit: BoxFit.contain,
            colorBlendMode: BlendMode.plus,
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(begin: const Offset(1.0, 1.0), end: const Offset(1.03, 1.03), duration: 800.ms, curve: Curves.easeInOut),
          
          // Floating Badges
          Positioned(
            left: 20,
            bottom: 40,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              borderRadius: 20,
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.pinkAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "SpO2 98.5%",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ).animate().fade(delay: 400.ms).slideX(begin: -0.2),
          ),
          Positioned(
            right: 20,
            top: 40,
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              borderRadius: 20,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(color: AppColors.oliveGreen, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Connected",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ).animate().fade(delay: 500.ms).slideX(begin: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.oliveGreen.withOpacity(0.95), // Solid feel
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: clusterId == null
              ? null
              : () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => DailyCheckInScreen(clusterId: clusterId!)));
                },
          borderRadius: BorderRadius.circular(24),
          child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('daily_check_in'),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  tr('tap_to_record'),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            height: 60,
            width: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 0.8,
                  strokeWidth: 6,
                  color: Colors.cyanAccent,
                  backgroundColor: Colors.white.withOpacity(0.1),
                ),
                Center(
                  child: const Icon(Icons.check, color: Colors.cyanAccent, size: 28),
                ),
              ],
            ),
          )
        ],
      ),
    ),
  ),
);
}

  Widget _buildQuickActionsGrid() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.oliveGreen, // Solid shade 1
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: clusterId == null
                    ? null
                    : () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ElderMedicineView(clusterId: clusterId!)));
                      },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.medication_liquid_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('medicines'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.oliveGreen, // Solid shade 2
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: clusterId == null
                    ? null
                    : () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ElderTaskView(clusterId: clusterId!)));
                      },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.content_paste_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('tasks'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSOSAndVoice() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: isSosLoading ? null : triggerSOS,
            child: GlassContainer(
              color: AppColors.sosRed.withOpacity(0.4),
              border: Border.all(color: AppColors.sosRedLight.withOpacity(0.8), width: 2),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: isSosLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_rounded, color: Colors.white, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          tr('sos_btn_text'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.oliveGreen,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: clusterId == null ? null : _startGeneralVoiceAssistant,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.mic_rounded, color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        tr('ai_voice_assistant').split(' ').last,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaregiverCall() {
    return GlassContainer(
      onTap: _callCaregiver,
      color: Colors.green.withOpacity(1),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.phone_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            tr('call_caregiver_btn'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopNav(),
          _buildGreeting(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHealthOverview().animate().fade(delay: 200.ms).slideY(begin: 0.2),
                const SizedBox(height: 16),
                _buildQuickActionsGrid().animate().fade(delay: 300.ms).slideY(begin: 0.2),
                const SizedBox(height: 16),
                _buildSOSAndVoice().animate().fade(delay: 400.ms).slideY(begin: 0.2),
                const SizedBox(height: 16),
                _buildCaregiverCall().animate().fade(delay: 500.ms).slideY(begin: 0.2),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel (Greeting & Heart & SOS)
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
             physics: const BouncingScrollPhysics(),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 _buildTopNav(),
                 _buildGreeting(),
                 const SizedBox(height: 24),
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 20),
                   child: _buildSOSAndVoice().animate().fade(delay: 400.ms).slideY(begin: 0.2),
                 ),
                 const SizedBox(height: 40),
               ],
             ),
          ),
        ),
        // Right Panel (Appointments, overviews, quick actions)
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.black.withOpacity(0.2),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _buildHealthOverview().animate().fade(delay: 200.ms).slideY(begin: 0.2),
                  const SizedBox(height: 20),
                  _buildQuickActionsGrid().animate().fade(delay: 300.ms).slideY(begin: 0.2),
                  const SizedBox(height: 20),
                  _buildCaregiverCall().animate().fade(delay: 500.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Establishing a dependency on EasyLocalization so this widget rebuilds on language change
    final _ = context.locale;
    return Scaffold(
      backgroundColor: Colors.transparent, // Fix: Use transparent to avoid black flash
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/default_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return _buildLandscapeLayout();
                } else {
                  return _buildPortraitLayout();
                }
              },
            ),
          ),
        ),
      );
  }
}

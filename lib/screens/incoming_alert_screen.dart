import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'sos_map_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

class IncomingAlertScreen extends StatefulWidget {
  final String clusterId;
  final String alertId;
  final String elderName;
  final String alertType; // "SOS" or "CALL_REQUEST"

  const IncomingAlertScreen({
    super.key,
    required this.clusterId,
    required this.alertId,
    required this.elderName,
    required this.alertType,
  });

  @override
  State<IncomingAlertScreen> createState() => _IncomingAlertScreenState();
}

class _IncomingAlertScreenState extends State<IncomingAlertScreen> {
  StreamSubscription<DocumentSnapshot>? _alertSubscription;
  bool _isHandled = false;

  @override
  void initState() {
    super.initState();
    _playRingtone();
    _listenToAlertStatus();
  }

  void _listenToAlertStatus() {
    _alertSubscription = FirebaseFirestore.instance
        .collection('elderClusters')
        .doc(widget.clusterId)
        .collection('alerts')
        .doc(widget.alertId)
        .snapshots()
        .listen((snapshot) {
      if (_isHandled) return;
      if (!snapshot.exists || (snapshot.data() != null && snapshot.data()!['resolved'] == true)) {
        _isHandled = true;
        _stopRingtone();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('alert_cancelled_by_elder'))),
          );
          Navigator.pop(context);
        }
      }
    });
  }

  void _playRingtone() {
    try {
      if (!kIsWeb) {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.glass,
          looping: true,
          volume: 1.0,
          asAlarm: true,
        );
      }
    } catch (e) {
      debugPrint("Ringtone failed: $e");
    }
  }

  void _stopRingtone() {
    try {
      if (!kIsWeb) {
        FlutterRingtonePlayer().stop();
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _stopRingtone();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    _isHandled = true;
    _stopRingtone();

    if (widget.alertType == "SOS") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SosMapScreen(
            clusterId: widget.clusterId,
            alertId: widget.alertId,
            elderName: widget.elderName,
            isLive: true,
          ),
        ),
      );
    } else {
      // For CALL_REQUEST, just mark as acknowledged/resolved and pop
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('alerts')
          .doc(widget.alertId)
          .update({'resolved': true});
          
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _handleDecline() async {
    _isHandled = true;
    _stopRingtone();
    // Resolve the alert directly
    try {
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('alerts')
          .doc(widget.alertId)
          .update({'resolved': true});
    } catch (e) {
      debugPrint("Failed to resolve alert: $e");
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSos = widget.alertType == "SOS";
    final Color bgColor = isSos ? Colors.red.shade900 : Colors.blue.shade900;
    final String title = isSos ? tr('emergency_sos_title') : tr('incoming_call_request');

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Caller Avatar
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white24,
                child: Icon(
                  isSos ? Icons.warning_rounded : Icons.phone_in_talk,
                  size: 60,
                  color: Colors.white,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 600.ms),
              
              const SizedBox(height: 32),
              
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.elderName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              
              const Spacer(),
              
              // Accept/Decline Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _handleDecline,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                          ),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(tr('decline_btn'), style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                  
                  // Accept
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _handleAccept,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.greenAccent,
                          ),
                          child: Icon(isSos ? Icons.location_on : Icons.call, color: Colors.blueGrey.shade900, size: 36),
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 1.seconds, color: Colors.white.withOpacity(0.5)),
                      
                      const SizedBox(height: 12),
                      Text(isSos ? tr('view_map_btn') : tr('answer_btn'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

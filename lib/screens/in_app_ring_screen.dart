import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'elder_dashboard.dart';
import '../services/ai_voice_assistant.dart';
import '../services/intent_parser.dart';

class InAppRingScreen extends StatefulWidget {
  final String clusterId;
  final String docId;
  final String type; // 'medicine' or 'task'
  final String title;
  final String description;
  final int snoozeCount;

  const InAppRingScreen({
    super.key,
    required this.clusterId,
    required this.docId,
    required this.type,
    required this.title,
    required this.description,
    this.snoozeCount = 0,
  });

  @override
  State<InAppRingScreen> createState() => _InAppRingScreenState();
}

class _InAppRingScreenState extends State<InAppRingScreen> {
  @override
  void initState() {
    super.initState();
    FlutterRingtonePlayer().playAlarm();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVoiceAssistant();
    });
  }
  
  Future<void> _startVoiceAssistant() async {
    // Let ringtone play for 3 seconds to get attention, then stop for AI
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    FlutterRingtonePlayer().stop();
    
    final isMed = widget.type == 'medicine';
    final announceText = "${tr('time_for')} ${isMed ? tr('medicine_word') : tr('task_word')}, ${widget.title}.";
    
    await AIVoiceAssistant().speak(announceText, context.locale.languageCode);
    await AIVoiceAssistant().awaitSpeakCompletion();
    
    if (!mounted) return;
    
    await AIVoiceAssistant().listenForCommand(
      languageCode: context.locale.languageCode,
      onResult: (text) {
        if (IntentParser.isConfirmation(text)) {
           _handleAction(isMed ? 'taken' : 'done');
        }
      }
    );
  }

  @override
  void dispose() {
    FlutterRingtonePlayer().stop();
    AIVoiceAssistant().stopAll();
    super.dispose();
  }

  Future<void> _handleAction(String action) async {
    FlutterRingtonePlayer().stop();
    
    try {
      final docRef = FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection(widget.type == 'medicine' ? 'medicines' : 'tasks')
          .doc(widget.docId);
          
      if (action == 'done' || action == 'taken') {
         if (widget.type == 'task') {
           await docRef.update({
             'status': 'completed',
             'completedAt': FieldValue.serverTimestamp(),
             'lastStatus': 'completed',
             'snoozeCount': 0,
             'snoozedUntil': FieldValue.delete(),
           });
         } else {
           await FirebaseFirestore.instance.collection('elderClusters').doc(widget.clusterId).collection('medicineLogs').add({
              "medicineId": widget.docId,
              "medicineName": widget.title,
              "elderId": widget.clusterId, 
              "status": "taken",
              "timestamp": FieldValue.serverTimestamp(),
           });
           await docRef.update({
               'lastTaken': FieldValue.serverTimestamp(), 
               'lastStatus': 'taken',
               'snoozeCount': 0,
               'snoozedUntil': FieldValue.delete(),
           });
         }
      } else if (action == 'snooze') {
         final newCount = widget.snoozeCount + 1;
         if (newCount > 3) {
            await FirebaseFirestore.instance.collection('elderClusters').doc(widget.clusterId).collection('alerts').add({
              "type": widget.type == 'medicine' ? "MISSED_MEDICATION" : "MISSED_TASK",
              "triggeredBy": "SNOOZE_LIMIT_${widget.clusterId}",
              "timestamp": FieldValue.serverTimestamp(),
              "resolved": false,
              "resolvedBy": null,
              "description": "Elder snoozed ${widget.type} '${widget.title}' more than 3 times."
            });
            await docRef.update({
                'snoozeCount': 0,
                'snoozedUntil': FieldValue.delete(),
                'lastStatus': 'missed (snooze limit)',
            });
            if (widget.type == 'task') {
               await docRef.update({'status': 'missed'});
            }
         } else {
            await docRef.update({
               'snoozeCount': newCount, 
               'lastStatus': 'snoozed',
               'snoozedUntil': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5)))
            });
         }
      } else if (action == 'skip') {
         if (widget.type == 'medicine') {
           await FirebaseFirestore.instance.collection('elderClusters').doc(widget.clusterId).collection('medicineLogs').add({
              "medicineId": widget.docId,
              "medicineName": widget.title,
              "elderId": widget.clusterId, 
              "status": "skipped",
              "timestamp": FieldValue.serverTimestamp(),
           });
           await FirebaseFirestore.instance.collection('elderClusters').doc(widget.clusterId).collection('alerts').add({
             "type": "MISSED_MEDICATION",
             "triggeredBy": widget.clusterId,
             "timestamp": FieldValue.serverTimestamp(),
             "resolved": false,
             "resolvedBy": null,
             "description": "Elder specifically skipped medicine '${widget.title}'."
           });
           await docRef.update({
               'lastTaken': FieldValue.serverTimestamp(), 
               'lastStatus': 'skipped',
               'snoozeCount': 0,
               'snoozedUntil': FieldValue.delete(),
           });
         }
      }
    } catch (e) {
      debugPrint("Error handling Action: $e");
    } finally {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ElderDashboard()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMed = widget.type == 'medicine';
    
    return Scaffold(
      backgroundColor: isMed ? Colors.blue.shade900 : Colors.green.shade900,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(isMed ? Icons.medication : Icons.task_alt, size: 100, color: Colors.white)
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 1.seconds),
                
                Text(
                  "${tr('time_for')} ${isMed ? tr('medicine_word') : tr('task_word')}!",
                  style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Text(widget.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Text(widget.description, style: const TextStyle(fontSize: 18, color: Colors.grey), textAlign: TextAlign.center),
                    ],
                  ),
                ),
                
                Column(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: isMed ? Colors.blue.shade900 : Colors.green.shade900,
                        minimumSize: const Size(double.infinity, 65),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                      onPressed: () => _handleAction(isMed ? 'taken' : 'done'),
                      child: Text(isMed ? tr('mark_as_taken') : tr('mark_as_done'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 65),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                      onPressed: () => _handleAction('snooze'),
                      child: Text(tr('snooze_5_min'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    if (isMed) ...[
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => _handleAction('skip'),
                        child: Text(tr('skip_medicine'), style: const TextStyle(color: Colors.white, fontSize: 18)),
                      )
                    ]
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

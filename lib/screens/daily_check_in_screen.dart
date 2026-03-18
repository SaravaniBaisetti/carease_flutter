import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class DailyCheckInScreen extends StatefulWidget {
  final String clusterId;

  const DailyCheckInScreen({super.key, required this.clusterId});

  @override
  State<DailyCheckInScreen> createState() => _DailyCheckInScreenState();
}

class _DailyCheckInScreenState extends State<DailyCheckInScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool isSubmitting = false;

  Future<void> _submitMood(String mood, String details, Color accentColor) async {
    setState(() => isSubmitting = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('healthLogs')
          .add({
        "elderId": user!.uid,
        "mood": mood,
        "details": details,
        "timestamp": FieldValue.serverTimestamp(),
        "dateString": DateFormat('yyyy-MM-dd').format(DateTime.now()), // For easier querying per day
      });

      if (mounted) {
        // Show success animation/dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.check_circle_rounded, color: accentColor, size: 80),
                ).animate().scale(curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                const Text("Thank you!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Your check-in has been sent to your caregiver.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // close dialog
                      Navigator.pop(context); // close screen
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text("Go Back", style: TextStyle(fontSize: 18)),
                  ),
                )
              ],
            ),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: \${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Widget _buildMoodCard(String emoji, String title, String subtitle, Color color) {
    return GestureDetector(
      onTap: isSubmitting ? null : () => _submitMood(title, subtitle, color),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 32)
          ],
        ),
      ).animate().fade().slideX(begin: 0.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Daily Check-in', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: isSubmitting 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                "How are you feeling today?",
                style: TextStyle(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold, 
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.2
                ),
              ).animate().fade().slideY(),
              const SizedBox(height: 12),
              const Text(
                "Tap the face that best describes your mood. Your caregiver will be notified.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ).animate().fade(delay: 100.ms).slideY(),
              const SizedBox(height: 48),
              
              _buildMoodCard("😊", "Great", "I am feeling good and healthy.", Colors.green),
              _buildMoodCard("😐", "Okay", "I am feeling just alright today.", Colors.orange),
              _buildMoodCard("🤕", "Not Well", "I am feeling sick or in pain.", Colors.red),
            ],
          ),
      ),
    );
  }
}

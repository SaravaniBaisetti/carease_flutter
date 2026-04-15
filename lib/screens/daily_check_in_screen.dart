import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
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

  // 0.0 = Bad, 1.0 = Not bad, 2.0 = Good
  double _sliderValue = 1.0;
  String _note = "";

  // The base colors for the dynamic background
  final Color colorBad = const Color(0xFFE85A4F); // Smooth red/orange
  final Color colorOkay = const Color(0xFFF3A754); // Smooth amber/orange
  final Color colorGood = const Color(0xFF9CCC65); // Smooth green

  Color _getBackgroundColor() {
    if (_sliderValue < 1.0) {
      return Color.lerp(colorBad, colorOkay, _sliderValue)!;
    } else {
      return Color.lerp(colorOkay, colorGood, _sliderValue - 1.0)!;
    }
  }

  String _getMoodLabel() {
    if (_sliderValue < 0.5) return tr('mood_bad');
    if (_sliderValue < 1.5) return tr('mood_not_bad');
    return tr('mood_good');
  }

  String _getFirestoreMood() {
    if (_sliderValue < 0.5) return "Not Well";
    if (_sliderValue < 1.5) return "Okay";
    return "Great";
  }

  Future<void> _submitMood() async {
    setState(() => isSubmitting = true);
    
    try {
      final moodStr = _getFirestoreMood();
      await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('healthLogs')
          .add({
        "elderId": user!.uid,
        "mood": moodStr,
        "details": _note,
        "timestamp": FieldValue.serverTimestamp(),
        "dateString": DateFormat('yyyy-MM-dd').format(DateTime.now()), 
      });

      if (mounted) {
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
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
                ).animate().scale(curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                Text(tr('thank_you_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(tr('check_in_sent'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // close dialog
                      Navigator.pop(context); // close screen
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(tr('go_back'), style: const TextStyle(fontSize: 18)),
                  ),
                )
              ],
            ),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('failed_colon')} ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showAddNoteDialog() {
    final controller = TextEditingController(text: _note);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('add_a_note_title')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: tr('any_specific_details'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _note = controller.text.trim();
              });
              Navigator.pop(context);
            },
            child: Text(tr('save_btn')),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBgColor = _getBackgroundColor();
    final darkColor = Colors.black87.withOpacity(0.85);

    return Scaffold(
      backgroundColor: currentBgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: Icon(Icons.close, color: darkColor, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: Icon(Icons.info_outline, color: darkColor, size: 28),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('slide_to_select')))
                );
              },
            ),
          )
        ],
      ),
      body: isSubmitting 
      ? Center(child: CircularProgressIndicator(color: darkColor))
      : SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Header Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  tr('how_was_day'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: darkColor,
                  ),
                ).animate().fade().slideY(begin: -0.2),
              ),
              
              const Spacer(flex: 3),
              
              // Animated Face
              SizedBox(
                width: 250,
                height: 250,
                child: CustomPaint(
                  painter: _FacePainter(sliderValue: _sliderValue, eyeColor: darkColor),
                ),
              ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),

              const SizedBox(height: 10),
              
              // Dynamic Mood Text
              Text(
                _getMoodLabel(),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: darkColor,
                  letterSpacing: -2,
                ),
              ),
              
              const Spacer(flex: 2),

              // Slider section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: darkColor,
                        inactiveTrackColor: darkColor.withOpacity(0.2),
                        thumbColor: darkColor,
                        overlayColor: darkColor.withOpacity(0.1),
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 28),
                      ),
                      child: Slider(
                        value: _sliderValue,
                        min: 0.0,
                        max: 2.0,
                        onChanged: (val) {
                          setState(() {
                            _sliderValue = val;
                          });
                        },
                        // Optionally add behavior exactly like video by changing steps
                        // By leaving it without 'divisions', it is completely smooth and continuous!
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tr('bad'), style: TextStyle(color: darkColor.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(tr('not_bad'), style: TextStyle(color: darkColor.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(tr('good'), style: TextStyle(color: darkColor.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Bottom Actions: Add Note & Submit
              Padding(
                padding: const EdgeInsets.only(left: 30, right: 30, bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _showAddNoteDialog,
                      child: Text(
                        _note.isEmpty ? tr('add_note_btn') : tr('edit_note_btn'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: darkColor.withOpacity(0.7)
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _submitMood,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tr('submit_btn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final double sliderValue; // 0.0 to 2.0
  final Color eyeColor;

  _FacePainter({required this.sliderValue, required this.eyeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.fill;
      
    // Eyes
    final double eyeRadius = size.width * 0.22;
    // Base y position for eyes
    final double eyeY = size.height * 0.35 + (sliderValue - 1.0) * -10.0; // Eyes slightly lift when happy
    
    // Left eye
    canvas.drawCircle(Offset(size.width * 0.25, eyeY), eyeRadius, paint);
    // Right eye
    canvas.drawCircle(Offset(size.width * 0.75, eyeY), eyeRadius, paint);

    // Mouth
    final mouthPaint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    double startX = size.width * 0.35;
    double endX = size.width * 0.65;
    double mouthBaseY = size.height * 0.75;
    
    // Control point Y interpolates based on slider value
    // When 0.0 (Bad) -> Control Y is HIGH (frown shape)
    // When 1.0 (Not bad) -> Control Y is FLAT (horizontal shape)
    // When 2.0 (Good) -> Control Y is LOW (smile shape)
    
    // Map slider: 
    // val 0 -> -35 offset (frown)
    // val 1 -> 0 offset (flat)
    // val 2 -> +35 offset (smile)
    double controlYOffset = (sliderValue - 1.0) * 45.0; 

    // Adjust width of mouth based on expression (wider when smiling)
    double mouthWidthAdjustment = (sliderValue - 1.0) * 15.0;
    startX -= mouthWidthAdjustment;
    endX += mouthWidthAdjustment;

    path.moveTo(startX, mouthBaseY);
    path.quadraticBezierTo(
      size.width * 0.5, 
      mouthBaseY + controlYOffset, 
      endX, 
      mouthBaseY
    );

    canvas.drawPath(path, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) {
    return oldDelegate.sliderValue != sliderValue || oldDelegate.eyeColor != eyeColor;
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class ElderPerformanceScreen extends StatefulWidget {
  final String clusterId;
  final String elderName;

  const ElderPerformanceScreen({
    super.key,
    required this.clusterId,
    required this.elderName,
  });

  @override
  State<ElderPerformanceScreen> createState() => _ElderPerformanceScreenState();
}

class _ElderPerformanceScreenState extends State<ElderPerformanceScreen> {
  String timePeriod = 'Weekly'; // Weekly, Monthly
  bool isLoading = true;

  // Check-ins (Mood Pie Chart)
  int moodGreat = 0;
  int moodOkay = 0;
  int moodBad = 0;

  // SOS Alerts
  int totalSosAlerts = 0;

  // Today's Medicines
  int takenMeds = 0;
  int pendingMeds = 0;
  int missedMeds = 0;

  // Today's Tasks
  int completedTasks = 0;
  int pendingTasks = 0;
  int missedTasks = 0;

  @override
  void initState() {
    super.initState();
    _fetchPerformanceData();
  }

  Future<void> _fetchPerformanceData() async {
    setState(() => isLoading = true);
    
    // Reset Data
    moodGreat = 0;
    moodOkay = 0;
    moodBad = 0;
    totalSosAlerts = 0;
    takenMeds = 0;
    pendingMeds = 0;
    missedMeds = 0;
    completedTasks = 0;
    pendingTasks = 0;
    missedTasks = 0;

    final now = DateTime.now();
    DateTime cutoffDate;
    if (timePeriod == 'Weekly') {
      cutoffDate = now.subtract(const Duration(days: 7));
    } else {
      cutoffDate = now.subtract(const Duration(days: 30));
    }

    try {
      // 1. Fetch Health Logs (Check-ins)
      final healthLogsQuery = await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('healthLogs')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .get();

      for (var doc in healthLogsQuery.docs) {
        final mood = doc.data()['mood'] ?? '';
        if (mood == 'Great') moodGreat++;
        else if (mood == 'Okay') moodOkay++;
        else if (mood == 'Not Well') moodBad++;
      }

      // 2. Fetch Alerts (SOS)
      final alertsQuery = await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('alerts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .get();
      
      for (var doc in alertsQuery.docs) {
        if (doc.data()['type'] == 'SOS') {
          totalSosAlerts++;
        }
      }

      // 3. Fetch Today's Medicines
      final medicinesQuery = await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('medicines')
          .where('isActive', isEqualTo: true)
          .get();

      for (var doc in medicinesQuery.docs) {
        final data = doc.data();
        final lastTaken = data['lastTaken'] as Timestamp?;
        final status = data['lastStatus'];
        
        bool isToday(DateTime? date) {
          if (date == null) return false;
          return date.year == now.year && date.month == now.month && date.day == now.day;
        }

        if (lastTaken != null && isToday(lastTaken.toDate())) {
          if (status == 'taken') takenMeds++;
          else if (status == 'skipped') missedMeds++;
          else pendingMeds++; // fallback
        } else {
          pendingMeds++; // Not interacted today, consider it pending or missed if late
        }
      }

      // 4. Fetch Today's Tasks
      final tasksQuery = await FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(widget.clusterId)
          .collection('tasks')
          .get();

      for (var doc in tasksQuery.docs) {
        final data = doc.data();
        // Since tasks might not be "isActive" but rely on "status" (pending vs done vs missed)
        final status = data['status'];
        if (status == 'done') completedTasks++;
        else if (status == 'missed') missedTasks++;
        else pendingTasks++;
      }

    } catch (e) {
      debugPrint("Error fetching performance data: $e");
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Period Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  tr('performance_overview'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              DropdownButton<String>(
                value: timePeriod,
                items: ['Weekly', 'Monthly']
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e == 'Weekly' ? tr('weekly') : tr('monthly')),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                     setState(() => timePeriod = val);
                     _fetchPerformanceData();
                  }
                },
              ),
            ],
          ).animate().fadeIn().slideY(begin: -0.1),

          const SizedBox(height: 16),
          
          // SOS and Emergency Stats
          _buildEmergencyStats().animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 24),

          // Mood Distribution Pie Chart
          _buildMoodChart().animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),

          const SizedBox(height: 24),

          // Today's Items Summary
          Text(tr('medicines_today'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 8),
          _buildBarChartSummary(
            title: tr('medicines_today'), 
            taken: takenMeds, 
            pending: pendingMeds, 
            missed: missedMeds,
            colorTaken: Colors.green,
            colorPending: Colors.blue,
            colorMissed: Colors.red,
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 24),
          
          Text(tr('tasks_today'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 8),
          _buildBarChartSummary(
            title: tr('tasks_today'), 
            taken: completedTasks, 
            pending: pendingTasks, 
            missed: missedTasks,
            colorTaken: Colors.teal,
            colorPending: Colors.orange,
            colorMissed: Colors.redAccent,
            labelTaken: tr('completed')
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEmergencyStats() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: totalSosAlerts > 0 ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              totalSosAlerts > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              size: 48,
              color: totalSosAlerts > 0 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              tr('total_sos_alerts'),
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            Text(
              totalSosAlerts.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: totalSosAlerts > 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodChart() {
    if (moodGreat == 0 && moodOkay == 0 && moodBad == 0) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(tr('no_check_ins_yet'), style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(tr('mood_distribution'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    if (moodGreat > 0)
                      PieChartSectionData(
                        color: Colors.green,
                        value: moodGreat.toDouble(),
                        title: '$moodGreat 😊',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    if (moodOkay > 0)
                      PieChartSectionData(
                        color: Colors.orange,
                        value: moodOkay.toDouble(),
                        title: '$moodOkay 😐',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    if (moodBad > 0)
                      PieChartSectionData(
                        color: Colors.red,
                        value: moodBad.toDouble(),
                        title: '$moodBad 🤕',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildIndicator(Colors.green, tr('good')),
                _buildIndicator(Colors.orange, tr('not_bad')),
                _buildIndicator(Colors.red, tr('bad')),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartSummary({
    required String title,
    required int taken,
    required int pending,
    required int missed,
    required Color colorTaken,
    required Color colorPending,
    required Color colorMissed,
    String? labelTaken,
  }) {
    final total = taken + pending + missed;
    if (total == 0) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(title == tr('medicines_today') ? tr('no_medicines_added') : tr('no_tasks_assigned'), style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _buildStatItem(labelTaken ?? tr('taken'), taken, colorTaken),
                _buildStatItem(tr('pending'), pending, colorPending),
                _buildStatItem(tr('missed'), missed, colorMissed),
              ],
            ),
            const SizedBox(height: 24),
            // Progress Bar representing distribution
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  if (taken > 0) Expanded(flex: taken, child: Container(height: 12, color: colorTaken)),
                  if (pending > 0) Expanded(flex: pending, child: Container(height: 12, color: colorPending)),
                  if (missed > 0) Expanded(flex: missed, child: Container(height: 12, color: colorMissed)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildIndicator(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

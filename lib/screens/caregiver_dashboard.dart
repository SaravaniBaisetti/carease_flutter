import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'elder_detail_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'incoming_alert_screen.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/language_picker.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/app_card.dart';
import '../widgets/enterprise_components.dart';
import '../theme/app_colors.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({super.key});

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {
  final user = FirebaseAuth.instance.currentUser;
  List<String> clusterIds = [];
  bool isLoading = true;
  String caregiverName = '';
  final List<StreamSubscription> _alertSubscriptions = [];
  final Set<String> _shownAlerts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      final data = userDoc.data();
      if (data != null) {
        caregiverName = data['name'] ?? 'Caregiver';
        final ids = data['clusterIds'];
        if (ids is List) {
          clusterIds = List<String>.from(ids);
        }
      }
    } catch (e) {
      debugPrint('Error loading caregiver dashboard: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
      _setupAlertListeners();
    }
  }

  void _setupAlertListeners() {
    for (var sub in _alertSubscriptions) {
      sub.cancel();
    }
    _alertSubscriptions.clear();

    for (String cId in clusterIds) {
      final sub = FirebaseFirestore.instance
          .collection('elderClusters')
          .doc(cId)
          .collection('alerts')
          .where('resolved', isEqualTo: false)
          .snapshots()
          .listen((snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final alertId = change.doc.id;
            final alertData = change.doc.data();

            if (alertData != null &&
                (alertData['type'] == 'SOS' ||
                    alertData['type'] == 'CALL_REQUEST') &&
                !_shownAlerts.contains(alertId)) {
              _shownAlerts.add(alertId);

              final clusterDoc = await FirebaseFirestore.instance
                  .collection('elderClusters')
                  .doc(cId)
                  .get();
              final eId = clusterDoc.data()?['elderId'];
              String eName = "Elder";
              if (eId != null) {
                final profile = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(eId)
                    .collection('profile')
                    .doc(eId)
                    .get();
                eName = profile.data()?['name'] ?? "Elder";
              }

              if (mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => IncomingAlertScreen(
                              clusterId: cId,
                              alertId: alertId,
                              elderName: eName,
                              alertType: alertData['type'],
                            )));
              }
            }
          }
        }
      });
      _alertSubscriptions.add(sub);
    }
  }

  @override
  void dispose() {
    for (var sub in _alertSubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _showAddElderDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('add_elder_title'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('add_elder_desc'),
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: tr('invite_code_label'),
                prefixIcon: const Icon(Icons.vpn_key_outlined,
                    color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel'),
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isEmpty) return;

              Navigator.pop(context);
              setState(() => isLoading = true);

              try {
                final clusterId = codeController.text.trim();
                final clusterDoc = await FirebaseFirestore.instance
                    .collection('elderClusters')
                    .doc(clusterId)
                    .get();

                if (!clusterDoc.exists) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('invalid_invite'))));
                  setState(() => isLoading = false);
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('elderClusters')
                    .doc(clusterId)
                    .update({
                  'primaryCaregiverId': user!.uid,
                });

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .update({
                  'clusterIds': FieldValue.arrayUnion([clusterId]),
                });

                _loadData();
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${tr('error_joining')} $e')));
                setState(() => isLoading = false);
              }
            },
            child: Text(tr('join_cluster_btn')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Flexible(
          child: Row(
            children: [
              const Icon(Icons.favorite, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tr('elders_overview'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
        actions: [
          const ThemeToggleButton(isCompact: true),
          const LanguagePicker(),
          IconButton(
            icon: const Icon(Icons.person, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const ProfileScreen(role: 'caregiver')))
                  .then((_) => _loadData());
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.logout, size: 24, color: Colors.pinkAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddElderDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(tr('add_elder'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 8,
      )
          .animate()
          .slideY(begin: 1.0, curve: Curves.easeOutBack, duration: 600.ms),
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
            child: clusterIds.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.family_restroom,
                          size: 80, color: Colors.grey.shade300)
                      .animate()
                      .scale(),
                  const SizedBox(height: 24),
                  Text(tr('no_elders_added'),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary.withOpacity(0.6)))
                      .animate()
                      .fade(delay: 200.ms),
                  const SizedBox(height: 8),
                  Text(tr('tap_add_elder'),
                          style: const TextStyle(
                              fontSize: 16, color: AppColors.textSecondary))
                      .animate()
                      .fade(delay: 300.ms),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                itemCount: clusterIds.length,
                itemBuilder: (context, index) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('elderClusters')
                        .doc(clusterIds[index])
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const AppCard(
                            child: Center(child: CircularProgressIndicator()));

                      final clusterData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      if (!snapshot.data!.exists || clusterData == null) {
                        return const SizedBox.shrink();
                      }

                      final elderId = clusterData['elderId'];
                      final clusterId = snapshot.data!.id;

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(elderId)
                            .collection('profile')
                            .doc(elderId)
                            .get(),
                        builder: (context, profileSnapshot) {
                          String elderName = "Loading...";
                          if (profileSnapshot.connectionState ==
                              ConnectionState.done) {
                            elderName = (profileSnapshot.data?.data()
                                    as Map<String, dynamic>?)?['name'] ??
                                'Elder Profiles Missing';
                          }

                          return _buildElderCard(
                                  context, clusterId, elderName, elderId)
                              .animate()
                              .fade(duration: 400.ms, delay: (index * 100).ms)
                              .slideX(begin: 0.1);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildElderCard(BuildContext context, String clusterId,
      String elderName, String elderId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ElderDetailScreen(clusterId: clusterId, elderName: elderName),
            ),
          );
        },
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person,
                      color: AppColors.primary, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(elderName,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('elderClusters')
                            .doc(clusterId)
                            .collection('alerts')
                            .where('resolved', isEqualTo: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return Text(tr('checking_alerts'),
                                style: const TextStyle(
                                    color: AppColors.textSecondary));

                          if (snapshot.data!.docs.isNotEmpty) {
                            return Row(
                              children: [
                                const Icon(Icons.warning_rounded,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                    "${snapshot.data!.docs.length} ${tr('active_alerts_count')}",
                                    style: const TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold)),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.success, size: 18),
                              const SizedBox(width: 6),
                              Text(tr('all_clear'),
                                  style: const TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 28),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMiniAction(Icons.medication_liquid_rounded,
                      tr('meds_mini'), AppColors.secondary),
                  _buildMiniAction(Icons.content_paste_rounded,
                      tr('tasks_mini'), AppColors.primary),
                  _buildMiniAction(Icons.bar_chart_rounded, tr('health_mini'),
                      AppColors.accentColor),
                  _buildMiniAction(Icons.notifications_active_rounded,
                      tr('alerts_mini'), AppColors.warning),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAction(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

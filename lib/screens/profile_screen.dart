import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui';
import '../theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileScreen extends StatefulWidget {
  final String role;

  const ProfileScreen({super.key, required this.role});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool isLoading = true;
  bool isSaving = false;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final ageController = TextEditingController();
  final bloodGroupController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final medicalConditionsController = TextEditingController();
  final emergencyMedicationController = TextEditingController();
  final emergencyContactsController = TextEditingController();
  final relationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('profile')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        nameController.text = data['name'] ?? '';
        phoneController.text = data['phone'] ?? '';
        if (widget.role == 'elder') {
          ageController.text = data['age']?.toString() ?? '';
          bloodGroupController.text = data['bloodGroup'] ?? '';
          heightController.text = data['height'] ?? '';
          weightController.text = data['weight'] ?? '';
          medicalConditionsController.text = data['medicalConditions'] ?? '';
          emergencyMedicationController.text = data['emergencyMedication'] ?? '';
          emergencyContactsController.text = data['emergencyContacts'] ?? '';
        } else {
          relationController.text = data['relationToElder'] ?? '';
        }
      } else {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
        if (userDoc.exists) {
          nameController.text = userDoc.data()?['name'] ?? '';
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (user == null) return;
    setState(() => isSaving = true);
    try {
      Map<String, dynamic> profileData = {
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
      };
      if (widget.role == 'elder') {
        profileData.addAll({
          'age': int.tryParse(ageController.text.trim()),
          'bloodGroup': bloodGroupController.text.trim(),
          'height': heightController.text.trim(),
          'weight': weightController.text.trim(),
          'medicalConditions': medicalConditionsController.text.trim(),
          'emergencyMedication': emergencyMedicationController.text.trim(),
          'emergencyContacts': emergencyContactsController.text.trim(),
        });
      } else {
        profileData.addAll({'relationToElder': relationController.text.trim()});
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('profile')
          .doc(user!.uid)
          .set(profileData, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'name': nameController.text.trim()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('profile_saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('failed_save_profile')} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    ageController.dispose();
    bloodGroupController.dispose();
    heightController.dispose();
    weightController.dispose();
    medicalConditionsController.dispose();
    emergencyMedicationController.dispose();
    emergencyContactsController.dispose();
    relationController.dispose();
    super.dispose();
  }

  Widget _buildGlassField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType, IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                icon: icon != null ? Icon(icon, color: Colors.white70, size: 20) : null,
                labelText: label,
                labelStyle: const TextStyle(color: Colors.white70),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(tr('my_profile_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 20), child: CircularProgressIndicator(color: Colors.white)))
          else
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 28),
              onPressed: _saveProfile,
            )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/default_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.3),
            child: SafeArea(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 3),
                                  ),
                                  child: const CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.white24,
                                    child: Icon(Icons.person, size: 60, color: Colors.white),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  ),
                                )
                              ],
                            ),
                          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                          const SizedBox(height: 32),
                          
                          _buildSectionHeader(tr('basic_information')),
                          _buildGlassField(tr('full_name'), nameController, icon: Icons.badge_outlined),
                          _buildGlassField(tr('phone_number'), phoneController, keyboardType: TextInputType.phone, icon: Icons.phone_outlined),

                          if (widget.role == 'elder') ...[
                            const SizedBox(height: 24),
                            _buildSectionHeader(tr('health_information')),
                            Row(
                              children: [
                                Expanded(child: _buildGlassField(tr('age'), ageController, keyboardType: TextInputType.number, icon: Icons.cake_outlined)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildGlassField(tr('blood_group'), bloodGroupController, icon: Icons.water_drop_outlined)),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: _buildGlassField(tr('height'), heightController, icon: Icons.height)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildGlassField(tr('weight'), weightController, icon: Icons.monitor_weight_outlined)),
                              ],
                            ),
                            _buildGlassField(tr('medical_conditions'), medicalConditionsController, maxLines: 3, icon: Icons.medical_information_outlined),
                            
                            const SizedBox(height: 24),
                            _buildSectionHeader(tr('emergency_information'), color: Colors.orangeAccent),
                            _buildGlassField(tr('emergency_meds'), emergencyMedicationController, maxLines: 3, icon: Icons.emergency_outlined),
                            _buildGlassField(tr('phone_number'), emergencyContactsController, maxLines: 2, keyboardType: TextInputType.phone, icon: Icons.contact_phone_outlined),
                          ] else ...[
                            const SizedBox(height: 24),
                            _buildSectionHeader(tr('role_information')),
                            _buildGlassField(tr('relation_to_elder'), relationController, icon: Icons.people_outline),
                          ],

                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary.withOpacity(0.8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: Text(tr('save_btn').toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                          ).animate().slideY(begin: 1.0, duration: 600.ms),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.withOpacity(0.9), letterSpacing: 0.5),
      ),
    );
  }
}

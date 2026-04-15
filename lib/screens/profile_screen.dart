import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

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

  // Controllers for fields
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
        // Also fetch name from base users collection if profile doesn't exist yet
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
        profileData.addAll({
          'relationToElder': relationController.text.trim(),
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('profile')
          .doc(user!.uid)
          .set(profileData, SetOptions(merge: true));

      // Also update name in the main user document
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
          SnackBar(content: Text('${tr('failed_save_profile')} ${e.toString()}')),
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

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('my_profile_title')),
        elevation: 0,
        actions: [
          if (isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 20), child: CircularProgressIndicator()))
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveProfile,
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.teal,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 30),
            
            Text(tr('basic_information'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField(tr('full_name'), nameController),
            _buildTextField(tr('phone_number'), phoneController, keyboardType: TextInputType.phone),

            if (widget.role == 'elder') ...[
              const SizedBox(height: 20),
              Text(tr('health_information'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField(tr('age'), ageController, keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(tr('blood_group'), bloodGroupController)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(tr('height'), heightController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField(tr('weight'), weightController)),
                ],
              ),
              _buildTextField(tr('medical_conditions'), medicalConditionsController, maxLines: 3),
              
              const SizedBox(height: 20),
              Text(tr('emergency_information'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              Text(tr('emergency_meds_desc'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              _buildTextField(tr('emergency_meds'), emergencyMedicationController, maxLines: 3),
              const SizedBox(height: 16),
              Text(tr('custom_emergency_contacts'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              _buildTextField(tr('comma_separated_phones'), emergencyContactsController, maxLines: 2, keyboardType: TextInputType.phone),
            ] else ...[
              const SizedBox(height: 20),
              Text(tr('role_information'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTextField(tr('relation_to_elder'), relationController),
            ],

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Profile'),
            )
          ],
        ),
      ),
    );
  }
}

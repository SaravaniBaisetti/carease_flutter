import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
          const SnackBar(content: Text('Profile saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
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
        title: const Text('My Profile'),
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
            
            const Text("Basic Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField("Full Name", nameController),
            _buildTextField("Phone Number", phoneController, keyboardType: TextInputType.phone),

            if (widget.role == 'elder') ...[
              const SizedBox(height: 20),
              const Text("Health Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField("Age", ageController, keyboardType: TextInputType.number)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Blood Group", bloodGroupController)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField("Height (cm/in)", heightController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("Weight", weightController)),
                ],
              ),
              _buildTextField("Medical Conditions", medicalConditionsController, maxLines: 3),
              
              const SizedBox(height: 20),
              const Text("Emergency Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              const Text("These medications will be displayed during an active SOS.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              _buildTextField("Emergency Medications (e.g., Nitroglycerin)", emergencyMedicationController, maxLines: 3),
              const SizedBox(height: 16),
              const Text("Custom Emergency Contacts", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              _buildTextField("Phone Numbers (comma separated)", emergencyContactsController, maxLines: 2, keyboardType: TextInputType.phone),
            ] else ...[
              const SizedBox(height: 20),
              const Text("Role Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTextField("Relation to Elder (e.g., Son, Nurse)", relationController),
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

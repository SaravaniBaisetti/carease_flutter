import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'caregiver_dashboard.dart';
import 'elder_dashboard.dart';
import 'family_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final inviteCodeController = TextEditingController();
  final authService = AuthService();
  
  String selectedRole = "elder"; // Default: elder creates cluster
  bool isLoginMode = true;
  bool isLoading = false;

  void toggleMode() {
    setState(() {
      isLoginMode = !isLoginMode;
    });
  }

  void handleAuthAction() async {
    setState(() => isLoading = true);
    try {
      if (isLoginMode) {
        // Login
        final user = await authService.signIn(
          emailController.text.trim(),
          passwordController.text.trim(),
        );

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();

        final role = doc.data()?['role'];

        if (!mounted) return;
        routeBasedOnRole(role);
      } else {
        // Sign Up — validate invite code for caregiver/family
        if (selectedRole != 'elder' && inviteCodeController.text.trim().isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invite Code is required for Caregivers and Family Members')),
          );
          setState(() => isLoading = false);
          return;
        }

        final result = await authService.signUp(
          emailController.text.trim(),
          passwordController.text.trim(),
          selectedRole,
          inviteCode: selectedRole != 'elder' ? inviteCodeController.text.trim() : null,
        );
        
        final user = result['user'];
        final clusterError = result['clusterError'] as String?;

        if (!mounted) return;

        if (clusterError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account created, but cluster join failed: $clusterError'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        if (user != null) {
          routeBasedOnRole(selectedRole);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication Failed: ${e.toString()}')),
        );
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  void routeBasedOnRole(String? role) {
    if (role == "caregiver") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CaregiverDashboard()),
      );
    } else if (role == "elder") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ElderDashboard()),
      );
    } else if (role == "family") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FamilyDashboard()),
      );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role not found')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.health_and_safety, size: 80, color: Theme.of(context).colorScheme.primary)
                    .animate().fade(duration: 600.ms).scale(curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                Text(
                  "CareEase",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ).animate().fade(delay: 200.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  isLoginMode ? "Welcome back" : "Create your account",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 48),
                
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)),
                        ),
                        
                        if (!isLoginMode) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedRole,
                            decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.person_outline)),
                            items: const [
                              DropdownMenuItem(value: 'elder', child: Text('Elder (Create Your Cluster)')),
                              DropdownMenuItem(value: 'caregiver', child: Text('Caregiver (Join Elder\'s Cluster)')),
                              DropdownMenuItem(value: 'family', child: Text('Family Member (Join Elder\'s Cluster)')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedRole = value!;
                              });
                            },
                          ),
                          if (selectedRole != 'elder') ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: inviteCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Elder\'s Cluster Invite Code',
                                prefixIcon: Icon(Icons.vpn_key_outlined),
                                helperText: 'Get this code from the elder\'s profile screen',
                              ),
                            ),
                          ],
                        ],

                        const SizedBox(height: 30),
                        if (isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          ElevatedButton(
                            onPressed: handleAuthAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isLoginMode ? "Login" : "Sign Up", style: const TextStyle(fontSize: 18)),
                          ),
                      ],
                    ),
                  ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 20),
                TextButton(
                  onPressed: toggleMode,
                  child: Text(
                    isLoginMode ? "Don't have an account? Sign Up" : "Already have an account? Login",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ).animate().fade(delay: 500.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

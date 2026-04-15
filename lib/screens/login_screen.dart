import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'caregiver_dashboard.dart';
import 'elder_dashboard.dart';
import 'family_dashboard.dart';
import '../widgets/language_picker.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_card.dart';
import '../theme/app_colors.dart';

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
          SnackBar(content: Text('${tr('auth_failed')}: ${e.toString()}')),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
                          ]
                        ),
                        child: Icon(Icons.health_and_safety, size: 80, color: AppColors.primary),
                      ).animate().fade(duration: 600.ms).scale(curve: Curves.easeOutBack),
                      
                      const SizedBox(height: 24),
                      Text(
                        tr("app_title"),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                      ).animate().fade(delay: 200.ms).slideY(begin: 0.2, end: 0),
                      
                      const SizedBox(height: 8),
                      Text(
                        isLoginMode ? tr("welcome_back") : tr("create_account"),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                      ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                      
                      const SizedBox(height: 48),
                      
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: emailController,
                              label: tr("email"),
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),
                            AppTextField(
                              controller: passwordController,
                              label: tr("password"),
                              prefixIcon: Icons.lock_outline,
                              obscureText: true,
                            ),
                            
                            if (!isLoginMode) ...[
                              const SizedBox(height: 20),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: selectedRole,
                                decoration: InputDecoration(
                                  labelText: tr("role"),
                                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                                ),
                                items: [
                                  DropdownMenuItem(value: 'elder', child: Text(tr("role_elder"))),
                                  DropdownMenuItem(value: 'caregiver', child: Text(tr("role_caregiver"))),
                                  DropdownMenuItem(value: 'family', child: Text(tr("role_family"))),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedRole = value!;
                                  });
                                },
                              ),
                              if (selectedRole != 'elder') ...[
                                const SizedBox(height: 20),
                                AppTextField(
                                  controller: inviteCodeController,
                                  label: tr("invite_code"),
                                  prefixIcon: Icons.vpn_key_outlined,
                                  helperText: tr("invite_helper"),
                                ),
                              ],
                            ],
        
                            const SizedBox(height: 32),
                            AppButton(
                              text: isLoginMode ? tr("login_btn") : tr("signup_btn"),
                              isLoading: isLoading,
                              onPressed: handleAuthAction,
                            ),
                          ],
                        ),
                      ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
                      
                      const SizedBox(height: 24),
                      AppButton(
                        variant: AppButtonVariant.text,
                        text: isLoginMode ? tr("no_account") : tr("have_account"),
                        onPressed: toggleMode,
                      ).animate().fade(delay: 500.ms),
                    ],
                  ),
                ),
              ),
              const Positioned(
                top: 10,
                right: 10,
                child: LanguagePicker(),
              ),
            ],
          ),
        ),
      );
  }
}

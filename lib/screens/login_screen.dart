import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  final user = await authService.signIn(
                    emailController.text.trim(),
                    passwordController.text.trim(),
                  );

                  final doc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .get();

                  final role = doc.data()?['role'];

                  print("Logged in as: $role");

                  if (role == "caregiver") {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => CaregiverDashboard()),
                    );
                  } else if (role == "elder") {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => ElderDashboard()),
                    );
                  } else if (role == "family") {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => FamilyDashboard()),
                    );
                  }
                } catch (e) {
                  print("Login failed: $e");
                }
              },
              child: const Text("Login"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await authService.signUp(
                    emailController.text.trim(),
                    passwordController.text.trim(),
                    "caregiver", // temporary role
                  );
                  print("Signup successful");
                } catch (e) {
                  print("Signup failed: $e");
                }
              },
              child: const Text("Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}

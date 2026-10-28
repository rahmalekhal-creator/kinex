import 'package:flutter/material.dart';

import 'package:reeducation/features/auth/pages/signup_screen.dart';

class ClinicRegisterScreen extends StatelessWidget {
  const ClinicRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Keep this route for backward compatibility while using the unified signup UI.
    return const SignupScreen();
  }
}






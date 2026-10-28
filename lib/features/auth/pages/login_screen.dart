import 'package:flutter/material.dart';
import 'package:reeducation/auth_session.dart';
import 'package:reeducation/features/notifications/data/unread_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reeducation/features/patient/pages/patient_home_page.dart';
import 'package:reeducation/features/therapist/pages/physiotherapist_home_page.dart';
import 'package:reeducation/features/admin/pages/admin_dashboard_page.dart';
import 'package:reeducation/features/clinic/pages/clinic_dashboard_page.dart';
import 'package:reeducation/features/auth/pages/signup_screen.dart';

import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/login_provider.dart';
import 'package:reeducation/widgets/kinex_logo.dart';
import 'package:reeducation/widgets/language_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final SQLdata db = SQLdata();
  final _formKey = GlobalKey<FormState>();
  String _email = '', _password = '';
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSubmitting = true);

      final Map<String, dynamic> loginresult = await db.login(_email, _password);

      if (!mounted) {
        return;
      }

      setState(() => _isSubmitting = false);

      if (!loginresult["error"] && loginresult["message"] == "Login successful") {
        final int id = int.tryParse(loginresult["id"]?.toString() ?? '') ?? 0;
        final int accountId = int.tryParse(loginresult["account_id"]?.toString() ?? '') ?? id;
        final String role = loginresult["role"]?.toString() ?? '';
        final bool isPremium = loginresult["isPremium"] == 1 || loginresult["isPremium"]?.toString() == '1';
        ref.read(AccountIdProvider.notifier).state = id;
        ref.read(roleProvider.notifier).state = role;
        ref.read(isSubProvider.notifier).state = isPremium;
        AuthSession.token = loginresult["token"]?.toString();
        UnreadNotifier.instance.reset();
        _showSuccessPopup(role: role, accountId: accountId, entityId: id);
      } else {
        _showFailedPopup(localizeServerMessage(loginresult["message"]?.toString() ?? ''));
      }
    }
  }

  void _showSuccessPopup({required String role, required int accountId, required int entityId}) {
    // Capture outer context BEFORE opening dialog to avoid context shadowing
    final outerContext = context;
    showDialog(
      context: outerContext,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101B30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              const Icon(Icons.check_circle_rounded, size: 60, color: Color(0xFF63E6FF)),
              const SizedBox(height: 10),
              Text(
                context.l10n.loginSuccessTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            context.l10n.loginSuccessBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFA8B3CF), height: 1.4),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop(); // close dialog
                  Widget destination;
                  if (role.toLowerCase() == 'patient') {
                    destination = PatientHomePage(accountId: accountId);
                  } else if (role.toLowerCase() == 'therapist' || role.toLowerCase() == 'physiotherapist') {
                    destination = PhysiotherapistHomePage(accountId: accountId);
                  } else if (role.toLowerCase() == 'clinic') {
                    destination = ClinicDashboardPage(accountId: accountId);
                  } else if (role.toLowerCase() == 'admin') {
                    destination = AdminDashboardPage(accountId: accountId);
                  } else {
                    return;
                  }
                  // Clear entire back stack so Android back button exits the app
                  Navigator.pushAndRemoveUntil(
                    outerContext,
                    MaterialPageRoute(builder: (_) => destination),
                    (_) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF63E6FF),
                  foregroundColor: const Color(0xFF071120),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  context.l10n.continueLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFailedPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101B30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              const Icon(Icons.error_outline_rounded, size: 60, color: Color(0xFF8A7CFF)),
              const SizedBox(height: 10),
              Text(
                context.l10n.loginFailedTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFA8B3CF), height: 1.4),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A7CFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  context.l10n.retry,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF071120),
              Color(0xFF0C1730),
              Color(0xFF121F3F),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -30,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF63E6FF).withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -20,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8A7CFF).withValues(alpha: 0.12),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF63E6FF), Color(0xFF8A7CFF)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF63E6FF).withValues(alpha: 0.30),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                           child: const Center(
                             child: KinexLogo(size: 66, radius: 33),
                           ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             KinexLogo(size: 18, radius: 5),
                            SizedBox(width: 8),
                            Text(
                               'Kinex',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.welcomeBack,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.loginTagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF63E6FF),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.loginIntro,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFA8B3CF),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.20),
                              blurRadius: 26,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.signInToYourAccount,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.useRegisteredCredentials,
                                style: const TextStyle(
                                  color: Color(0xFFA8B3CF),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 22),
                              TextFormField(
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white),
                                decoration: _fieldDecoration(
                                  label: l10n.emailAddress,
                                  hint: l10n.emailHint,
                                  icon: Icons.alternate_email_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.pleaseEnterEmail;
                                  }
                                  final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
                                  if (!emailRegex.hasMatch(value)) {
                                    return l10n.enterValidEmail;
                                  }
                                  return null;
                                },
                                onSaved: (value) => _email = value!.trim(),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: Colors.white),
                                decoration: _fieldDecoration(
                                  label: l10n.password,
                                  hint: l10n.enterYourPassword,
                                  icon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: const Color(0xFFA8B3CF),
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return l10n.pleaseEnterPassword;
                                  }
                                  if (value.length < 6) {
                                    return l10n.passwordMinLength;
                                  }
                                  return null;
                                },
                                onSaved: (value) => _password = value!,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF63E6FF),
                                    foregroundColor: const Color(0xFF071120),
                                    disabledBackgroundColor: const Color(0xFF63E6FF).withValues(alpha: 0.45),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF071120)),
                                          ),
                                        )
                                      : Text(
                                          l10n.login,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              l10n.becomePartnerClinic,
                              style: const TextStyle(color: Color(0xFFA8B3CF)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                                );
                              },
                              child: Text(
                                l10n.registerYourClinic,
                                style: const TextStyle(
                                  color: Color(0xFF63E6FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PositionedDirectional(
                top: 4,
                end: 4,
                child: LanguageButton(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFFA8B3CF)),
      hintStyle: const TextStyle(color: Color(0xFF6E7A98)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      prefixIcon: Icon(icon, color: const Color(0xFF63E6FF)),
      suffixIcon: suffixIcon,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFF63E6FF), width: 1.2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFFF7A9E)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFFF7A9E), width: 1.2),
      ),
    );
  }
}



import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/login_provider.dart';
import 'package:reeducation/widgets/kinex_logo.dart';
import 'package:reeducation/widgets/language_button.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final SQLdata _db = SQLdata();

  bool _isSubmitting = false;
  bool _obscurePassword = true;

  String _email = '';
  String _password = '';
  String _clinicName = '';
  String _address = '';
  String _phone = '';
  File? _justifFile;

  Future<void> _pickJustifFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) {
      return;
    }

    setState(() {
      _justifFile = File(result.files.first.path!);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_justifFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.uploadJustificationPrompt)),
      );
      return;
    }
    _formKey.currentState?.save();

    setState(() => _isSubmitting = true);
    final response = await _db.clinicSignup(
      email: _email,
      password: _password,
      clinicName: _clinicName,
      address: _address,
      phone: _phone,
      justifFile: _justifFile,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);

    final success = response['error'] != true;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF101B30),
        title: Row(
          children: [
            Icon(
              success ? Icons.verified_rounded : Icons.error_outline_rounded,
              color: success ? const Color(0xFF63E6FF) : const Color(0xFFFF7A9E),
            ),
            const SizedBox(width: 8),
            Text(
              success ? context.l10n.requestSent : context.l10n.registrationFailed,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          localizeServerMessage((response['message'] ?? '').toString()),
          style: const TextStyle(color: Color(0xFFA8B3CF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.ok, style: const TextStyle(color: Color(0xFF63E6FF))),
          ),
        ],
      ),
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF071120), Color(0xFF0C1730), Color(0xFF121F3F)],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          KinexLogo(size: 18, radius: 5),
                          SizedBox(width: 8),
                          Text('Kinex', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const LanguageButton(color: Colors.white),
                    IconButton(
                      tooltip: l10n.toggleTheme,
                      onPressed: () {
                        final container = ProviderScope.containerOf(context, listen: false);
                        final current = container.read(themeModeProvider);
                        container.read(themeModeProvider.notifier).state =
                            current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                      },
                      icon: Icon(
                        Theme.of(context).brightness == Brightness.dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.clinicRegistration,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.clinicRegistrationIntro,
                  style: const TextStyle(color: Color(0xFFA8B3CF), height: 1.5),
                ),
                const SizedBox(height: 22),
                _card(
                  child: Column(
                    children: [
                      _field(
                        label: l10n.clinicName,
                        icon: Icons.local_hospital_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
                        onSaved: (v) => _clinicName = v!.trim(),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: l10n.clinicEmail,
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return l10n.required;
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                            return l10n.invalidEmailFormat;
                          }
                          return null;
                        },
                        onSaved: (v) => _email = v!.trim(),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: l10n.password,
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: const Color(0xFFA8B3CF),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return l10n.required;
                          if (v.trim().length < 6) return l10n.minSixCharacters;
                          return null;
                        },
                        onSaved: (v) => _password = v!.trim(),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: l10n.address,
                        icon: Icons.location_on_outlined,
                        onSaved: (v) => _address = (v ?? '').trim(),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        label: l10n.phone,
                        icon: Icons.call_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return null;
                          if (!RegExp(r'^[0-9+()\-\s]{6,20}$').hasMatch(value)) {
                            return l10n.invalidPhoneFormat;
                          }
                          return null;
                        },
                        onSaved: (v) => _phone = (v ?? '').trim(),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: RichText(
                          text: TextSpan(
                            text: l10n.justificationFile,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            children: const [
                              TextSpan(text: '*', style: TextStyle(color: Color(0xFFFF7A9E))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickJustifFile,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(
                              color: _justifFile == null
                                  ? const Color(0xFFFF7A9E).withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.upload_file_rounded, color: Color(0xFF63E6FF)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _justifFile == null
                                      ? l10n.tapToUploadDocument
                                      : _justifFile!.path.split(Platform.pathSeparator).last,
                                  style: TextStyle(
                                    color: _justifFile == null ? const Color(0xFFA8B3CF) : Colors.white,
                                    fontWeight: _justifFile == null ? FontWeight.w500 : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (_justifFile != null)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Color(0xFFFF7A9E)),
                                  onPressed: () => setState(() => _justifFile = null),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.justificationReviewNote,
                          style: const TextStyle(color: Color(0xFFA8B3CF), fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF63E6FF),
                    foregroundColor: const Color(0xFF071120),
                      disabledBackgroundColor: const Color(0xFF63E6FF).withValues(alpha: 0.45),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.3, color: Color(0xFF071120)),
                        )
                      : Text(l10n.submitForApproval, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    l10n.clinicOnlySignupNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFA8B3CF), fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _field({
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onSaved: onSaved,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFA8B3CF)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        prefixIcon: Icon(icon, color: const Color(0xFF63E6FF)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}


import 'dart:io';

import 'package:flutter/material.dart';
import 'package:reeducation/features/exercise_ai/core/tracked_exercises.dart';
import 'package:reeducation/features/exercise_ai/hip/hip_module.dart' show loadHipSpec;
import 'package:reeducation/features/exercise_ai/pages/session_feedback_page.dart';
import 'package:reeducation/features/exercise_ai/voice/voice_lines.dart'
    show armWord, bodyRegionLabel, sideWord, trackedExerciseLabel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/l10n/value_labels.dart';
import 'package:reeducation/login_provider.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';
import 'package:reeducation/features/auth/pages/login_screen.dart';
import 'physio_complaints_page.dart';
import 'physio_messages_page.dart';
import 'package:reeducation/auth_session.dart';
import 'package:reeducation/features/notifications/data/app_notification.dart';
import 'package:reeducation/features/notifications/data/notifications_api.dart';
import 'package:reeducation/features/notifications/data/unread_notifier.dart';
import 'package:reeducation/features/notifications/pages/notification_detail_page.dart';
import 'package:reeducation/features/notifications/pages/notifications_page.dart';
import 'package:reeducation/features/notifications/widgets/notification_bell.dart';

class PhysiotherapistHomePage extends StatefulWidget {
  final int accountId;

  const PhysiotherapistHomePage({super.key, required this.accountId});

  @override
  State<PhysiotherapistHomePage> createState() => _PhysiotherapistHomePageState();
}

class _PhysiotherapistHomePageState extends State<PhysiotherapistHomePage> {
      void _toggleTheme() {
        final container = ProviderScope.containerOf(context, listen: false);
        final current = container.read(themeModeProvider);
        container.read(themeModeProvider.notifier).state =
            current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      }

  final SQLdata _db = SQLdata();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  int _selectedTab = 0;
  bool _isLoading = true;
  bool _isUpdatingProfile = false;
  bool _isUploadingPhoto = false;
  String? _error;

  Map<String, dynamic> _homeProfile = <String, dynamic>{};
  Map<String, dynamic> _profileData = <String, dynamic>{};
  List<Map<String, dynamic>> _patients = <Map<String, dynamic>>[];
  bool _hasActiveSubscription = false;
  int _photoRefreshToken = 0;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBg => _isDark ? const Color(0xFF111827) : Colors.white;
  Color get _primaryText => Theme.of(context).colorScheme.onSurface;
  Color get _secondaryText => _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF667085);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _db.fetchPhysioHome(widget.accountId),
        _db.fetchPhysioPatients(widget.accountId),
        _db.fetchPhysioProfileTab(widget.accountId),
      ]);

      if (!mounted) return;

      final home = results[0];
      final patientsResp = results[1];
      final profileResp = results[2];

      final homeProfile = (home['profile'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final access = (home['access'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final profile = (profileResp['profile'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final patientsRaw = patientsResp['patients'];
      final patients = patientsRaw is List
          ? patientsRaw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList()
          : <Map<String, dynamic>>[];

      _nameController.text = (profile['name'] ?? homeProfile['name'] ?? '').toString();
      _phoneController.text = (profile['phone'] ?? homeProfile['phone'] ?? '').toString();
      _specializationController.text =
          (profile['specialization'] ?? homeProfile['specialization'] ?? '').toString();

      setState(() {
        _homeProfile = homeProfile;
        _profileData = profile;
        _patients = patients;
        _hasActiveSubscription = access['has_active_subscription'] == true || access['has_active_subscription'] == 1;
        _photoRefreshToken++;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizeError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await _db.uploadPatientPhoto(accountId: widget.accountId, photo: File(picked.path));
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profilePhotoUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeError(e))),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProfileChanges() async {
    if (_isUpdatingProfile) return;
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nameAndPhoneRequired)),
      );
      return;
    }

    setState(() => _isUpdatingProfile = true);
    try {
      await _db.updatePhysioProfileTab(
        accountId: widget.accountId,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        specialization: _specializationController.text.trim(),
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
      );
      _passwordController.clear();
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileUpdatedSuccessfully)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeError(e))),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingProfile = false);
    }
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationsPage(
          onOpen: _openNotification,
          categories: NotificationsPage.physioCategories,
          showSettings: true,
        )),
    );
  }

  /// A message opens the conversation; a notification about a patient opens its details, from where the
  /// physiotherapist can open the patient's file or write to the patient.
  Future<void> _openNotification(BuildContext context, AppNotification n) async {
    if (n.type == 'message') {
      final other = n.number('sender_account_id');
      if (other <= 0) throw const NotificationsException(NotificationsFailure.notFound);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhysioMessagesPage(
            accountId: widget.accountId,
            patientAccountId: other,
            patientName: n.str('sender_name'),
          ),
        ),
      );
      return;
    }
    if (!n.isAboutPatient) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailPage(
          notification: n,
          onOpenPatient: (ctx, patientId, name) => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => PhysioPatientDetailPage(
                accountId: widget.accountId,
                patientId: patientId,
                patientName: name,
                canViewAiFeedback: _hasActiveSubscription,
              ),
            ),
          ),
          onMessagePatient: (ctx, patientAccountId, name, draft) => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => PhysioMessagesPage(
                accountId: widget.accountId,
                patientAccountId: patientAccountId,
                patientName: name,
                initialDraft: draft,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: kinexAppBar(
        title: _selectedTab == 0 ? l10n.physioHome : l10n.physioProfile,
        actions: [
          NotificationBell(onPressed: _openNotifications),
          if (_selectedTab == 0)
            IconButton(
              tooltip: l10n.viewComplaints,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhysioComplaintsPage(accountId: widget.accountId),
                  ),
                );
              },
              icon: const Icon(Icons.feedback_outlined),
            ),
          IconButton(
            tooltip: l10n.logOut,
            onPressed: () {
              AuthSession.clear();
              UnreadNotifier.instance.reset();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: l10n.toggleTheme,
        onPressed: _toggleTheme,
        child: Icon(
          Theme.of(context).brightness == Brightness.dark
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
        backgroundColor: _cardBg,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: _secondaryText,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.groups_outlined), label: l10n.patients),
          BottomNavigationBarItem(icon: const Icon(Icons.person_outline_rounded), label: l10n.profile),
        ],
      ),
      body: KinexScreenBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorView()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: KeyedSubtree(
                        key: ValueKey<int>(_selectedTab),
                        child: _selectedTab == 0 ? _buildPatientsTab() : _buildProfileTab(),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? context.l10n.unknownError,
              style: const TextStyle(color: Color(0xFFB42318), fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.myPatients,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 10),
          _aiBanner(),
          const SizedBox(height: 6),
          Text(
            _hasActiveSubscription
                ? context.l10n.subscriptionActiveAiUnlocked
                : context.l10n.subscriptionInactiveAiLocked,
            style: TextStyle(
              color: _hasActiveSubscription ? const Color(0xFF2F9E44) : const Color(0xFFB54708),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (_patients.isEmpty)
            _infoCard(context.l10n.noAssignedPatients)
          else
            ..._patients.map((patient) => _buildPatientCard(patient)),
        ],
      ),
    );
  }

  Widget _aiBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E90FA), Color(0xFF7C4DFF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.physioAiBanner,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final name = (patient['name'] ?? context.l10n.patient).toString();
    final phone = (patient['phone'] ?? '').toString();
    final assigned = int.tryParse((patient['assigned_count'] ?? 0).toString()) ?? 0;
    final completed = int.tryParse((patient['completed_count'] ?? 0).toString()) ?? 0;
    final progress = assigned > 0 ? (completed / assigned).clamp(0, 1).toDouble() : 0.0;
    final patientId = int.tryParse((patient['patient_id'] ?? 0).toString()) ?? 0;
    final patientAccountId = int.tryParse((patient['account_id'] ?? 0).toString()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          if (phone.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(phone, style: TextStyle(color: _primaryText, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 8),
          Text(
            context.l10n.completedOfAssigned('$completed', '$assigned'),
            style: TextStyle(fontWeight: FontWeight.w700, color: _primaryText),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: const Color(0xFFE4E7EC),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E90FA)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhysioPatientDetailPage(
                          accountId: widget.accountId,
                          patientId: patientId,
                          patientName: name,
                          canViewAiFeedback: _hasActiveSubscription,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: Text(context.l10n.manage),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: patientAccountId > 0
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhysioMessagesPage(
                                accountId: widget.accountId,
                                patientAccountId: patientAccountId,
                                patientName: name,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(context.l10n.message),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final profile = _profileData.isNotEmpty ? _profileData : _homeProfile;
    final l10n = context.l10n;
    final name = (profile['name'] ?? l10n.physiotherapist).toString();
    final specialization = (profile['specialization'] ?? '').toString();
    final clinicName = (_homeProfile['clinic_name'] ?? '').toString();
    final photoUrl = _withCacheBuster(_normalizePhotoUrl((profile['photo_url'] ?? '').toString()));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: Color(0xFF2E90FA), size: 30),
              const SizedBox(width: 8),
              Text(
                l10n.profile,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.manageDetailsAndClinic,
            style: TextStyle(color: _secondaryText),
          ),
          const SizedBox(height: 14),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: const Color(0xFFDDE3EC),
                  child: photoUrl.trim().isEmpty
                      ? const Icon(Icons.person_rounded, size: 56, color: Color(0xFF64748B))
                      : ClipOval(
                          child: Image.network(
                            photoUrl,
                            width: 112,
                            height: 112,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person_rounded, size: 56, color: Color(0xFF64748B));
                            },
                          ),
                        ),
                ),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E90FA),
                        shape: BoxShape.circle,
                      ),
                      child: _isUploadingPhoto
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
          if (specialization.trim().isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  specialization,
                  style: TextStyle(color: _primaryText, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (clinicName.trim().isNotEmpty) _infoCard(l10n.clinicValue(clinicName)),
          if (clinicName.trim().isNotEmpty) const SizedBox(height: 12),
          _infoCard(_hasActiveSubscription
              ? l10n.subscriptionActiveAiAvailable
              : l10n.subscriptionInactiveAiHidden),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: Color(0xFF2E90FA)),
                    const SizedBox(width: 8),
                    Text(
                      l10n.editInformation,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: _primaryText),
                  decoration: _inputDecoration(l10n.name, Icons.person_outline_rounded),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  style: TextStyle(color: _primaryText),
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(l10n.phone, Icons.phone_outlined),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _specializationController,
                  style: TextStyle(color: _primaryText),
                  decoration: _inputDecoration(l10n.specialization, Icons.school_outlined),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  style: TextStyle(color: _primaryText),
                  obscureText: true,
                  decoration: _inputDecoration(l10n.newPasswordOptional, Icons.lock_outline_rounded),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUpdatingProfile ? null : _saveProfileChanges,
                    child: _isUpdatingProfile
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(l10n.saveProfile),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AuthSession.clear();
                      UnreadNotifier.instance.reset();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    label: Text(l10n.logOut, style: const TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: _primaryText)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _secondaryText),
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2E90FA), width: 1.2),
      ),
    );
  }

  String _normalizePhotoUrl(String rawUrl) {
    final raw = rawUrl.trim().replaceAll('\\', '/');
    if (raw.isEmpty) {
      return '';
    }

    if (raw.startsWith('C:/wamp64/www/reed/')) {
      return _db.convertLocalPathToUrl(raw);
    }

    if (raw.startsWith('uploads/') || raw.startsWith('/uploads/')) {
      return '${_db.phpapi}${raw.replaceFirst(RegExp('^/+'), '')}';
    }

    return raw;
  }

  String _withCacheBuster(String url) {
    if (url.isEmpty) return '';
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['v'] = _photoRefreshToken.toString();
    return uri.replace(queryParameters: qp).toString();
  }
}

class PhysioPatientDetailPage extends StatefulWidget {
  final int accountId;
  final int patientId;
  final String patientName;
  final bool canViewAiFeedback;

  const PhysioPatientDetailPage({
    super.key,
    required this.accountId,
    required this.patientId,
    required this.patientName,
    required this.canViewAiFeedback,
  });

  @override
  State<PhysioPatientDetailPage> createState() => _PhysioPatientDetailPageState();
}

class _PhysioPatientDetailPageState extends State<PhysioPatientDetailPage> {
  final SQLdata _db = SQLdata();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBg => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardBg => _isDark ? const Color(0xFF111827) : Colors.white;
  Color get _primaryText => Theme.of(context).colorScheme.onSurface;
  Color get _secondaryText => _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280);

  bool _isLoading = true;
  bool _isAssigning = false;
  String? _error;

  Map<String, dynamic> _patient = <String, dynamic>{};
  List<Map<String, dynamic>> _assigned = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _catalog = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _logs = <Map<String, dynamic>>[];

  /// Prescriptions & Daily Schedule tracking
  int _selectedMainView = 0; // 0: Prescriptions, 1: Schedule & Logs
  int _selectedPrescriptionTab = 0; // 0: Active, 1: Past / Completed
  String _selectedScheduleFilter = 'All'; // 'All', 'Today', 'Yesterday', 'This Week', 'Last Week', 'Older'

  List<Map<String, dynamic>> _prescriptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _activePrescriptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _pastPrescriptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _dailyInstances = <Map<String, dynamic>>[];
  Map<String, dynamic> _adherenceStats = <String, dynamic>{};

  /// e4 (hip abduction): sessions (per day) with reps per class, good-form share, median lift and target.
  Map<String, dynamic> _e4Progress = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _db.fetchPhysioPatientDetails(
        accountId: widget.accountId,
        patientId: widget.patientId,
      );
      if (!mounted) return;

      final patient = (data['patient'] as Map<String, dynamic>? ?? <String, dynamic>{});
      final assignedRaw = data['assigned_exercises'];
      final catalogRaw = data['exercise_catalog'];
      final logsRaw = data['progress_logs'];
      final e4Raw = data['e4_progress'];

      final assignedList = assignedRaw is List
          ? assignedRaw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList()
          : <Map<String, dynamic>>[];
      final catalogList = catalogRaw is List
          ? catalogRaw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList()
          : <Map<String, dynamic>>[];
      final logsList = logsRaw is List
          ? logsRaw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList()
          : <Map<String, dynamic>>[];

      final prescriptionsRaw = data['prescriptions'];
      final activeRxRaw = data['active_prescriptions'];
      final pastRxRaw = data['past_prescriptions'];
      final dailyRaw = data['daily_instances'];
      final adherenceRaw = data['adherence_stats'];

      List<Map<String, dynamic>> prescriptions = prescriptionsRaw is List
          ? prescriptionsRaw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList()
          : <Map<String, dynamic>>[];
      List<Map<String, dynamic>> activeRx = activeRxRaw is List
          ? activeRxRaw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList()
          : <Map<String, dynamic>>[];
      List<Map<String, dynamic>> pastRx = pastRxRaw is List
          ? pastRxRaw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList()
          : <Map<String, dynamic>>[];
      List<Map<String, dynamic>> dailyInstances = dailyRaw is List
          ? dailyRaw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList()
          : <Map<String, dynamic>>[];
      Map<String, dynamic> adherenceStats = adherenceRaw is Map
          ? adherenceRaw.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};

      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Fallback calculation for prescriptions if backend did not send them
      if (prescriptions.isEmpty && assignedList.isNotEmpty) {
        final Map<String, Map<String, dynamic>> rxMap = {};
        for (final item in assignedList) {
          final peId = int.tryParse((item['id'] ?? 0).toString()) ?? 0;
          final rxId = (item['prescription_id'] ?? 'rx_$peId').toString();
          final assignedDate = (item['assigned_date'] ?? item['date'] ?? todayStr).toString().split(' ').first;
          final startDate = (item['start_date'] ?? assignedDate).toString().split(' ').first;
          final endDate = (item['end_date'] ?? assignedDate).toString().split(' ').first;
          final isCompleted = (item['status'] ?? '').toString().toLowerCase() == 'completed' || item['is_completed'] == true;

          if (!rxMap.containsKey(rxId)) {
            rxMap[rxId] = {
              'prescription_id': rxId,
              'id': peId,
              'first_pe_id': peId,
              'exercise_id': item['exercise_id'],
              'exercise_name': item['name'] ?? item['exercise_name'] ?? '',
              'name': item['name'] ?? item['exercise_name'] ?? '',
              'start_date': startDate,
              'end_date': endDate,
              'frequency': item['frequency'] ?? 'daily',
              'sets': item['sets'] ?? 0,
              'reps': item['reps'] ?? 0,
              'ai_exercise': item['ai_exercise'],
              'side': item['side'],
              'target_deg': item['target_deg'],
              'total_days': 0,
              'completed_days': 0,
            };
          }
          rxMap[rxId]!['total_days'] = (rxMap[rxId]!['total_days'] as int) + 1;
          if (isCompleted) {
            rxMap[rxId]!['completed_days'] = (rxMap[rxId]!['completed_days'] as int) + 1;
          }
        }
        for (final rx in rxMap.values) {
          final total = rx['total_days'] as int;
          final comp = rx['completed_days'] as int;
          rx['progress_percent'] = total > 0 ? ((comp * 100) / total).round() : 0;
          final end = (rx['end_date'] ?? '').toString();
          final isActive = end.isEmpty || end.compareTo(todayStr) >= 0;
          rx['is_active'] = isActive ? 1 : 0;
          prescriptions.add(rx);
          if (isActive) {
            activeRx.add(rx);
          } else {
            pastRx.add(rx);
          }
        }
      }

      // Fallback for daily instances if backend did not send them
      if (dailyInstances.isEmpty && assignedList.isNotEmpty) {
        for (final item in assignedList) {
          final peId = int.tryParse((item['id'] ?? 0).toString()) ?? 0;
          final assignedDate = (item['assigned_date'] ?? item['date'] ?? todayStr).toString().split(' ').first;
          final rawStatus = (item['status'] ?? 'Pending').toString();
          final isCompleted = rawStatus.toLowerCase() == 'completed' || rawStatus.toLowerCase() == 'done';
          String computedStatus;
          if (isCompleted) {
            computedStatus = 'completed';
          } else if (assignedDate.isNotEmpty && assignedDate.compareTo(todayStr) < 0) {
            computedStatus = 'missed';
          } else if (assignedDate.isNotEmpty && assignedDate == todayStr) {
            computedStatus = 'pending';
          } else {
            computedStatus = 'upcoming';
          }
          dailyInstances.add({
            'id': peId,
            'prescription_id': item['prescription_id'] ?? 'rx_$peId',
            'exercise_id': item['exercise_id'],
            'exercise_name': item['name'] ?? item['exercise_name'] ?? '',
            'name': item['name'] ?? item['exercise_name'] ?? '',
            'date': assignedDate,
            'assigned_date': assignedDate,
            'status': computedStatus,
            'sets': item['sets'] ?? 0,
            'reps': item['reps'] ?? 0,
            'ai_exercise': item['ai_exercise'],
            'side': item['side'],
            'target_deg': item['target_deg'],
            'progress_id': item['progress_id'],
            'has_ai_feedback': item['has_ai_feedback'] ?? 0,
            'reps_done': item['reps_done'],
            'pain_level': item['pain_level'],
            'notes': item['notes'],
          });
        }
      }

      // Fallback for adherence stats
      if (adherenceStats.isEmpty && dailyInstances.isNotEmpty) {
        int sched = 0;
        int comp = 0;
        int missed = 0;
        int pending = 0;
        int upcoming = 0;
        for (final inst in dailyInstances) {
          final d = (inst['date'] ?? inst['assigned_date'] ?? '').toString().split(' ').first;
          final s = (inst['status'] ?? '').toString().toLowerCase();
          if (d.isNotEmpty && d.compareTo(todayStr) <= 0) {
            sched++;
            if (s == 'completed') {
              comp++;
            } else if (s == 'missed') {
              missed++;
            } else if (s == 'pending') {
              pending++;
            }
          } else {
            upcoming++;
          }
        }
        adherenceStats = {
          'adherence_percent': sched > 0 ? ((comp * 100) / sched).round() : 0,
          'scheduled_to_date': sched,
          'completed_to_date': comp,
          'missed_count': missed,
          'pending_today': pending,
          'upcoming_count': upcoming,
        };
      }

      setState(() {
        _patient = patient;
        _assigned = assignedList;
        _catalog = catalogList;
        _logs = logsList;
        _prescriptions = prescriptions;
        _activePrescriptions = activeRx;
        _pastPrescriptions = pastRx;
        _dailyInstances = dailyInstances;
        _adherenceStats = adherenceStats;
        _e4Progress = e4Raw is Map ? e4Raw.map((k, v) => MapEntry(k.toString(), v)) : <String, dynamic>{};
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizeError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _showAssignDialog() async {
    if (_catalog.isEmpty || _isAssigning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noExerciseInCatalog)),
      );
      return;
    }

    int selectedExerciseId = int.tryParse((_catalog.first['id'] ?? 0).toString()) ?? 0;
    String nameOf(int id) => (_catalog.firstWhere((e) => (int.tryParse((e['id'] ?? 0).toString()) ?? 0) == id,
            orElse: () => <String, dynamic>{})['name'] ?? '')
        .toString();

    String? aiExercise = guessTrackedExercise(nameOf(selectedExerciseId));
    String aiSide = 'right';
    final setsController = TextEditingController(text: '2');
    final repsController = TextEditingController(text: '10');
    final targetController = TextEditingController(text: aiExercise == 'e4' ? '25.0' : '');
    final hipSpec = await loadHipSpec();
    if (!mounted) return;

    final now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, now.day);
    DateTime endDate = startDate.add(const Duration(days: 6)); // Default: 1 Week
    String selectedPreset = '1_week'; // 'today', '3_days', '1_week', '2_weeks', 'custom'
    String frequencyType = 'daily'; // 'daily', 'weekdays', 'specific'
    final Set<int> specificWeekdays = {1, 2, 3, 4, 5}; // 1 = Mon ... 7 = Sun

    int countSessions() {
      int count = 0;
      DateTime cur = DateTime(startDate.year, startDate.month, startDate.day);
      final endNorm = DateTime(endDate.year, endDate.month, endDate.day);
      while (!cur.isAfter(endNorm)) {
        final w = cur.weekday;
        bool matches = false;
        if (frequencyType == 'daily') {
          matches = true;
        } else if (frequencyType == 'weekdays') {
          matches = (w >= 1 && w <= 5);
        } else if (frequencyType == 'specific') {
          matches = specificWeekdays.contains(w);
        }
        if (matches) count++;
        cur = cur.add(const Duration(days: 1));
      }
      return count;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          final totalSessions = countSessions();
          final startStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
          final endStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

          return AlertDialog(
            title: Text(context.l10n.assignExerciseTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedExerciseId,
                    items: _catalog.map((exercise) {
                      final id = int.tryParse((exercise['id'] ?? 0).toString()) ?? 0;
                      final name = (exercise['name'] ?? context.l10n.exercise).toString();
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedExerciseId = value;
                        aiExercise = guessTrackedExercise(nameOf(value));
                        if (aiExercise == 'e4' && targetController.text.isEmpty) {
                          targetController.text = '25.0';
                        }
                      });
                    },
                    decoration: InputDecoration(labelText: context.l10n.exercise),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('ai-$selectedExerciseId-$aiExercise'),
                    initialValue: aiExercise,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(context.l10n.trackedNone)),
                      for (final (region, items) in groupByRegion(trackedExercises, (TrackedExercise t) => t.id)) ...[
                        DropdownMenuItem<String?>(
                          value: '#$region',
                          enabled: false,
                          child: Text(
                            bodyRegionLabel(context.l10n, region).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ),
                        for (final t in items)
                          DropdownMenuItem<String?>(
                            value: t.id,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(start: 12),
                              child: Text(trackedExerciseLabel(context.l10n, t.id)),
                            ),
                          ),
                      ],
                    ],
                    selectedItemBuilder: (context) => [
                      Text(context.l10n.trackedNone),
                      for (final (region, items) in groupByRegion(trackedExercises, (TrackedExercise t) => t.id)) ...[
                        Text(bodyRegionLabel(context.l10n, region)),
                        for (final t in items)
                          Text(
                            '${bodyRegionLabel(context.l10n, region)} · ${trackedExerciseLabel(context.l10n, t.id)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ],
                    onChanged: (value) => setDialogState(() {
                      aiExercise = value;
                      if (value == 'e4' && targetController.text.isEmpty) {
                        targetController.text = '25.0';
                      }
                    }),
                    decoration: InputDecoration(labelText: context.l10n.trackedLabel),
                  ),
                  if (aiExercise != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          isLegExercise(aiExercise)
                              ? context.l10n.trackedLiftedLeg
                              : aiExercise == 'e1'
                              ? context.l10n.trackedInjuredArm
                              : context.l10n.trackedWorkingArm,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'left', label: Text(context.l10n.trackedArmLeft)),
                        ButtonSegment(value: 'right', label: Text(context.l10n.trackedArmRight)),
                      ],
                      selected: {aiSide},
                      onSelectionChanged: (v) => setDialogState(() => aiSide = v.first),
                    ),
                    if (aiExercise == 'e4') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF2E90FA)),
                          const SizedBox(width: 6),
                          Text(
                            'Target Lift Angle (Forgiving Range)',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _primaryText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('Gentle (20°)'),
                            selected: targetController.text.trim() == '20.0' || targetController.text.trim() == '20',
                            onSelected: (val) {
                              setDialogState(() => targetController.text = '20.0');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Standard (25°)'),
                            selected: targetController.text.trim() == '25.0' || targetController.text.trim() == '25',
                            onSelected: (val) {
                              setDialogState(() => targetController.text = '25.0');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Active (30°)'),
                            selected: targetController.text.trim() == '30.0' || targetController.text.trim() == '30',
                            onSelected: (val) {
                              setDialogState(() => targetController.text = '30.0');
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Auto Baseline'),
                            selected: targetController.text.trim().isEmpty,
                            onSelected: (val) {
                              setDialogState(() => targetController.clear());
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('assign_target_deg'),
                        controller: targetController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.l10n.trackedTargetAngle,
                          hintText: 'e.g. 25.0 (or leave blank for auto)',
                          helperText: 'A forgiving 2.0° tolerance buffer is applied so patients are credited for near-target reps and not frustrated.',
                          helperMaxLines: 3,
                          suffixText: '°',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: setsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: context.l10n.sets),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: repsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: context.l10n.reps),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Date Span Presets ──
                  Text('Prescription Duration', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _primaryText)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('Today'),
                        selected: selectedPreset == 'today',
                        onSelected: (val) {
                          setDialogState(() {
                            selectedPreset = 'today';
                            startDate = DateTime(now.year, now.month, now.day);
                            endDate = startDate;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('3 Days'),
                        selected: selectedPreset == '3_days',
                        onSelected: (val) {
                          setDialogState(() {
                            selectedPreset = '3_days';
                            startDate = DateTime(now.year, now.month, now.day);
                            endDate = startDate.add(const Duration(days: 2));
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('1 Week'),
                        selected: selectedPreset == '1_week',
                        onSelected: (val) {
                          setDialogState(() {
                            selectedPreset = '1_week';
                            startDate = DateTime(now.year, now.month, now.day);
                            endDate = startDate.add(const Duration(days: 6));
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('2 Weeks'),
                        selected: selectedPreset == '2_weeks',
                        onSelected: (val) {
                          setDialogState(() {
                            selectedPreset = '2_weeks';
                            startDate = DateTime(now.year, now.month, now.day);
                            endDate = startDate.add(const Duration(days: 13));
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Custom'),
                        selected: selectedPreset == 'custom',
                        onSelected: (val) async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 2),
                            initialDateRange: DateTimeRange(start: startDate, end: endDate),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedPreset = 'custom';
                              startDate = picked.start;
                              endDate = picked.end;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Frequency Selection ──
                  Text('Frequency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _primaryText)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Daily'),
                        selected: frequencyType == 'daily',
                        onSelected: (val) => setDialogState(() => frequencyType = 'daily'),
                      ),
                      ChoiceChip(
                        label: const Text('Weekdays (Mon-Fri)'),
                        selected: frequencyType == 'weekdays',
                        onSelected: (val) => setDialogState(() => frequencyType = 'weekdays'),
                      ),
                      ChoiceChip(
                        label: const Text('Specific Days'),
                        selected: frequencyType == 'specific',
                        onSelected: (val) => setDialogState(() => frequencyType = 'specific'),
                      ),
                    ],
                  ),
                  if (frequencyType == 'specific') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int d = 1; d <= 7; d++)
                          FilterChip(
                            label: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][d - 1]),
                            selected: specificWeekdays.contains(d),
                            onSelected: (sel) {
                              setDialogState(() {
                                if (sel) {
                                  specificWeekdays.add(d);
                                } else if (specificWeekdays.length > 1) {
                                  specificWeekdays.remove(d);
                                }
                              });
                            },
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),

                  // ── Summary Info Banner ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFB2DDFF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, size: 18, color: Color(0xFF1570EF)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$totalSessions session(s) scheduled\n${_formatDateRange(startStr, endStr)}',
                            style: const TextStyle(color: Color(0xFF1570EF), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
              ElevatedButton(
                onPressed: () async {
                  final sets = int.tryParse(setsController.text.trim()) ?? 0;
                  final reps = int.tryParse(repsController.text.trim()) ?? 0;
                  if (selectedExerciseId <= 0 || sets <= 0 || reps <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.selectExerciseAndValidSetsReps)),
                    );
                    return;
                  }
                  if (totalSessions <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a date range with at least 1 session.')),
                    );
                    return;
                  }
                  final target = aiExercise == 'e4' ? parseTargetDeg(targetController.text) : null;
                  if (target != null && target.isNaN) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.trackedTargetAngleInvalid)),
                    );
                    return;
                  }
                  final freqString = frequencyType == 'specific'
                      ? 'specific:${(specificWeekdays.toList()..sort()).join(',')}'
                      : frequencyType;

                  Navigator.pop(context);
                  await _assign(
                    selectedExerciseId,
                    sets,
                    reps,
                    startDate: startDate,
                    endDate: endDate,
                    frequency: freqString,
                    aiExercise: aiExercise,
                    side: aiExercise == null ? null : aiSide,
                    targetDeg: target,
                  );
                },
                child: Text(context.l10n.assign),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _assign(
    int exerciseId,
    int sets,
    int reps, {
    DateTime? startDate,
    DateTime? endDate,
    String? frequency,
    String? aiExercise,
    String? side,
    double? targetDeg,
  }) async {
    if (_isAssigning) return;
    setState(() => _isAssigning = true);
    try {
      await _db.assignPatientExerciseByPhysio(
        accountId: widget.accountId,
        patientId: widget.patientId,
        exerciseId: exerciseId,
        sets: sets,
        reps: reps,
        startDate: startDate,
        endDate: endDate,
        frequency: frequency,
        aiExercise: aiExercise,
        side: side,
        targetDeg: targetDeg,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.exerciseAssignedSuccessfully)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeError(e))),
      );
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  Future<void> _remove(int patientExerciseId, {String? prescriptionId}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Prescription'),
        content: const Text('Are you sure you want to remove this prescription and its scheduled sessions?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD92D20), foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _db.removePatientExerciseByPhysio(
        accountId: widget.accountId,
        patientExerciseId: patientExerciseId,
        prescriptionId: prescriptionId,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription removed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kinexAppBar(
        title: widget.patientName,
        actions: [
          if (widget.canViewAiFeedback)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhysioAiFeedbackPage(
                      accountId: widget.accountId,
                      patientId: widget.patientId,
                      patientName: widget.patientName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.psychology_alt_outlined),
              tooltip: context.l10n.aiFeedback,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAssignDialog,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.assignExercise),
      ),
      body: KinexScreenBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      children: [
                        // ── Patient Adherence Overview ──
                        _buildPatientStatsCard(),
                        const SizedBox(height: 16),

                        // ── This week's activity ──
                        _buildWeekActivityCard(),
                        const SizedBox(height: 16),

                        // ── e4: lift angle against target ──
                        if (_hasE4) ...[
                          _buildE4ProgressCard(),
                          const SizedBox(height: 16),
                        ],

                        // ── Main View Switcher: Prescriptions vs Schedule & Logs ──
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              icon: Icon(Icons.assignment_outlined),
                              label: Text('Prescriptions'),
                            ),
                            ButtonSegment(
                              value: 1,
                              icon: Icon(Icons.calendar_month_outlined),
                              label: Text('Schedule & Logs'),
                            ),
                          ],
                          selected: {_selectedMainView},
                          onSelectionChanged: (set) => setState(() => _selectedMainView = set.first),
                        ),
                        const SizedBox(height: 16),

                        if (_selectedMainView == 0)
                          _buildPrescriptionsView()
                        else
                          _buildScheduleAndLogsView(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildPatientStatsCard() {
    final scheduledToDate = int.tryParse((_adherenceStats['scheduled_to_date'] ?? 0).toString()) ?? 0;
    final completedToDate = int.tryParse((_adherenceStats['completed_to_date'] ?? 0).toString()) ?? 0;
    final missedCount = int.tryParse((_adherenceStats['missed_count'] ?? 0).toString()) ?? 0;
    final pendingToday = int.tryParse((_adherenceStats['pending_today'] ?? 0).toString()) ?? 0;
    final upcomingCount = int.tryParse((_adherenceStats['upcoming_count'] ?? 0).toString()) ?? 0;
    final adherencePercent = scheduledToDate > 0
        ? ((completedToDate * 100) / scheduledToDate).round().clamp(0, 100)
        : (int.tryParse((_adherenceStats['adherence_percent'] ?? 0).toString()) ?? 0).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E90FA), Color(0xFF1570EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E90FA).withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Treatment Adherence',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedToDate completed / $scheduledToDate scheduled to date',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (adherencePercent / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: (adherencePercent / 100).clamp(0.0, 1.0),
                      strokeWidth: 7,
                      backgroundColor: Colors.white30,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    Center(
                      child: Text(
                        '$adherencePercent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildStatsBadge(
                label: '$completedToDate Completed',
                bg: Colors.white.withValues(alpha: 0.22),
                icon: Icons.check_circle_outline_rounded,
              ),
              _buildStatsBadge(
                label: '$missedCount Missed',
                bg: Colors.black.withValues(alpha: 0.22),
                icon: Icons.cancel_outlined,
              ),
              _buildStatsBadge(
                label: '$pendingToday Pending Today',
                bg: Colors.white.withValues(alpha: 0.22),
                icon: Icons.hourglass_top_rounded,
              ),
              if (upcomingCount > 0)
                _buildStatsBadge(
                  label: '$upcomingCount Upcoming',
                  bg: Colors.white.withValues(alpha: 0.15),
                  icon: Icons.calendar_today_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBadge({required String label, required Color bg, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ChoiceChip(
              label: Text('Active (${_activePrescriptions.length})'),
              selected: _selectedPrescriptionTab == 0,
              onSelected: (val) => setState(() => _selectedPrescriptionTab = 0),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text('Past / Completed (${_pastPrescriptions.length})'),
              selected: _selectedPrescriptionTab == 1,
              onSelected: (val) => setState(() => _selectedPrescriptionTab = 1),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedPrescriptionTab == 0) ...[
          if (_activePrescriptions.isEmpty)
            _buildEmptySection(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No Active Prescriptions',
              subtitle: 'Tap "+ Assign Exercise" below to create a multi-day plan.',
            )
          else
            for (final rx in _activePrescriptions) _buildPrescriptionCard(rx, isActive: true),
        ] else ...[
          if (_pastPrescriptions.isEmpty)
            _buildEmptySection(
              icon: Icons.history_rounded,
              title: 'No Past Prescriptions',
              subtitle: 'Completed and expired prescriptions will be displayed here.',
            )
          else
            for (final rx in _pastPrescriptions) _buildPrescriptionCard(rx, isActive: false),
        ],
      ],
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> rx, {required bool isActive}) {
    final name = (rx['name'] ?? rx['exercise_name'] ?? 'Exercise').toString();
    final startDate = (rx['start_date'] ?? '').toString();
    final endDate = (rx['end_date'] ?? '').toString();
    final frequency = (rx['frequency'] ?? 'daily').toString();
    final sets = int.tryParse((rx['sets'] ?? 0).toString()) ?? 0;
    final reps = int.tryParse((rx['reps'] ?? 0).toString()) ?? 0;
    final totalDays = int.tryParse((rx['total_days'] ?? 0).toString()) ?? 0;
    final completedDays = int.tryParse((rx['completed_days'] ?? 0).toString()) ?? 0;
    final percent = totalDays > 0 ? ((completedDays * 100) / totalDays).round().clamp(0, 100) : 0;
    final rxId = (rx['prescription_id'] ?? rx['id'] ?? '').toString();
    final firstPeId = int.tryParse((rx['first_pe_id'] ?? rx['id'] ?? 0).toString()) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF2E90FA).withValues(alpha: 0.25) : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _primaryText)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFEAF8EC) : const Color(0xFFF2F4F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? 'Active' : (percent >= 100 ? 'Completed' : 'Ended'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isActive ? const Color(0xFF2F9E44) : const Color(0xFF667085),
                              ),
                            ),
                          ),
                          Text(
                            context.l10n.setsTimesReps('$sets', '$reps'),
                            style: TextStyle(color: _secondaryText, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _remove(firstPeId, prescriptionId: rxId),
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD92D20)),
                  tooltip: 'Delete prescription',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: _secondaryText),
                const SizedBox(width: 6),
                Text(
                  _formatDateRange(startDate, endDate),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _secondaryText),
                ),
                const SizedBox(width: 14),
                Icon(Icons.repeat_rounded, size: 15, color: _secondaryText),
                const SizedBox(width: 4),
                Text(
                  _formatFrequency(frequency),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _secondaryText),
                ),
              ],
            ),
            if ((rx['ai_exercise'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.videocam_outlined, size: 14, color: Color(0xFF2E90FA)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _trackedLine(rx),
                      style: TextStyle(color: _secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedDays of $totalDays days completed',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryText),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: percent >= 100 ? const Color(0xFF2F9E44) : const Color(0xFF2E90FA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: _isDark ? const Color(0xFF1F2937) : const Color(0xFFEAECF0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  percent >= 100 ? const Color(0xFF2F9E44) : const Color(0xFF2E90FA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleAndLogsView() {
    final now = DateTime.now();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final thisWeekStartDay = DateTime(thisWeekStart.year, thisWeekStart.month, thisWeekStart.day);
    final thisWeekStartStr = '${thisWeekStartDay.year.toString().padLeft(4, '0')}-${thisWeekStartDay.month.toString().padLeft(2, '0')}-${thisWeekStartDay.day.toString().padLeft(2, '0')}';
    final thisWeekEndDay = thisWeekStartDay.add(const Duration(days: 6));
    final thisWeekEndStr = '${thisWeekEndDay.year.toString().padLeft(4, '0')}-${thisWeekEndDay.month.toString().padLeft(2, '0')}-${thisWeekEndDay.day.toString().padLeft(2, '0')}';

    final lastWeekStartDay = thisWeekStartDay.subtract(const Duration(days: 7));
    final lastWeekStartStr = '${lastWeekStartDay.year.toString().padLeft(4, '0')}-${lastWeekStartDay.month.toString().padLeft(2, '0')}-${lastWeekStartDay.day.toString().padLeft(2, '0')}';
    final lastWeekEndDay = thisWeekStartDay.subtract(const Duration(days: 1));
    final lastWeekEndStr = '${lastWeekEndDay.year.toString().padLeft(4, '0')}-${lastWeekEndDay.month.toString().padLeft(2, '0')}-${lastWeekEndDay.day.toString().padLeft(2, '0')}';

    final filtered = _dailyInstances.where((inst) {
      final date = (inst['date'] ?? inst['assigned_date'] ?? '').toString().split(' ').first;
      if (date.isEmpty) return false;
      switch (_selectedScheduleFilter) {
        case 'Today':
          return date == todayStr;
        case 'Yesterday':
          return date == yesterdayStr;
        case 'This Week':
          return date.compareTo(thisWeekStartStr) >= 0 && date.compareTo(thisWeekEndStr) <= 0;
        case 'Last Week':
          return date.compareTo(lastWeekStartStr) >= 0 && date.compareTo(lastWeekEndStr) <= 0;
        case 'Older':
          return date.compareTo(lastWeekStartStr) < 0;
        case 'All':
        default:
          return true;
      }
    }).toList();

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final inst in filtered) {
      final date = (inst['date'] ?? inst['assigned_date'] ?? '').toString().split(' ').first;
      grouped.putIfAbsent(date, () => []).add(inst);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in ['All', 'Today', 'Yesterday', 'This Week', 'Last Week', 'Older'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: _selectedScheduleFilter == f,
                    onSelected: (val) => setState(() => _selectedScheduleFilter = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (sortedDates.isEmpty)
          _buildEmptySection(
            icon: Icons.event_busy_outlined,
            title: 'No Sessions Found',
            subtitle: 'No exercises scheduled or logged for the selected time filter.',
          )
        else
          for (final date in sortedDates) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 15, color: date == todayStr ? const Color(0xFF2E90FA) : _secondaryText),
                  const SizedBox(width: 6),
                  Text(
                    _formatHeaderDate(date),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: date == todayStr ? const Color(0xFF2E90FA) : _primaryText,
                    ),
                  ),
                  if (date == todayStr) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E90FA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ] else if (date == yesterdayStr) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('YESTERDAY', style: TextStyle(color: _secondaryText, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ],
              ),
            ),
            for (final inst in grouped[date]!) _buildDailyInstanceCard(inst),
          ],
      ],
    );
  }

  Widget _buildDailyInstanceCard(Map<String, dynamic> item) {
    final name = (item['exercise_name'] ?? item['name'] ?? 'Exercise').toString();
    final status = (item['status'] ?? 'pending').toString().toLowerCase().trim();
    final sets = int.tryParse((item['sets'] ?? 0).toString()) ?? 0;
    final reps = int.tryParse((item['reps'] ?? 0).toString()) ?? 0;
    final repsDone = item['reps_done'];
    final pain = item['pain_level'];
    final notes = (item['notes'] ?? '').toString().trim();
    final progressId = int.tryParse((item['progress_id'] ?? 0).toString()) ?? 0;
    final hasAi = item['has_ai_feedback'] == 1 || item['has_ai_feedback'] == true || progressId > 0;

    Color bg;
    Color fg;
    String statusText;
    IconData statusIcon;

    if (status == 'completed' || status == 'done') {
      bg = const Color(0xFFEAF8EC);
      fg = const Color(0xFF2F9E44);
      statusText = 'Completed';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'missed') {
      bg = const Color(0xFFFEE4E2);
      fg = const Color(0xFFD92D20);
      statusText = 'Missed';
      statusIcon = Icons.cancel_rounded;
    } else if (status == 'upcoming') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF1570EF);
      statusText = 'Upcoming';
      statusIcon = Icons.schedule_rounded;
    } else {
      bg = const Color(0xFFFEF0C7);
      fg = const Color(0xFFB54708);
      statusText = 'Pending Today';
      statusIcon = Icons.hourglass_top_rounded;
    }

    final isCompleted = status == 'completed' || status == 'done';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isCompleted && progressId > 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionFeedbackPage(
                    accountId: widget.accountId,
                    progressId: progressId,
                    title: name,
                  ),
                ),
              );
            } else {
              final peId = int.tryParse((item['id'] ?? 0).toString()) ?? 0;
              final matchingLogs = _logs.where((l) => int.tryParse((l['ppid'] ?? 0).toString()) == peId).toList();
              _showExerciseProgressSheet(item: item, exerciseLogs: matchingLogs);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primaryText)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon, size: 12, color: fg),
                                    const SizedBox(width: 4),
                                    Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
                                  ],
                                ),
                              ),
                              Text(
                                context.l10n.setsTimesReps('$sets', '$reps'),
                                style: TextStyle(color: _secondaryText, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isCompleted && hasAi)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFB2DDFF)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.psychology_alt_outlined, size: 14, color: Color(0xFF1570EF)),
                            SizedBox(width: 4),
                            Text('AI Feedback', style: TextStyle(color: Color(0xFF1570EF), fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
                if ((item['ai_exercise'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.videocam_outlined, size: 13, color: Color(0xFF2E90FA)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _trackedLine(item),
                          style: TextStyle(color: _secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (isCompleted && (repsDone != null || pain != null)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (repsDone != null) ...[
                        _statChip(
                          icon: Icons.repeat_rounded,
                          label: '$repsDone',
                          sub: context.l10n.repsDone,
                          color: const Color(0xFF2E90FA),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (pain != null)
                        _statChip(
                          icon: Icons.monitor_heart_outlined,
                          label: context.l10n.painOutOfTen('$pain'),
                          sub: context.l10n.painLevelLower,
                          color: _painColor(int.tryParse(pain.toString()) ?? 5),
                        ),
                    ],
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.notes_rounded, size: 14, color: _secondaryText),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(notes, style: TextStyle(color: _primaryText, fontSize: 12, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isCompleted && progressId > 0) ...[
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'View Detailed AI Session Feedback',
                        style: TextStyle(color: Color(0xFF2E90FA), fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF2E90FA)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySection({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: _secondaryText),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _primaryText)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatHeaderDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatDateRange(String start, String end) {
    if (start.isEmpty && end.isEmpty) return '';
    if (start == end || end.isEmpty) return _formatHeaderDate(start);
    final s = DateTime.tryParse(start);
    final e = DateTime.tryParse(end);
    if (s == null || e == null) return '$start – $end';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (s.year == e.year) {
      return '${months[s.month - 1]} ${s.day} – ${months[e.month - 1]} ${e.day}, ${s.year}';
    }
    return '${months[s.month - 1]} ${s.day}, ${s.year} – ${months[e.month - 1]} ${e.day}, ${e.year}';
  }

  String _formatFrequency(String? freq) {
    if (freq == null || freq.isEmpty || freq.toLowerCase() == 'daily') return 'Daily';
    if (freq.toLowerCase() == 'weekdays') return 'Weekdays (Mon–Fri)';
    if (freq.toLowerCase() == 'weekends') return 'Weekends (Sat–Sun)';
    if (freq.startsWith('specific:')) {
      const dayNames = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
      final days = freq.substring(9).split(',').map((s) => int.tryParse(s.trim()) ?? 0).where((i) => i >= 1 && i <= 7);
      if (days.isNotEmpty) {
        return days.map((i) => dayNames[i] ?? '').join(', ');
      }
    }
    return freq;
  }

  Widget _buildWeekActivityCard() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final weekLogs = _logs.where((log) {
      final d = DateTime.tryParse((log['date'] ?? '').toString());
      return d != null && !d.isBefore(weekStartDay);
    }).toList();

    final dailyCounts = List<int>.filled(7, 0);
    for (final log in weekLogs) {
      final d = DateTime.tryParse((log['date'] ?? '').toString());
      if (d != null) {
        final idx = (d.weekday - 1).clamp(0, 6);
        dailyCounts[idx]++;
      }
    }
    final maxCount = dailyCounts.reduce((a, b) => a > b ? a : b);
    final labels = context.l10n.weekdayInitials.split(',');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF2E90FA), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.thisWeeksActivity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.l10n.sessionsLogged('${weekLogs.length}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: _secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final count = dailyCounts[i];
                final barH = maxCount > 0 ? (count / maxCount * 50).clamp(4.0, 50.0) : 0.0;
                final isToday = i == (now.weekday - 1);
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (count > 0)
                        Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _secondaryText)),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: count > 0 ? barH : 4,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isToday
                              ? const Color(0xFF2E90FA)
                              : count > 0
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                          color: isToday ? const Color(0xFF2E90FA) : _secondaryText,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _trackedLine(Map<String, dynamic> item) {
    final l = context.l10n;
    final ex = item['ai_exercise']?.toString();
    final side = (item['side'] ?? '').toString();
    if (!isLegExercise(ex)) {
      return l.trackedSummary(trackedExerciseLabel(l, ex), armWord(l, side));
    }
    final line = l.trackedSummaryLeg(trackedExerciseLabel(l, ex), sideWord(l, ex!, side));
    final target = double.tryParse((item['target_deg'] ?? '').toString());
    return target == null ? line : '$line · ${l.trackedTargetShort(target.toStringAsFixed(0))}';
  }

  bool get _hasE4 =>
      _assigned.any((a) => a['ai_exercise']?.toString() == 'e4') ||
      ((_e4Progress['sessions'] as List?)?.isNotEmpty ?? false);

  Widget _buildE4ProgressCard() {
    final l = context.l10n;
    final sessions = ((_e4Progress['sessions'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
    double? num(Object? v) => v == null ? null : double.tryParse(v.toString());
    final usual = num(_e4Progress['usual_lift_deg']);
    final target = num(_e4Progress['target_deg']);
    final last = sessions.isEmpty ? null : sessions.last;
    final byLabel = last == null
        ? const <String, dynamic>{}
        : (last['by_label'] as Map? ?? const {}).map((k, v) => MapEntry(k.toString(), v));
    final share = last == null ? null : num(last['good_share']);
    Widget chip(String text, Color bg, Color fg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.e4ProgressTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            Text(l.e4ProgressEmpty, style: TextStyle(color: _secondaryText))
          else ...[
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _E4RangeChartPainter(
                  peaks: [for (final s in sessions) num(s['median_peak_deg'])],
                  targets: [for (final s in sessions) num(s['target_deg'])],
                  dates: [for (final s in sessions) (s['date'] ?? '').toString()],
                  lineColor: const Color(0xFF2E90FA),
                  targetColor: const Color(0xFFF79009),
                  textColor: _secondaryText,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 14, height: 3, color: const Color(0xFF2E90FA)),
                  const SizedBox(width: 4),
                  Text(l.e4ProgressMedian, style: TextStyle(fontSize: 12, color: _secondaryText)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 14, height: 3, color: const Color(0xFFF79009)),
                  const SizedBox(width: 4),
                  Text(l.e4ProgressTarget, style: TextStyle(fontSize: 12, color: _secondaryText)),
                ]),
              ],
            ),
            const SizedBox(height: 10),
            Text(l.e4ProgressPerClass, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                chip('${l.repLabelGood}: ${byLabel['good'] ?? 0}', const Color(0xFFEAF8EC), const Color(0xFF2F9E44)),
                chip('${l.repLabelKnee}: ${byLabel['knee'] ?? 0}', const Color(0xFFFFF1E6), const Color(0xFFB54708)),
                chip('${l.repLabelLeanin}: ${byLabel['leanin'] ?? 0}', const Color(0xFFFFF1E6), const Color(0xFFB54708)),
                chip('${l.repLabelLeanout}: ${byLabel['leanout'] ?? 0}', const Color(0xFFFFF1E6), const Color(0xFFB54708)),
                if (share != null)
                  chip(l.e4ProgressGoodShare((share * 100).round()), const Color(0xFFEFF6FF), const Color(0xFF2E90FA)),
              ],
            ),
          ],
          if (usual != null || target != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (target != null) '${l.e4ProgressTarget}: ${target.toStringAsFixed(0)}°',
                if (usual != null) l.e4ProgressUsualLift(usual.toStringAsFixed(0)),
              ].join(' · '),
              style: TextStyle(color: _secondaryText, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> item) {
    final patientExerciseId = int.tryParse((item['id'] ?? 0).toString()) ?? 0;
    final name = (item['name'] ?? context.l10n.exercise).toString();
    final status = (item['status'] ?? 'Pending').toString();
    final sets = int.tryParse((item['sets'] ?? 0).toString()) ?? 0;
    final reps = int.tryParse((item['reps'] ?? 0).toString()) ?? 0;
    final isCompleted = status.toLowerCase().trim() == 'completed' || status.toLowerCase().trim() == 'done';
    final latestProgress = (item['latest_progress'] is Map<String, dynamic>)
        ? item['latest_progress'] as Map<String, dynamic>
        : <String, dynamic>{};
    final repsDone = latestProgress['reps_done'];

    final exerciseLogs = _logs.where((log) {
      return int.tryParse((log['ppid'] ?? 0).toString()) == patientExerciseId;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showExerciseProgressSheet(
          item: item,
          exerciseLogs: exerciseLogs,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _primaryText)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted ? const Color(0xFFEAF8EC) : const Color(0xFFFFF1E6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                statusLabel(context.l10n, status),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isCompleted ? const Color(0xFF2F9E44) : const Color(0xFFB54708),
                                ),
                              ),
                            ),
                            Text(
                              context.l10n.setsTimesReps('$sets', '$reps'),
                              style: TextStyle(color: _secondaryText, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        if ((item['ai_exercise'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.videocam_outlined, size: 14, color: Color(0xFF2E90FA)),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _trackedLine(item),
                                    style: TextStyle(color: _secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (repsDone != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              context.l10n.latestRepsDone('$repsDone'),
                              style: TextStyle(color: _secondaryText, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (exerciseLogs.isNotEmpty)
                        Container(
                          margin: const EdgeInsetsDirectional.only(end: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            context.l10n.logsCount('${exerciseLogs.length}'),
                            style: const TextStyle(color: Color(0xFF2E90FA), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      Icon(Icons.chevron_right_rounded, color: _secondaryText),
                      IconButton(
                        onPressed: patientExerciseId > 0 ? () => _remove(patientExerciseId) : null,
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD92D20)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExerciseProgressSheet({
    required Map<String, dynamic> item,
    required List<Map<String, dynamic>> exerciseLogs,
  }) {
    final name = (item['name'] ?? item['exercise_name'] ?? context.l10n.exercise).toString();
    final status = (item['status'] ?? 'Pending').toString();
    final sets = int.tryParse((item['sets'] ?? 0).toString()) ?? 0;
    final reps = int.tryParse((item['reps'] ?? 0).toString()) ?? 0;
    final isCompleted = status.toLowerCase().trim() == 'completed' || status.toLowerCase().trim() == 'done';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: _pageBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCompleted ? const Color(0xFFEAF8EC) : const Color(0xFFFFF1E6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      statusLabel(context.l10n, status),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isCompleted ? const Color(0xFF2F9E44) : const Color(0xFFB54708),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    context.l10n.setsTimesReps('$sets', '$reps'),
                                    style: const TextStyle(color: Color(0xFF475467), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: exerciseLogs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.assignment_outlined, size: 48, color: _secondaryText),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.l10n.noProgressReportsForExercise,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: _secondaryText, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: exerciseLogs.length,
                            itemBuilder: (ctx, i) {
                              final log = exerciseLogs[i];
                              final date = log['date']?.toString() ?? '';
                              final repsDone = log['reps_done'];
                              final pain = log['pain_level'];
                              final notes = (log['notes'] ?? '').toString().trim();
                              final parsedDate = DateTime.tryParse(date);
                              final dateLabel = parsedDate != null
                                  ? context.l10n.dateAtTime('${parsedDate.day}/${parsedDate.month}/${parsedDate.year}', '${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}')
                                  : date;

                              final progressId = int.tryParse((log['id'] ?? 0).toString()) ?? 0;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: _cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: progressId <= 0
                                        ? null
                                        : () => Navigator.push(
                                              ctx,
                                              MaterialPageRoute(
                                                builder: (_) => SessionFeedbackPage(
                                                  accountId: widget.accountId,
                                                  progressId: progressId,
                                                  title: name,
                                                ),
                                              ),
                                            ),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today_outlined, size: 14, color: _secondaryText),
                                              const SizedBox(width: 6),
                                              Text(
                                                dateLabel,
                                                style: TextStyle(fontSize: 12, color: _secondaryText, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (repsDone != null) ...[
                                                _statChip(
                                                  icon: Icons.repeat_rounded,
                                                  label: '$repsDone',
                                                  sub: context.l10n.repsDone,
                                                  color: const Color(0xFF2E90FA),
                                                ),
                                                const SizedBox(width: 10),
                                              ],
                                              if (pain != null)
                                                _statChip(
                                                  icon: Icons.monitor_heart_outlined,
                                                  label: context.l10n.painOutOfTen('$pain'),
                                                  sub: context.l10n.painLevelLower,
                                                  color: _painColor(int.tryParse(pain.toString()) ?? 5),
                                                ),
                                            ],
                                          ),
                                          if (notes.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Icon(Icons.notes_rounded, size: 16, color: _secondaryText),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      notes,
                                                      style: TextStyle(color: _primaryText, fontSize: 13, height: 1.4),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          if (progressId > 0) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                const Icon(Icons.psychology_alt_outlined, size: 16, color: Color(0xFF2E90FA)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  context.l10n.sessionOpenFeedback,
                                                  style: const TextStyle(
                                                      color: Color(0xFF2E90FA), fontWeight: FontWeight.w800, fontSize: 13),
                                                ),
                                                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF2E90FA)),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _painColor(int level) {
    if (level <= 3) return const Color(0xFF4CAF50);
    if (level <= 6) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }

  Widget _statChip({required IconData icon, required String label, required String sub, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
              Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

class PhysioAiFeedbackPage extends StatefulWidget {
  final int accountId;
  final int patientId;
  final String patientName;

  const PhysioAiFeedbackPage({
    super.key,
    required this.accountId,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PhysioAiFeedbackPage> createState() => _PhysioAiFeedbackPageState();
}

class _PhysioAiFeedbackPageState extends State<PhysioAiFeedbackPage> {
  final SQLdata _db = SQLdata();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _feedback = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _db.fetchPhysioAiFeedback(
        accountId: widget.accountId,
        patientId: widget.patientId,
      );
      if (!mounted) return;
      setState(() {
        _feedback = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizeError(e);
        _isLoading = false;
      });
    }
  }

  /// One AI feedback entry: the exercise, the day, the score and the counts as badges; opens the session.
  Widget _feedbackCard(BuildContext context, Map<String, dynamic> item) {
    final l = context.l10n;
    final score = (item['score'] as num?)?.toDouble();
    final progressId = int.tryParse((item['progress_id'] ?? 0).toString()) ?? 0;
    final when = DateTime.tryParse((item['progress_date'] ?? item['generated_at'] ?? '').toString());
    // the rep-by-rep lines of the analysis, counted by kind (the detailed view is one tap away)
    final lines = (item['analysis'] ?? '').toString().split('\n').where((x) => x.trim().isNotEmpty).toList();
    final scoreColor = score == null
        ? const Color(0xFF667085)
        : score >= 70
        ? const Color(0xFF12B76A)
        : score >= 40
        ? const Color(0xFFF79009)
        : const Color(0xFFD92D20);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: progressId <= 0
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionFeedbackPage(
                        accountId: widget.accountId,
                        progressId: progressId,
                        title: (item['exercise_name'] ?? '').toString(),
                      ),
                    ),
                  ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scoreColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Text(
                    score == null ? '-' : '${score.round()}%',
                    style: TextStyle(color: scoreColor, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['ai_exercise'] != null
                            ? trackedExerciseLabel(l, item['ai_exercise']?.toString())
                            : (item['exercise_name'] ?? l.exercise).toString(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (when != null)
                            _chip(
                              l.dateAtTime('${when.day}/${when.month}/${when.year}',
                                  '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'),
                              const Color(0xFF475467),
                            ),
                          if (lines.isNotEmpty) _chip('${lines.length} · ${l.repsDone}', const Color(0xFF2E90FA)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kinexAppBar(title: context.l10n.aiFeedbackFor(widget.patientName)),
      body: KinexScreenBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFB42318))))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                      if (_feedback.isEmpty)
                        Text(context.l10n.noAiFeedbackYet)
                      else
                        // grouped under body-region headers (Shoulder, Hip), untracked exercises last
                        for (final (region, items)
                            in groupByRegion(_feedback, (Map<String, dynamic> f) => f['ai_exercise']?.toString())) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 8),
                            child: Text(
                              bodyRegionLabel(context.l10n, region),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF667085)),
                            ),
                          ),
                          ...items.map((item) => _feedbackCard(context, item)),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}







/// Median lift of the good-form reps per session (line) against the target used (dashed), in degrees.
class _E4RangeChartPainter extends CustomPainter {
  final List<double?> peaks, targets;
  final List<String> dates;
  final Color lineColor, targetColor, textColor;

  _E4RangeChartPainter({
    required this.peaks,
    required this.targets,
    required this.dates,
    required this.lineColor,
    required this.targetColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = [...peaks, ...targets].whereType<double>().toList();
    if (values.isEmpty) return;
    const left = 30.0, bottom = 18.0, top = 6.0;
    final w = size.width - left - 6, h = size.height - bottom - top;
    final hi = (values.reduce((a, b) => a > b ? a : b) / 10).ceil() * 10.0 + 5;
    final n = peaks.length;
    double x(int i) => left + (n == 1 ? w / 2 : w * i / (n - 1));
    double y(double v) => top + h * (1 - v / hi);
    final axis = Paint()
      ..color = textColor.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    void label(String t, Offset o, {bool right = false}) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(color: textColor, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, right ? o - Offset(tp.width, tp.height / 2) : o);
    }

    for (final v in [0.0, hi / 2, hi]) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), axis);
      label('${v.round()}°', Offset(left - 4, y(v)), right: true);
    }
    // target (dashed, per session: it can change)
    final tp = Paint()
      ..color = targetColor
      ..strokeWidth = 2;
    for (var i = 0; i < n; i++) {
      final t = targets[i];
      if (t == null) continue;
      final x0 = n == 1 ? left : x(i) - (i == 0 ? 0 : w / (2 * (n - 1)));
      final x1 = n == 1 ? left + w : x(i) + (i == n - 1 ? 0 : w / (2 * (n - 1)));
      for (var xx = x0; xx < x1; xx += 8) {
        canvas.drawLine(Offset(xx, y(t)), Offset((xx + 4).clamp(x0, x1), y(t)), tp);
      }
    }
    // median lift
    final lp = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    var started = false;
    for (var i = 0; i < n; i++) {
      final p = peaks[i];
      if (p == null) continue;
      final o = Offset(x(i), y(p));
      started ? path.lineTo(o.dx, o.dy) : path.moveTo(o.dx, o.dy);
      started = true;
      canvas.drawCircle(o, 3.5, Paint()..color = lineColor);
    }
    canvas.drawPath(path, lp);
    // first and last dates
    if (dates.isNotEmpty) {
      label(_short(dates.first), Offset(left, size.height - 12));
      if (n > 1) label(_short(dates.last), Offset(left + w, size.height - 6), right: true);
    }
  }

  static String _short(String d) => d.length >= 10 ? d.substring(5, 10) : d;

  @override
  bool shouldRepaint(covariant _E4RangeChartPainter old) =>
      old.peaks != peaks || old.targets != targets || old.lineColor != lineColor;
}

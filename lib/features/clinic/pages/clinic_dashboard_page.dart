import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/l10n/value_labels.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';
import 'clinic_complaints_page.dart';
import 'package:reeducation/features/auth/pages/login_screen.dart';

class ClinicDashboardPage extends StatefulWidget {
  final int accountId;
  const ClinicDashboardPage({super.key, required this.accountId});
  @override
  State<ClinicDashboardPage> createState() => _ClinicDashboardPageState();
}

class _ClinicDashboardPageState extends State<ClinicDashboardPage>
    with SingleTickerProviderStateMixin {
  final SQLdata _db = SQLdata();
  late TabController _tabController;
  int _tabIndex = 0;

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  // ── Registration form state (used in bottom sheet) ───────────────────────
  final _memberFormKey = GlobalKey<FormState>();
  String _memberRole = 'patient';
  String _memberName = '';
  String _memberEmail = '';
  String _memberPassword = '';
  String _memberPhone = '';
  String _memberBirthDate = '';
  String _memberSpecialization = '';
  int? _selectedTherapistId;
  String _memberSearchQuery = '';

  // ── Profile tab ──────────────────────────────────────────────────────────
  final _profileFormKey = GlobalKey<FormState>();
  String _clinicName = '';
  String _clinicAddress = '';
  String _clinicPhone = '';
  String _clinicPhotoUrl = '';
  final ImagePicker _picker = ImagePicker();
  bool _uploadingClinicPhoto = false;

  // ── Payment ──────────────────────────────────────────────────────────────
  String? _lastPaymentReference;
  bool _processingPayment = false;
  String _selectedPlan = 'monthly';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) return;
        setState(() => _tabIndex = _tabController.index);
      });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _db.fetchClinicDashboard(widget.accountId);
      if (!mounted) return;
      final clinic = (res['clinic'] as Map?)?.cast<String, dynamic>() ?? {};
      _clinicName    = (clinic['name']    ?? '').toString();
      _clinicAddress = (clinic['address'] ?? '').toString();
      _clinicPhone   = (clinic['phone']   ?? '').toString();
      _clinicPhotoUrl = (clinic['photo_url'] ?? '').toString();
      setState(() => _data = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = localizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Popup helper ─────────────────────────────────────────────────────────
  Future<void> _showPopup({required bool isError, required String message}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? Colors.redAccent : const Color(0xFF2E90FA),
          ),
          const SizedBox(width: 8),
          Text(isError ? context.l10n.error : context.l10n.success,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.ok)),
        ],
      ),
    );
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  void _logout() => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );

  Future<void> _pickAndUploadClinicPhoto() async {
    if (_uploadingClinicPhoto) return;
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingClinicPhoto = true);
    try {
      final res = await _db.uploadPatientPhoto(accountId: widget.accountId, photo: File(picked.path));
      if (!mounted) return;
      await _showPopup(isError: res['error'] == true, message: localizeServerMessage((res['message'] ?? '').toString()));
      await _load();
    } catch (e) {
      if (!mounted) return;
      await _showPopup(isError: true, message: localizeError(e));
    } finally {
      if (mounted) setState(() => _uploadingClinicPhoto = false);
    }
  }

  // ── Open the "Add member" form in a modal bottom sheet ───────────────────
  void _openAddMemberSheet() {
    final therapists =
        (_data['therapists'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Reset form state each time we open the sheet
    setState(() {
      _memberRole = 'patient';
      _memberName = '';
      _memberEmail = '';
      _memberPassword = '';
      _memberPhone = '';
      _memberBirthDate = '';
      _memberSpecialization = '';
      _selectedTherapistId = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        // StatefulBuilder lets us rebuild just the sheet on setState
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _memberFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Sheet handle & title ───────────────────────────
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDE3EC),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Row(children: [
                        const Icon(Icons.person_add_alt_1_rounded,
                            color: Color(0xFF2E90FA)),
                        const SizedBox(width: 8),
                        Text(context.l10n.addNewMember,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ]),
                      const SizedBox(height: 14),

                      // ── Role selector ─────────────────────────────────
                      DropdownButtonFormField<String>(
                        initialValue: _memberRole,
                        decoration: InputDecoration(labelText: context.l10n.role),
                        items: [
                          DropdownMenuItem(value: 'patient',   child: Text(context.l10n.patient)),
                          DropdownMenuItem(value: 'therapist', child: Text(context.l10n.physiotherapist)),
                        ],
                        onChanged: (v) => setSheetState(
                            () => setState(() => _memberRole = v ?? 'patient')),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.fullName,
                            prefixIcon: const Icon(Icons.person_outline)),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? context.l10n.required : null,
                        onSaved: (v) => _memberName = v!.trim(),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.email,
                            prefixIcon: const Icon(Icons.alternate_email_rounded)),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return context.l10n.required;
                          final emailRx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          return emailRx.hasMatch(value) ? null : context.l10n.invalidEmailFormat;
                        },
                        onSaved: (v) => _memberEmail = v!.trim(),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.password,
                            prefixIcon: const Icon(Icons.lock_outline_rounded)),
                        obscureText: true,
                        validator: (v) =>
                            (v == null || v.length < 6) ? context.l10n.minSixChars : null,
                        onSaved: (v) => _memberPassword = v!.trim(),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.phone,
                            prefixIcon: const Icon(Icons.phone_outlined)),
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return null;
                          final phoneRx = RegExp(r'^[0-9+()\-\s]{6,20}$');
                          return phoneRx.hasMatch(value) ? null : context.l10n.invalidPhoneFormat;
                        },
                        onSaved: (v) => _memberPhone = (v ?? '').trim(),
                      ),

                      // ── Patient-only fields ───────────────────────────
                      if (_memberRole == 'patient') ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime(now.year - 30),
                              firstDate: DateTime(1900),
                              lastDate: now,
                            );
                            if (picked != null) {
                              setSheetState(() => setState(() {
                                _memberBirthDate =
                                    '${picked.year}-'
                                    '${picked.month.toString().padLeft(2, '0')}-'
                                    '${picked.day.toString().padLeft(2, '0')}';
                              }));
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: context.l10n.birthDate,
                              prefixIcon: const Icon(Icons.cake_outlined),
                              suffixIcon: const Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              _memberBirthDate.isEmpty
                                  ? context.l10n.selectBirthDate
                                  : _memberBirthDate,
                              style: TextStyle(
                                color: _memberBirthDate.isEmpty
                                    ? const Color(0xFF9E9E9E)
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int?>(
                          initialValue: _selectedTherapistId,
                          decoration: InputDecoration(
                              labelText: context.l10n.assignedPhysiotherapist,
                              prefixIcon: const Icon(Icons.medical_services_outlined)),
                          items: [
                            DropdownMenuItem<int?>(
                                value: null, child: Text(context.l10n.noAssignment)),
                            ...therapists.map((t) => DropdownMenuItem<int?>(
                                  value: int.tryParse(
                                      (t['id'] ?? '').toString()),
                                  child: Text((t['name'] ?? '').toString()),
                                )),
                          ],
                          onChanged: (v) =>
                              setSheetState(() => setState(() => _selectedTherapistId = v)),
                        ),
                      ],

                      // ── Therapist-only fields ─────────────────────────
                      if (_memberRole == 'therapist') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: InputDecoration(
                              labelText: context.l10n.specialization,
                              prefixIcon: const Icon(Icons.school_outlined)),
                          onSaved: (v) => _memberSpecialization = (v ?? '').trim(),
                        ),
                      ],

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!(_memberFormKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            _memberFormKey.currentState?.save();

                            if (_memberRole == 'patient' && _memberBirthDate.trim().isEmpty) {
                              await _showPopup(
                                isError: true,
                                message: context.l10n.birthDateRequiredForPatients,
                              );
                              return;
                            }

                            final payload = <String, dynamic>{
                              'role':     _memberRole,
                              'email':    _memberEmail,
                              'password': _memberPassword,
                              'name':     _memberName,
                              'phone':    _memberPhone,
                              if (_memberRole == 'patient')
                                'birth_date': _memberBirthDate,
                              if (_memberRole == 'patient' &&
                                  _selectedTherapistId != null)
                                'therapist_id': _selectedTherapistId,
                              if (_memberRole == 'therapist')
                                'specialization': _memberSpecialization,
                            };

                            final res = await _db.clinicRegisterMember(
                                widget.accountId, payload);
                            if (!mounted) return;

                            Navigator.of(sheetCtx).pop(); // close sheet first
                            await _showPopup(
                              isError: res['error'] == true,
                              message: localizeServerMessage((res['message'] ?? '').toString()),
                            );
                            if (res['error'] != true) await _load();
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(context.l10n.createMember),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Delete member ────────────────────────────────────────────────────────
  Future<void> _deleteMember({
    required int accountId,
    required String role,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.l10n.deleteMember),
        content: Text(context.l10n.deleteMemberConfirm(roleLabel(context.l10n, role), name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlg).pop(false),
              child: Text(context.l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(dlg).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await _db.clinicDeleteMember(
        clinicAccountId:  widget.accountId,
        memberAccountId:  accountId,
        memberRole:       role,
      );
      if (!mounted) return;
      await _showPopup(isError: res['error'] == true, message: localizeServerMessage((res['message'] ?? '').toString()));
      await _load();
    } catch (e) {
      if (!mounted) return;
      await _showPopup(isError: true, message: localizeError(e));
    }
  }

  // ── Profile save ─────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
    _profileFormKey.currentState?.save();
    final res = await _db.clinicUpdateProfile(
      clinicAccountId: widget.accountId,
      name: _clinicName, address: _clinicAddress, phone: _clinicPhone,
    );
    if (!mounted) return;
    await _showPopup(isError: res['error'] == true, message: localizeServerMessage((res['message'] ?? '').toString()));
    if (res['error'] != true) await _load();
  }

  // ── Stripe ───────────────────────────────────────────────────────────────
  Future<void> _subscribe(String plan) async {
    setState(() => _processingPayment = true);
    try {
      final res = await _db.createSubscription(
        clinicAccountId: widget.accountId,
        plan: plan,
      );
      if (!mounted) return;
      _lastPaymentReference = (res['reference'] ?? '').toString().trim().isEmpty
          ? _lastPaymentReference
          : (res['reference'] ?? '').toString();
      final url = (res['checkout_url'] ?? '').toString();
      await _showPopup(isError: res['error'] == true, message: localizeServerMessage((res['message'] ?? '').toString()));
      if (url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      await _showPopup(isError: true, message: localizeError(e));
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  Future<void> _verifyPayment() async {
    final reference = (_lastPaymentReference ?? '').trim();
    if (reference.isEmpty) {
      await _showPopup(isError: true, message: context.l10n.noPaymentReference);
      return;
    }
    setState(() => _processingPayment = true);
    try {
      final res = await _db.verifySubscriptionPayment(
        clinicAccountId: widget.accountId, reference: reference,
      );
      if (!mounted) return;
      await _showPopup(isError: res['error'] == true, message: localizeServerMessage((res['message'] ?? '').toString()));
      await _load();
    } catch (e) {
      if (!mounted) return;
      await _showPopup(isError: true, message: localizeError(e));
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final counts    = (_data['counts'] as Map<String, dynamic>?) ?? {};
    final therapists = (_data['therapists'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final patients   = (_data['patients']   as List?)?.cast<Map<String, dynamic>>() ?? [];
    final isPremium  = _data['is_premium'] == 1 || _data['is_premium'] == true;
    final memberQ = _memberSearchQuery.trim().toLowerCase();
    final filteredTherapists = therapists.where((t) {
      if (memberQ.isEmpty) return true;
      final name = (t['name'] ?? '').toString().toLowerCase();
      final email = (t['email'] ?? '').toString().toLowerCase();
      final phone = (t['phone'] ?? '').toString().toLowerCase();
      final spec = (t['specialization'] ?? '').toString().toLowerCase();
      return name.contains(memberQ) || email.contains(memberQ) || phone.contains(memberQ) || spec.contains(memberQ);
    }).toList();
    final filteredPatients = patients.where((p) {
      if (memberQ.isEmpty) return true;
      final name = (p['name'] ?? '').toString().toLowerCase();
      final email = (p['email'] ?? '').toString().toLowerCase();
      final phone = (p['phone'] ?? '').toString().toLowerCase();
      final therapist = (p['therapist_name'] ?? '').toString().toLowerCase();
      return name.contains(memberQ) || email.contains(memberQ) || phone.contains(memberQ) || therapist.contains(memberQ);
    }).toList();

    return Scaffold(
      appBar: kinexAppBar(
        title: l10n.clinicDashboard,
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined),
            tooltip: l10n.complaints,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ClinicComplaintsPage(accountId: widget.accountId)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: l10n.logout,
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFA8B3CF),
          tabs: [
            Tab(text: l10n.overview),
            Tab(text: l10n.members),
            Tab(text: l10n.subscription),
            Tab(text: l10n.profile),
          ],
        ),
      ),

      // ── FAB: shown only on Members tab ────────────────────────────────────
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _openAddMemberSheet,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(l10n.addMember),
              backgroundColor: const Color(0xFF2E90FA),
              foregroundColor: Colors.white,
            )
          : null,

      body: KinexScreenBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : TabBarView(
                    controller: _tabController,
                    children: [

                    // ── Overview ────────────────────────────────────────────
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _gradientCard(
                          title:    ((_data['clinic'] as Map?)?['name'] ?? l10n.clinic).toString(),
                          subtitle: isPremium ? l10n.premiumActive : l10n.standardPlan,
                          trailing: Icon(
                            isPremium
                                ? Icons.workspace_premium_rounded
                                : Icons.pending_actions_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _metric(l10n.patients,   counts['patients']?.toString()   ?? '0')),
                          const SizedBox(width: 10),
                          Expanded(child: _metric(l10n.therapists, counts['therapists']?.toString() ?? '0')),
                        ]),
                        const SizedBox(height: 14),
                        Text(l10n.assignedPatients,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        ...patients.map((p) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title:    Text((p['name'] ?? '').toString()),
                            subtitle: Text(
                                l10n.therapistValue((p['therapist_name'] ?? l10n.unassigned).toString())),
                          ),
                        )),
                      ],
                    ),

                    // ── Members list ────────────────────────────────────────
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          // Header
                          Row(children: [
                            const Icon(Icons.groups_rounded, color: Color(0xFF2E90FA)),
                            const SizedBox(width: 8),
                            Text(
                              l10n.clinicMembersCount('${filteredPatients.length + filteredTherapists.length}'),
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          TextField(
                            onChanged: (v) => setState(() => _memberSearchQuery = v),
                            decoration: InputDecoration(
                              hintText: l10n.searchMembers,
                              prefixIcon: const Icon(Icons.search_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (filteredTherapists.isEmpty && filteredPatients.isEmpty)
                            Center(
                              child: Column(children: [
                                const SizedBox(height: 40),
                                Icon(Icons.group_off_outlined,
                                    size: 56,
                                    color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(l10n.noMembersYet,
                                    style: const TextStyle(
                                        color: Color(0xFF667085), fontSize: 15)),
                                const SizedBox(height: 8),
                                Text(l10n.tapButtonToAddMember,
                                    style: const TextStyle(color: Color(0xFF9EA8C0))),
                              ]),
                            ),

                          // Physiotherapists section
                          if (filteredTherapists.isNotEmpty) ...[
                            _sectionHeader(l10n.physiotherapists,
                                Icons.medical_services_outlined),
                            const SizedBox(height: 8),
                            ...filteredTherapists.map((t) {
                              final aId =
                                  int.tryParse((t['account_id'] ?? '').toString()) ?? 0;
                              final name = (t['name'] ?? '').toString();
                              return _memberCard(
                                icon: Icons.medical_services_outlined,
                                iconColor: const Color(0xFF7C4DFF),
                                name: name.isEmpty ? l10n.physiotherapist : name,
                                lines: [
                                  '📧 ${(t['email'] ?? '-')}',
                                  '📞 ${(t['phone'] ?? '-')}',
                                  '🎓 ${(t['specialization'] ?? '-')}',
                                ],
                                onDelete: aId <= 0
                                    ? null
                                    : () => _deleteMember(
                                        accountId: aId,
                                        role: 'therapist',
                                        name: name),
                              );
                            }),
                            const SizedBox(height: 10),
                          ],

                          // Patients section
                          if (filteredPatients.isNotEmpty) ...[
                            _sectionHeader(l10n.patients, Icons.person_outline),
                            const SizedBox(height: 8),
                            ...filteredPatients.map((p) {
                              final aId =
                                  int.tryParse((p['account_id'] ?? '').toString()) ?? 0;
                              final name = (p['name'] ?? '').toString();
                              return _memberCard(
                                icon: Icons.person_rounded,
                                iconColor: const Color(0xFF2E90FA),
                                name: name.isEmpty ? l10n.patient : name,
                                lines: [
                                  '📧 ${(p['email'] ?? '-')}',
                                  '📞 ${(p['phone'] ?? '-')}',
                                  '👨‍⚕️ ${(p['therapist_name'] ?? l10n.unassigned)}',
                                ],
                                onDelete: aId <= 0
                                    ? null
                                    : () => _deleteMember(
                                        accountId: aId,
                                        role: 'patient',
                                        name: name),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),

                    // ── Subscription ────────────────────────────────────────
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPremium ? l10n.premiumActiveCheck : l10n.upgradeToPremium,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text(isPremium
                                    ? l10n.premiumUnlockedDescription
                                    : l10n.premiumLockedDescription),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (_) {
                                    final patientCount = int.tryParse((counts['patients'] ?? 0).toString()) ?? 0;
                                    final monthlyTotal = 5.0 + (0.1 * patientCount);
                                    final yearlyTotal = 50.0 + (0.1 * patientCount);
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F8FD),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${l10n.pricingPatientsLine('$patientCount')}\n'
                                        '${l10n.pricingMonthlyLine('$patientCount', monthlyTotal.toStringAsFixed(2))}\n'
                                        '${l10n.pricingYearlyLine('$patientCount', yearlyTotal.toStringAsFixed(2))}',
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF344054)),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                SegmentedButton<String>(
                                  segments: [
                                    ButtonSegment<String>(
                                      value: 'monthly',
                                      label: Text(l10n.monthly),
                                      icon: const Icon(Icons.calendar_view_month_rounded),
                                    ),
                                    ButtonSegment<String>(
                                      value: 'yearly',
                                      label: Text(l10n.yearly),
                                      icon: const Icon(Icons.event_repeat_rounded),
                                    ),
                                  ],
                                  selected: {_selectedPlan},
                                  onSelectionChanged: (set) {
                                    setState(() => _selectedPlan = set.first);
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedPlan == 'yearly'
                                      ? l10n.yearlyPricingNote
                                      : l10n.monthlyPricingNote,
                                  style: const TextStyle(color: Color(0xFF667085)),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _processingPayment ? null : () => _subscribe(_selectedPlan),
                                    icon: const Icon(Icons.credit_card_rounded),
                                    label: Text(_selectedPlan == 'yearly' ? l10n.payYearlyWithStripe : l10n.payMonthlyWithStripe),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _processingPayment ? null : _verifyPayment,
                                    icon: const Icon(Icons.verified_outlined),
                                    label: Text(
                                      _lastPaymentReference == null
                                          ? l10n.iPaidVerify
                                          : l10n.verifyStripePayment,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Profile ─────────────────────────────────────────────
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Form(
                              key: _profileFormKey,
                              child: Column(children: [
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    l10n.clinicProfile,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    l10n.clinicProfileSubtitle,
                                    style: const TextStyle(color: Color(0xFF667085)),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 46,
                                        backgroundColor: const Color(0xFFDDE3EC),
                                        child: _clinicPhotoUrl.trim().isEmpty
                                            ? const Icon(Icons.local_hospital_rounded, size: 36, color: Color(0xFF64748B))
                                            : ClipOval(
                                                child: Image.network(
                                                  _clinicPhotoUrl.startsWith('http')
                                                      ? _clinicPhotoUrl
                                                      : '${_db.phpapi}${_clinicPhotoUrl.startsWith('/') ? _clinicPhotoUrl.substring(1) : _clinicPhotoUrl}',
                                                  width: 92,
                                                  height: 92,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => const Icon(Icons.local_hospital_rounded, size: 36, color: Color(0xFF64748B)),
                                                ),
                                              ),
                                      ),
                                      PositionedDirectional(
                                        end: 0,
                                        bottom: 0,
                                        child: InkWell(
                                          onTap: _uploadingClinicPhoto ? null : _pickAndUploadClinicPhoto,
                                          child: Container(
                                            width: 34,
                                            height: 34,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2E90FA),
                                              shape: BoxShape.circle,
                                            ),
                                            child: _uploadingClinicPhoto
                                                ? const Padding(
                                                    padding: EdgeInsets.all(8),
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  initialValue: _clinicName,
                                  decoration: InputDecoration(
                                      labelText: l10n.clinicName,
                                      prefixIcon: const Icon(Icons.local_hospital_outlined)),
                                  validator: (v) =>
                                      (v == null || v.trim().length < 3) ? l10n.minThreeCharacters : null,
                                  onSaved: (v) => _clinicName = v!.trim(),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  initialValue: _clinicAddress,
                                  decoration: InputDecoration(
                                      labelText: l10n.address,
                                      prefixIcon: const Icon(Icons.location_on_outlined)),
                                  onSaved: (v) => _clinicAddress = (v ?? '').trim(),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  initialValue: _clinicPhone,
                                  decoration: InputDecoration(
                                      labelText: l10n.phone,
                                      prefixIcon: const Icon(Icons.phone_outlined)),
                                  keyboardType: TextInputType.phone,
                                  validator: (v) {
                                    final value = (v ?? '').trim();
                                    if (value.isEmpty) return null;
                                    final phoneRx = RegExp(r'^[0-9+()\-\s]{6,20}$');
                                    return phoneRx.hasMatch(value) ? null : l10n.invalidPhoneFormat;
                                  },
                                  onSaved: (v) => _clinicPhone = (v ?? '').trim(),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _saveProfile,
                                    icon: const Icon(Icons.save_outlined),
                                    label: Text(l10n.saveProfileLower),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: const Color(0xFF667085)),
      const SizedBox(width: 6),
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF667085),
              letterSpacing: 0.5)),
    ]);
  }

  Widget _memberCard({
    required IconData icon,
    required Color iconColor,
    required String name,
    required List<String> lines,
    VoidCallback? onDelete,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                ...lines.map((l) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(l,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF667085))),
                    )),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent, size: 20),
            onPressed: onDelete,
            tooltip: context.l10n.delete,
          ),
        ]),
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E90FA))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF667085))),
        ]),
      ),
    );
  }

  Widget _gradientCard({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
            colors: [Color(0xFF2E90FA), Color(0xFF7C4DFF)]),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(color: Color(0xFFE8EFFF))),
            ],
          ),
        ),
        trailing,
      ]),
    );
  }
}






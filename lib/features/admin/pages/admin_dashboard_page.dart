import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/l10n/value_labels.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';
import 'package:reeducation/features/auth/pages/login_screen.dart';

class AdminDashboardPage extends StatefulWidget {
  final int accountId;

  const AdminDashboardPage({super.key, required this.accountId});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final SQLdata _db = SQLdata();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  int _selectedPage = 0;
  final TextEditingController _accountSearchCtrl = TextEditingController();
  final TextEditingController _clinicSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _db.fetchAdminDashboard(widget.accountId);
      if (!mounted) return;
      setState(() => _data = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = localizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPopup({required bool isError, required String message}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: isError ? Colors.redAccent : const Color(0xFF2E90FA),
            ),
            const SizedBox(width: 8),
            Text(isError ? context.l10n.error : context.l10n.success,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _accountSearchCtrl.dispose();
    _clinicSearchCtrl.dispose();
    super.dispose();
  }

  bool _matchesNameOnly(String query, String value) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return value.trim().toLowerCase().contains(q);
  }

  bool _matchesClinicSearch(String query, Map<String, dynamic> clinic) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    final fields = [
      (clinic['name'] ?? '').toString().toLowerCase(),
      (clinic['email'] ?? '').toString().toLowerCase(),
      (clinic['phone'] ?? '').toString().toLowerCase(),
      (clinic['id'] ?? clinic['clinic_id'] ?? '').toString().toLowerCase(),
      (clinic['account_id'] ?? '').toString().toLowerCase(),
    ];
    return fields.any((value) => value.contains(q));
  }

  Uri? _justifUri(dynamic rawPath) {
    final value = (rawPath ?? '').toString().trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Uri.tryParse(value);
    }

    if (value.toLowerCase().startsWith('c:/wamp64/www/reed/uploads/')) {
      return Uri.tryParse(_db.convertLocalPathToUrl(value));
    }

    final base = _db.phpapi.endsWith('/') ? _db.phpapi : '${_db.phpapi}/';
    final normalized = value.startsWith('/') ? value.substring(1) : value;
    return Uri.tryParse('$base$normalized');
  }

  Future<void> _openJustif(dynamic rawPath) async {
    final uri = _justifUri(rawPath);
    if (uri == null) {
      await _showPopup(isError: true, message: context.l10n.noJustificationFile);
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      await _showPopup(isError: true, message: context.l10n.unableToOpenDocument);
    }
  }

  Future<void> _deleteAccount({required int accountId, required String label}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.l10n.deleteAccount),
        content: Text(context.l10n.deleteAccountConfirm(label, accountId.toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(context.l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await _db.adminDeleteAccount(
        adminAccountId: widget.accountId,
        targetAccountId: accountId,
      );
      if (!mounted) return;
      await _showPopup(isError: false, message: res['message'] != null ? localizeServerMessage(res['message'].toString()) : context.l10n.accountDeleted);
      await _load();
    } catch (e) {
      if (!mounted) return;
      await _showPopup(isError: true, message: localizeError(e));
    }
  }

  Future<void> _setClinicStatus(int clinicAccountId, bool approve) async {
    try {
      final res = await _db.adminSetClinicStatus(
        adminAccountId: widget.accountId,
        clinicAccountId: clinicAccountId,
        isActive: approve,
      );
      if (!mounted) return;
      await _showPopup(isError: res['error'] == true, message: localizeServerMessage((res['message'] ?? '').toString()));
      await _load();
    } catch (e) {
      if (!mounted) return;
      await _showPopup(isError: true, message: localizeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final counts = (_data['counts'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final pending = (_data['pending_clinics'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    final accounts = (_data['accounts'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    final clinics = (_data['clinics'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];

    final accountQ = _accountSearchCtrl.text.trim();
    final clinicQ = _clinicSearchCtrl.text.trim();
    final filteredAccounts = accounts.where((a) => _matchesNameOnly(accountQ, (a['display_name'] ?? '').toString())).toList();

    final filteredPending = pending.where((c) => _matchesClinicSearch(clinicQ, c)).toList();

    final filteredClinics = clinics.where((c) => _matchesClinicSearch(clinicQ, c)).toList();

    final pages = <Widget>[
      _buildHomePage(counts: counts, pending: filteredPending),
      _buildAccountsPage(accounts: filteredAccounts),
      _buildClinicsPage(clinics: filteredClinics),
    ];

    final pageTitles = [l10n.adminHome, l10n.accounts, l10n.clinics];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: kinexAppBar(
        title: pageTitles[_selectedPage],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.refresh,
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: l10n.logout,
            onPressed: _logout,
          ),
        ],
      ),
      body: KinexScreenBackground(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(onRefresh: _load, child: IndexedStack(index: _selectedPage, children: pages)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedPage,
        onDestinationSelected: (value) => setState(() => _selectedPage = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: l10n.home),
          NavigationDestination(icon: const Icon(Icons.badge_outlined), selectedIcon: const Icon(Icons.badge_rounded), label: l10n.accounts),
          NavigationDestination(icon: const Icon(Icons.local_hospital_outlined), selectedIcon: const Icon(Icons.local_hospital_rounded), label: l10n.clinics),
        ],
      ),
    );
  }

  Widget _buildHomePage({
    required Map<String, dynamic> counts,
    required List<Map<String, dynamic>> pending,
  }) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(l10n.statsOverview, Icons.insights_rounded),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _statTile(label: l10n.accounts, value: counts['accounts'], icon: Icons.badge_outlined, colors: const [Color(0xFF63E6FF), Color(0xFF2E90FA)]),
            _statTile(label: l10n.clinics, value: counts['clinics'], icon: Icons.local_hospital_outlined, colors: const [Color(0xFF8A7CFF), Color(0xFF6C5CE7)]),
            _statTile(label: l10n.patients, value: counts['patients'], icon: Icons.groups_2_outlined, colors: const [Color(0xFF2DD4BF), Color(0xFF0EA5A6)]),
            _statTile(label: l10n.therapists, value: counts['therapists'], icon: Icons.medical_services_outlined, colors: const [Color(0xFFF59E0B), Color(0xFFD97706)]),
          ],
        ),
        const SizedBox(height: 18),
        _sectionTitle(l10n.pendingClinics, Icons.hourglass_top_rounded),
        const SizedBox(height: 8),
        TextField(
          controller: _clinicSearchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.searchPendingClinics,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        if (pending.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(l10n.noPendingClinics))),
        ...pending.map((c) {
          final accountId = int.tryParse((c['account_id'] ?? '').toString()) ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((c['name'] ?? l10n.clinic).toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text((c['email'] ?? '').toString()),
                  Text(l10n.phoneValue((c['phone'] ?? '-').toString())),
                  if ((c['justif'] ?? '').toString().trim().isNotEmpty)
                    Text(l10n.documentAttached, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: accountId <= 0 ? null : () => _setClinicStatus(accountId, true),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(l10n.approve),
                      ),
                      OutlinedButton.icon(
                        onPressed: ((c['justif_url'] ?? c['justif']) ?? '').toString().isEmpty
                            ? null
                            : () => _openJustif(c['justif_url'] ?? c['justif']),
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(l10n.openDoc),
                      ),
                      OutlinedButton.icon(
                        onPressed: accountId <= 0
                            ? null
                            : () => _deleteAccount(accountId: accountId, label: (c['name'] ?? l10n.clinic).toString()),
                        icon: const Icon(Icons.close_rounded),
                        label: Text(l10n.reject),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAccountsPage({required List<Map<String, dynamic>> accounts}) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(l10n.accounts, Icons.badge_outlined),
        const SizedBox(height: 8),
        TextField(
          controller: _accountSearchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.searchAccountsByName,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        if (accounts.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(l10n.noMatchingAccounts))),
        ...accounts.map((a) {
          final accountId = int.tryParse((a['id'] ?? '').toString()) ?? 0;
          final role = (a['role'] ?? '').toString();
          final icon = role == 'clinic'
              ? Icons.local_hospital_outlined
              : (role == 'therapist' ? Icons.medical_services_outlined : Icons.person_outline_rounded);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Icon(icon)),
              title: Text(((a['display_name'] ?? '').toString().trim().isEmpty ? l10n.unnamedAccount : (a['display_name'] ?? '').toString())),
              subtitle: Text('${l10n.emailValue((a['email'] ?? '-').toString())}\n${l10n.accountRoleActive(roleLabel(l10n, role), (a['is_active'] ?? 0).toString())}'),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: l10n.deleteAccount,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                onPressed: accountId <= 0 ? null : () => _deleteAccount(accountId: accountId, label: (a['email'] ?? '').toString()),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildClinicsPage({required List<Map<String, dynamic>> clinics}) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(l10n.clinics, Icons.local_hospital_rounded),
        const SizedBox(height: 8),
        TextField(
          controller: _clinicSearchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.searchClinics,
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        if (clinics.isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(l10n.noMatchingClinics))),
        ...clinics.map((c) {
          final accountId = int.tryParse((c['account_id'] ?? '').toString()) ?? 0;
          final docPath = c['justif_url'] ?? c['justif'];
          final hasDoc = (docPath ?? '').toString().trim().isNotEmpty;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.local_hospital_rounded)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (c['name'] ?? l10n.clinic).toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.emailValue((c['email'] ?? '-').toString())),
                  Text(l10n.phoneValue((c['phone'] ?? '-').toString())),
                  if (hasDoc)
                    Text(
                      l10n.documentAttached,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: hasDoc ? () => _openJustif(docPath) : null,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: Text(l10n.viewDocument),
                      ),
                      OutlinedButton.icon(
                        onPressed: accountId <= 0
                            ? null
                            : () => _deleteAccount(accountId: accountId, label: (c['name'] ?? l10n.clinic).toString()),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(l10n.delete),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _statTile({
    required String label,
    required dynamic value,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white),
              const Spacer(),
              Text((value ?? 0).toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24)),
            ],
          ),
          const Spacer(),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ],
    );
  }
}






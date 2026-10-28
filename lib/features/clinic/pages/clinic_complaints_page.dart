import 'package:flutter/material.dart';

import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/l10n/value_labels.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';

class ClinicComplaintsPage extends StatefulWidget {
  final int accountId;
  const ClinicComplaintsPage({super.key, required this.accountId});

  @override
  State<ClinicComplaintsPage> createState() => _ClinicComplaintsPageState();
}

class _ClinicComplaintsPageState extends State<ClinicComplaintsPage> {
  final SQLdata _db = SQLdata();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _complaints = <Map<String, dynamic>>[];

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
      final list = await _db.fetchClinicComplaints(widget.accountId);
      if (!mounted) return;
      setState(() => _complaints = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = localizeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: kinexAppBar(title: l10n.clinicComplaints),
      body: KinexScreenBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_complaints.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(l10n.noComplaintsFound),
                            ),
                          ),
                        ..._complaints.map((c) => Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text((c['patient_name'] ?? l10n.patient).toString(),
                                        style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFF2E90FA)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(l10n.therapistValue((c['therapist_name'] ?? '-').toString()))),
                                    ]),
                                    Row(children: [
                                      const Icon(Icons.flag_outlined, size: 16, color: Color(0xFF2E90FA)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(l10n.statusValue(statusLabel(l10n, (c['status'] ?? 'pending').toString())))),
                                    ]),
                                    Row(children: [
                                      const Icon(Icons.schedule_outlined, size: 16, color: Color(0xFF2E90FA)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(l10n.dateValue((c['submitted_at'] ?? '-').toString()))),
                                    ]),
                                    const Divider(height: 16),
                                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(Icons.description_outlined, size: 16, color: Color(0xFF2E90FA)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text((c['description'] ?? '').toString())),
                                    ]),
                                    if (((c['symptoms'] ?? '').toString()).trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(Icons.monitor_heart_outlined, size: 16, color: Color(0xFF2E90FA)),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(child: Text(l10n.symptomsValue((c['symptoms'] ?? '').toString()))),
                                      ]),
                                    ]
                                  ],
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
      ),
    );
  }
}





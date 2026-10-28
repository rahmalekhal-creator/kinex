/// The AI feedback of one session from the session log: each live set of that exercise on that day, with the same
/// structured view as the end of a set (metrics, mistakes with their corrections, range, every rep), rebuilt from the
/// reps stored on the server. Sets recorded before the reps were stored show their counts and their text analysis.
library;

import 'package:flutter/material.dart';
import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';

import '../core/exercise_module.dart';
import '../core/tracked_exercises.dart';
import '../voice/voice_lines.dart';
import '../widgets/set_report_view.dart';

/// A stored rep (live_rep row) as the verdict the summary shows.
RepVerdict repFromJson(Map<String, dynamic> r) {
  double dbl(Object? v) => v == null ? double.nan : (v as num).toDouble();
  final status = (r['status'] ?? 'not_scored').toString();
  return RepVerdict(
    rep: (r['rep'] as num?)?.toInt() ?? 0,
    tPeakS: double.nan,
    scored: const {'good', 'mistake', 'unsure', 'below_target'}.contains(status),
    label: (r['label'] ?? 'not_scored').toString(),
    status: status,
    message: '',
    confidence: dbl(r['confidence']),
    probs: const [],
    bufferFrames: 0,
    bufferEndMs: double.nan,
    pipelineMs: 0,
    onnxMs: 0,
    peakDeg: dbl(r['peak_deg']),
    targetDeg: dbl(r['target_deg']),
  );
}

class SessionFeedbackPage extends StatefulWidget {
  final int accountId;
  final int? progressId;
  final int? patientExerciseId;

  /// The day (with [patientExerciseId]).
  final DateTime? date;

  /// Shown while loading.
  final String title;

  const SessionFeedbackPage({
    super.key,
    required this.accountId,
    this.progressId,
    this.patientExerciseId,
    this.date,
    this.title = '',
  });

  @override
  State<SessionFeedbackPage> createState() => _SessionFeedbackPageState();
}

class _SessionFeedbackPageState extends State<SessionFeedbackPage> {
  final SQLdata _db = SQLdata();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  /// Sets shown open (rep-by-rep view); the last set is open at first.
  final Set<int> _open = {};

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
      final d = widget.date;
      final data = await _db.fetchSessionFeedback(
        accountId: widget.accountId,
        progressId: widget.progressId,
        patientExerciseId: widget.patientExerciseId,
        date: d == null
            ? null
            : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
      if (!mounted) return;
      final sets = (data['sets'] as List?) ?? const [];
      setState(() {
        _data = data;
        _loading = false;
        if (sets.isNotEmpty) _open.add(sets.length - 1);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = localizeError(e);
        _loading = false;
      });
    }
  }

  static String _time(String dt) {
    final t = DateTime.tryParse(dt);
    if (t == null) return dt;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static String _date(String dt) {
    final t = DateTime.tryParse(dt);
    if (t == null) return dt;
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ex = (_data?['exercise'] as Map?)?.cast<String, dynamic>();
    final aiEx = ex?['ai_exercise']?.toString();
    final title = aiEx != null ? exerciseTitle(l, aiEx) : (ex?['name'] ?? widget.title).toString();
    return Scaffold(
      appBar: kinexAppBar(title: l.sessionFeedbackTitle),
      body: KinexScreenBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB42318))),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      ..._header(context),
                      const SizedBox(height: 14),
                      ..._sets(context, aiEx, ex?['side']?.toString() ?? ''),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _header(BuildContext context) {
    final l = context.l10n;
    final p = (_data?['progress'] as Map?)?.cast<String, dynamic>();
    final ex = (_data?['exercise'] as Map?)?.cast<String, dynamic>();
    if (p == null) return const [];
    final aiEx = ex?['ai_exercise']?.toString();
    final side = ex?['side']?.toString() ?? '';
    final notes = (p['notes'] ?? '').toString().trim();
    final pain = p['pain_level'];
    return [
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _badge(Icons.calendar_today_outlined, _date((p['date'] ?? '').toString()), const Color(0xFF475467)),
          if (regionOf(aiEx) != null)
            _badge(Icons.accessibility_new_rounded, bodyRegionLabel(l, regionOf(aiEx)), const Color(0xFF344054)),
          if (aiEx != null && side.isNotEmpty)
            _badge(
              isLegExercise(aiEx) ? Icons.directions_walk_rounded : Icons.front_hand_outlined,
              sideWord(l, aiEx, side),
              const Color(0xFF2E90FA),
            ),
          _badge(Icons.repeat_rounded, '${p['reps_done'] ?? 0} · ${l.repsDone}', const Color(0xFF2E90FA)),
          if (pain != null) _badge(Icons.monitor_heart_outlined, l.sessionPainLevel('$pain'), _painColor(pain as int)),
        ],
      ),
      if (notes.isNotEmpty && ((_data?['sets'] as List?)?.isEmpty ?? true)) ...[
        const SizedBox(height: 12),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.sessionNotes, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _sets(BuildContext context, String? aiEx, String side) {
    final l = context.l10n;
    final sets = ((_data?['sets'] as List?) ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    if (sets.isEmpty) {
      return [
        _card(Text(aiEx == null ? l.sessionManualReport : l.sessionNoSets, style: const TextStyle(fontWeight: FontWeight.w600))),
      ];
    }
    return [
      for (var i = 0; i < sets.length; i++) _setCard(context, i, sets[i], aiEx, side),
    ];
  }

  Widget _setCard(BuildContext context, int i, Map<String, dynamic> s, String? aiEx, String side) {
    final l = context.l10n;
    final reps = ((s['reps'] as List?) ?? const []).whereType<Map>().map((m) => repFromJson(m.cast<String, dynamic>())).toList();
    final judged = (s['judged'] as num?)?.toInt() ?? 0;
    final good = (s['good'] as num?)?.toInt() ?? 0;
    final mistakes = (s['mistakes'] as num?)?.toInt() ?? 0;
    final below = (s['below_target'] as num?)?.toInt() ?? 0;
    final wrong = (s['wrong_side'] as num?)?.toInt() ?? 0;
    final score = (s['score'] as num?)?.toDouble() ?? (judged > 0 ? 100.0 * good / judged : null);
    final pain = s['pain_level'];
    final open = _open.contains(i);
    final analysis = (s['analysis'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1220) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => open ? _open.remove(i) : _open.add(i)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.sessionSetTitle(i + 1, _time((s['created_at'] ?? '').toString())),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (score != null)
                              _pill(l.sessionScore(score.round()), const Color(0xFF1570EF)),
                            _pill(l.sessionGoodShort(good), const Color(0xFF12B76A)),
                            if (mistakes > 0) _pill(l.sessionMistakesShort(mistakes), const Color(0xFFF79009)),
                            if (below > 0) _pill(l.sessionBelowTargetShort(below), const Color(0xFF2E90FA)),
                            if (wrong > 0) _pill(l.sessionWrongSideShort(wrong), const Color(0xFFF04438)),
                            if (pain != null) _pill(l.sessionPainLevel('$pain'), _painColor(pain as int)),
                            if (s['pain_reported'] == true) _pill(l.sessionPainDuring, const Color(0xFFB42318)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: reps.isNotEmpty && aiEx != null
                  ? SetReportView(exercise: aiEx, side: side, verdicts: reps)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.sessionNoRepDetail, style: const TextStyle(color: Color(0xFF667085))),
                        if (analysis.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final line in analysis.split('\n'))
                            _card(Text(line), margin: const EdgeInsets.only(bottom: 6)),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _card(Widget child, {EdgeInsets margin = EdgeInsets.zero}) => Container(
    margin: margin,
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111827) : Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _badge(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ],
    ),
  );

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
  );

  static Color _painColor(int p) => p >= 7
      ? const Color(0xFFD92D20)
      : p >= 4
      ? const Color(0xFFF79009)
      : const Color(0xFF12B76A);
}

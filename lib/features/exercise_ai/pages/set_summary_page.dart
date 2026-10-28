import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';

import 'package:reeducation/DB_API.dart';
import 'package:reeducation/l10n/l10n.dart';

import '../core/assignment_context.dart';
import '../core/exercise_module.dart';
import '../core/live_session.dart';
import '../core/set_events.dart';
import '../core/tracked_exercises.dart';
import '../voice/voice_lines.dart';
import '../widgets/set_report_view.dart';

/// End of the set: reps counted, reps scored, good reps, mistakes by type, and every rep's verdict.
class SetSummaryPage extends StatefulWidget {
  final LiveSession session;
  final ExerciseInfo exercise;
  final String side;

  /// Where to save the result (null = nothing is sent).
  final AssignmentContext? assignment;

  const SetSummaryPage({
    super.key,
    required this.session,
    required this.exercise,
    this.side = '',
    this.assignment,
  });

  @override
  State<SetSummaryPage> createState() => _SetSummaryPageState();
}

enum _SendState { idle, sending, sent, failed }

class _SetSummaryPageState extends State<SetSummaryPage> {
  final SQLdata _db = SQLdata();
  _SendState _send = _SendState.idle;
  String _sendError = '';
  int? _progressId;
  int? _pain;

  /// One id per set, kept across retries: the server ignores a set it already has.
  late final String _setUid =
      '${widget.assignment?.accountId ?? 0}-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 30)}';

  LiveSession get session => widget.session;
  ExerciseInfo get exercise => widget.exercise;

  @override
  void initState() {
    super.initState();
    if (widget.assignment != null) _sendSet();
  }

  /// notes (short, shown in the physiotherapist's progress list) and analysis (rep by rep).
  (String, String, double, int) _report() {
    final l = L10n.current;
    final ex = exercise.id;
    final scored = session.verdicts.where((r) => r.scored).toList();
    final good = scored.where((r) => r.status == 'good').length;
    final mistakes = <String, int>{};
    for (final r in scored.where((r) => r.status == 'mistake')) {
      final m = feedbackText(l, ex, r, widget.side);
      mistakes[m] = (mistakes[m] ?? 0) + 1;
    }
    final unsure = scored.where((r) => r.status == 'unsure').length;
    final below = scored.where((r) => r.status == 'below_target').length;
    final wrong = session.verdicts
        .where((r) => r.status == 'wrong_side')
        .length;
    final notes = StringBuffer(
      isLegExercise(ex)
          ? l.reportNotesLeg(
              exerciseTitle(l, ex),
              legWord(l, widget.side),
              scored.length,
              good,
            )
          : l.reportNotes(
              exerciseTitle(l, ex),
              armWord(l, widget.side),
              scored.length,
              good,
            ),
    );
    if (mistakes.isNotEmpty) {
      notes.write(
        ' ${l.reportMistakes(mistakes.entries.map((e) => '${e.key} x${e.value}').join('; '))}',
      );
    }
    if (below > 0) notes.write(' ${l.reportBelowTarget(below)}');
    if (unsure > 0) notes.write(' ${l.reportUnsure(unsure)}');
    if (wrong > 0) notes.write(' ${l.reportWrongSide(wrong)}');
    // what the patient reported during the set (patient-reported, not a medical finding)
    for (final e in session.events) {
      final time = _clock(e.setSeconds);
      final source = e.source == 'voice'
          ? l.reportSourceVoice
          : l.reportSourceButton;
      if (e.type == 'pain_report') {
        notes.write(' ${l.reportPainEvent(time, source)}');
      }
      if (e.type == 'discomfort') notes.write(' ${l.reportDiscomfort(time)}');
    }
    String peak(RepVerdict r) =>
        r.peakDeg.isFinite ? ' · ${roundDeg(r.peakDeg)}°' : '';
    final analysis = [
      for (final r in session.verdicts)
        r.scored && r.confidence.isFinite
            ? '${l.liveRep(r.rep)}: ${repLabelName(l, ex, r)} - ${feedbackText(l, ex, r, widget.side)} (${(r.confidence * 100).round()}%)${peak(r)}'
            : '${l.liveRep(r.rep)}: ${repLabelName(l, ex, r)} - ${feedbackText(l, ex, r, widget.side)}',
      for (final e in session.events.where((e) => e.type == 'pain_report'))
        l.reportPainEvent(
          _clock(e.setSeconds),
          e.source == 'voice' ? l.reportSourceVoice : l.reportSourceButton,
        ),
    ].join('\n');
    final score = scored.isEmpty ? 0.0 : 100.0 * good / scored.length;
    return (notes.toString(), analysis, score, scored.length);
  }

  static String _clock(double s) {
    final t = s.isFinite ? s.round() : 0;
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  bool get _painReported => session.events.any((e) => e.type == 'pain_report');
  bool get _somethingToSend =>
      session.verdicts.isNotEmpty || session.events.isNotEmpty;

  Future<void> _sendSet() async {
    final a = widget.assignment;
    if (a == null ||
        a.patientExerciseId <= 0 ||
        _send == _SendState.sending ||
        _send == _SendState.sent) {
      return;
    }
    final (notes, analysis, score, repsDone) = _report();
    if (!_somethingToSend) {
      setState(() => _send = _SendState.idle);
      return;
    }
    setState(() {
      _send = _SendState.sending;
      _sendError = '';
    });
    try {
      final r = await _db.submitLiveSession(
        accountId: a.accountId,
        patientExerciseId: a.patientExerciseId,
        repsDone: repsDone,
        notes: notes,
        analysis: analysis,
        score: score,
        setUid: _setUid,
        good: session.verdicts
            .where((r) => r.scored && r.status == 'good')
            .length,
        mistakes: session.verdicts
            .where((r) => r.scored && r.status == 'mistake')
            .length,
        unsure: session.verdicts
            .where((r) => r.scored && r.status == 'unsure')
            .length,
        belowTarget: session.verdicts
            .where((r) => r.scored && r.status == 'below_target')
            .length,
        wrongSide: session.verdicts
            .where((r) => r.status == 'wrong_side')
            .length,
        reps: [
          for (final r in session.verdicts)
            {
              'rep': r.rep,
              'label': r.label,
              'status': r.status,
              if (r.confidence.isFinite) 'confidence': r.confidence,
              if (r.peakDeg.isFinite) 'peak_deg': r.peakDeg,
              if (r.targetDeg.isFinite) 'target_deg': r.targetDeg,
            },
        ],
        // what the patient said / pressed (their own report, sent as is)
        painEvents: [
          for (final e in session.events.where((e) => e.type == 'pain_report'))
            {
              'time': _clock(e.setSeconds),
              'source': e.source,
              'utterance': e.utterance,
            },
        ],
      );
      // the home screen (progress bar, list, history) re-fetches now, even if the patient already left this page
      SetEvents.notifySaved();
      if (!mounted) return;
      setState(() {
        _send = _SendState.sent;
        _progressId = int.tryParse((r['progress_id'] ?? 0).toString());
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _send = _SendState.failed;
        _sendError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _setPain(int level) async {
    final a = widget.assignment;
    final id = _progressId;
    if (a == null || id == null) return;
    setState(() => _pain = level);
    try {
      await _db.setLiveSessionPain(
        accountId: a.accountId,
        progressId: id,
        painLevel: level,
        setUid: _setUid,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _pain = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget _sendCard(Color cardBg, Color secondaryText) {
    if (widget.assignment == null || !_somethingToSend) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final (icon, color, text) = switch (_send) {
      _SendState.sending => (
        Icons.cloud_upload_outlined,
        const Color(0xFF2E90FA),
        l.summarySending,
      ),
      _SendState.sent => (
        Icons.check_circle_rounded,
        const Color(0xFF12B76A),
        l.summarySent,
      ),
      _SendState.failed => (
        Icons.error_outline_rounded,
        const Color(0xFFD92D20),
        l.summaryNotSentError(_sendError),
      ),
      _SendState.idle => (
        Icons.cloud_upload_outlined,
        const Color(0xFF667085),
        l.summaryNotSent,
      ),
    };
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              if (_send == _SendState.failed)
                TextButton(onPressed: _sendSet, child: Text(l.summaryTryAgain)),
            ],
          ),
          if (_send == _SendState.sent && _progressId != null) ...[
            const SizedBox(height: 12),
            Text(
              l.summaryPainQuestion,
              style: TextStyle(
                color: secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i <= 10; i++)
                  ChoiceChip(
                    label: Text('$i'),
                    selected: _pain == i,
                    onSelected: (_) => _setPain(i),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final secondaryText = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475467);
    final l = context.l10n;
    final ex = exercise.id;

    return Scaffold(
      appBar: kinexAppBar(title: l.summaryTitle),
      body: KinexScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                exerciseTitle(l, ex),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_painReported)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE4E2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.healing_rounded,
                        color: Color(0xFFB42318),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.summaryPainReported,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _sendCard(cardBg, secondaryText),
              const SizedBox(height: 14),
              SetReportView(
                exercise: ex,
                side: widget.side,
                verdicts: session.verdicts,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E90FA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              l.liveDone,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

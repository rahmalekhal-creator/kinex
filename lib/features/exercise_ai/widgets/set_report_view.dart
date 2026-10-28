/// The result of one live set: metrics (reps counted / scored / good), the mistakes grouped by type with their
/// corrections, e4's range (good form below the target, median lift against the target), reps done with the wrong
/// side, and every rep's verdict. Shown at the end of a set (SetSummaryPage) and for a past set in the session
/// history (SessionFeedbackPage), so both look the same.
library;

import 'package:flutter/material.dart';
import 'package:reeducation/l10n/l10n.dart';

import '../core/exercise_module.dart';
import '../core/np_port.dart' show nanmedian;
import '../core/tracked_exercises.dart';
import '../voice/voice_lines.dart';

Color repStatusColor(String s) => switch (s) {
  'good' => const Color(0xFF12B76A),
  'mistake' => const Color(0xFFF79009),
  'below_target' => const Color(0xFF2E90FA),
  'wrong_side' => const Color(0xFFF04438),
  _ => const Color(0xFF667085),
};

class SetReportView extends StatelessWidget {
  /// Tracked exercise (e1..e4) and the prescribed side.
  final String exercise, side;
  final List<RepVerdict> verdicts;

  /// Show the rep-by-rep list (the history can fold it).
  final bool showEveryRep;

  const SetReportView({
    super.key,
    required this.exercise,
    required this.side,
    required this.verdicts,
    this.showEveryRep = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final secondaryText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475467);
    final l = context.l10n;
    final ex = exercise;
    final v = verdicts;
    final scored = v.where((r) => r.scored).toList();
    final good = scored.where((r) => r.status == 'good').length;
    final unsure = scored.where((r) => r.status == 'unsure').length;
    final mistakes = <String, List<RepVerdict>>{};
    for (final r in scored.where((r) => r.status == 'mistake')) {
      mistakes.putIfAbsent(r.label, () => []).add(r);
    }
    final below = scored.where((r) => r.status == 'below_target').toList();
    final wrong = v.where((r) => r.status == 'wrong_side').length;
    final counted = v.length - wrong;
    final leg = isLegExercise(ex);
    // e4: median lift of the good-form reps against the target used
    final formPeaks = [
      for (final r in scored)
        if ((r.status == 'good' || r.status == 'below_target') && r.peakDeg.isFinite) r.peakDeg,
    ];
    final targets = [
      for (final r in scored)
        if (r.targetDeg.isFinite) r.targetDeg,
    ];

    Widget metric(String value, String label, Color color) => Expanded(
      child: Container(
        height: 92,
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 32, color: color, fontWeight: FontWeight.w800)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );

    Widget group(String title, String detail, int count, Color color) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (detail.isNotEmpty && detail != title)
                  Text(detail, style: TextStyle(color: secondaryText, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            metric('$counted', l.summaryRepsCounted, const Color(0xFF2E90FA)),
            const SizedBox(width: 10),
            metric('${scored.length}', l.summaryRepsScored, const Color(0xFF2E90FA)),
            const SizedBox(width: 10),
            metric('$good', l.summaryGoodReps, const Color(0xFF12B76A)),
          ],
        ),
        const SizedBox(height: 18),
        Text(l.summaryMistakes, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (mistakes.isEmpty)
          Text(
            scored.isEmpty ? l.summaryNoneScored : l.summaryNoMistakes,
            style: TextStyle(color: secondaryText, fontWeight: FontWeight.w600),
          ),
        for (final e in mistakes.entries)
          group(
            repLabelName(l, ex, e.value.first),
            feedbackText(l, ex, e.value.first, side),
            e.value.length,
            const Color(0xFFF79009),
          ),
        if (below.isNotEmpty)
          group(
            l.summaryBelowTarget,
            feedbackText(l, ex, below.last, side, simple: true),
            below.length,
            const Color(0xFF2E90FA),
          ),
        if (leg && formPeaks.isNotEmpty && targets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.summaryPeak(roundDeg(nanmedian(formPeaks)), roundDeg(nanmedian(targets))),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (wrong > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              leg ? l.summaryWrongSideLeg(wrong) : l.summaryWrongSideArm(wrong),
              style: const TextStyle(color: Color(0xFFF04438), fontWeight: FontWeight.w700),
            ),
          ),
        if (unsure > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l.summaryUnsure(unsure), style: TextStyle(color: secondaryText)),
          ),
        if (showEveryRep) ...[
          const SizedBox(height: 18),
          Text(l.summaryEveryRep, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final r in v)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(l.liveRep(r.rep), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 5, right: 10),
                    decoration: BoxDecoration(color: repStatusColor(r.status), shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${repLabelName(l, ex, r)}\n',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: feedbackText(l, ex, r, side)),
                        ],
                      ),
                      style: TextStyle(color: secondaryText, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

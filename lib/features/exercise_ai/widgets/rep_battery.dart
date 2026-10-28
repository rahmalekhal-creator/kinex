import 'package:flutter/material.dart';

import '../core/exercise_module.dart';

const repGood = Color(0xFF12B76A);
const repMistake = Color(0xFFF79009);
const repUnsure = Color(0xFF98A2B3);
const repBelowTarget = Color(0xFF2E90FA);
const repWrongSide = Color(0xFFF04438);

Color repColor(RepVerdict v) => switch (v.status) {
  'good' => repGood,
  'mistake' => repMistake,
  'below_target' => repBelowTarget,
  'wrong_side' => repWrongSide,
  _ => repUnsure,
};

/// The set's progress as a battery: one cell per rep, filled from the bottom in order (green = good,
/// orange = mistake, blue = good form below the range target, red = wrong side, grey = not sure / not scored), [capacity] cells in all; the good-rep count on top.
class RepBattery extends StatelessWidget {
  final List<RepVerdict> verdicts;
  final int goodTarget, capacity;

  const RepBattery({
    super.key,
    required this.verdicts,
    required this.goodTarget,
    required this.capacity,
  });

  @override
  Widget build(BuildContext context) {
    final good = verdicts.where((v) => v.status == 'good').length;
    return LayoutBuilder(
      builder: (context, box) {
        // cells shrink on small screens
        final maxH = box.maxHeight.isFinite ? box.maxHeight : 360.0;
        // cells shrink on small screens and for long sets (the reps come from the physiotherapist): always fit
        final gap = capacity > 24 ? 1.0 : 3.0;
        final cell = ((maxH - 70) / capacity - gap).clamp(2.0, 18.0);
        return Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
          decoration: BoxDecoration(
            color: const Color(0x99071120),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$good',
                key: const Key('battery_good'),
                style: const TextStyle(
                  color: repGood,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                '/$goodTarget',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              // battery cap
              Container(
                width: 14,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                ),
              ),
              Container(
                width: 30,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // top cell = last rep slot; the first rep fills the bottom cell
                    for (var i = capacity - 1; i >= 0; i--)
                      Container(
                        key: i < verdicts.length
                            ? Key('battery_cell_$i')
                            : null,
                        height: cell,
                        margin: EdgeInsets.only(
                          top: i == capacity - 1 ? 0 : gap,
                        ),
                        decoration: BoxDecoration(
                          color: i < verdicts.length
                              ? repColor(verdicts[i])
                              : Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

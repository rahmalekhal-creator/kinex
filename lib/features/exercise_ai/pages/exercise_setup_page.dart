import 'package:flutter/material.dart';
import 'package:kinex_pose/kinex_pose.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reeducation/l10n/l10n.dart';

import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';

import '../core/assignment_context.dart';
import '../core/exercise_module.dart';
import '../core/tracked_exercises.dart';
import '../hip/hip_module.dart';
import '../shoulder/shoulder_module.dart';
import '../voice/voice_config.dart';
import '../voice/voice_lines.dart';
import 'live_exercise_page.dart';

/// Before a live set: the exercise and the arm are the physiotherapist's choice (shown, not asked);
/// the patient picks the camera and the voice settings. The model and the timing overlay are developer settings.
class ExerciseSetupPage extends StatefulWidget {
  /// Tracked exercise decided by the physiotherapist: e1 .. e4.
  final String exerciseId;

  /// Side decided by the physiotherapist: left / right (e1: the injured arm; e4: the lifted leg).
  final String side;

  /// The assignment this set belongs to (to save the result for the physiotherapist); null = not saved.
  final AssignmentContext? assignment;

  const ExerciseSetupPage({
    super.key,
    required this.exerciseId,
    required this.side,
    this.assignment,
  });

  @override
  State<ExerciseSetupPage> createState() => _ExerciseSetupPageState();
}

/// The module that follows [exerciseId]: the shoulder module (e1-e3) or the hip module (e4, with its range target).
ExerciseModule exerciseModuleFor(String exerciseId, AssignmentContext? a) =>
    isLegExercise(exerciseId)
    ? HipModule(targetDeg: a?.targetDeg, usualLiftDeg: a?.usualLiftDeg)
    : ShoulderModule();

class _ExerciseSetupPageState extends State<ExerciseSetupPage> {
  late final ExerciseModule _module = exerciseModuleFor(
    widget.exerciseId,
    widget.assignment,
  );
  bool _front = true;
  late String _variant = _module.modelVariants.first;
  bool _showPerf = true;
  bool _fullRes = false; // analyse at 1280 px instead of 640 (to compare on a phone)
  bool _gpu =
      false; // MediaPipe on the GPU (falls back to the CPU if the phone cannot)
  VoiceConfig _voice = const VoiceConfig();

  ExerciseInfo get _info =>
      _module.exercises.firstWhere((e) => e.id == widget.exerciseId);

  @override
  void dispose() {
    _module.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.assistantCameraNeeded)),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveExercisePage(
          module: _module,
          exercise: _info,
          side: widget.side,
          frontCamera: _front,
          variant: _variant,
          showPerf: _showPerf,
          useGpu: _gpu,
          fullResolution: _fullRes,
          assignment: widget.assignment,
          voice: _voice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final secondaryText = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475467);
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final leg = isLegExercise(widget.exerciseId);
    final arm = sideWord(l, widget.exerciseId, widget.side);
    final targetDeg = widget.assignment?.targetDeg;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );

    Widget card(Widget child) => Material(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: child,
      ),
    );

    return Scaffold(
      appBar: kinexAppBar(title: l.assistantTitle),
      body: KinexScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (!KinexPose.supported)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l.assistantAndroidOnly,
                    style: const TextStyle(
                      color: Color(0xFF93370D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              // what the physiotherapist set up: shown, not asked
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF2E90FA),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseTitle(l, widget.exerciseId),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exerciseDescription(l, widget.exerciseId),
                      style: TextStyle(color: secondaryText, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          leg
                              ? Icons.directions_walk_rounded
                              : Icons.front_hand_outlined,
                          size: 18,
                          color: Color(0xFF2E90FA),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          leg
                              ? l.assistantLegLabel(arm)
                              : widget.exerciseId == 'e1'
                              ? l.assistantInjuredArmLabel(arm)
                              : l.assistantArmLabel(arm),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.assistantSetByPhysio,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (leg && targetDeg != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.straighten_rounded,
                            size: 18,
                            color: Color(0xFF2E90FA),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.assistantTargetLabel(
                              targetDeg.toStringAsFixed(0),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              section(l.assistantCamera),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l.assistantCameraFront),
                    icon: const Icon(Icons.camera_front_outlined),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(l.assistantCameraBack),
                    icon: const Icon(Icons.camera_rear_outlined),
                  ),
                ],
                selected: {_front},
                onSelectionChanged: (s) => setState(() => _front = s.first),
              ),
              section(l.assistantVoice),
              card(
                Column(
                  children: [
                    SwitchListTile(
                      key: const Key('setup_voice'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l.assistantVoiceOn,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      value: _voice.spokenFeedback,
                      onChanged: (v) => setState(
                        () => _voice = _voice.copyWith(spokenFeedback: v),
                      ),
                    ),
                    if (_voice.spokenFeedback)
                      Row(
                        children: [
                          Text(
                            l.assistantVoiceRate,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Expanded(
                            child: Slider(
                              value: _voice.speechRate,
                              min: 0.3,
                              max: 0.7,
                              divisions: 4,
                              onChanged: (v) => setState(
                                () => _voice = _voice.copyWith(speechRate: v),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              section(l.assistantDevSettings),
              card(
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.assistantModel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DropdownButton<String>(
                          value: _variant,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final v in _module.modelVariants)
                              DropdownMenuItem(
                                value: v,
                                child: Text(
                                  v == 'multitask'
                                      ? l.assistantModelMultitask
                                      : l.assistantModelSeparate,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _variant = v ?? _variant),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l.assistantShowTiming,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      value: _showPerf,
                      onChanged: (v) => setState(() => _showPerf = v),
                    ),
                    SwitchListTile(
                      key: const Key('setup_gpu'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l.assistantUseGpu,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(l.assistantUseGpuHint),
                      value: _gpu,
                      onChanged: (v) => setState(() => _gpu = v),
                    ),
                    SwitchListTile(
                      key: const Key('setup_full_res'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l.assistantFullResolution,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(l.assistantFullResolutionHint),
                      value: _fullRes,
                      onChanged: (v) => setState(() => _fullRes = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.tips_and_updates_outlined,
                      color: Color(0xFF2E90FA),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        leg
                            ? l.assistantPlacementTipLeg
                            : l.assistantPlacementTip,
                        style: TextStyle(color: secondaryText, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: KinexPose.supported ? _start : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              l.assistantStartSet,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

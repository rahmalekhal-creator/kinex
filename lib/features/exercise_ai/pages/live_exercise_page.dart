import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinex_pose/kinex_pose.dart';
import 'package:reeducation/l10n/l10n.dart';

import '../core/assignment_context.dart';
import '../core/exercise_module.dart';
import '../core/live_session.dart';
import '../core/tracked_exercises.dart';
import '../voice/speech_io.dart';
import '../voice/voice_assistant.dart';
import '../voice/voice_config.dart';
import '../voice/voice_lines.dart';
import '../widgets/live_controls.dart';
import '../widgets/rep_battery.dart';
import '../widgets/skeleton_painter.dart';
import 'set_summary_page.dart';

/// Camera + skeleton (as much of the screen as possible), a short status line, the battery of reps on the side,
/// a small toast after each rep (it disappears after a few seconds), the controls and the microphone at the bottom.
/// The set ends by itself after 10 good reps or 15 reps in total.
class LiveExercisePage extends StatefulWidget {
  final ExerciseModule module;
  final ExerciseInfo exercise;
  final String side, variant;
  final bool frontCamera, showPerf, useGpu, fullResolution;
  final AssignmentContext? assignment;
  final VoiceConfig voice;

  const LiveExercisePage({
    super.key,
    required this.module,
    required this.exercise,
    required this.side,
    required this.variant,
    required this.frontCamera,
    this.showPerf = false,
    this.useGpu = false,
    this.fullResolution = false,
    this.assignment,
    this.voice = const VoiceConfig(),
  });

  @override
  State<LiveExercisePage> createState() => _LiveExercisePageState();
}

class _LiveExercisePageState extends State<LiveExercisePage> {
  late final LiveSession _s = LiveSession(
    module: widget.module,
    exercise: widget.exercise.id,
    side: widget.side,
    variant: widget.variant,
    frontCamera: widget.frontCamera,
    useGpu: widget.useGpu,
    fullResolution: widget.fullResolution,
    // the reps asked by the physiotherapist: the set ends at that many good reps, or twice that many in total
    goodTarget: widget.assignment?.targetReps ?? 0,
  );
  VoiceAssistant? _voice;
  DateTime? _activeSince;
  bool _left = false;

  // the toast of the last rep: shown for a few seconds, then the camera is clear again
  RepVerdict? _toast;
  Timer? _toastTimer;
  int _seenVerdicts = 0;
  static const _toastFor = Duration(seconds: 4);

  // the camera view and the skeleton are built once: the skeleton repaints by itself on every new frame
  late final Widget _camera = Stack(
    fit: StackFit.expand,
    children: [
      const PosePreview(),
      IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: SkeletonPainter(
              frames: _s.frame,
              mirrored: () => _s.previewMirrored,
              highlightSide: () => _s.arm ?? widget.side,
            ),
          ),
        ),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _s.addListener(_onChange);
    _s.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_voice == null) {
      // the voice follows the app language; speech recognition starts only on a tap on the microphone
      final v = VoiceAssistant(
        session: _s,
        output: FlutterTtsOutput(),
        input: SpeechToTextInput(widget.voice),
        config: widget.voice,
      );
      _voice = v;
      v.init(Localizations.localeOf(context).languageCode);
    }
  }

  void _onChange() {
    if (_s.phase == SessionPhase.active) _activeSince ??= DateTime.now();
    if (_s.verdicts.length > _seenVerdicts) {
      _seenVerdicts = _s.verdicts.length;
      _toastTimer?.cancel();
      setState(() => _toast = _s.verdicts.last);
      _toastTimer = Timer(_toastFor, () {
        if (mounted) setState(() => _toast = null);
      });
    }
    if (_s.phase == SessionPhase.done && !_left) {
      _left = true;
      _voice?.shutdown();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SetSummaryPage(
            session: _s,
            exercise: widget.exercise,
            side: widget.side,
            assignment: widget.assignment,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _s.removeListener(_onChange);
    _voice?.dispose(); // stops speech, cancels listening
    if (_s.phase != SessionPhase.done) _s.cancel();
    super.dispose();
  }

  String _status(AppLocalizations l) {
    switch (_s.phase) {
      case SessionPhase.starting:
        return l.liveStarting;
      case SessionPhase.positioning:
        return l.livePositioning;
      case SessionPhase.stillCountdown:
        return l.liveStandStill(_s.countdown.ceil());
      case SessionPhase.active:
        final since = _activeSince;
        return since != null &&
                DateTime.now().difference(since).inMilliseconds < 2000
            ? l.liveStart
            : exerciseTitle(l, widget.exercise.id);
      case SessionPhase.paused:
        return _s.painHold ? l.livePainTitle : l.livePausedTitle;
      case SessionPhase.finishing:
        return l.liveFinishing;
      case SessionPhase.done:
        return l.liveDone;
      case SessionPhase.failed:
        return l.liveCameraProblem('${_s.error}');
    }
  }

  String _wrongSideText(AppLocalizations l) {
    final ex = widget.exercise.id;
    final moving = sideWord(l, ex, widget.side == 'left' ? 'right' : 'left');
    final asked = sideWord(l, ex, widget.side);
    return isLegExercise(ex)
        ? l.liveWrongLeg(moving, asked)
        : l.liveWrongArm(moving, asked);
  }

  bool get _showProgress =>
      _s.phase == SessionPhase.active ||
      _s.phase == SessionPhase.paused ||
      _s.phase == SessionPhase.finishing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: Listenable.merge([_s, ?_voice]),
          builder: (context, _) {
            final voice = _voice;
            final angle = _s.liveAngle;
            final toast = _toast;
            return Stack(
              fit: StackFit.expand,
              children: [
                _camera,
                // progress battery on the side, out of the way of the body
                if (_showProgress)
                  PositionedDirectional(
                    end: 8,
                    top: 90,
                    bottom: 150,
                    child: Center(
                      child: RepBattery(
                        verdicts: _s.verdicts,
                        goodTarget: _s.goodTarget,
                        capacity: _s.maxReps,
                      ),
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black45,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: _pill(
                                _status(l),
                                big: _s.phase == SessionPhase.stillCountdown,
                              ),
                            ),
                            if (_s.phase == SessionPhase.active &&
                                angle.isFinite) ...[
                              const SizedBox(width: 6),
                              _pill(
                                '${angle.round()}°',
                                tooltip: isLegExercise(widget.exercise.id)
                                    ? l.liveLegAngle
                                    : l.liveArmAngle,
                              ),
                            ],
                          ],
                        ),
                        if (widget.showPerf && _s.perfLine.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _s.perfLine,
                              style: const TextStyle(
                                color: Color(0xFFFFD66B),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        // the other arm / leg is doing the exercise: its reps do not count until the patient switches
                        if (_s.sideConflict || _s.wrongSideNow)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _pill(_wrongSideText(l), small: true),
                          ),
                        if (voice != null &&
                            (voice.languageFallback || voice.ttsUnavailable))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _pill(
                              voice.ttsUnavailable
                                  ? l.voiceTtsUnavailable
                                  : l.voiceLanguageFallback,
                              small: true,
                            ),
                          ),
                        const Spacer(),
                        if (_s.phase == SessionPhase.paused)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PausedCard(session: _s),
                          )
                        else
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: toast == null
                                ? const SizedBox.shrink()
                                : _repToast(l, toast),
                          ),
                        // No microphone button: voice commands need the phone's speech-recognition service, which
                        // many devices lack. Spoken feedback (text-to-speech) stays; pause / pain are on-screen
                        // buttons in the controls bar below.
                        LiveControlsBar(
                          session: _s,
                          onFinish: _s.finish,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A small toast for the last rep: a coloured dot, the rep number and the short message.
  Widget _repToast(AppLocalizations l, RepVerdict v) => Padding(
    key: ValueKey(v.rep),
    padding: const EdgeInsetsDirectional.only(
      bottom: 8,
      end: 56,
    ), // keeps clear of the battery
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xD9071120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: repColor(v), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (v.status) {
              'good' => Icons.check_circle_rounded,
              'mistake' => Icons.error_rounded,
              'below_target' => Icons.trending_up_rounded,
              'wrong_side' => Icons.swap_horiz_rounded,
              _ => Icons.help_rounded,
            },
            color: repColor(v),
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${l.liveRep(v.rep)} · ${feedbackText(l, widget.exercise.id, v, widget.side)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pill(
    String text, {
    bool big = false,
    bool small = false,
    String? tooltip,
  }) {
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 10 : 12,
        vertical: small ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xB3071120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: big ? 20 : (small ? 12 : 14),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip, child: pill);
  }
}

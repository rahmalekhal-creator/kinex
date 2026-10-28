/// The manual controls of a live set (Pause / Resume / I feel pain / Finish) and the microphone button.
/// The controls only depend on the session: they work whether or not voice recognition is available.
library;

import 'package:flutter/material.dart';
import 'package:reeducation/l10n/l10n.dart';

import '../core/session_controls.dart';
import '../voice/voice_assistant.dart';

class LiveControlsBar extends StatelessWidget {
  final VoiceSessionControls session;

  /// Ends the set (the only way out of the pain hold).
  final VoidCallback onFinish;

  const LiveControlsBar({
    super.key,
    required this.session,
    required this.onFinish,
  });

  bool get _running =>
      session.phase == SessionPhase.positioning ||
      session.phase == SessionPhase.stillCountdown ||
      session.phase == SessionPhase.active;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final paused = session.phase == SessionPhase.paused;
    final finishing =
        session.phase == SessionPhase.finishing ||
        session.phase == SessionPhase.done;
    final buttons = <Widget>[
      if (_running)
        _button(
          key: const Key('live_pause'),
          icon: Icons.pause_rounded,
          label: l.livePause,
          color: const Color(0xFF475467),
          onTap: () => session.pause(PauseReason.patient),
        ),
      if (paused && !session.painHold)
        _button(
          key: const Key('live_resume'),
          icon: Icons.play_arrow_rounded,
          label: l.liveResume,
          color: const Color(0xFF12B76A),
          onTap: () => session.resume(),
        ),
      if ((_running || paused) && !session.painHold)
        _button(
          key: const Key('live_pain'),
          icon: Icons.healing_rounded,
          label: l.liveReportPain,
          color: const Color(0xFFD92D20),
          onTap: () => session.reportPain(source: 'button'),
        ),
      _button(
        key: const Key('live_finish'),
        icon: finishing ? null : Icons.stop_rounded,
        label: l.liveFinishSet,
        color: const Color(0xFF2E90FA),
        busy: finishing,
        onTap: (session.phase == SessionPhase.active || paused)
            ? onFinish
            : null,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  Widget _button({
    required Key key,
    required IconData? icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool busy = false,
  }) => SizedBox(
    height: 46,
    child: ElevatedButton(
      key: key,
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 20),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The card shown while the set is paused: an ordinary pause, or the pain hold.
class PausedCard extends StatelessWidget {
  final VoiceSessionControls session;
  const PausedCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pain = session.painHold;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (pain ? const Color(0xFFB42318) : const Color(0xFF071120))
            .withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pain
                    ? Icons.healing_rounded
                    : Icons.pause_circle_filled_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pain ? l.livePainTitle : l.livePausedTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pain ? l.livePainBody : l.livePausedBody,
            style: const TextStyle(
              color: Colors.white,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the microphone / voice is doing, in a few words; null when there is nothing worth showing.
String? micStatusText(AppLocalizations l, VoiceAssistant a) {
  final heard = a.heard;
  return switch (a.state) {
    AssistantState.listening =>
      heard != null && heard.isNotEmpty ? l.micHeard(heard) : l.micListening,
    AssistantState.processing =>
      heard != null && heard.isNotEmpty ? l.micHeard(heard) : l.micProcessing,
    AssistantState.unavailable => l.micUnavailable,
    AssistantState.permissionDenied => l.micPermissionDenied,
    AssistantState.error => l.micError,
    AssistantState.speaking || AssistantState.idle => null,
  };
}

/// Small line above the controls while the microphone is in use or not available.
class MicStatus extends StatelessWidget {
  final VoiceAssistant assistant;
  const MicStatus({super.key, required this.assistant});

  @override
  Widget build(BuildContext context) {
    final text = micStatusText(context.l10n, assistant);
    if (text == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC071120),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Round microphone button; its colour and icon show what the assistant is doing.
class MicButton extends StatelessWidget {
  final VoiceAssistant assistant;
  const MicButton({super.key, required this.assistant});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (assistant.state) {
      AssistantState.listening => (Icons.mic_rounded, const Color(0xFFD92D20)),
      AssistantState.processing => (
        Icons.hourglass_top_rounded,
        const Color(0xFFF79009),
      ),
      AssistantState.speaking => (
        Icons.volume_up_rounded,
        const Color(0xFF2E90FA),
      ),
      AssistantState.unavailable || AssistantState.permissionDenied => (
        Icons.mic_off_rounded,
        const Color(0xFF667085),
      ),
      AssistantState.error => (
        Icons.error_outline_rounded,
        const Color(0xFFD92D20),
      ),
      AssistantState.idle => (Icons.mic_none_rounded, const Color(0xFF2E90FA)),
    };
    return Tooltip(
      message: context.l10n.micTooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('live_mic'),
          customBorder: const CircleBorder(),
          onTap: assistant.toggleListening,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

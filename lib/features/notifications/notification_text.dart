import 'package:flutter/material.dart';

import 'package:reeducation/l10n/app_localizations.dart';

import 'data/app_notification.dart';

/// Title, one-line description, icon and colour of a notification, in the user's language.
class NotificationText {
  static String title(AppLocalizations l, AppNotification n) {
    final name = n.str('patient_name');
    switch (n.type) {
      case 'message':
        return l.notifMessageTitle(n.str('sender_name'));
      case 'routine_update':
        return l.notifRoutineTitle;
      case 'inactivity':
        return l.notifInactivityTitle(name);
      case 'incorrect_reps':
        return l.notifIncorrectTitle(name);
      case 'pain_report':
        return l.notifPainTitle(name);
    }
    return n.title;
  }

  static String body(AppLocalizations l, AppNotification n) {
    switch (n.type) {
      case 'message':
        return n.str('preview');
      case 'routine_update':
        return l.notifRoutineBody(n.str('exercise_name'), n.number('sets'), n.number('reps'));
      case 'inactivity':
        return l.notifInactivityBody(n.str('date'), n.number('prescribed'));
      case 'incorrect_reps':
        return l.notifIncorrectBody(n.str('exercise_name'), n.number('mistakes'), n.number('judged'));
      case 'pain_report':
        final level = n.numberOrNull('pain_level');
        return level != null
            ? l.notifPainBodyLevel(n.str('exercise_name'), level)
            : l.notifPainBodyDuring(n.str('exercise_name'));
    }
    return n.body;
  }

  static IconData icon(AppNotification n) => switch (n.type) {
        'message' => Icons.chat_bubble_outline_rounded,
        'routine_update' => Icons.fitness_center_rounded,
        'inactivity' => Icons.event_busy_rounded,
        'incorrect_reps' => Icons.rule_rounded,
        'pain_report' => Icons.healing_rounded,
        _ => Icons.notifications_none_rounded,
      };

  static Color color(AppNotification n) => switch (n.category) {
        'messages' => const Color(0xFF2E90FA),
        'routine' => const Color(0xFF12B76A),
        'progress' => const Color(0xFFF79009),
        'pain' => const Color(0xFFD92D20),
        _ => const Color(0xFF667085),
      };

  static String category(AppLocalizations l, String c) => switch (c) {
        'messages' => l.notifCategoryMessages,
        'routine' => l.notifCategoryRoutine,
        'progress' => l.notifCategoryProgress,
        'pain' => l.notifCategoryPain,
        _ => l.notifCategoryAll,
      };

  /// "just now", "5 min ago", "3 h ago", "Yesterday", or the date - against the server clock, so a phone in another
  /// time zone (or with a wrong clock) still shows the right age.
  static String when(AppLocalizations l, DateTime? at, DateTime? serverNow) {
    if (at == null) return '';
    final now = serverNow ?? DateTime.now();
    final d = now.difference(at);
    if (d.inMinutes < 1) return l.notifJustNow;
    if (d.inMinutes < 60) return l.notifMinutesAgo(d.inMinutes);
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    if (day == today) return l.notifHoursAgo(d.inHours);
    if (today.difference(day).inDays == 1) return l.notifYesterday;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  }
}

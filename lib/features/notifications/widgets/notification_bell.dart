import 'package:flutter/material.dart';

import 'package:reeducation/l10n/l10n.dart';

import '../data/app_notification.dart';
import '../data/unread_notifier.dart';

/// Bell with the real unread count (polled), for the home pages' app bars.
class NotificationBell extends StatefulWidget {
  final VoidCallback onPressed;
  final double size;
  final Color? color;

  const NotificationBell({super.key, required this.onPressed, this.size = 24, this.color});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    UnreadNotifier.instance.attach();
  }

  @override
  void dispose() {
    UnreadNotifier.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UnreadCounts>(
      valueListenable: UnreadNotifier.instance,
      builder: (context, counts, _) {
        final n = counts.total;
        final urgent = (counts.byCategory['pain'] ?? 0) > 0;
        return IconButton(
          key: const Key('notification_bell'),
          tooltip: n > 0 ? '${context.l10n.notifications} (${context.l10n.notifUnreadCount(n)})' : context.l10n.notifications,
          onPressed: widget.onPressed,
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(n > 99 ? '99+' : '$n', key: const Key('notification_badge')),
            backgroundColor: urgent ? const Color(0xFFD92D20) : const Color(0xFFF04438),
            child: Icon(
              n > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_rounded,
              size: widget.size,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

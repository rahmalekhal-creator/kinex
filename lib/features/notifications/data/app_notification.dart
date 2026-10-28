/// One notification as stored by the backend (reed/notifications_api.php). The server keeps the facts in `data`;
/// the app writes the text in the user's language (notification_text.dart).
class AppNotification {
  final int id;
  final String type; // message | routine_update | inactivity | incorrect_reps | pain_report
  final String category; // messages | routine | progress | pain
  final int priority; // 0 normal, 1 important, 2 urgent
  final String title; // server text (English), used when the type is unknown to this app version
  final String body;
  final Map<String, dynamic> data;
  final DateTime? createdAt; // clinic time, as stored
  final bool read;
  final bool resolved;

  const AppNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    required this.read,
    required this.resolved,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _int(j['id']),
        type: (j['type'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        priority: _int(j['priority']),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        data: j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : const <String, dynamic>{},
        createdAt: parseServerTime(j['created_at']),
        read: j['read'] == true,
        resolved: j['resolved'] == true,
      );

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        category: category,
        priority: priority,
        title: title,
        body: body,
        data: data,
        createdAt: createdAt,
        read: read ?? this.read,
        resolved: resolved,
      );

  bool get isUrgent => priority >= 2;

  /// Notifications about one patient, sent to their physiotherapist.
  bool get isAboutPatient => type == 'inactivity' || type == 'incorrect_reps' || type == 'pain_report';

  String str(String key) => (data[key] ?? '').toString();
  int number(String key) => _int(data[key]);
  int? numberOrNull(String key) => data[key] == null ? null : int.tryParse(data[key].toString());
}

int _int(Object? v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

/// 'YYYY-MM-DD HH:MM:SS' (clinic time) -> a DateTime with the same wall-clock values.
DateTime? parseServerTime(Object? v) {
  final s = (v ?? '').toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

class NotificationPage {
  final List<AppNotification> items;
  final bool hasMore;
  final UnreadCounts unread;
  final DateTime? serverNow;

  const NotificationPage({required this.items, required this.hasMore, required this.unread, this.serverNow});
}

class UnreadCounts {
  static const categories = ['messages', 'routine', 'progress', 'pain'];
  final int total;
  final Map<String, int> byCategory;

  const UnreadCounts(this.total, this.byCategory);
  static const zero = UnreadCounts(0, {});

  factory UnreadCounts.fromJson(Map<String, dynamic> j) {
    final by = <String, int>{};
    if (j['unread_by_category'] is Map) {
      (j['unread_by_category'] as Map).forEach((k, v) => by[k.toString()] = _int(v));
    }
    return UnreadCounts(_int(j['unread']), by);
  }

  int of(String category) => category == 'all' ? total : (byCategory[category] ?? 0);
}

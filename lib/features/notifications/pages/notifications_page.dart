import 'package:flutter/material.dart';

import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/widgets/kinex_app_bar.dart';
import 'package:reeducation/widgets/kinex_screen_background.dart';

import '../data/app_notification.dart';
import '../data/notifications_api.dart';
import '../data/unread_notifier.dart';
import '../notification_text.dart';
import 'notification_settings_page.dart';

/// Opens what a notification is about. The home page that shows the bell provides it (it knows the account and its
/// pages); returns normally when it opened something, throws [NotificationsException] when the item is gone.
typedef NotificationOpener = Future<void> Function(BuildContext context, AppNotification n);

class NotificationsPage extends StatefulWidget {
  final NotificationOpener onOpen;
  final NotificationsApi? api;

  /// The category filters offered (the ones this role can receive), after "All".
  final List<String> categories;

  static const patientCategories = ['messages', 'routine'];
  static const physioCategories = ['pain', 'progress', 'messages'];

  /// Shows the settings button (which types are received).
  final bool showSettings;

  const NotificationsPage({
    super.key,
    required this.onOpen,
    this.api,
    this.categories = UnreadCounts.categories,
    this.showSettings = false,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _pageSize = 20;
  late final _categories = ['all', ...widget.categories];

  late final NotificationsApi _api = widget.api ?? UnreadNotifier.instance.api;
  final ScrollController _scroll = ScrollController();

  String _category = 'all';
  List<AppNotification> _items = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  NotificationsFailure? _error;
  DateTime? _serverNow;
  int _seenTotal = -1;
  UnreadCounts _unread = UnreadNotifier.instance.value;

  @override
  void initState() {
    super.initState();
    UnreadNotifier.instance.attach();
    UnreadNotifier.instance.addListener(_onCountChanged);
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    UnreadNotifier.instance.removeListener(_onCountChanged);
    UnreadNotifier.instance.detach();
    _scroll.dispose();
    super.dispose();
  }

  /// A new notification arrived (seen by the poll): reload the first page, unless the user is reading further down.
  void _onCountChanged() {
    final counts = UnreadNotifier.instance.value;
    if (!mounted) return;
    setState(() => _unread = counts);
    if (counts.total > _seenTotal && !_loading && (!_scroll.hasClients || _scroll.offset < 200)) {
      _load(silent: true);
    }
  }

  void _onScroll() {
    if (_hasMore && !_loadingMore && _scroll.position.extentAfter < 300) _loadMore();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final p = await _api.list(page: 1, limit: _pageSize, category: _category);
      if (!mounted) return;
      setState(() {
        _items = p.items;
        _page = 1;
        _hasMore = p.hasMore;
        _serverNow = p.serverNow;
        _loading = false;
        _error = null;
        _unread = p.unread;
        _seenTotal = p.unread.total;
      });
      UnreadNotifier.instance.set(p.unread);
    } on NotificationsException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _items.isEmpty) _error = e.reason;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final p = await _api.list(page: _page + 1, limit: _pageSize, category: _category);
      if (!mounted) return;
      final known = _items.map((n) => n.id).toSet();
      setState(() {
        _items = [..._items, ...p.items.where((n) => !known.contains(n.id))];
        _page += 1;
        _hasMore = p.hasMore;
        _loadingMore = false;
      });
    } on NotificationsException {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      _snack(context.l10n.notifLoadError);
    }
  }

  void _selectCategory(String c) {
    if (c == _category) return;
    setState(() => _category = c);
    _load();
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.read) return;
    _replace(n.copyWith(read: true));
    try {
      final counts = await _api.markRead(n.id);
      _setCounts(counts);
    } on NotificationsException {
      _replace(n); // not saved: show it unread again
    }
  }

  Future<void> _markAllRead() async {
    final before = _items;
    setState(() => _items = [for (final n in _items) n.copyWith(read: true)]);
    try {
      _setCounts(await _api.markAllRead(category: _category));
    } on NotificationsException {
      if (!mounted) return;
      setState(() => _items = before);
      _snack(context.l10n.notifLoadError);
    }
  }

  void _setCounts(UnreadCounts c) {
    UnreadNotifier.instance.set(c);
    if (!mounted) return;
    setState(() {
      _unread = c;
      _seenTotal = c.total;
    });
  }

  void _replace(AppNotification n) {
    if (!mounted) return;
    setState(() => _items = [for (final x in _items) x.id == n.id ? n : x]);
  }

  Future<void> _open(AppNotification n) async {
    _markRead(n);
    try {
      await widget.onOpen(context, n);
    } on NotificationsException catch (e) {
      if (!mounted) return;
      _snack(e.reason == NotificationsFailure.forbidden
          ? context.l10n.notifNoLongerAssigned
          : e.reason == NotificationsFailure.notFound
              ? context.l10n.notifUnavailable
              : context.l10n.notifLoadError);
    }
    // back from the conversation / exercise / patient: read states may have changed there
    if (mounted) _load(silent: true);
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final unreadHere = _unread.of(_category);
    return Scaffold(
      appBar: kinexAppBar(
        title: l.notifications,
        actions: [
          if (unreadHere > 0)
            IconButton(
              key: const Key('notif_mark_all'),
              tooltip: l.notifMarkAllRead,
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
          if (widget.showSettings)
            IconButton(
              key: const Key('notif_settings'),
              tooltip: l.notifSettingsTitle,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NotificationSettingsPage(api: widget.api)),
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
        ],
      ),
      body: KinexScreenBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
                  child: Text(
                    l.notifUnreadCount(_unread.total),
                    key: const Key('notif_unread_total'),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      for (final c in _categories)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            key: Key('notif_cat_$c'),
                            selected: _category == c,
                            onSelected: (_) => _selectCategory(c),
                            label: Text(_unread.of(c) > 0
                                ? '${NotificationText.category(l, c)} (${_unread.of(c)})'
                                : NotificationText.category(l, c)),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: RefreshIndicator(onRefresh: _load, child: _body())),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final l = context.l10n;
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _message(
        _error == NotificationsFailure.signedOut ? l.notifSignedOut : l.notifLoadError,
        Icons.cloud_off_rounded,
        action: _error == NotificationsFailure.signedOut ? null : TextButton(onPressed: _load, child: Text(l.retry)),
      );
    }
    if (_items.isEmpty) {
      return _message(_category == 'all' ? l.notifEmpty : l.notifEmptyCategory, Icons.notifications_off_outlined);
    }
    return ListView.builder(
      key: const Key('notif_list'),
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _items.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(onPressed: _loadMore, child: Text(l.notifLoadMore)),
            ),
          );
        }
        return _tile(_items[i]);
      },
    );
  }

  Widget _message(String text, IconData icon, {Widget? action}) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(icon, size: 48, color: const Color(0xFF98A2B3)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(text, textAlign: TextAlign.center, key: const Key('notif_state_text')),
          ),
          if (action != null) Center(child: action),
        ],
      );

  Widget _tile(AppNotification n) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = NotificationText.color(n);
    final unreadBg = isDark ? const Color(0xFF13233D) : const Color(0xFFEFF6FF);
    final readBg = isDark ? const Color(0xFF111827) : Colors.white;
    final secondary = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF667085);
    final body = NotificationText.body(l, n);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: Key('notif_${n.id}'),
        color: n.read ? readBg : unreadBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _open(n),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: BorderDirectional(
                start: BorderSide(color: n.isUrgent && !n.read ? color : Colors.transparent, width: 4),
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(NotificationText.icon(n), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        NotificationText.title(l, n),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800, fontSize: 15),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondary)),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(NotificationText.when(l, n.createdAt, _serverNow),
                              style: TextStyle(fontSize: 12, color: secondary)),
                          if (n.isUrgent) _chip(l.notifUrgent, const Color(0xFFD92D20)),
                          if (n.resolved) _chip(l.notifResolved, const Color(0xFF12B76A)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!n.read)
                  IconButton(
                    key: Key('notif_read_${n.id}'),
                    tooltip: l.notifMarkRead,
                    onPressed: () => _markRead(n),
                    icon: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Color(0xFF2E90FA), shape: BoxShape.circle),
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

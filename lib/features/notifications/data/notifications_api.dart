import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:reeducation/auth_session.dart';
import 'package:reeducation/config.dart';

import 'app_notification.dart';

/// Why a call failed: the screens show a matching message.
enum NotificationsFailure { signedOut, notFound, forbidden, network, server }

class NotificationsException implements Exception {
  final NotificationsFailure reason;
  final String message;
  const NotificationsException(this.reason, [this.message = '']);
  @override
  String toString() => 'NotificationsException($reason, $message)';
}

/// Client of reed/notifications_api.php. The account is the one of the login token.
class NotificationsApi {
  NotificationsApi({http.Client? client, String? baseUrl, String? Function()? token})
      : _client = client ?? http.Client(),
        _base = baseUrl ?? kServerBaseUrl,
        _token = token ?? (() => AuthSession.token);

  final http.Client _client;
  final String _base;
  final String? Function() _token;

  Uri _uri([Map<String, String>? query]) => Uri.parse('${_base}notifications_api.php').replace(queryParameters: query);

  Future<Map<String, dynamic>> _call(Future<http.Response> Function(Map<String, String> headers) send) async {
    final token = _token();
    if (token == null || token.isEmpty) {
      throw const NotificationsException(NotificationsFailure.signedOut);
    }
    final http.Response r;
    try {
      r = await send({'X-Auth-Token': token}).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const NotificationsException(NotificationsFailure.network, 'timeout');
    } catch (e) {
      throw NotificationsException(NotificationsFailure.network, e.toString());
    }
    Map<String, dynamic> body = const {};
    try {
      final d = json.decode(r.body);
      if (d is Map<String, dynamic>) body = d;
    } catch (_) {}
    final msg = (body['message'] ?? '').toString();
    switch (r.statusCode) {
      case 200:
        if (body['error'] == true) throw NotificationsException(NotificationsFailure.server, msg);
        return body;
      case 401:
        throw NotificationsException(NotificationsFailure.signedOut, msg);
      case 403:
        throw NotificationsException(NotificationsFailure.forbidden, msg);
      case 404:
        throw NotificationsException(NotificationsFailure.notFound, msg);
      default:
        throw NotificationsException(NotificationsFailure.server, 'HTTP ${r.statusCode} $msg');
    }
  }

  Future<NotificationPage> list({int page = 1, int limit = 20, String category = 'all', bool unreadOnly = false}) async {
    final j = await _call((h) => _client.get(
        _uri({
          'action': 'list',
          'page': '$page',
          'limit': '$limit',
          'category': category,
          'unread_only': unreadOnly ? '1' : '0',
        }),
        headers: h));
    final items = (j['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => AppNotification.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return NotificationPage(
      items: items,
      hasMore: j['has_more'] == true,
      unread: UnreadCounts.fromJson(j),
      serverNow: parseServerTime(j['server_now']),
    );
  }

  Future<UnreadCounts> count() async =>
      UnreadCounts.fromJson(await _call((h) => _client.get(_uri({'action': 'count'}), headers: h)));

  Future<UnreadCounts> markRead(int id) async => UnreadCounts.fromJson(
      await _call((h) => _client.post(_uri(), headers: h, body: {'action': 'read', 'id': '$id'})));

  Future<UnreadCounts> markAllRead({String category = 'all'}) async => UnreadCounts.fromJson(
      await _call((h) => _client.post(_uri(), headers: h, body: {'action': 'read_all', 'category': category})));

  /// type -> on/off, for the types the account's role receives (on unless turned off).
  Future<Map<String, bool>> prefs() async =>
      _prefsOf(await _call((h) => _client.get(_uri({'action': 'prefs'}), headers: h)));

  /// Turns a type off (such notifications are then not created at all) or back on.
  Future<Map<String, bool>> setPref(String type, bool enabled) async => _prefsOf(await _call((h) =>
      _client.post(_uri(), headers: h, body: {'action': 'set_pref', 'type': type, 'enabled': enabled ? '1' : '0'})));

  static Map<String, bool> _prefsOf(Map<String, dynamic> j) => {
        if (j['prefs'] is Map)
          for (final e in (j['prefs'] as Map).entries) e.key.toString(): e.value == true,
      };

  /// What the notification points to (patient, day, set, report...), checked again by the server: a patient who is
  /// no longer assigned to the physiotherapist gives [NotificationsFailure.forbidden].
  Future<Map<String, dynamic>> context(int id) =>
      _call((h) => _client.get(_uri({'action': 'context', 'id': '$id'}), headers: h));
}

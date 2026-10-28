/// The login token of the signed-in account (issued by login.php, kept in memory only: logging out or closing the
/// app ends it). Sent as the X-Auth-Token header by the endpoints that check who is calling (notifications_api.php).
class AuthSession {
  static String? token;

  static bool get isSignedIn => (token ?? '').isNotEmpty;

  static void clear() => token = null;
}

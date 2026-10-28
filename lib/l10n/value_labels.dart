import 'l10n.dart';

/// Display name for an account role stored in the database.
String roleLabel(AppLocalizations l10n, String role) {
  switch (role.trim().toLowerCase()) {
    case 'clinic':
      return l10n.clinic;
    case 'therapist':
    case 'physiotherapist':
      return l10n.physiotherapist;
    case 'patient':
      return l10n.patient;
    case 'admin':
      return l10n.roleAdmin;
    default:
      return role;
  }
}

/// Display name for an exercise / complaint status stored in the database.
String statusLabel(AppLocalizations l10n, String status) {
  switch (status.trim().toLowerCase()) {
    case 'pending':
      return l10n.pending;
    case 'completed':
    case 'done':
      return l10n.completed;
    default:
      return status;
  }
}

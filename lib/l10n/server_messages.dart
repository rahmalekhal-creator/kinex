import 'l10n.dart';

/// Translates a message produced by the PHP backend or by DB_API.dart.
///
/// Messages are matched on their original English text, so English output is
/// unchanged. Unknown messages (e.g. developer-facing database errors) are
/// returned as-is.
String localizeServerMessage(String raw) {
  final l10n = L10n.current;
  final message = raw.trim();
  if (l10n.localeName == 'en' || message.isEmpty) {
    return raw;
  }

  final known = _knownMessages(l10n)[message];
  if (known != null) {
    return known;
  }

  if (message.startsWith('Unable to reach server')) {
    return l10n.errorServerUnreachable;
  }
  if (message.endsWith('timed out') || message.startsWith('Connection timeout')) {
    return l10n.errorTimeout;
  }
  final status = RegExp(r'(?:Server error:?|status code)\s*(\d{3})').firstMatch(message);
  if (status != null) {
    return l10n.errorServerStatus(status.group(1)!);
  }
  return raw;
}

/// Turns a caught error into a user-facing, localized message.
String localizeError(Object error) {
  return localizeServerMessage(error.toString().replaceFirst('Exception: ', ''));
}

Map<String, String> _knownMessages(AppLocalizations l) => {
      'No account found with this email': l.srvNoAccountForEmail,
      'Invalid password': l.srvInvalidPassword,
      'Waiting for approval': l.srvWaitingForApproval,
      'Email and password are required': l.srvEmailPasswordRequired,
      'Clinic registered. Waiting for admin approval.': l.srvClinicRegistered,
      'Email already exists': l.srvEmailExists,
      'Justification file is required': l.srvJustifRequired,
      'Justification file must be PDF/JPG/PNG': l.srvJustifType,
      'Justification file must be <= 8MB': l.srvJustifSize,
      'Justification upload failed': l.srvJustifUploadFailed,
      'Clinic name must be at least 3 characters': l.srvClinicNameMin,
      'Name must be at least 2 characters': l.srvNameMin,
      'Invalid phone number': l.srvInvalidPhoneNumber,
      'Profile updated successfully': l.srvProfileUpdated,
      'Photo uploaded successfully': l.srvPhotoUploaded,
      'Photo must be JPG/PNG/WEBP': l.srvPhotoType,
      'Clinic profile updated successfully': l.srvClinicProfileUpdated,
      'Clinic profile not found': l.srvClinicProfileNotFound,
      'Clinic account must be approved before using this feature': l.srvClinicMustBeApproved,
      'Member not found in your clinic': l.srvMemberNotFound,
      'Patient account created successfully': l.srvPatientCreated,
      'Therapist account created successfully': l.srvTherapistCreated,
      'Patient deleted successfully': l.srvPatientDeleted,
      'Therapist deleted successfully': l.srvTherapistDeleted,
      'Stripe checkout ready. Complete payment then tap Verify.': l.srvStripeCheckoutReady,
      'Payment is not completed yet. Finish checkout and try again.': l.srvPaymentNotCompleted,
      'Payment confirmed. Subscription activated successfully.': l.srvPaymentConfirmed,
      'Payment reference not found for this clinic': l.srvPaymentRefNotFound,
      'Clinic approved': l.srvClinicApproved,
      'Clinic moved to waiting state': l.srvClinicMovedToWaiting,
      'You cannot delete your own admin account': l.srvCannotDeleteSelf,
      'Admin accounts cannot be deleted': l.srvAdminNotDeletable,
      'Admin access required': l.srvAdminRequired,
      'Exercise assigned successfully': l.srvExerciseAssigned,
      'Exercise removed successfully': l.srvExerciseRemoved,
      'sets and reps must be greater than 0': l.srvSetsRepsPositive,
      'Exercise not found': l.srvExerciseNotFound,
      'Patient is not assigned to this physiotherapist': l.srvPatientNotAssignedToPhysio,
      'Patient not assigned to this physiotherapist': l.srvPatientNotAssignedToPhysio2,
      'AI feedback is available only with active clinic subscription': l.srvAiFeedbackSubscription,
      'Physiotherapist not found': l.srvPhysioNotFound,
      'Physiotherapist profile not found': l.srvPhysioProfileNotFound,
      'Patient profile not found': l.srvPatientProfileNotFound,
      'No physiotherapist is assigned to you yet': l.srvNoPhysioAssigned,
      'Message content is required': l.srvMessageContentRequired,
      'Message sent successfully': l.srvMessageSent,
      'Complaint submitted successfully': l.srvComplaintSubmitted,
      'Description must be at least 5 characters': l.srvDescriptionMin,
      'Progress report saved': l.srvProgressSaved,
      'Exercise completed and progress saved': l.srvExerciseCompletedSaved,
      'Patient exercise assignment not found': l.srvAssignmentNotFound,
      'Premium subscription required for video upload': l.srvPremiumForVideo,
      'Unsupported video format': l.srvUnsupportedVideo,
      'Account not found': l.srvAccountNotFound,
      'Account deleted': l.srvAccountDeleted,
      'Clinic deleted': l.srvClinicDeleted,
      'Clinic updated': l.srvClinicUpdated,
      'Account updated': l.srvAccountUpdated,
      'AI feedback video uploaded successfully': l.srvAiVideoUploaded,
      'Invalid response format from server': l.errorInvalidResponse,
      'Invalid email format': l.invalidEmailFormat,
      'Invalid phone format': l.invalidPhoneFormat,
      'Password must be at least 6 characters': l.passwordMinLength,
      'Name and phone are required': l.nameAndPhoneRequired,
    };

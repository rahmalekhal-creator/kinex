// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String accountRoleActive(String active, String role) {
    return 'Role: $role | Active: $active';
  }

  @override
  String get accounts => 'Accounts';

  @override
  String get addMember => 'Add member';

  @override
  String get addNewMember => 'Add new member';

  @override
  String get address => 'Address';

  @override
  String get adminHome => 'Admin Home';

  @override
  String get aiCoachBanner =>
      'Kinex AI Coach: smarter rehab guidance, every day.';

  @override
  String get aiFeedback => 'AI Feedback';

  @override
  String aiFeedbackFor(String name) {
    return 'AI Feedback - $name';
  }

  @override
  String get all => 'All';

  @override
  String get allSetsDone => 'All sets done! ✓';

  @override
  String get approve => 'Approve';

  @override
  String get armSideLeft => 'left';

  @override
  String get armSideRight => 'right';

  @override
  String get assign => 'Assign';

  @override
  String get assignExercise => 'Assign Exercise';

  @override
  String get assignExerciseTitle => 'Assign exercise';

  @override
  String get assignedBy => 'Assigned by';

  @override
  String get assignedExercises => 'Assigned Exercises';

  @override
  String get assignedPatients => 'Assigned patients';

  @override
  String get assignedPhysiotherapist => 'Assigned physiotherapist';

  @override
  String get assistantAndroidOnly =>
      'The live exercise assistant runs on Android phones.';

  @override
  String assistantArmLabel(String arm) {
    return 'Arm: $arm';
  }

  @override
  String get assistantCamera => 'Camera';

  @override
  String get assistantCameraBack => 'Back';

  @override
  String get assistantCameraFront => 'Front';

  @override
  String get assistantCameraNeeded =>
      'Camera access is needed for the exercise assistant.';

  @override
  String get assistantDevSettings => 'Developer settings';

  @override
  String get assistantFullResolution => 'Full-resolution analysis (1280 px)';

  @override
  String get assistantFullResolutionHint =>
      'Slower. By default the frames are analysed at 640 px: the same landmarks, much less work per frame.';

  @override
  String assistantInjuredArmLabel(String arm) {
    return 'Injured arm: $arm';
  }

  @override
  String assistantLegLabel(String leg) {
    return 'Lifted leg: $leg';
  }

  @override
  String get assistantModel => 'Model';

  @override
  String get assistantModelMultitask => 'Multi-task network';

  @override
  String get assistantModelSeparate => 'Separate networks';

  @override
  String get assistantPlacementTip =>
      'Put the phone upright in front of you, about 2-3 m away, so that your whole body from the knees up is in view. Stand still for 2 seconds when asked, then start.';

  @override
  String get assistantPlacementTipLeg =>
      'Put the phone upright in front of you at hip height, about 2-3 m away, so that your WHOLE body is in view, feet included. Put the chair beside the leg you stand on and hold it. Stand still for 2 seconds when asked, then start.';

  @override
  String get assistantSetByPhysio => 'set by your physiotherapist';

  @override
  String get assistantShowTiming => 'Show timing overlay';

  @override
  String get assistantStartSet => 'Start the set';

  @override
  String assistantTargetLabel(String deg) {
    return 'Your target: $deg°';
  }

  @override
  String get assistantTitle => 'Exercise assistant';

  @override
  String get assistantUseGpu => 'Run pose detection on the GPU (developer)';

  @override
  String get assistantUseGpuHint =>
      'Faster on many phones; uses the CPU if the phone cannot. The timing line shows which one runs.';

  @override
  String get assistantVoice => 'Voice assistant';

  @override
  String get assistantVoiceOn => 'Spoken instructions and corrections';

  @override
  String get assistantVoiceRate => 'Speaking speed';

  @override
  String get becomePartnerClinic => 'Become a partner clinic';

  @override
  String get birthDate => 'Birth date';

  @override
  String get birthDateRequiredForPatients =>
      'Birth date is required for patients.';

  @override
  String get bodyRegionHip => 'Hip';

  @override
  String get bodyRegionOther => 'Other exercises';

  @override
  String get bodyRegionShoulder => 'Shoulder';

  @override
  String get cancel => 'Cancel';

  @override
  String get changeLanguage => 'Change language';

  @override
  String get clinic => 'Clinic';

  @override
  String get clinicComplaints => 'Clinic Complaints';

  @override
  String get clinicDashboard => 'Clinic Dashboard';

  @override
  String get clinicEmail => 'Clinic email';

  @override
  String clinicMembersCount(String count) {
    return 'Clinic members ($count)';
  }

  @override
  String get clinicName => 'Clinic name';

  @override
  String get clinicOnlySignupNote =>
      'Only clinics can register here. Patients and physiotherapists are created from the clinic dashboard using the logged-in clinic account.';

  @override
  String get clinicProfile => 'Clinic profile';

  @override
  String get clinicProfileSubtitle =>
      'Update your clinic information and picture.';

  @override
  String get clinicRegistration => 'Clinic registration';

  @override
  String get clinicRegistrationIntro =>
      'Create a clinic account. Upload your professional justification file so admin can validate your registration quickly.';

  @override
  String clinicValue(String name) {
    return 'Clinic: $name';
  }

  @override
  String get clinics => 'Clinics';

  @override
  String comingSoon(String title) {
    return '$title coming soon';
  }

  @override
  String get complaintSentSuccessfully => 'Complaint sent successfully.';

  @override
  String get complaints => 'Complaints';

  @override
  String get completeLabel => 'Complete';

  @override
  String get completed => 'Completed';

  @override
  String completedOfAssigned(String completed, String assigned) {
    return '$completed completed / $assigned assigned';
  }

  @override
  String completedRepsOf(String done, String target) {
    return 'Completed – $done$target reps ✓';
  }

  @override
  String get continueLabel => 'Continue';

  @override
  String get continueToLogin => 'Continue to Login';

  @override
  String get createMember => 'Create member';

  @override
  String get dailyCompletionPercent => 'Daily Completion %';

  @override
  String dateAtTime(String time, String date) {
    return '$date at $time';
  }

  @override
  String dateValue(String date) {
    return 'Date: $date';
  }

  @override
  String get delete => 'Delete';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String deleteAccountConfirm(String id, String label) {
    return 'Delete \"$label\" (ID: $id)?';
  }

  @override
  String get deleteMember => 'Delete member';

  @override
  String deleteMemberConfirm(String name, String role) {
    return 'Delete $role \"$name\" from this clinic?';
  }

  @override
  String get describeYourComplaint => 'Describe your complaint';

  @override
  String get description => 'Description';

  @override
  String get descriptionRequired => 'Description is required';

  @override
  String get documentAttached => 'Document attached';

  @override
  String get done => 'Done';

  @override
  String get e4ProgressEmpty => 'No hip abduction set recorded yet.';

  @override
  String e4ProgressGoodShare(int percent) {
    return 'Good form: $percent %';
  }

  @override
  String get e4ProgressMedian => 'Median lift';

  @override
  String get e4ProgressPerClass => 'Reps per class';

  @override
  String get e4ProgressTarget => 'Target';

  @override
  String get e4ProgressTitle => 'Hip abduction - range over time';

  @override
  String e4ProgressUsualLift(String deg) {
    return 'Usual lift: $deg°';
  }

  @override
  String get editInformation => 'Edit information';

  @override
  String get editInformationTitle => 'Edit Information';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get email => 'Email';

  @override
  String get emailAddress => 'Email address';

  @override
  String get emailHint => 'name@example.com';

  @override
  String emailValue(String email) {
    return 'Email: $email';
  }

  @override
  String get enterValidEmail => 'Enter a valid email address';

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get error => 'Error';

  @override
  String get errorInvalidResponse => 'Invalid response format from server';

  @override
  String errorServerStatus(String code) {
    return 'Server error ($code).';
  }

  @override
  String get errorServerUnreachable =>
      'Unable to reach the server. Check your connection and try again.';

  @override
  String get errorTimeout => 'The request timed out. Please try again.';

  @override
  String get exE1Desc =>
      'Hold a stick with both hands and lift it forward and up, then lower it all the way down.';

  @override
  String get exE1Simple =>
      'Hold the stick with both hands. Lift it up slowly. Then bring it all the way down.';

  @override
  String get exE1Title => 'Forward elevation with a stick';

  @override
  String get exE2Desc =>
      'Lift one straight arm out to the side, then bring it back down along your body.';

  @override
  String get exE2Simple =>
      'Keep your arm straight. Lift it to the side. Then put it back down.';

  @override
  String get exE2Title => 'Arm abduction';

  @override
  String get exE3Desc =>
      'Keep the elbow against your body, bent at 90 degrees, and rotate the forearm outward and back.';

  @override
  String get exE3Simple =>
      'Keep your elbow against your side. Turn your hand outward. Then bring it back.';

  @override
  String get exE3Title => 'Arm rotation, elbow at the side';

  @override
  String get exE4Desc =>
      'Stand facing the phone with a chair beside you and hold it with the hand on the side of the leg you stand on. Lift the other leg sideways, knee straight and trunk upright, then lower it with control. Lift only as far as you can with a good form: your physiotherapist sets your target.';

  @override
  String get exE4Simple =>
      'Hold the chair. Keep your knee straight. Lift your leg to the side. Then put it back down slowly.';

  @override
  String get exE4Title => 'Standing hip abduction';

  @override
  String get exercise => 'Exercise';

  @override
  String exerciseAnalysisFailed(String error) {
    return 'Exercise analysis failed: $error';
  }

  @override
  String get exerciseAssigned => 'Exercise assigned';

  @override
  String get exerciseAssignedSuccessfully => 'Exercise assigned successfully.';

  @override
  String get exerciseCompletedCheck => 'Exercise completed ✓';

  @override
  String get exerciseDataReady => 'Exercise data ready';

  @override
  String get exercises => 'Exercises';

  @override
  String exercisesLoggedOf(String reported, String total) {
    return '$reported / $total exercises logged';
  }

  @override
  String fbBelowTarget(int target, int reached) {
    return 'Good form - lift your leg a bit higher: target $target deg, you reached $reached deg';
  }

  @override
  String get fbBelowTargetSimple => 'Good. Now lift your leg a little higher.';

  @override
  String get fbE1Elb => 'Keep your elbows straight while you lift the stick';

  @override
  String get fbE1ElbSimple => 'Arms straight. Do not bend your elbows.';

  @override
  String fbE1Imb(String arm) {
    return 'Lift the stick evenly - raise your $arm arm as high as the other one';
  }

  @override
  String get fbE1ImbSimple => 'Lift both hands to the same height.';

  @override
  String get fbE1Rngdown => 'Lower the stick all the way down between reps';

  @override
  String get fbE1RngdownSimple => 'Go all the way down each time.';

  @override
  String get fbE2Elb => 'Keep your elbow straight';

  @override
  String get fbE2ElbSimple => 'Arm straight. Do not bend your elbow.';

  @override
  String get fbE2Lean =>
      'Keep your trunk upright - do not lean to lift the arm';

  @override
  String get fbE2LeanSimple => 'Stand straight. Do not lean to the side.';

  @override
  String get fbE2Rngdown =>
      'Bring your arm all the way down to your side between reps';

  @override
  String get fbE2RngdownSimple => 'Put your arm all the way down each time.';

  @override
  String get fbE2Shld =>
      'Do not shrug - keep your shoulder down while the arm goes up to shoulder height';

  @override
  String get fbE2ShldSimple => 'Keep your shoulder low and relaxed.';

  @override
  String get fbE3Wrong => 'Keep your elbow against your body while you rotate';

  @override
  String get fbE3WrongSimple => 'Keep your elbow touching your side.';

  @override
  String fbE4Knee(String leg) {
    return 'Keep your $leg knee straight while you lift the leg';
  }

  @override
  String get fbE4KneeSimple => 'Knee straight. Do not bend it.';

  @override
  String get fbE4Leanin =>
      'Keep your trunk upright - do not lean toward the leg you lift';

  @override
  String get fbE4LeaninSimple => 'Stand straight. Do not lean toward the leg.';

  @override
  String get fbE4Leanout =>
      'Keep your trunk upright - do not lean away from the leg (toward the chair)';

  @override
  String get fbE4LeanoutSimple =>
      'Stand straight. Do not lean toward the chair.';

  @override
  String get fbE4Unsure =>
      'Not sure about this rep - check that your whole body, feet included, is in view';

  @override
  String get fbE4UnsureSimple => 'Step back so the camera sees your feet.';

  @override
  String get fbGood => 'Good rep - well done';

  @override
  String get fbPartial =>
      'Rep cut by the start/end of the recording - not scored';

  @override
  String get fbUnsure =>
      'Not sure about this rep - check that your whole body is in view';

  @override
  String get fbUnsureSimple => 'Step back so the camera sees your whole body.';

  @override
  String fbWrongArm(String arm) {
    return 'Wrong arm - switch to your $arm arm: this rep does not count';
  }

  @override
  String fbWrongArmSimple(String arm) {
    return 'Use your $arm arm.';
  }

  @override
  String fbWrongLeg(String leg) {
    return 'Wrong leg - switch to your $leg leg: this rep does not count';
  }

  @override
  String fbWrongLegSimple(String leg) {
    return 'Lift your $leg leg.';
  }

  @override
  String framesAnalyzed(String count) {
    return 'Frames analyzed: $count';
  }

  @override
  String get fullName => 'Full name';

  @override
  String get hiPatient => 'Hi, Patient';

  @override
  String get history => 'History';

  @override
  String get home => 'Home';

  @override
  String get iPaidVerify => 'I paid — Verify my payment';

  @override
  String get invalidEmailFormat => 'Invalid email format';

  @override
  String get invalidPhoneFormat => 'Invalid phone format';

  @override
  String get invalidVideoUrl => 'Invalid or unsupported video URL';

  @override
  String get justificationFile => 'Justification file ';

  @override
  String get justificationReviewNote =>
      'This file is reviewed by admin before account approval.';

  @override
  String keypointsExtracted(String count) {
    return 'Keypoints extracted: $count';
  }

  @override
  String latestRepsDone(String reps) {
    return 'Latest: $reps reps done';
  }

  @override
  String get legSideLeft => 'left';

  @override
  String get legSideRight => 'right';

  @override
  String get liveArmAngle => 'arm angle';

  @override
  String liveArmMoving(String arm) {
    return 'The $arm arm is moving: scoring the $arm arm';
  }

  @override
  String liveCameraProblem(String error) {
    return 'Camera problem: $error';
  }

  @override
  String get liveDone => 'Done';

  @override
  String get liveFinishSet => 'Finish the set';

  @override
  String get liveFinishing => 'Scoring the last reps...';

  @override
  String get liveLegAngle => 'leg angle';

  @override
  String get livePainBody =>
      'Do not continue this exercise now. Please follow your physiotherapist\'s guidance before continuing. Your report will be sent to your physiotherapist: it is what you reported, not a medical diagnosis.';

  @override
  String get livePainTitle => 'Paused because you reported pain';

  @override
  String get livePause => 'Pause';

  @override
  String get livePausedBody =>
      'Press Resume when you are ready. You will be asked to stand still again before restarting.';

  @override
  String get livePausedTitle => 'Exercise paused';

  @override
  String get livePositioning =>
      'Step back until your whole body from the knees up is in view';

  @override
  String liveRep(int n) {
    return 'Rep $n';
  }

  @override
  String get liveReportPain => 'I feel pain';

  @override
  String get liveReps => 'reps';

  @override
  String get liveResume => 'Resume';

  @override
  String liveStandStill(int seconds) {
    return 'Stand still... $seconds';
  }

  @override
  String get liveStart => 'Start!';

  @override
  String get liveStarting => 'Starting the camera...';

  @override
  String liveWrongArm(String moving, String arm) {
    return 'You are moving your $moving arm - switch to your $arm arm. Those reps do not count.';
  }

  @override
  String liveWrongLeg(String moving, String leg) {
    return 'You are lifting your $moving leg - switch to your $leg leg. Those reps do not count.';
  }

  @override
  String get logOut => 'Log out';

  @override
  String get logProgress => 'Log Progress';

  @override
  String logProgressFor(String name) {
    return 'Log Progress – $name';
  }

  @override
  String get login => 'Login';

  @override
  String get loginFailedTitle => 'Unable to Sign In';

  @override
  String get loginIntro =>
      'Track your recovery, follow smarter exercise guidance, and stay connected with your physiotherapist.';

  @override
  String get loginSuccessBody => 'Welcome back to your Kinex workspace.';

  @override
  String get loginSuccessTitle => 'Login Successful!';

  @override
  String get loginTagline => 'Continue your AI-powered rehab journey.';

  @override
  String get logout => 'Logout';

  @override
  String logsCount(String count) {
    return '$count logs';
  }

  @override
  String get manage => 'Manage';

  @override
  String get manageDetailsAndClinic => 'Manage your details and clinic access.';

  @override
  String get manageProfileAndSupport =>
      'Manage your personal info and support options.';

  @override
  String get me => 'Me';

  @override
  String get members => 'Members';

  @override
  String get message => 'Message';

  @override
  String get micError => 'Voice command error. Try again or use the buttons.';

  @override
  String micHeard(String text) {
    return 'Heard: \"$text\"';
  }

  @override
  String get micListening => 'Listening...';

  @override
  String get micPermissionDenied =>
      'Microphone permission was refused. Allow it in the phone settings to use voice commands.';

  @override
  String get micProcessing => 'Understanding...';

  @override
  String get micReady => 'Tap the microphone to talk';

  @override
  String get micSpeaking => 'Speaking...';

  @override
  String get micTooltip => 'Microphone';

  @override
  String get micUnavailable =>
      'Voice commands are not available on this phone. Use the buttons.';

  @override
  String get minSixCharacters => 'Min 6 characters';

  @override
  String get minSixChars => 'Min 6 chars';

  @override
  String get minThreeCharacters => 'Min 3 characters';

  @override
  String get monthNames =>
      'January,February,March,April,May,June,July,August,September,October,November,December';

  @override
  String get monthShortNames =>
      'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String monthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get monthly => 'Monthly';

  @override
  String get monthlyPricingNote => 'Monthly: 5 EUR + 0.10 EUR per patient';

  @override
  String get myPatients => 'My Patients';

  @override
  String get myTherapist => 'My Physiotherapist';

  @override
  String get name => 'Name';

  @override
  String get nameAndPhoneRequired => 'Name and phone are required';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get newPasswordOptional => 'New password (optional)';

  @override
  String get noAiFeedbackYet => 'No AI feedback yet.';

  @override
  String get noAssignedExercises => 'No assigned exercises yet.';

  @override
  String get noAssignedPatients => 'No assigned patients yet.';

  @override
  String get noAssignedTherapist => 'No assigned physiotherapist';

  @override
  String get noAssignment => 'No assignment';

  @override
  String get noComplaintsFound => 'No complaints found.';

  @override
  String get noExerciseDescription =>
      'No description available for this exercise.';

  @override
  String get noExerciseInCatalog => 'No available exercise in catalog.';

  @override
  String get noExercisesForDay => 'No exercises found for the selected day.';

  @override
  String get noExercisesForFilter => 'No exercises found for this filter.';

  @override
  String get noExercisesToday => 'No exercises assigned for today yet.';

  @override
  String get noJustificationFile => 'No justification file available.';

  @override
  String get noMatchingAccounts => 'No matching accounts found.';

  @override
  String get noMatchingClinics => 'No matching clinics found.';

  @override
  String get noMembersYet => 'No members yet';

  @override
  String get noMessagesYet => 'No messages yet. Start the conversation.';

  @override
  String get noPaymentReference => 'No payment reference. Start payment first.';

  @override
  String get noPendingClinics => 'No pending clinics found.';

  @override
  String get noProgressReportsForExercise =>
      'No progress reports yet for this exercise.';

  @override
  String get noSets => 'No sets';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get notifAssistantNotes => 'What the assistant noted';

  @override
  String get notifCategoryAll => 'All';

  @override
  String get notifCategoryMessages => 'Messages';

  @override
  String get notifCategoryPain => 'Pain reports';

  @override
  String get notifCategoryProgress => 'Exercise progress';

  @override
  String get notifCategoryRoutine => 'Routine updates';

  @override
  String get notifCorrectReps => 'Correct';

  @override
  String get notifDay => 'Day';

  @override
  String get notifDetailTitle => 'Notification';

  @override
  String get notifDoneThatDay => 'Recorded that day';

  @override
  String get notifDraftHint =>
      'A suggested message will be placed in the chat box. Nothing is sent until you press Send.';

  @override
  String notifDraftInactivity(String name, String date) {
    return 'Hello $name, I noticed that no exercises were recorded on $date. Is everything all right?';
  }

  @override
  String notifDraftIncorrect(String name, String exercise) {
    return 'Hello $name, I looked at your $exercise set: many repetitions were not done as expected. Let us review the movement together.';
  }

  @override
  String notifDraftPain(String name, String exercise) {
    return 'Hello $name, I saw that you reported pain during $exercise. How are you feeling now?';
  }

  @override
  String get notifEmpty => 'No notifications yet';

  @override
  String get notifEmptyCategory => 'Nothing in this category';

  @override
  String notifHoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String notifInactivityBody(String date, int count) {
    return '$date · $count exercise(s) were prescribed';
  }

  @override
  String notifInactivityTitle(String name) {
    return '$name did no exercises';
  }

  @override
  String notifIncorrectBody(String exercise, int mistakes, int judged) {
    return '$exercise · $mistakes of $judged judged repetitions incorrect';
  }

  @override
  String get notifIncorrectReps => 'Incorrect';

  @override
  String notifIncorrectTitle(String name) {
    return '$name: most repetitions incorrect';
  }

  @override
  String get notifJustNow => 'just now';

  @override
  String get notifLoadError =>
      'Could not load the notifications. Check the connection and try again.';

  @override
  String get notifLoadMore => 'Load more';

  @override
  String get notifMarkAllRead => 'Mark all as read';

  @override
  String get notifMarkRead => 'Mark as read';

  @override
  String get notifMessagePatient => 'Message patient';

  @override
  String notifMessageTitle(String name) {
    return 'New message from $name';
  }

  @override
  String notifMinutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String get notifNoLongerAssigned =>
      'This patient is no longer assigned to you.';

  @override
  String get notifNothingRecorded => 'No exercise was recorded that day.';

  @override
  String get notifOpenConversation => 'Open conversation';

  @override
  String get notifOpenExercise => 'Open exercise';

  @override
  String get notifOpenPatient => 'Open patient file';

  @override
  String notifPainBodyDuring(String exercise) {
    return '$exercise · reported during the exercise';
  }

  @override
  String notifPainBodyLevel(String exercise, int level) {
    return '$exercise · pain $level/10';
  }

  @override
  String get notifPainDuringSet => 'Reported during the exercise';

  @override
  String notifPainEvent(String time, String source) {
    return 'At $time of the set, $source';
  }

  @override
  String get notifPainNoRating => 'No rating given yet';

  @override
  String get notifPainRating => 'Pain rating';

  @override
  String notifPainTitle(String name) {
    return '$name reported pain';
  }

  @override
  String get notifPatientNotes => 'Patient notes';

  @override
  String get notifPatientReportOnly =>
      'This is the patient\'s own report, not a medical finding.';

  @override
  String notifPatientWords(String words) {
    return 'Patient said: \"$words\"';
  }

  @override
  String get notifPrefInactivity => 'No exercise done';

  @override
  String get notifPrefInactivityHint =>
      'A patient had exercises due and recorded none that day (checked each night)';

  @override
  String get notifPrefIncorrect => 'Mostly incorrect repetitions';

  @override
  String get notifPrefIncorrectHint =>
      'At least 90 % of the judged repetitions of a set were incorrect (8 or more judged)';

  @override
  String get notifPrefMessageHint => 'A patient sends you a message';

  @override
  String get notifPrefPainHint =>
      'A patient reports pain during an exercise, or rates it 4/10 or more';

  @override
  String get notifPrefPainOffBody =>
      'You will no longer be told when a patient reports pain. The reports stay in their progress history.';

  @override
  String get notifPrefPainOffTitle => 'Turn off pain alerts?';

  @override
  String get notifPrefTurnOff => 'Turn off';

  @override
  String get notifPrescribed => 'Exercises prescribed then';

  @override
  String get notifReportedAt => 'Reported';

  @override
  String notifRepsDone(int reps) {
    return '$reps reps';
  }

  @override
  String get notifResolved => 'Resolved';

  @override
  String get notifResumedSince => 'The patient has exercised again since.';

  @override
  String notifRoutineBody(String exercise, int sets, int reps) {
    return '$exercise: $sets sets × $reps reps';
  }

  @override
  String get notifRoutineTitle => 'Your exercise plan was updated';

  @override
  String get notifSetResult => 'Set result';

  @override
  String notifSetsReps(int sets, int reps) {
    return '$sets × $reps';
  }

  @override
  String get notifSettingsIntro =>
      'Choose what you are notified about. A type that is off is not recorded at all: turning it back on does not bring back what happened meanwhile.';

  @override
  String get notifSettingsTitle => 'Notification settings';

  @override
  String get notifSignedOut => 'Your session has expired. Please log in again.';

  @override
  String notifTrackingConfirmed(int judged) {
    return 'All $judged repetitions were judged with confident tracking.';
  }

  @override
  String notifTrackingPartly(int unsure) {
    return '$unsure repetition(s) could not be judged reliably by the camera and are not counted in this alert.';
  }

  @override
  String get notifUnavailable => 'This item is no longer available.';

  @override
  String notifUnreadCount(int count) {
    return '$count unread';
  }

  @override
  String get notifUnsureReps => 'Not judged';

  @override
  String get notifUrgent => 'Urgent';

  @override
  String get notifYesterday => 'Yesterday';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsComingSoon => 'Notification preferences coming soon.';

  @override
  String get ok => 'OK';

  @override
  String get onboardingAudience => 'Designed for patients and physiotherapists';

  @override
  String get onboardingCardHelper =>
      'Built to support safer daily rehab sessions';

  @override
  String get onboardingEyebrow1 => 'Motion intelligence';

  @override
  String get onboardingEyebrow2 => 'Guided recovery';

  @override
  String get onboardingEyebrow3 => 'Physiotherapist connection';

  @override
  String get onboardingFooter =>
      'Follow exercises, track your progression, and stay connected with your physiotherapist in one secure app.';

  @override
  String get onboardingHeadline => 'Recover smarter,\nmove with confidence.';

  @override
  String get onboardingIntro =>
      'Personalized AI guidance for rehabilitation exercises, progress tracking, and physiotherapist collaboration.';

  @override
  String get onboardingSubtitle1 =>
      'Advanced pose estimation helps patients perform each exercise with safer and more accurate form.';

  @override
  String get onboardingSubtitle2 =>
      'Receive clear corrective cues and confidence-building feedback while following your rehab plan.';

  @override
  String get onboardingSubtitle3 =>
      'Share progress remotely so your physiotherapist can monitor recovery and personalize your next steps.';

  @override
  String get onboardingTitle1 => 'AI-Powered Movement Analysis';

  @override
  String get onboardingTitle2 => 'Instant Form Correction';

  @override
  String get onboardingTitle3 => 'Connected to Your Physiotherapist';

  @override
  String oneSet(String count) {
    return '$count set';
  }

  @override
  String get openDoc => 'Open doc';

  @override
  String get overview => 'Overview';

  @override
  String get painLevel => 'Pain level';

  @override
  String get painLevelLower => 'pain level';

  @override
  String painOutOfTen(String pain) {
    return '$pain/10';
  }

  @override
  String painOutOfTenSpaced(String pain) {
    return '$pain / 10';
  }

  @override
  String get password => 'Password';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get patient => 'Patient';

  @override
  String get patientChat => 'Patient chat';

  @override
  String get patientComplaints => 'Patient Complaints';

  @override
  String get patientProgress => 'Patient Progress';

  @override
  String get patients => 'Patients';

  @override
  String get payMonthlyWithStripe => 'Pay Monthly with Stripe';

  @override
  String get payYearlyWithStripe => 'Pay Yearly with Stripe';

  @override
  String get payloadPreview =>
      'Payload preview (ready to send to your AI model):';

  @override
  String get pending => 'Pending';

  @override
  String get pendingClinics => 'Pending Clinics';

  @override
  String percentValue(String percent) {
    return '$percent%';
  }

  @override
  String get phone => 'Phone';

  @override
  String get phoneRequired => 'Phone is required';

  @override
  String phoneValue(String phone) {
    return 'Phone: $phone';
  }

  @override
  String get physioAiBanner =>
      'Kinex AI Rehab dashboard for smarter patient follow-up.';

  @override
  String get physioHome => 'Physiotherapist Home';

  @override
  String get physioProfile => 'Physiotherapist Profile';

  @override
  String get physiotherapist => 'Physiotherapist';

  @override
  String get physiotherapists => 'Physiotherapists';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get premiumActive => 'Premium active';

  @override
  String get premiumActiveCheck => 'Premium active ✅';

  @override
  String get premiumLockedDescription =>
      'Unlock video capture with AI feedback and premium patient features.';

  @override
  String get premiumUnlockedDescription =>
      'Video upload and AI feedback are unlocked for your patients.';

  @override
  String get preparingExercise => 'Preparing exercise...';

  @override
  String pricingMonthlyLine(String count, String total) {
    return 'Monthly = 5.00 + (0.10 x $count) = $total EUR';
  }

  @override
  String pricingPatientsLine(String count) {
    return 'Patients: $count';
  }

  @override
  String pricingYearlyLine(String count, String total) {
    return 'Yearly = 50.00 + (0.10 x $count) = $total EUR';
  }

  @override
  String get profile => 'Profile';

  @override
  String get profilePhotoUpdated => 'Profile photo updated.';

  @override
  String get profileUpdatedSuccessfully => 'Profile updated successfully.';

  @override
  String get progress => 'Progress';

  @override
  String progressReps(String current, String total) {
    return 'Progress: $current / $total reps';
  }

  @override
  String progressRepsOf(String done, String target) {
    return 'Progress: $done$target reps';
  }

  @override
  String get recordingLockedSubscription =>
      'Recording locked (subscription required)';

  @override
  String get refresh => 'Refresh';

  @override
  String get registerYourClinic => 'Register your clinic';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get reject => 'Reject';

  @override
  String get repLabelBelowTarget => 'Good form – below your target range';

  @override
  String get repLabelGood => 'Good';

  @override
  String get repLabelKnee => 'Knee bends';

  @override
  String get repLabelLeanin => 'Leaning toward the lifted leg';

  @override
  String get repLabelLeanout => 'Leaning away from the lifted leg';

  @override
  String get repLabelUnsure => 'Not sure';

  @override
  String get repLabelWrongSide => 'Wrong side – not counted';

  @override
  String reportBelowTarget(int count) {
    return '$count good-form rep(s) below the target.';
  }

  @override
  String reportDiscomfort(String time) {
    return 'Patient said they were uncomfortable at $time. Set paused.';
  }

  @override
  String reportMistakes(String list) {
    return 'Mistakes: $list.';
  }

  @override
  String reportNotes(String exercise, String arm, int judged, int good) {
    return 'Live camera set - $exercise ($arm arm): $judged reps judged, $good good.';
  }

  @override
  String reportNotesLeg(String exercise, String leg, int judged, int good) {
    return 'Live camera set - $exercise ($leg leg): $judged reps judged, $good good.';
  }

  @override
  String reportPainEvent(String time, String source) {
    return 'Patient-reported pain at $time ($source) - reported by the patient, not a medical finding. Set paused.';
  }

  @override
  String get reportSourceButton => 'with the button';

  @override
  String get reportSourceVoice => 'by voice';

  @override
  String reportUnsure(int count) {
    return '$count not sure.';
  }

  @override
  String reportWrongSide(int count) {
    return '$count rep(s) with the wrong side, not counted.';
  }

  @override
  String get reps => 'Reps';

  @override
  String repsBullet(String count) {
    return '• $count reps';
  }

  @override
  String get repsCompleted => 'Reps completed';

  @override
  String repsCount(String count) {
    return '$count reps';
  }

  @override
  String get repsDone => 'reps done';

  @override
  String get requestSent => 'Request sent';

  @override
  String get required => 'Required';

  @override
  String get retry => 'Retry';

  @override
  String get role => 'Role';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get save => 'Save';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get saveProfile => 'Save Profile';

  @override
  String get saveProfileLower => 'Save profile';

  @override
  String scoreValue(String score) {
    return 'Score: $score';
  }

  @override
  String get searchAccountsByName => 'Search accounts by name only';

  @override
  String get searchClinics => 'Search clinics (name, email, phone, ID)';

  @override
  String get searchMembers => 'Search patient / physiotherapist';

  @override
  String get searchPendingClinics =>
      'Search pending clinics (name, email, phone, ID)';

  @override
  String get selectBirthDate => 'Select birth date';

  @override
  String get selectExerciseAndValidSetsReps =>
      'Select exercise and valid sets/reps.';

  @override
  String get send => 'Send';

  @override
  String get sendComplaint => 'Send Complaint';

  @override
  String sessionBelowTargetShort(int count) {
    return '$count below target';
  }

  @override
  String get sessionFeedbackTitle => 'Session feedback';

  @override
  String sessionGoodShort(int count) {
    return '$count good';
  }

  @override
  String get sessionHistory => 'Session History';

  @override
  String get sessionManualReport => 'Reported by hand (no camera set)';

  @override
  String sessionMistakesShort(int count) {
    return '$count to correct';
  }

  @override
  String get sessionNoRepDetail =>
      'Rep-by-rep details are not available for this set (recorded before the update).';

  @override
  String get sessionNoSets =>
      'No live camera set was recorded for this session.';

  @override
  String get sessionNotes => 'Notes';

  @override
  String get sessionOpenFeedback => 'AI feedback';

  @override
  String get sessionPainDuring => 'Pain reported during the set';

  @override
  String sessionPainLevel(String pain) {
    return 'Pain $pain/10';
  }

  @override
  String sessionScore(int percent) {
    return '$percent % good';
  }

  @override
  String sessionSetTitle(int number, String time) {
    return 'Set $number · $time';
  }

  @override
  String sessionWrongSideShort(int count) {
    return '$count wrong side';
  }

  @override
  String sessionsLogged(String count) {
    return '$count sessions logged';
  }

  @override
  String get sets => 'Sets';

  @override
  String get setsCompleted => 'Sets completed';

  @override
  String setsCount(String count) {
    return '$count sets';
  }

  @override
  String get setsDoneLower => 'sets done';

  @override
  String setsTimesReps(String sets, String reps) {
    return '$sets sets × $reps reps';
  }

  @override
  String get settings => 'Settings';

  @override
  String shortDate(String day, String month, String year) {
    return '$month $day, $year';
  }

  @override
  String get signInToYourAccount => 'Sign in to your account';

  @override
  String get specialization => 'Specialization';

  @override
  String get srvAccountDeleted => 'Account deleted';

  @override
  String get srvAccountNotFound => 'Account not found';

  @override
  String get srvAccountUpdated => 'Account updated';

  @override
  String get srvAdminNotDeletable => 'Admin accounts cannot be deleted';

  @override
  String get srvAdminRequired => 'Admin access required';

  @override
  String get srvAiFeedbackSubscription =>
      'AI feedback is available only with active clinic subscription';

  @override
  String get srvAiVideoUploaded => 'AI feedback video uploaded successfully';

  @override
  String get srvAssignmentNotFound => 'Patient exercise assignment not found';

  @override
  String get srvCannotDeleteSelf => 'You cannot delete your own admin account';

  @override
  String get srvClinicApproved => 'Clinic approved';

  @override
  String get srvClinicDeleted => 'Clinic deleted';

  @override
  String get srvClinicMovedToWaiting => 'Clinic moved to waiting state';

  @override
  String get srvClinicMustBeApproved =>
      'Clinic account must be approved before using this feature';

  @override
  String get srvClinicNameMin => 'Clinic name must be at least 3 characters';

  @override
  String get srvClinicProfileNotFound => 'Clinic profile not found';

  @override
  String get srvClinicProfileUpdated => 'Clinic profile updated successfully';

  @override
  String get srvClinicRegistered =>
      'Clinic registered. Waiting for admin approval.';

  @override
  String get srvClinicUpdated => 'Clinic updated';

  @override
  String get srvComplaintSubmitted => 'Complaint submitted successfully';

  @override
  String get srvDescriptionMin => 'Description must be at least 5 characters';

  @override
  String get srvEmailExists => 'Email already exists';

  @override
  String get srvEmailPasswordRequired => 'Email and password are required';

  @override
  String get srvExerciseAssigned => 'Exercise assigned successfully';

  @override
  String get srvExerciseCompletedSaved =>
      'Exercise completed and progress saved';

  @override
  String get srvExerciseNotFound => 'Exercise not found';

  @override
  String get srvExerciseRemoved => 'Exercise removed successfully';

  @override
  String get srvInvalidPassword => 'Invalid password';

  @override
  String get srvInvalidPhoneNumber => 'Invalid phone number';

  @override
  String get srvJustifRequired => 'Justification file is required';

  @override
  String get srvJustifSize => 'Justification file must be <= 8MB';

  @override
  String get srvJustifType => 'Justification file must be PDF/JPG/PNG';

  @override
  String get srvJustifUploadFailed => 'Justification upload failed';

  @override
  String get srvMemberNotFound => 'Member not found in your clinic';

  @override
  String get srvMessageContentRequired => 'Message content is required';

  @override
  String get srvMessageSent => 'Message sent successfully';

  @override
  String get srvNameMin => 'Name must be at least 2 characters';

  @override
  String get srvNoAccountForEmail => 'No account found with this email';

  @override
  String get srvNoPhysioAssigned => 'No physiotherapist is assigned to you yet';

  @override
  String get srvPatientCreated => 'Patient account created successfully';

  @override
  String get srvPatientDeleted => 'Patient deleted successfully';

  @override
  String get srvPatientNotAssignedToPhysio =>
      'Patient is not assigned to this physiotherapist';

  @override
  String get srvPatientNotAssignedToPhysio2 =>
      'Patient not assigned to this physiotherapist';

  @override
  String get srvPatientProfileNotFound => 'Patient profile not found';

  @override
  String get srvPaymentConfirmed =>
      'Payment confirmed. Subscription activated successfully.';

  @override
  String get srvPaymentNotCompleted =>
      'Payment is not completed yet. Finish checkout and try again.';

  @override
  String get srvPaymentRefNotFound =>
      'Payment reference not found for this clinic';

  @override
  String get srvPhotoType => 'Photo must be JPG/PNG/WEBP';

  @override
  String get srvPhotoUploaded => 'Photo uploaded successfully';

  @override
  String get srvPhysioNotFound => 'Physiotherapist not found';

  @override
  String get srvPhysioProfileNotFound => 'Physiotherapist profile not found';

  @override
  String get srvPremiumForVideo =>
      'Premium subscription required for video upload';

  @override
  String get srvProfileUpdated => 'Profile updated successfully';

  @override
  String get srvProgressSaved => 'Progress report saved';

  @override
  String get srvSetsRepsPositive => 'sets and reps must be greater than 0';

  @override
  String get srvStripeCheckoutReady =>
      'Stripe checkout ready. Complete payment then tap Verify.';

  @override
  String get srvTherapistCreated =>
      'Physiotherapist account created successfully';

  @override
  String get srvTherapistDeleted => 'Physiotherapist deleted successfully';

  @override
  String get srvUnsupportedVideo => 'Unsupported video format';

  @override
  String get srvWaitingForApproval => 'Waiting for approval';

  @override
  String get standardPlan => 'Standard plan';

  @override
  String get startExercise => 'Start Exercise';

  @override
  String get statsOverview => 'Stats Overview';

  @override
  String statusValue(String status) {
    return 'Status: $status';
  }

  @override
  String get submitComplaint => 'Submit a complaint';

  @override
  String get submitForApproval => 'Submit for approval';

  @override
  String get subscription => 'Subscription';

  @override
  String get subscriptionActiveAiAvailable =>
      'Subscription active: AI feedback available.';

  @override
  String get subscriptionActiveAiUnlocked =>
      'Clinic subscription active - AI Feedback unlocked';

  @override
  String get subscriptionInactiveAiHidden =>
      'Subscription inactive: AI feedback hidden.';

  @override
  String get subscriptionInactiveAiLocked =>
      'Clinic subscription inactive - AI Feedback locked';

  @override
  String get success => 'Success';

  @override
  String get summaryBelowTarget => 'Good form, below your target';

  @override
  String get summaryEveryRep => 'Every rep';

  @override
  String get summaryGoodReps => 'good reps';

  @override
  String get summaryMistakes => 'Mistakes';

  @override
  String get summaryNoMistakes => 'No mistakes - well done!';

  @override
  String get summaryNoneScored => 'No rep could be scored.';

  @override
  String get summaryNotSent => 'Not sent';

  @override
  String summaryNotSentError(String error) {
    return 'Not sent: $error';
  }

  @override
  String get summaryPainQuestion =>
      'How much pain did you feel? (0 = none, 10 = worst)';

  @override
  String get summaryPainReported =>
      'You reported pain during this set. Your physiotherapist will see it.';

  @override
  String summaryPeak(int deg, int target) {
    return 'Leg lift: median $deg° (target $target°)';
  }

  @override
  String get summaryRepsCounted => 'reps counted';

  @override
  String get summaryRepsScored => 'reps scored';

  @override
  String get summarySending => 'Sending to your physiotherapist...';

  @override
  String get summarySent => 'Saved and sent to your physiotherapist';

  @override
  String get summaryTitle => 'Set summary';

  @override
  String get summaryTryAgain => 'Try again';

  @override
  String summaryUnsure(int count) {
    return '$count rep(s) could not be judged with confidence.';
  }

  @override
  String summaryWrongSideArm(int count) {
    return '$count rep(s) done with the other arm were not counted.';
  }

  @override
  String summaryWrongSideLeg(int count) {
    return '$count rep(s) done with the other leg were not counted.';
  }

  @override
  String get switchToDarkMode => 'Switch to dark mode';

  @override
  String get switchToLightMode => 'Switch to light mode';

  @override
  String get symptomsOptional => 'Symptoms (optional)';

  @override
  String symptomsValue(String symptoms) {
    return 'Symptoms: $symptoms';
  }

  @override
  String get tapButtonToAddMember => 'Tap the button below to add one.';

  @override
  String get tapToStartLogging => 'Tap below to start logging your progress';

  @override
  String get tapToUploadDocument => 'Tap to upload (PDF/JPG/PNG)';

  @override
  String targetReps(String reps) {
    return 'Target: $reps reps';
  }

  @override
  String targetSetsReps(String total, String reps, String sets) {
    return 'Target: $sets sets × $reps reps = $total total reps';
  }

  @override
  String get therapistChat => 'Physiotherapist chat';

  @override
  String therapistValue(String name) {
    return 'Physiotherapist: $name';
  }

  @override
  String get therapists => 'Physiotherapists';

  @override
  String get thisWeek => 'This Week';

  @override
  String get thisWeeksActivity => 'This week\'s activity';

  @override
  String get today => 'Today';

  @override
  String get todayUpper => 'TODAY';

  @override
  String get todaysExercises => 'Today\'s Exercises';

  @override
  String get todaysPlan => 'Today\'s Plan';

  @override
  String get toggleTheme => 'Toggle theme';

  @override
  String get totalRepsCompleted => 'Total reps completed';

  @override
  String get trackedArmLeft => 'Left';

  @override
  String get trackedArmRight => 'Right';

  @override
  String get trackedE1 => 'Forward elevation with a stick (both arms)';

  @override
  String get trackedE2 => 'Arm abduction (one arm)';

  @override
  String get trackedE3 => 'Arm rotation, elbow at the side (one arm)';

  @override
  String get trackedE4 => 'Standing hip abduction (one leg)';

  @override
  String get trackedInjuredArm => 'Injured arm';

  @override
  String get trackedLabel => 'Live camera tracking';

  @override
  String get trackedLiftedLeg => 'Lifted leg';

  @override
  String get trackedNone => 'No live tracking';

  @override
  String trackedSummary(String exercise, String arm) {
    return '$exercise · $arm arm';
  }

  @override
  String trackedSummaryLeg(String exercise, String leg) {
    return '$exercise · $leg leg';
  }

  @override
  String get trackedTargetAngle => 'Target lift angle (°)';

  @override
  String trackedTargetAngleHelp(String percent, String deg) {
    return 'Leg angle away from the body at the top of the lift. Leave empty to use $percent % of the patient\'s usual lift (or the default angle of $deg° until it is known).';
  }

  @override
  String get trackedTargetAngleInvalid =>
      'Enter an angle between 5 and 90°, or leave it empty';

  @override
  String trackedTargetShort(String deg) {
    return 'target $deg°';
  }

  @override
  String get trackedWorkingArm => 'Arm that does the exercise';

  @override
  String get trackingNotSet =>
      'Your physiotherapist has not set up live camera tracking for this exercise yet.';

  @override
  String get truncated => '...truncated...';

  @override
  String get typeYourMessage => 'Type your message...';

  @override
  String unableToOpenCamera(String error) {
    return 'Unable to open camera: $error';
  }

  @override
  String get unableToOpenDocument => 'Unable to open the document.';

  @override
  String get unassigned => 'Unassigned';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get unnamedAccount => 'Unnamed account';

  @override
  String get updateProgress => 'Update Progress';

  @override
  String get upgradeToPremium => 'Upgrade to Premium';

  @override
  String get uploadJustificationPrompt =>
      'Please upload your clinic justification file.';

  @override
  String get useRegisteredCredentials =>
      'Use your registered email and password.';

  @override
  String get verifyStripePayment => 'Verify Stripe payment';

  @override
  String get video => 'Video';

  @override
  String get videoRecordingLocked =>
      'Video recording is locked: clinic subscription is inactive.';

  @override
  String get viewComplaints => 'View complaints';

  @override
  String get viewDocument => 'View document';

  @override
  String get voiceAlreadyRunning => 'The exercise is already running.';

  @override
  String get voiceHelp =>
      'You can say: repeat, I don\'t understand, pause, resume, help, or it hurts.';

  @override
  String get voiceLanguageFallback =>
      'Voice is not available in your language on this phone: using English.';

  @override
  String voiceMilestone(int count) {
    return 'You have completed $count repetitions.';
  }

  @override
  String get voiceNotUnderstood =>
      'Sorry, I did not understand. Say help to hear the commands.';

  @override
  String get voiceNothingToRepeat => 'There is no instruction to repeat yet.';

  @override
  String get voicePainClarify =>
      'I paused the exercise to be safe. Are you feeling pain now? If yes, say: it hurts, or press I feel pain.';

  @override
  String get voicePainHoldRefuse =>
      'The exercise stays paused because you reported pain. Please follow your physiotherapist\'s guidance.';

  @override
  String get voicePainResponse =>
      'I heard that you are in pain. The exercise is paused. Please follow your physiotherapist\'s guidance before continuing.';

  @override
  String get voicePaused =>
      'The exercise is paused. Press resume when you are ready.';

  @override
  String get voiceResumed => 'Let\'s continue. Stand still first.';

  @override
  String get voiceSetDone => 'The set is finished. Well done.';

  @override
  String get voiceStandStill => 'Stand still for two seconds.';

  @override
  String voiceStart(String exercise) {
    return 'You can start: $exercise.';
  }

  @override
  String get voiceStepBack => 'Please step back so your whole body is visible.';

  @override
  String get voiceStepBackFeet =>
      'Step back so the camera sees your whole body, feet included';

  @override
  String get voiceTtsUnavailable =>
      'Spoken feedback is not available on this phone.';

  @override
  String get voiceUncomfortable =>
      'I paused the exercise. Are you in pain? If yes, say: it hurts, or press I feel pain.';

  @override
  String get weekdayInitials => 'M,T,W,T,F,S,S';

  @override
  String get weekdayShortNames => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String weeklyGoalPercent(String percent) {
    return '$percent% Weekly Goal';
  }

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get yearly => 'Yearly';

  @override
  String get yearlyPricingNote => 'Yearly: 50 EUR + 0.10 EUR per patient';
}

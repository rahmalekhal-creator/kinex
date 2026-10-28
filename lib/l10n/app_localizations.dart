import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @accountRoleActive.
  ///
  /// In en, this message translates to:
  /// **'Role: {role} | Active: {active}'**
  String accountRoleActive(String active, String role);

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addMember;

  /// No description provided for @addNewMember.
  ///
  /// In en, this message translates to:
  /// **'Add new member'**
  String get addNewMember;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @adminHome.
  ///
  /// In en, this message translates to:
  /// **'Admin Home'**
  String get adminHome;

  /// No description provided for @aiCoachBanner.
  ///
  /// In en, this message translates to:
  /// **'Kinex AI Coach: smarter rehab guidance, every day.'**
  String get aiCoachBanner;

  /// No description provided for @aiFeedback.
  ///
  /// In en, this message translates to:
  /// **'AI Feedback'**
  String get aiFeedback;

  /// No description provided for @aiFeedbackFor.
  ///
  /// In en, this message translates to:
  /// **'AI Feedback - {name}'**
  String aiFeedbackFor(String name);

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allSetsDone.
  ///
  /// In en, this message translates to:
  /// **'All sets done! ✓'**
  String get allSetsDone;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @armSideLeft.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get armSideLeft;

  /// No description provided for @armSideRight.
  ///
  /// In en, this message translates to:
  /// **'right'**
  String get armSideRight;

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @assignExercise.
  ///
  /// In en, this message translates to:
  /// **'Assign Exercise'**
  String get assignExercise;

  /// No description provided for @assignExerciseTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign exercise'**
  String get assignExerciseTitle;

  /// No description provided for @assignedBy.
  ///
  /// In en, this message translates to:
  /// **'Assigned by'**
  String get assignedBy;

  /// No description provided for @assignedExercises.
  ///
  /// In en, this message translates to:
  /// **'Assigned Exercises'**
  String get assignedExercises;

  /// No description provided for @assignedPatients.
  ///
  /// In en, this message translates to:
  /// **'Assigned patients'**
  String get assignedPatients;

  /// No description provided for @assignedPhysiotherapist.
  ///
  /// In en, this message translates to:
  /// **'Assigned physiotherapist'**
  String get assignedPhysiotherapist;

  /// No description provided for @assistantAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'The live exercise assistant runs on Android phones.'**
  String get assistantAndroidOnly;

  /// No description provided for @assistantArmLabel.
  ///
  /// In en, this message translates to:
  /// **'Arm: {arm}'**
  String assistantArmLabel(String arm);

  /// No description provided for @assistantCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get assistantCamera;

  /// No description provided for @assistantCameraBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get assistantCameraBack;

  /// No description provided for @assistantCameraFront.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get assistantCameraFront;

  /// No description provided for @assistantCameraNeeded.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed for the exercise assistant.'**
  String get assistantCameraNeeded;

  /// No description provided for @assistantDevSettings.
  ///
  /// In en, this message translates to:
  /// **'Developer settings'**
  String get assistantDevSettings;

  /// No description provided for @assistantFullResolution.
  ///
  /// In en, this message translates to:
  /// **'Full-resolution analysis (1280 px)'**
  String get assistantFullResolution;

  /// No description provided for @assistantFullResolutionHint.
  ///
  /// In en, this message translates to:
  /// **'Slower. By default the frames are analysed at 640 px: the same landmarks, much less work per frame.'**
  String get assistantFullResolutionHint;

  /// No description provided for @assistantInjuredArmLabel.
  ///
  /// In en, this message translates to:
  /// **'Injured arm: {arm}'**
  String assistantInjuredArmLabel(String arm);

  /// No description provided for @assistantLegLabel.
  ///
  /// In en, this message translates to:
  /// **'Lifted leg: {leg}'**
  String assistantLegLabel(String leg);

  /// No description provided for @assistantModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get assistantModel;

  /// No description provided for @assistantModelMultitask.
  ///
  /// In en, this message translates to:
  /// **'Multi-task network'**
  String get assistantModelMultitask;

  /// No description provided for @assistantModelSeparate.
  ///
  /// In en, this message translates to:
  /// **'Separate networks'**
  String get assistantModelSeparate;

  /// No description provided for @assistantPlacementTip.
  ///
  /// In en, this message translates to:
  /// **'Put the phone upright in front of you, about 2-3 m away, so that your whole body from the knees up is in view. Stand still for 2 seconds when asked, then start.'**
  String get assistantPlacementTip;

  /// No description provided for @assistantPlacementTipLeg.
  ///
  /// In en, this message translates to:
  /// **'Put the phone upright in front of you at hip height, about 2-3 m away, so that your WHOLE body is in view, feet included. Put the chair beside the leg you stand on and hold it. Stand still for 2 seconds when asked, then start.'**
  String get assistantPlacementTipLeg;

  /// No description provided for @assistantSetByPhysio.
  ///
  /// In en, this message translates to:
  /// **'set by your physiotherapist'**
  String get assistantSetByPhysio;

  /// No description provided for @assistantShowTiming.
  ///
  /// In en, this message translates to:
  /// **'Show timing overlay'**
  String get assistantShowTiming;

  /// No description provided for @assistantStartSet.
  ///
  /// In en, this message translates to:
  /// **'Start the set'**
  String get assistantStartSet;

  /// No description provided for @assistantTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Your target: {deg}°'**
  String assistantTargetLabel(String deg);

  /// No description provided for @assistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercise assistant'**
  String get assistantTitle;

  /// No description provided for @assistantUseGpu.
  ///
  /// In en, this message translates to:
  /// **'Run pose detection on the GPU (developer)'**
  String get assistantUseGpu;

  /// No description provided for @assistantUseGpuHint.
  ///
  /// In en, this message translates to:
  /// **'Faster on many phones; uses the CPU if the phone cannot. The timing line shows which one runs.'**
  String get assistantUseGpuHint;

  /// No description provided for @assistantVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice assistant'**
  String get assistantVoice;

  /// No description provided for @assistantVoiceOn.
  ///
  /// In en, this message translates to:
  /// **'Spoken instructions and corrections'**
  String get assistantVoiceOn;

  /// No description provided for @assistantVoiceRate.
  ///
  /// In en, this message translates to:
  /// **'Speaking speed'**
  String get assistantVoiceRate;

  /// No description provided for @becomePartnerClinic.
  ///
  /// In en, this message translates to:
  /// **'Become a partner clinic'**
  String get becomePartnerClinic;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get birthDate;

  /// No description provided for @birthDateRequiredForPatients.
  ///
  /// In en, this message translates to:
  /// **'Birth date is required for patients.'**
  String get birthDateRequiredForPatients;

  /// No description provided for @bodyRegionHip.
  ///
  /// In en, this message translates to:
  /// **'Hip'**
  String get bodyRegionHip;

  /// No description provided for @bodyRegionOther.
  ///
  /// In en, this message translates to:
  /// **'Other exercises'**
  String get bodyRegionOther;

  /// No description provided for @bodyRegionShoulder.
  ///
  /// In en, this message translates to:
  /// **'Shoulder'**
  String get bodyRegionShoulder;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get changeLanguage;

  /// No description provided for @clinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get clinic;

  /// No description provided for @clinicComplaints.
  ///
  /// In en, this message translates to:
  /// **'Clinic Complaints'**
  String get clinicComplaints;

  /// No description provided for @clinicDashboard.
  ///
  /// In en, this message translates to:
  /// **'Clinic Dashboard'**
  String get clinicDashboard;

  /// No description provided for @clinicEmail.
  ///
  /// In en, this message translates to:
  /// **'Clinic email'**
  String get clinicEmail;

  /// No description provided for @clinicMembersCount.
  ///
  /// In en, this message translates to:
  /// **'Clinic members ({count})'**
  String clinicMembersCount(String count);

  /// No description provided for @clinicName.
  ///
  /// In en, this message translates to:
  /// **'Clinic name'**
  String get clinicName;

  /// No description provided for @clinicOnlySignupNote.
  ///
  /// In en, this message translates to:
  /// **'Only clinics can register here. Patients and physiotherapists are created from the clinic dashboard using the logged-in clinic account.'**
  String get clinicOnlySignupNote;

  /// No description provided for @clinicProfile.
  ///
  /// In en, this message translates to:
  /// **'Clinic profile'**
  String get clinicProfile;

  /// No description provided for @clinicProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your clinic information and picture.'**
  String get clinicProfileSubtitle;

  /// No description provided for @clinicRegistration.
  ///
  /// In en, this message translates to:
  /// **'Clinic registration'**
  String get clinicRegistration;

  /// No description provided for @clinicRegistrationIntro.
  ///
  /// In en, this message translates to:
  /// **'Create a clinic account. Upload your professional justification file so admin can validate your registration quickly.'**
  String get clinicRegistrationIntro;

  /// No description provided for @clinicValue.
  ///
  /// In en, this message translates to:
  /// **'Clinic: {name}'**
  String clinicValue(String name);

  /// No description provided for @clinics.
  ///
  /// In en, this message translates to:
  /// **'Clinics'**
  String get clinics;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'{title} coming soon'**
  String comingSoon(String title);

  /// No description provided for @complaintSentSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Complaint sent successfully.'**
  String get complaintSentSuccessfully;

  /// No description provided for @complaints.
  ///
  /// In en, this message translates to:
  /// **'Complaints'**
  String get complaints;

  /// No description provided for @completeLabel.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get completeLabel;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @completedOfAssigned.
  ///
  /// In en, this message translates to:
  /// **'{completed} completed / {assigned} assigned'**
  String completedOfAssigned(String completed, String assigned);

  /// No description provided for @completedRepsOf.
  ///
  /// In en, this message translates to:
  /// **'Completed – {done}{target} reps ✓'**
  String completedRepsOf(String done, String target);

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @continueToLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue to Login'**
  String get continueToLogin;

  /// No description provided for @createMember.
  ///
  /// In en, this message translates to:
  /// **'Create member'**
  String get createMember;

  /// No description provided for @dailyCompletionPercent.
  ///
  /// In en, this message translates to:
  /// **'Daily Completion %'**
  String get dailyCompletionPercent;

  /// No description provided for @dateAtTime.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String dateAtTime(String time, String date);

  /// No description provided for @dateValue.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dateValue(String date);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{label}\" (ID: {id})?'**
  String deleteAccountConfirm(String id, String label);

  /// No description provided for @deleteMember.
  ///
  /// In en, this message translates to:
  /// **'Delete member'**
  String get deleteMember;

  /// No description provided for @deleteMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {role} \"{name}\" from this clinic?'**
  String deleteMemberConfirm(String name, String role);

  /// No description provided for @describeYourComplaint.
  ///
  /// In en, this message translates to:
  /// **'Describe your complaint'**
  String get describeYourComplaint;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Description is required'**
  String get descriptionRequired;

  /// No description provided for @documentAttached.
  ///
  /// In en, this message translates to:
  /// **'Document attached'**
  String get documentAttached;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @e4ProgressEmpty.
  ///
  /// In en, this message translates to:
  /// **'No hip abduction set recorded yet.'**
  String get e4ProgressEmpty;

  /// No description provided for @e4ProgressGoodShare.
  ///
  /// In en, this message translates to:
  /// **'Good form: {percent} %'**
  String e4ProgressGoodShare(int percent);

  /// No description provided for @e4ProgressMedian.
  ///
  /// In en, this message translates to:
  /// **'Median lift'**
  String get e4ProgressMedian;

  /// No description provided for @e4ProgressPerClass.
  ///
  /// In en, this message translates to:
  /// **'Reps per class'**
  String get e4ProgressPerClass;

  /// No description provided for @e4ProgressTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get e4ProgressTarget;

  /// No description provided for @e4ProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Hip abduction - range over time'**
  String get e4ProgressTitle;

  /// No description provided for @e4ProgressUsualLift.
  ///
  /// In en, this message translates to:
  /// **'Usual lift: {deg}°'**
  String e4ProgressUsualLift(String deg);

  /// No description provided for @editInformation.
  ///
  /// In en, this message translates to:
  /// **'Edit information'**
  String get editInformation;

  /// No description provided for @editInformationTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Information'**
  String get editInformationTitle;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get emailHint;

  /// No description provided for @emailValue.
  ///
  /// In en, this message translates to:
  /// **'Email: {email}'**
  String emailValue(String email);

  /// No description provided for @enterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get enterValidEmail;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Invalid response format from server'**
  String get errorInvalidResponse;

  /// No description provided for @errorServerStatus.
  ///
  /// In en, this message translates to:
  /// **'Server error ({code}).'**
  String errorServerStatus(String code);

  /// No description provided for @errorServerUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the server. Check your connection and try again.'**
  String get errorServerUnreachable;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get errorTimeout;

  /// No description provided for @exE1Desc.
  ///
  /// In en, this message translates to:
  /// **'Hold a stick with both hands and lift it forward and up, then lower it all the way down.'**
  String get exE1Desc;

  /// No description provided for @exE1Simple.
  ///
  /// In en, this message translates to:
  /// **'Hold the stick with both hands. Lift it up slowly. Then bring it all the way down.'**
  String get exE1Simple;

  /// No description provided for @exE1Title.
  ///
  /// In en, this message translates to:
  /// **'Forward elevation with a stick'**
  String get exE1Title;

  /// No description provided for @exE2Desc.
  ///
  /// In en, this message translates to:
  /// **'Lift one straight arm out to the side, then bring it back down along your body.'**
  String get exE2Desc;

  /// No description provided for @exE2Simple.
  ///
  /// In en, this message translates to:
  /// **'Keep your arm straight. Lift it to the side. Then put it back down.'**
  String get exE2Simple;

  /// No description provided for @exE2Title.
  ///
  /// In en, this message translates to:
  /// **'Arm abduction'**
  String get exE2Title;

  /// No description provided for @exE3Desc.
  ///
  /// In en, this message translates to:
  /// **'Keep the elbow against your body, bent at 90 degrees, and rotate the forearm outward and back.'**
  String get exE3Desc;

  /// No description provided for @exE3Simple.
  ///
  /// In en, this message translates to:
  /// **'Keep your elbow against your side. Turn your hand outward. Then bring it back.'**
  String get exE3Simple;

  /// No description provided for @exE3Title.
  ///
  /// In en, this message translates to:
  /// **'Arm rotation, elbow at the side'**
  String get exE3Title;

  /// No description provided for @exE4Desc.
  ///
  /// In en, this message translates to:
  /// **'Stand facing the phone with a chair beside you and hold it with the hand on the side of the leg you stand on. Lift the other leg sideways, knee straight and trunk upright, then lower it with control. Lift only as far as you can with a good form: your physiotherapist sets your target.'**
  String get exE4Desc;

  /// No description provided for @exE4Simple.
  ///
  /// In en, this message translates to:
  /// **'Hold the chair. Keep your knee straight. Lift your leg to the side. Then put it back down slowly.'**
  String get exE4Simple;

  /// No description provided for @exE4Title.
  ///
  /// In en, this message translates to:
  /// **'Standing hip abduction'**
  String get exE4Title;

  /// No description provided for @exercise.
  ///
  /// In en, this message translates to:
  /// **'Exercise'**
  String get exercise;

  /// No description provided for @exerciseAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Exercise analysis failed: {error}'**
  String exerciseAnalysisFailed(String error);

  /// No description provided for @exerciseAssigned.
  ///
  /// In en, this message translates to:
  /// **'Exercise assigned'**
  String get exerciseAssigned;

  /// No description provided for @exerciseAssignedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Exercise assigned successfully.'**
  String get exerciseAssignedSuccessfully;

  /// No description provided for @exerciseCompletedCheck.
  ///
  /// In en, this message translates to:
  /// **'Exercise completed ✓'**
  String get exerciseCompletedCheck;

  /// No description provided for @exerciseDataReady.
  ///
  /// In en, this message translates to:
  /// **'Exercise data ready'**
  String get exerciseDataReady;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @exercisesLoggedOf.
  ///
  /// In en, this message translates to:
  /// **'{reported} / {total} exercises logged'**
  String exercisesLoggedOf(String reported, String total);

  /// No description provided for @fbBelowTarget.
  ///
  /// In en, this message translates to:
  /// **'Good form - lift your leg a bit higher: target {target} deg, you reached {reached} deg'**
  String fbBelowTarget(int target, int reached);

  /// No description provided for @fbBelowTargetSimple.
  ///
  /// In en, this message translates to:
  /// **'Good. Now lift your leg a little higher.'**
  String get fbBelowTargetSimple;

  /// No description provided for @fbE1Elb.
  ///
  /// In en, this message translates to:
  /// **'Keep your elbows straight while you lift the stick'**
  String get fbE1Elb;

  /// No description provided for @fbE1ElbSimple.
  ///
  /// In en, this message translates to:
  /// **'Arms straight. Do not bend your elbows.'**
  String get fbE1ElbSimple;

  /// No description provided for @fbE1Imb.
  ///
  /// In en, this message translates to:
  /// **'Lift the stick evenly - raise your {arm} arm as high as the other one'**
  String fbE1Imb(String arm);

  /// No description provided for @fbE1ImbSimple.
  ///
  /// In en, this message translates to:
  /// **'Lift both hands to the same height.'**
  String get fbE1ImbSimple;

  /// No description provided for @fbE1Rngdown.
  ///
  /// In en, this message translates to:
  /// **'Lower the stick all the way down between reps'**
  String get fbE1Rngdown;

  /// No description provided for @fbE1RngdownSimple.
  ///
  /// In en, this message translates to:
  /// **'Go all the way down each time.'**
  String get fbE1RngdownSimple;

  /// No description provided for @fbE2Elb.
  ///
  /// In en, this message translates to:
  /// **'Keep your elbow straight'**
  String get fbE2Elb;

  /// No description provided for @fbE2ElbSimple.
  ///
  /// In en, this message translates to:
  /// **'Arm straight. Do not bend your elbow.'**
  String get fbE2ElbSimple;

  /// No description provided for @fbE2Lean.
  ///
  /// In en, this message translates to:
  /// **'Keep your trunk upright - do not lean to lift the arm'**
  String get fbE2Lean;

  /// No description provided for @fbE2LeanSimple.
  ///
  /// In en, this message translates to:
  /// **'Stand straight. Do not lean to the side.'**
  String get fbE2LeanSimple;

  /// No description provided for @fbE2Rngdown.
  ///
  /// In en, this message translates to:
  /// **'Bring your arm all the way down to your side between reps'**
  String get fbE2Rngdown;

  /// No description provided for @fbE2RngdownSimple.
  ///
  /// In en, this message translates to:
  /// **'Put your arm all the way down each time.'**
  String get fbE2RngdownSimple;

  /// No description provided for @fbE2Shld.
  ///
  /// In en, this message translates to:
  /// **'Do not shrug - keep your shoulder down while the arm goes up to shoulder height'**
  String get fbE2Shld;

  /// No description provided for @fbE2ShldSimple.
  ///
  /// In en, this message translates to:
  /// **'Keep your shoulder low and relaxed.'**
  String get fbE2ShldSimple;

  /// No description provided for @fbE3Wrong.
  ///
  /// In en, this message translates to:
  /// **'Keep your elbow against your body while you rotate'**
  String get fbE3Wrong;

  /// No description provided for @fbE3WrongSimple.
  ///
  /// In en, this message translates to:
  /// **'Keep your elbow touching your side.'**
  String get fbE3WrongSimple;

  /// No description provided for @fbE4Knee.
  ///
  /// In en, this message translates to:
  /// **'Keep your {leg} knee straight while you lift the leg'**
  String fbE4Knee(String leg);

  /// No description provided for @fbE4KneeSimple.
  ///
  /// In en, this message translates to:
  /// **'Knee straight. Do not bend it.'**
  String get fbE4KneeSimple;

  /// No description provided for @fbE4Leanin.
  ///
  /// In en, this message translates to:
  /// **'Keep your trunk upright - do not lean toward the leg you lift'**
  String get fbE4Leanin;

  /// No description provided for @fbE4LeaninSimple.
  ///
  /// In en, this message translates to:
  /// **'Stand straight. Do not lean toward the leg.'**
  String get fbE4LeaninSimple;

  /// No description provided for @fbE4Leanout.
  ///
  /// In en, this message translates to:
  /// **'Keep your trunk upright - do not lean away from the leg (toward the chair)'**
  String get fbE4Leanout;

  /// No description provided for @fbE4LeanoutSimple.
  ///
  /// In en, this message translates to:
  /// **'Stand straight. Do not lean toward the chair.'**
  String get fbE4LeanoutSimple;

  /// No description provided for @fbE4Unsure.
  ///
  /// In en, this message translates to:
  /// **'Not sure about this rep - check that your whole body, feet included, is in view'**
  String get fbE4Unsure;

  /// No description provided for @fbE4UnsureSimple.
  ///
  /// In en, this message translates to:
  /// **'Step back so the camera sees your feet.'**
  String get fbE4UnsureSimple;

  /// No description provided for @fbGood.
  ///
  /// In en, this message translates to:
  /// **'Good rep - well done'**
  String get fbGood;

  /// No description provided for @fbPartial.
  ///
  /// In en, this message translates to:
  /// **'Rep cut by the start/end of the recording - not scored'**
  String get fbPartial;

  /// No description provided for @fbUnsure.
  ///
  /// In en, this message translates to:
  /// **'Not sure about this rep - check that your whole body is in view'**
  String get fbUnsure;

  /// No description provided for @fbUnsureSimple.
  ///
  /// In en, this message translates to:
  /// **'Step back so the camera sees your whole body.'**
  String get fbUnsureSimple;

  /// No description provided for @fbWrongArm.
  ///
  /// In en, this message translates to:
  /// **'Wrong arm - switch to your {arm} arm: this rep does not count'**
  String fbWrongArm(String arm);

  /// No description provided for @fbWrongArmSimple.
  ///
  /// In en, this message translates to:
  /// **'Use your {arm} arm.'**
  String fbWrongArmSimple(String arm);

  /// No description provided for @fbWrongLeg.
  ///
  /// In en, this message translates to:
  /// **'Wrong leg - switch to your {leg} leg: this rep does not count'**
  String fbWrongLeg(String leg);

  /// No description provided for @fbWrongLegSimple.
  ///
  /// In en, this message translates to:
  /// **'Lift your {leg} leg.'**
  String fbWrongLegSimple(String leg);

  /// No description provided for @framesAnalyzed.
  ///
  /// In en, this message translates to:
  /// **'Frames analyzed: {count}'**
  String framesAnalyzed(String count);

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @hiPatient.
  ///
  /// In en, this message translates to:
  /// **'Hi, Patient'**
  String get hiPatient;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @iPaidVerify.
  ///
  /// In en, this message translates to:
  /// **'I paid — Verify my payment'**
  String get iPaidVerify;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get invalidEmailFormat;

  /// No description provided for @invalidPhoneFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone format'**
  String get invalidPhoneFormat;

  /// No description provided for @invalidVideoUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid or unsupported video URL'**
  String get invalidVideoUrl;

  /// No description provided for @justificationFile.
  ///
  /// In en, this message translates to:
  /// **'Justification file '**
  String get justificationFile;

  /// No description provided for @justificationReviewNote.
  ///
  /// In en, this message translates to:
  /// **'This file is reviewed by admin before account approval.'**
  String get justificationReviewNote;

  /// No description provided for @keypointsExtracted.
  ///
  /// In en, this message translates to:
  /// **'Keypoints extracted: {count}'**
  String keypointsExtracted(String count);

  /// No description provided for @latestRepsDone.
  ///
  /// In en, this message translates to:
  /// **'Latest: {reps} reps done'**
  String latestRepsDone(String reps);

  /// No description provided for @legSideLeft.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get legSideLeft;

  /// No description provided for @legSideRight.
  ///
  /// In en, this message translates to:
  /// **'right'**
  String get legSideRight;

  /// No description provided for @liveArmAngle.
  ///
  /// In en, this message translates to:
  /// **'arm angle'**
  String get liveArmAngle;

  /// No description provided for @liveArmMoving.
  ///
  /// In en, this message translates to:
  /// **'The {arm} arm is moving: scoring the {arm} arm'**
  String liveArmMoving(String arm);

  /// No description provided for @liveCameraProblem.
  ///
  /// In en, this message translates to:
  /// **'Camera problem: {error}'**
  String liveCameraProblem(String error);

  /// No description provided for @liveDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get liveDone;

  /// No description provided for @liveFinishSet.
  ///
  /// In en, this message translates to:
  /// **'Finish the set'**
  String get liveFinishSet;

  /// No description provided for @liveFinishing.
  ///
  /// In en, this message translates to:
  /// **'Scoring the last reps...'**
  String get liveFinishing;

  /// No description provided for @liveLegAngle.
  ///
  /// In en, this message translates to:
  /// **'leg angle'**
  String get liveLegAngle;

  /// No description provided for @livePainBody.
  ///
  /// In en, this message translates to:
  /// **'Do not continue this exercise now. Please follow your physiotherapist\'s guidance before continuing. Your report will be sent to your physiotherapist: it is what you reported, not a medical diagnosis.'**
  String get livePainBody;

  /// No description provided for @livePainTitle.
  ///
  /// In en, this message translates to:
  /// **'Paused because you reported pain'**
  String get livePainTitle;

  /// No description provided for @livePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get livePause;

  /// No description provided for @livePausedBody.
  ///
  /// In en, this message translates to:
  /// **'Press Resume when you are ready. You will be asked to stand still again before restarting.'**
  String get livePausedBody;

  /// No description provided for @livePausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Exercise paused'**
  String get livePausedTitle;

  /// No description provided for @livePositioning.
  ///
  /// In en, this message translates to:
  /// **'Step back until your whole body from the knees up is in view'**
  String get livePositioning;

  /// No description provided for @liveRep.
  ///
  /// In en, this message translates to:
  /// **'Rep {n}'**
  String liveRep(int n);

  /// No description provided for @liveReportPain.
  ///
  /// In en, this message translates to:
  /// **'I feel pain'**
  String get liveReportPain;

  /// No description provided for @liveReps.
  ///
  /// In en, this message translates to:
  /// **'reps'**
  String get liveReps;

  /// No description provided for @liveResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get liveResume;

  /// No description provided for @liveStandStill.
  ///
  /// In en, this message translates to:
  /// **'Stand still... {seconds}'**
  String liveStandStill(int seconds);

  /// No description provided for @liveStart.
  ///
  /// In en, this message translates to:
  /// **'Start!'**
  String get liveStart;

  /// No description provided for @liveStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting the camera...'**
  String get liveStarting;

  /// No description provided for @liveWrongArm.
  ///
  /// In en, this message translates to:
  /// **'You are moving your {moving} arm - switch to your {arm} arm. Those reps do not count.'**
  String liveWrongArm(String moving, String arm);

  /// No description provided for @liveWrongLeg.
  ///
  /// In en, this message translates to:
  /// **'You are lifting your {moving} leg - switch to your {leg} leg. Those reps do not count.'**
  String liveWrongLeg(String moving, String leg);

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @logProgress.
  ///
  /// In en, this message translates to:
  /// **'Log Progress'**
  String get logProgress;

  /// No description provided for @logProgressFor.
  ///
  /// In en, this message translates to:
  /// **'Log Progress – {name}'**
  String logProgressFor(String name);

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @loginFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to Sign In'**
  String get loginFailedTitle;

  /// No description provided for @loginIntro.
  ///
  /// In en, this message translates to:
  /// **'Track your recovery, follow smarter exercise guidance, and stay connected with your physiotherapist.'**
  String get loginIntro;

  /// No description provided for @loginSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Welcome back to your Kinex workspace.'**
  String get loginSuccessBody;

  /// No description provided for @loginSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Login Successful!'**
  String get loginSuccessTitle;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Continue your AI-powered rehab journey.'**
  String get loginTagline;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} logs'**
  String logsCount(String count);

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @manageDetailsAndClinic.
  ///
  /// In en, this message translates to:
  /// **'Manage your details and clinic access.'**
  String get manageDetailsAndClinic;

  /// No description provided for @manageProfileAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Manage your personal info and support options.'**
  String get manageProfileAndSupport;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @micError.
  ///
  /// In en, this message translates to:
  /// **'Voice command error. Try again or use the buttons.'**
  String get micError;

  /// No description provided for @micHeard.
  ///
  /// In en, this message translates to:
  /// **'Heard: \"{text}\"'**
  String micHeard(String text);

  /// No description provided for @micListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get micListening;

  /// No description provided for @micPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission was refused. Allow it in the phone settings to use voice commands.'**
  String get micPermissionDenied;

  /// No description provided for @micProcessing.
  ///
  /// In en, this message translates to:
  /// **'Understanding...'**
  String get micProcessing;

  /// No description provided for @micReady.
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone to talk'**
  String get micReady;

  /// No description provided for @micSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking...'**
  String get micSpeaking;

  /// No description provided for @micTooltip.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get micTooltip;

  /// No description provided for @micUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice commands are not available on this phone. Use the buttons.'**
  String get micUnavailable;

  /// No description provided for @minSixCharacters.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get minSixCharacters;

  /// No description provided for @minSixChars.
  ///
  /// In en, this message translates to:
  /// **'Min 6 chars'**
  String get minSixChars;

  /// No description provided for @minThreeCharacters.
  ///
  /// In en, this message translates to:
  /// **'Min 3 characters'**
  String get minThreeCharacters;

  /// No description provided for @monthNames.
  ///
  /// In en, this message translates to:
  /// **'January,February,March,April,May,June,July,August,September,October,November,December'**
  String get monthNames;

  /// No description provided for @monthShortNames.
  ///
  /// In en, this message translates to:
  /// **'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'**
  String get monthShortNames;

  /// No description provided for @monthYear.
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String monthYear(String month, String year);

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @monthlyPricingNote.
  ///
  /// In en, this message translates to:
  /// **'Monthly: 5 EUR + 0.10 EUR per patient'**
  String get monthlyPricingNote;

  /// No description provided for @myPatients.
  ///
  /// In en, this message translates to:
  /// **'My Patients'**
  String get myPatients;

  /// No description provided for @myTherapist.
  ///
  /// In en, this message translates to:
  /// **'My Physiotherapist'**
  String get myTherapist;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameAndPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Name and phone are required'**
  String get nameAndPhoneRequired;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @newPasswordOptional.
  ///
  /// In en, this message translates to:
  /// **'New password (optional)'**
  String get newPasswordOptional;

  /// No description provided for @noAiFeedbackYet.
  ///
  /// In en, this message translates to:
  /// **'No AI feedback yet.'**
  String get noAiFeedbackYet;

  /// No description provided for @noAssignedExercises.
  ///
  /// In en, this message translates to:
  /// **'No assigned exercises yet.'**
  String get noAssignedExercises;

  /// No description provided for @noAssignedPatients.
  ///
  /// In en, this message translates to:
  /// **'No assigned patients yet.'**
  String get noAssignedPatients;

  /// No description provided for @noAssignedTherapist.
  ///
  /// In en, this message translates to:
  /// **'No assigned physiotherapist'**
  String get noAssignedTherapist;

  /// No description provided for @noAssignment.
  ///
  /// In en, this message translates to:
  /// **'No assignment'**
  String get noAssignment;

  /// No description provided for @noComplaintsFound.
  ///
  /// In en, this message translates to:
  /// **'No complaints found.'**
  String get noComplaintsFound;

  /// No description provided for @noExerciseDescription.
  ///
  /// In en, this message translates to:
  /// **'No description available for this exercise.'**
  String get noExerciseDescription;

  /// No description provided for @noExerciseInCatalog.
  ///
  /// In en, this message translates to:
  /// **'No available exercise in catalog.'**
  String get noExerciseInCatalog;

  /// No description provided for @noExercisesForDay.
  ///
  /// In en, this message translates to:
  /// **'No exercises found for the selected day.'**
  String get noExercisesForDay;

  /// No description provided for @noExercisesForFilter.
  ///
  /// In en, this message translates to:
  /// **'No exercises found for this filter.'**
  String get noExercisesForFilter;

  /// No description provided for @noExercisesToday.
  ///
  /// In en, this message translates to:
  /// **'No exercises assigned for today yet.'**
  String get noExercisesToday;

  /// No description provided for @noJustificationFile.
  ///
  /// In en, this message translates to:
  /// **'No justification file available.'**
  String get noJustificationFile;

  /// No description provided for @noMatchingAccounts.
  ///
  /// In en, this message translates to:
  /// **'No matching accounts found.'**
  String get noMatchingAccounts;

  /// No description provided for @noMatchingClinics.
  ///
  /// In en, this message translates to:
  /// **'No matching clinics found.'**
  String get noMatchingClinics;

  /// No description provided for @noMembersYet.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get noMembersYet;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Start the conversation.'**
  String get noMessagesYet;

  /// No description provided for @noPaymentReference.
  ///
  /// In en, this message translates to:
  /// **'No payment reference. Start payment first.'**
  String get noPaymentReference;

  /// No description provided for @noPendingClinics.
  ///
  /// In en, this message translates to:
  /// **'No pending clinics found.'**
  String get noPendingClinics;

  /// No description provided for @noProgressReportsForExercise.
  ///
  /// In en, this message translates to:
  /// **'No progress reports yet for this exercise.'**
  String get noProgressReportsForExercise;

  /// No description provided for @noSets.
  ///
  /// In en, this message translates to:
  /// **'No sets'**
  String get noSets;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @notifAssistantNotes.
  ///
  /// In en, this message translates to:
  /// **'What the assistant noted'**
  String get notifAssistantNotes;

  /// No description provided for @notifCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notifCategoryAll;

  /// No description provided for @notifCategoryMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notifCategoryMessages;

  /// No description provided for @notifCategoryPain.
  ///
  /// In en, this message translates to:
  /// **'Pain reports'**
  String get notifCategoryPain;

  /// No description provided for @notifCategoryProgress.
  ///
  /// In en, this message translates to:
  /// **'Exercise progress'**
  String get notifCategoryProgress;

  /// No description provided for @notifCategoryRoutine.
  ///
  /// In en, this message translates to:
  /// **'Routine updates'**
  String get notifCategoryRoutine;

  /// No description provided for @notifCorrectReps.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get notifCorrectReps;

  /// No description provided for @notifDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get notifDay;

  /// No description provided for @notifDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notifDetailTitle;

  /// No description provided for @notifDoneThatDay.
  ///
  /// In en, this message translates to:
  /// **'Recorded that day'**
  String get notifDoneThatDay;

  /// No description provided for @notifDraftHint.
  ///
  /// In en, this message translates to:
  /// **'A suggested message will be placed in the chat box. Nothing is sent until you press Send.'**
  String get notifDraftHint;

  /// No description provided for @notifDraftInactivity.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}, I noticed that no exercises were recorded on {date}. Is everything all right?'**
  String notifDraftInactivity(String name, String date);

  /// No description provided for @notifDraftIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}, I looked at your {exercise} set: many repetitions were not done as expected. Let us review the movement together.'**
  String notifDraftIncorrect(String name, String exercise);

  /// No description provided for @notifDraftPain.
  ///
  /// In en, this message translates to:
  /// **'Hello {name}, I saw that you reported pain during {exercise}. How are you feeling now?'**
  String notifDraftPain(String name, String exercise);

  /// No description provided for @notifEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notifEmpty;

  /// No description provided for @notifEmptyCategory.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this category'**
  String get notifEmptyCategory;

  /// No description provided for @notifHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String notifHoursAgo(int n);

  /// No description provided for @notifInactivityBody.
  ///
  /// In en, this message translates to:
  /// **'{date} · {count} exercise(s) were prescribed'**
  String notifInactivityBody(String date, int count);

  /// No description provided for @notifInactivityTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} did no exercises'**
  String notifInactivityTitle(String name);

  /// No description provided for @notifIncorrectBody.
  ///
  /// In en, this message translates to:
  /// **'{exercise} · {mistakes} of {judged} judged repetitions incorrect'**
  String notifIncorrectBody(String exercise, int mistakes, int judged);

  /// No description provided for @notifIncorrectReps.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get notifIncorrectReps;

  /// No description provided for @notifIncorrectTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}: most repetitions incorrect'**
  String notifIncorrectTitle(String name);

  /// No description provided for @notifJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get notifJustNow;

  /// No description provided for @notifLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the notifications. Check the connection and try again.'**
  String get notifLoadError;

  /// No description provided for @notifLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get notifLoadMore;

  /// No description provided for @notifMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notifMarkAllRead;

  /// No description provided for @notifMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notifMarkRead;

  /// No description provided for @notifMessagePatient.
  ///
  /// In en, this message translates to:
  /// **'Message patient'**
  String get notifMessagePatient;

  /// No description provided for @notifMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'New message from {name}'**
  String notifMessageTitle(String name);

  /// No description provided for @notifMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String notifMinutesAgo(int n);

  /// No description provided for @notifNoLongerAssigned.
  ///
  /// In en, this message translates to:
  /// **'This patient is no longer assigned to you.'**
  String get notifNoLongerAssigned;

  /// No description provided for @notifNothingRecorded.
  ///
  /// In en, this message translates to:
  /// **'No exercise was recorded that day.'**
  String get notifNothingRecorded;

  /// No description provided for @notifOpenConversation.
  ///
  /// In en, this message translates to:
  /// **'Open conversation'**
  String get notifOpenConversation;

  /// No description provided for @notifOpenExercise.
  ///
  /// In en, this message translates to:
  /// **'Open exercise'**
  String get notifOpenExercise;

  /// No description provided for @notifOpenPatient.
  ///
  /// In en, this message translates to:
  /// **'Open patient file'**
  String get notifOpenPatient;

  /// No description provided for @notifPainBodyDuring.
  ///
  /// In en, this message translates to:
  /// **'{exercise} · reported during the exercise'**
  String notifPainBodyDuring(String exercise);

  /// No description provided for @notifPainBodyLevel.
  ///
  /// In en, this message translates to:
  /// **'{exercise} · pain {level}/10'**
  String notifPainBodyLevel(String exercise, int level);

  /// No description provided for @notifPainDuringSet.
  ///
  /// In en, this message translates to:
  /// **'Reported during the exercise'**
  String get notifPainDuringSet;

  /// No description provided for @notifPainEvent.
  ///
  /// In en, this message translates to:
  /// **'At {time} of the set, {source}'**
  String notifPainEvent(String time, String source);

  /// No description provided for @notifPainNoRating.
  ///
  /// In en, this message translates to:
  /// **'No rating given yet'**
  String get notifPainNoRating;

  /// No description provided for @notifPainRating.
  ///
  /// In en, this message translates to:
  /// **'Pain rating'**
  String get notifPainRating;

  /// No description provided for @notifPainTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} reported pain'**
  String notifPainTitle(String name);

  /// No description provided for @notifPatientNotes.
  ///
  /// In en, this message translates to:
  /// **'Patient notes'**
  String get notifPatientNotes;

  /// No description provided for @notifPatientReportOnly.
  ///
  /// In en, this message translates to:
  /// **'This is the patient\'s own report, not a medical finding.'**
  String get notifPatientReportOnly;

  /// No description provided for @notifPatientWords.
  ///
  /// In en, this message translates to:
  /// **'Patient said: \"{words}\"'**
  String notifPatientWords(String words);

  /// No description provided for @notifPrefInactivity.
  ///
  /// In en, this message translates to:
  /// **'No exercise done'**
  String get notifPrefInactivity;

  /// No description provided for @notifPrefInactivityHint.
  ///
  /// In en, this message translates to:
  /// **'A patient had exercises due and recorded none that day (checked each night)'**
  String get notifPrefInactivityHint;

  /// No description provided for @notifPrefIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Mostly incorrect repetitions'**
  String get notifPrefIncorrect;

  /// No description provided for @notifPrefIncorrectHint.
  ///
  /// In en, this message translates to:
  /// **'At least 90 % of the judged repetitions of a set were incorrect (8 or more judged)'**
  String get notifPrefIncorrectHint;

  /// No description provided for @notifPrefMessageHint.
  ///
  /// In en, this message translates to:
  /// **'A patient sends you a message'**
  String get notifPrefMessageHint;

  /// No description provided for @notifPrefPainHint.
  ///
  /// In en, this message translates to:
  /// **'A patient reports pain during an exercise, or rates it 4/10 or more'**
  String get notifPrefPainHint;

  /// No description provided for @notifPrefPainOffBody.
  ///
  /// In en, this message translates to:
  /// **'You will no longer be told when a patient reports pain. The reports stay in their progress history.'**
  String get notifPrefPainOffBody;

  /// No description provided for @notifPrefPainOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off pain alerts?'**
  String get notifPrefPainOffTitle;

  /// No description provided for @notifPrefTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get notifPrefTurnOff;

  /// No description provided for @notifPrescribed.
  ///
  /// In en, this message translates to:
  /// **'Exercises prescribed then'**
  String get notifPrescribed;

  /// No description provided for @notifReportedAt.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get notifReportedAt;

  /// No description provided for @notifRepsDone.
  ///
  /// In en, this message translates to:
  /// **'{reps} reps'**
  String notifRepsDone(int reps);

  /// No description provided for @notifResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get notifResolved;

  /// No description provided for @notifResumedSince.
  ///
  /// In en, this message translates to:
  /// **'The patient has exercised again since.'**
  String get notifResumedSince;

  /// No description provided for @notifRoutineBody.
  ///
  /// In en, this message translates to:
  /// **'{exercise}: {sets} sets × {reps} reps'**
  String notifRoutineBody(String exercise, int sets, int reps);

  /// No description provided for @notifRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'Your exercise plan was updated'**
  String get notifRoutineTitle;

  /// No description provided for @notifSetResult.
  ///
  /// In en, this message translates to:
  /// **'Set result'**
  String get notifSetResult;

  /// No description provided for @notifSetsReps.
  ///
  /// In en, this message translates to:
  /// **'{sets} × {reps}'**
  String notifSetsReps(int sets, int reps);

  /// No description provided for @notifSettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose what you are notified about. A type that is off is not recorded at all: turning it back on does not bring back what happened meanwhile.'**
  String get notifSettingsIntro;

  /// No description provided for @notifSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notifSettingsTitle;

  /// No description provided for @notifSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get notifSignedOut;

  /// No description provided for @notifTrackingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'All {judged} repetitions were judged with confident tracking.'**
  String notifTrackingConfirmed(int judged);

  /// No description provided for @notifTrackingPartly.
  ///
  /// In en, this message translates to:
  /// **'{unsure} repetition(s) could not be judged reliably by the camera and are not counted in this alert.'**
  String notifTrackingPartly(int unsure);

  /// No description provided for @notifUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer available.'**
  String get notifUnavailable;

  /// No description provided for @notifUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String notifUnreadCount(int count);

  /// No description provided for @notifUnsureReps.
  ///
  /// In en, this message translates to:
  /// **'Not judged'**
  String get notifUnsureReps;

  /// No description provided for @notifUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get notifUrgent;

  /// No description provided for @notifYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notifYesterday;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences coming soon.'**
  String get notificationsComingSoon;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @onboardingAudience.
  ///
  /// In en, this message translates to:
  /// **'Designed for patients and physiotherapists'**
  String get onboardingAudience;

  /// No description provided for @onboardingCardHelper.
  ///
  /// In en, this message translates to:
  /// **'Built to support safer daily rehab sessions'**
  String get onboardingCardHelper;

  /// No description provided for @onboardingEyebrow1.
  ///
  /// In en, this message translates to:
  /// **'Motion intelligence'**
  String get onboardingEyebrow1;

  /// No description provided for @onboardingEyebrow2.
  ///
  /// In en, this message translates to:
  /// **'Guided recovery'**
  String get onboardingEyebrow2;

  /// No description provided for @onboardingEyebrow3.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist connection'**
  String get onboardingEyebrow3;

  /// No description provided for @onboardingFooter.
  ///
  /// In en, this message translates to:
  /// **'Follow exercises, track your progression, and stay connected with your physiotherapist in one secure app.'**
  String get onboardingFooter;

  /// No description provided for @onboardingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Recover smarter,\nmove with confidence.'**
  String get onboardingHeadline;

  /// No description provided for @onboardingIntro.
  ///
  /// In en, this message translates to:
  /// **'Personalized AI guidance for rehabilitation exercises, progress tracking, and physiotherapist collaboration.'**
  String get onboardingIntro;

  /// No description provided for @onboardingSubtitle1.
  ///
  /// In en, this message translates to:
  /// **'Advanced pose estimation helps patients perform each exercise with safer and more accurate form.'**
  String get onboardingSubtitle1;

  /// No description provided for @onboardingSubtitle2.
  ///
  /// In en, this message translates to:
  /// **'Receive clear corrective cues and confidence-building feedback while following your rehab plan.'**
  String get onboardingSubtitle2;

  /// No description provided for @onboardingSubtitle3.
  ///
  /// In en, this message translates to:
  /// **'Share progress remotely so your physiotherapist can monitor recovery and personalize your next steps.'**
  String get onboardingSubtitle3;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'AI-Powered Movement Analysis'**
  String get onboardingTitle1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Instant Form Correction'**
  String get onboardingTitle2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Connected to Your Physiotherapist'**
  String get onboardingTitle3;

  /// No description provided for @oneSet.
  ///
  /// In en, this message translates to:
  /// **'{count} set'**
  String oneSet(String count);

  /// No description provided for @openDoc.
  ///
  /// In en, this message translates to:
  /// **'Open doc'**
  String get openDoc;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @painLevel.
  ///
  /// In en, this message translates to:
  /// **'Pain level'**
  String get painLevel;

  /// No description provided for @painLevelLower.
  ///
  /// In en, this message translates to:
  /// **'pain level'**
  String get painLevelLower;

  /// No description provided for @painOutOfTen.
  ///
  /// In en, this message translates to:
  /// **'{pain}/10'**
  String painOutOfTen(String pain);

  /// No description provided for @painOutOfTenSpaced.
  ///
  /// In en, this message translates to:
  /// **'{pain} / 10'**
  String painOutOfTenSpaced(String pain);

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @patientChat.
  ///
  /// In en, this message translates to:
  /// **'Patient chat'**
  String get patientChat;

  /// No description provided for @patientComplaints.
  ///
  /// In en, this message translates to:
  /// **'Patient Complaints'**
  String get patientComplaints;

  /// No description provided for @patientProgress.
  ///
  /// In en, this message translates to:
  /// **'Patient Progress'**
  String get patientProgress;

  /// No description provided for @patients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get patients;

  /// No description provided for @payMonthlyWithStripe.
  ///
  /// In en, this message translates to:
  /// **'Pay Monthly with Stripe'**
  String get payMonthlyWithStripe;

  /// No description provided for @payYearlyWithStripe.
  ///
  /// In en, this message translates to:
  /// **'Pay Yearly with Stripe'**
  String get payYearlyWithStripe;

  /// No description provided for @payloadPreview.
  ///
  /// In en, this message translates to:
  /// **'Payload preview (ready to send to your AI model):'**
  String get payloadPreview;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @pendingClinics.
  ///
  /// In en, this message translates to:
  /// **'Pending Clinics'**
  String get pendingClinics;

  /// No description provided for @percentValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String percentValue(String percent);

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone is required'**
  String get phoneRequired;

  /// No description provided for @phoneValue.
  ///
  /// In en, this message translates to:
  /// **'Phone: {phone}'**
  String phoneValue(String phone);

  /// No description provided for @physioAiBanner.
  ///
  /// In en, this message translates to:
  /// **'Kinex AI Rehab dashboard for smarter patient follow-up.'**
  String get physioAiBanner;

  /// No description provided for @physioHome.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist Home'**
  String get physioHome;

  /// No description provided for @physioProfile.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist Profile'**
  String get physioProfile;

  /// No description provided for @physiotherapist.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist'**
  String get physiotherapist;

  /// No description provided for @physiotherapists.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapists'**
  String get physiotherapists;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @premiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium active'**
  String get premiumActive;

  /// No description provided for @premiumActiveCheck.
  ///
  /// In en, this message translates to:
  /// **'Premium active ✅'**
  String get premiumActiveCheck;

  /// No description provided for @premiumLockedDescription.
  ///
  /// In en, this message translates to:
  /// **'Unlock video capture with AI feedback and premium patient features.'**
  String get premiumLockedDescription;

  /// No description provided for @premiumUnlockedDescription.
  ///
  /// In en, this message translates to:
  /// **'Video upload and AI feedback are unlocked for your patients.'**
  String get premiumUnlockedDescription;

  /// No description provided for @preparingExercise.
  ///
  /// In en, this message translates to:
  /// **'Preparing exercise...'**
  String get preparingExercise;

  /// No description provided for @pricingMonthlyLine.
  ///
  /// In en, this message translates to:
  /// **'Monthly = 5.00 + (0.10 x {count}) = {total} EUR'**
  String pricingMonthlyLine(String count, String total);

  /// No description provided for @pricingPatientsLine.
  ///
  /// In en, this message translates to:
  /// **'Patients: {count}'**
  String pricingPatientsLine(String count);

  /// No description provided for @pricingYearlyLine.
  ///
  /// In en, this message translates to:
  /// **'Yearly = 50.00 + (0.10 x {count}) = {total} EUR'**
  String pricingYearlyLine(String count, String total);

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated.'**
  String get profilePhotoUpdated;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully.'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @progressReps.
  ///
  /// In en, this message translates to:
  /// **'Progress: {current} / {total} reps'**
  String progressReps(String current, String total);

  /// No description provided for @progressRepsOf.
  ///
  /// In en, this message translates to:
  /// **'Progress: {done}{target} reps'**
  String progressRepsOf(String done, String target);

  /// No description provided for @recordingLockedSubscription.
  ///
  /// In en, this message translates to:
  /// **'Recording locked (subscription required)'**
  String get recordingLockedSubscription;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @registerYourClinic.
  ///
  /// In en, this message translates to:
  /// **'Register your clinic'**
  String get registerYourClinic;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationFailed;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @repLabelBelowTarget.
  ///
  /// In en, this message translates to:
  /// **'Good form – below your target range'**
  String get repLabelBelowTarget;

  /// No description provided for @repLabelGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get repLabelGood;

  /// No description provided for @repLabelKnee.
  ///
  /// In en, this message translates to:
  /// **'Knee bends'**
  String get repLabelKnee;

  /// No description provided for @repLabelLeanin.
  ///
  /// In en, this message translates to:
  /// **'Leaning toward the lifted leg'**
  String get repLabelLeanin;

  /// No description provided for @repLabelLeanout.
  ///
  /// In en, this message translates to:
  /// **'Leaning away from the lifted leg'**
  String get repLabelLeanout;

  /// No description provided for @repLabelUnsure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get repLabelUnsure;

  /// No description provided for @repLabelWrongSide.
  ///
  /// In en, this message translates to:
  /// **'Wrong side – not counted'**
  String get repLabelWrongSide;

  /// No description provided for @reportBelowTarget.
  ///
  /// In en, this message translates to:
  /// **'{count} good-form rep(s) below the target.'**
  String reportBelowTarget(int count);

  /// No description provided for @reportDiscomfort.
  ///
  /// In en, this message translates to:
  /// **'Patient said they were uncomfortable at {time}. Set paused.'**
  String reportDiscomfort(String time);

  /// No description provided for @reportMistakes.
  ///
  /// In en, this message translates to:
  /// **'Mistakes: {list}.'**
  String reportMistakes(String list);

  /// No description provided for @reportNotes.
  ///
  /// In en, this message translates to:
  /// **'Live camera set - {exercise} ({arm} arm): {judged} reps judged, {good} good.'**
  String reportNotes(String exercise, String arm, int judged, int good);

  /// No description provided for @reportNotesLeg.
  ///
  /// In en, this message translates to:
  /// **'Live camera set - {exercise} ({leg} leg): {judged} reps judged, {good} good.'**
  String reportNotesLeg(String exercise, String leg, int judged, int good);

  /// No description provided for @reportPainEvent.
  ///
  /// In en, this message translates to:
  /// **'Patient-reported pain at {time} ({source}) - reported by the patient, not a medical finding. Set paused.'**
  String reportPainEvent(String time, String source);

  /// No description provided for @reportSourceButton.
  ///
  /// In en, this message translates to:
  /// **'with the button'**
  String get reportSourceButton;

  /// No description provided for @reportSourceVoice.
  ///
  /// In en, this message translates to:
  /// **'by voice'**
  String get reportSourceVoice;

  /// No description provided for @reportUnsure.
  ///
  /// In en, this message translates to:
  /// **'{count} not sure.'**
  String reportUnsure(int count);

  /// No description provided for @reportWrongSide.
  ///
  /// In en, this message translates to:
  /// **'{count} rep(s) with the wrong side, not counted.'**
  String reportWrongSide(int count);

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get reps;

  /// No description provided for @repsBullet.
  ///
  /// In en, this message translates to:
  /// **'• {count} reps'**
  String repsBullet(String count);

  /// No description provided for @repsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Reps completed'**
  String get repsCompleted;

  /// No description provided for @repsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reps'**
  String repsCount(String count);

  /// No description provided for @repsDone.
  ///
  /// In en, this message translates to:
  /// **'reps done'**
  String get repsDone;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get requestSent;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get saveProfile;

  /// No description provided for @saveProfileLower.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfileLower;

  /// No description provided for @scoreValue.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String scoreValue(String score);

  /// No description provided for @searchAccountsByName.
  ///
  /// In en, this message translates to:
  /// **'Search accounts by name only'**
  String get searchAccountsByName;

  /// No description provided for @searchClinics.
  ///
  /// In en, this message translates to:
  /// **'Search clinics (name, email, phone, ID)'**
  String get searchClinics;

  /// No description provided for @searchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search patient / physiotherapist'**
  String get searchMembers;

  /// No description provided for @searchPendingClinics.
  ///
  /// In en, this message translates to:
  /// **'Search pending clinics (name, email, phone, ID)'**
  String get searchPendingClinics;

  /// No description provided for @selectBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Select birth date'**
  String get selectBirthDate;

  /// No description provided for @selectExerciseAndValidSetsReps.
  ///
  /// In en, this message translates to:
  /// **'Select exercise and valid sets/reps.'**
  String get selectExerciseAndValidSetsReps;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sendComplaint.
  ///
  /// In en, this message translates to:
  /// **'Send Complaint'**
  String get sendComplaint;

  /// No description provided for @sessionBelowTargetShort.
  ///
  /// In en, this message translates to:
  /// **'{count} below target'**
  String sessionBelowTargetShort(int count);

  /// No description provided for @sessionFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Session feedback'**
  String get sessionFeedbackTitle;

  /// No description provided for @sessionGoodShort.
  ///
  /// In en, this message translates to:
  /// **'{count} good'**
  String sessionGoodShort(int count);

  /// No description provided for @sessionHistory.
  ///
  /// In en, this message translates to:
  /// **'Session History'**
  String get sessionHistory;

  /// No description provided for @sessionManualReport.
  ///
  /// In en, this message translates to:
  /// **'Reported by hand (no camera set)'**
  String get sessionManualReport;

  /// No description provided for @sessionMistakesShort.
  ///
  /// In en, this message translates to:
  /// **'{count} to correct'**
  String sessionMistakesShort(int count);

  /// No description provided for @sessionNoRepDetail.
  ///
  /// In en, this message translates to:
  /// **'Rep-by-rep details are not available for this set (recorded before the update).'**
  String get sessionNoRepDetail;

  /// No description provided for @sessionNoSets.
  ///
  /// In en, this message translates to:
  /// **'No live camera set was recorded for this session.'**
  String get sessionNoSets;

  /// No description provided for @sessionNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get sessionNotes;

  /// No description provided for @sessionOpenFeedback.
  ///
  /// In en, this message translates to:
  /// **'AI feedback'**
  String get sessionOpenFeedback;

  /// No description provided for @sessionPainDuring.
  ///
  /// In en, this message translates to:
  /// **'Pain reported during the set'**
  String get sessionPainDuring;

  /// No description provided for @sessionPainLevel.
  ///
  /// In en, this message translates to:
  /// **'Pain {pain}/10'**
  String sessionPainLevel(String pain);

  /// No description provided for @sessionScore.
  ///
  /// In en, this message translates to:
  /// **'{percent} % good'**
  String sessionScore(int percent);

  /// No description provided for @sessionSetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set {number} · {time}'**
  String sessionSetTitle(int number, String time);

  /// No description provided for @sessionWrongSideShort.
  ///
  /// In en, this message translates to:
  /// **'{count} wrong side'**
  String sessionWrongSideShort(int count);

  /// No description provided for @sessionsLogged.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions logged'**
  String sessionsLogged(String count);

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @setsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sets completed'**
  String get setsCompleted;

  /// No description provided for @setsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sets'**
  String setsCount(String count);

  /// No description provided for @setsDoneLower.
  ///
  /// In en, this message translates to:
  /// **'sets done'**
  String get setsDoneLower;

  /// No description provided for @setsTimesReps.
  ///
  /// In en, this message translates to:
  /// **'{sets} sets × {reps} reps'**
  String setsTimesReps(String sets, String reps);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @shortDate.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String shortDate(String day, String month, String year);

  /// No description provided for @signInToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToYourAccount;

  /// No description provided for @specialization.
  ///
  /// In en, this message translates to:
  /// **'Specialization'**
  String get specialization;

  /// No description provided for @srvAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get srvAccountDeleted;

  /// No description provided for @srvAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get srvAccountNotFound;

  /// No description provided for @srvAccountUpdated.
  ///
  /// In en, this message translates to:
  /// **'Account updated'**
  String get srvAccountUpdated;

  /// No description provided for @srvAdminNotDeletable.
  ///
  /// In en, this message translates to:
  /// **'Admin accounts cannot be deleted'**
  String get srvAdminNotDeletable;

  /// No description provided for @srvAdminRequired.
  ///
  /// In en, this message translates to:
  /// **'Admin access required'**
  String get srvAdminRequired;

  /// No description provided for @srvAiFeedbackSubscription.
  ///
  /// In en, this message translates to:
  /// **'AI feedback is available only with active clinic subscription'**
  String get srvAiFeedbackSubscription;

  /// No description provided for @srvAiVideoUploaded.
  ///
  /// In en, this message translates to:
  /// **'AI feedback video uploaded successfully'**
  String get srvAiVideoUploaded;

  /// No description provided for @srvAssignmentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Patient exercise assignment not found'**
  String get srvAssignmentNotFound;

  /// No description provided for @srvCannotDeleteSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot delete your own admin account'**
  String get srvCannotDeleteSelf;

  /// No description provided for @srvClinicApproved.
  ///
  /// In en, this message translates to:
  /// **'Clinic approved'**
  String get srvClinicApproved;

  /// No description provided for @srvClinicDeleted.
  ///
  /// In en, this message translates to:
  /// **'Clinic deleted'**
  String get srvClinicDeleted;

  /// No description provided for @srvClinicMovedToWaiting.
  ///
  /// In en, this message translates to:
  /// **'Clinic moved to waiting state'**
  String get srvClinicMovedToWaiting;

  /// No description provided for @srvClinicMustBeApproved.
  ///
  /// In en, this message translates to:
  /// **'Clinic account must be approved before using this feature'**
  String get srvClinicMustBeApproved;

  /// No description provided for @srvClinicNameMin.
  ///
  /// In en, this message translates to:
  /// **'Clinic name must be at least 3 characters'**
  String get srvClinicNameMin;

  /// No description provided for @srvClinicProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Clinic profile not found'**
  String get srvClinicProfileNotFound;

  /// No description provided for @srvClinicProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Clinic profile updated successfully'**
  String get srvClinicProfileUpdated;

  /// No description provided for @srvClinicRegistered.
  ///
  /// In en, this message translates to:
  /// **'Clinic registered. Waiting for admin approval.'**
  String get srvClinicRegistered;

  /// No description provided for @srvClinicUpdated.
  ///
  /// In en, this message translates to:
  /// **'Clinic updated'**
  String get srvClinicUpdated;

  /// No description provided for @srvComplaintSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Complaint submitted successfully'**
  String get srvComplaintSubmitted;

  /// No description provided for @srvDescriptionMin.
  ///
  /// In en, this message translates to:
  /// **'Description must be at least 5 characters'**
  String get srvDescriptionMin;

  /// No description provided for @srvEmailExists.
  ///
  /// In en, this message translates to:
  /// **'Email already exists'**
  String get srvEmailExists;

  /// No description provided for @srvEmailPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Email and password are required'**
  String get srvEmailPasswordRequired;

  /// No description provided for @srvExerciseAssigned.
  ///
  /// In en, this message translates to:
  /// **'Exercise assigned successfully'**
  String get srvExerciseAssigned;

  /// No description provided for @srvExerciseCompletedSaved.
  ///
  /// In en, this message translates to:
  /// **'Exercise completed and progress saved'**
  String get srvExerciseCompletedSaved;

  /// No description provided for @srvExerciseNotFound.
  ///
  /// In en, this message translates to:
  /// **'Exercise not found'**
  String get srvExerciseNotFound;

  /// No description provided for @srvExerciseRemoved.
  ///
  /// In en, this message translates to:
  /// **'Exercise removed successfully'**
  String get srvExerciseRemoved;

  /// No description provided for @srvInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid password'**
  String get srvInvalidPassword;

  /// No description provided for @srvInvalidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get srvInvalidPhoneNumber;

  /// No description provided for @srvJustifRequired.
  ///
  /// In en, this message translates to:
  /// **'Justification file is required'**
  String get srvJustifRequired;

  /// No description provided for @srvJustifSize.
  ///
  /// In en, this message translates to:
  /// **'Justification file must be <= 8MB'**
  String get srvJustifSize;

  /// No description provided for @srvJustifType.
  ///
  /// In en, this message translates to:
  /// **'Justification file must be PDF/JPG/PNG'**
  String get srvJustifType;

  /// No description provided for @srvJustifUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Justification upload failed'**
  String get srvJustifUploadFailed;

  /// No description provided for @srvMemberNotFound.
  ///
  /// In en, this message translates to:
  /// **'Member not found in your clinic'**
  String get srvMemberNotFound;

  /// No description provided for @srvMessageContentRequired.
  ///
  /// In en, this message translates to:
  /// **'Message content is required'**
  String get srvMessageContentRequired;

  /// No description provided for @srvMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent successfully'**
  String get srvMessageSent;

  /// No description provided for @srvNameMin.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get srvNameMin;

  /// No description provided for @srvNoAccountForEmail.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email'**
  String get srvNoAccountForEmail;

  /// No description provided for @srvNoPhysioAssigned.
  ///
  /// In en, this message translates to:
  /// **'No physiotherapist is assigned to you yet'**
  String get srvNoPhysioAssigned;

  /// No description provided for @srvPatientCreated.
  ///
  /// In en, this message translates to:
  /// **'Patient account created successfully'**
  String get srvPatientCreated;

  /// No description provided for @srvPatientDeleted.
  ///
  /// In en, this message translates to:
  /// **'Patient deleted successfully'**
  String get srvPatientDeleted;

  /// No description provided for @srvPatientNotAssignedToPhysio.
  ///
  /// In en, this message translates to:
  /// **'Patient is not assigned to this physiotherapist'**
  String get srvPatientNotAssignedToPhysio;

  /// No description provided for @srvPatientNotAssignedToPhysio2.
  ///
  /// In en, this message translates to:
  /// **'Patient not assigned to this physiotherapist'**
  String get srvPatientNotAssignedToPhysio2;

  /// No description provided for @srvPatientProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Patient profile not found'**
  String get srvPatientProfileNotFound;

  /// No description provided for @srvPaymentConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed. Subscription activated successfully.'**
  String get srvPaymentConfirmed;

  /// No description provided for @srvPaymentNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment is not completed yet. Finish checkout and try again.'**
  String get srvPaymentNotCompleted;

  /// No description provided for @srvPaymentRefNotFound.
  ///
  /// In en, this message translates to:
  /// **'Payment reference not found for this clinic'**
  String get srvPaymentRefNotFound;

  /// No description provided for @srvPhotoType.
  ///
  /// In en, this message translates to:
  /// **'Photo must be JPG/PNG/WEBP'**
  String get srvPhotoType;

  /// No description provided for @srvPhotoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded successfully'**
  String get srvPhotoUploaded;

  /// No description provided for @srvPhysioNotFound.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist not found'**
  String get srvPhysioNotFound;

  /// No description provided for @srvPhysioProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist profile not found'**
  String get srvPhysioProfileNotFound;

  /// No description provided for @srvPremiumForVideo.
  ///
  /// In en, this message translates to:
  /// **'Premium subscription required for video upload'**
  String get srvPremiumForVideo;

  /// No description provided for @srvProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get srvProfileUpdated;

  /// No description provided for @srvProgressSaved.
  ///
  /// In en, this message translates to:
  /// **'Progress report saved'**
  String get srvProgressSaved;

  /// No description provided for @srvSetsRepsPositive.
  ///
  /// In en, this message translates to:
  /// **'sets and reps must be greater than 0'**
  String get srvSetsRepsPositive;

  /// No description provided for @srvStripeCheckoutReady.
  ///
  /// In en, this message translates to:
  /// **'Stripe checkout ready. Complete payment then tap Verify.'**
  String get srvStripeCheckoutReady;

  /// No description provided for @srvTherapistCreated.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist account created successfully'**
  String get srvTherapistCreated;

  /// No description provided for @srvTherapistDeleted.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist deleted successfully'**
  String get srvTherapistDeleted;

  /// No description provided for @srvUnsupportedVideo.
  ///
  /// In en, this message translates to:
  /// **'Unsupported video format'**
  String get srvUnsupportedVideo;

  /// No description provided for @srvWaitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get srvWaitingForApproval;

  /// No description provided for @standardPlan.
  ///
  /// In en, this message translates to:
  /// **'Standard plan'**
  String get standardPlan;

  /// No description provided for @startExercise.
  ///
  /// In en, this message translates to:
  /// **'Start Exercise'**
  String get startExercise;

  /// No description provided for @statsOverview.
  ///
  /// In en, this message translates to:
  /// **'Stats Overview'**
  String get statsOverview;

  /// No description provided for @statusValue.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusValue(String status);

  /// No description provided for @submitComplaint.
  ///
  /// In en, this message translates to:
  /// **'Submit a complaint'**
  String get submitComplaint;

  /// No description provided for @submitForApproval.
  ///
  /// In en, this message translates to:
  /// **'Submit for approval'**
  String get submitForApproval;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @subscriptionActiveAiAvailable.
  ///
  /// In en, this message translates to:
  /// **'Subscription active: AI feedback available.'**
  String get subscriptionActiveAiAvailable;

  /// No description provided for @subscriptionActiveAiUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Clinic subscription active - AI Feedback unlocked'**
  String get subscriptionActiveAiUnlocked;

  /// No description provided for @subscriptionInactiveAiHidden.
  ///
  /// In en, this message translates to:
  /// **'Subscription inactive: AI feedback hidden.'**
  String get subscriptionInactiveAiHidden;

  /// No description provided for @subscriptionInactiveAiLocked.
  ///
  /// In en, this message translates to:
  /// **'Clinic subscription inactive - AI Feedback locked'**
  String get subscriptionInactiveAiLocked;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @summaryBelowTarget.
  ///
  /// In en, this message translates to:
  /// **'Good form, below your target'**
  String get summaryBelowTarget;

  /// No description provided for @summaryEveryRep.
  ///
  /// In en, this message translates to:
  /// **'Every rep'**
  String get summaryEveryRep;

  /// No description provided for @summaryGoodReps.
  ///
  /// In en, this message translates to:
  /// **'good reps'**
  String get summaryGoodReps;

  /// No description provided for @summaryMistakes.
  ///
  /// In en, this message translates to:
  /// **'Mistakes'**
  String get summaryMistakes;

  /// No description provided for @summaryNoMistakes.
  ///
  /// In en, this message translates to:
  /// **'No mistakes - well done!'**
  String get summaryNoMistakes;

  /// No description provided for @summaryNoneScored.
  ///
  /// In en, this message translates to:
  /// **'No rep could be scored.'**
  String get summaryNoneScored;

  /// No description provided for @summaryNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get summaryNotSent;

  /// No description provided for @summaryNotSentError.
  ///
  /// In en, this message translates to:
  /// **'Not sent: {error}'**
  String summaryNotSentError(String error);

  /// No description provided for @summaryPainQuestion.
  ///
  /// In en, this message translates to:
  /// **'How much pain did you feel? (0 = none, 10 = worst)'**
  String get summaryPainQuestion;

  /// No description provided for @summaryPainReported.
  ///
  /// In en, this message translates to:
  /// **'You reported pain during this set. Your physiotherapist will see it.'**
  String get summaryPainReported;

  /// No description provided for @summaryPeak.
  ///
  /// In en, this message translates to:
  /// **'Leg lift: median {deg}° (target {target}°)'**
  String summaryPeak(int deg, int target);

  /// No description provided for @summaryRepsCounted.
  ///
  /// In en, this message translates to:
  /// **'reps counted'**
  String get summaryRepsCounted;

  /// No description provided for @summaryRepsScored.
  ///
  /// In en, this message translates to:
  /// **'reps scored'**
  String get summaryRepsScored;

  /// No description provided for @summarySending.
  ///
  /// In en, this message translates to:
  /// **'Sending to your physiotherapist...'**
  String get summarySending;

  /// No description provided for @summarySent.
  ///
  /// In en, this message translates to:
  /// **'Saved and sent to your physiotherapist'**
  String get summarySent;

  /// No description provided for @summaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Set summary'**
  String get summaryTitle;

  /// No description provided for @summaryTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get summaryTryAgain;

  /// No description provided for @summaryUnsure.
  ///
  /// In en, this message translates to:
  /// **'{count} rep(s) could not be judged with confidence.'**
  String summaryUnsure(int count);

  /// No description provided for @summaryWrongSideArm.
  ///
  /// In en, this message translates to:
  /// **'{count} rep(s) done with the other arm were not counted.'**
  String summaryWrongSideArm(int count);

  /// No description provided for @summaryWrongSideLeg.
  ///
  /// In en, this message translates to:
  /// **'{count} rep(s) done with the other leg were not counted.'**
  String summaryWrongSideLeg(int count);

  /// No description provided for @switchToDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark mode'**
  String get switchToDarkMode;

  /// No description provided for @switchToLightMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to light mode'**
  String get switchToLightMode;

  /// No description provided for @symptomsOptional.
  ///
  /// In en, this message translates to:
  /// **'Symptoms (optional)'**
  String get symptomsOptional;

  /// No description provided for @symptomsValue.
  ///
  /// In en, this message translates to:
  /// **'Symptoms: {symptoms}'**
  String symptomsValue(String symptoms);

  /// No description provided for @tapButtonToAddMember.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to add one.'**
  String get tapButtonToAddMember;

  /// No description provided for @tapToStartLogging.
  ///
  /// In en, this message translates to:
  /// **'Tap below to start logging your progress'**
  String get tapToStartLogging;

  /// No description provided for @tapToUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload (PDF/JPG/PNG)'**
  String get tapToUploadDocument;

  /// No description provided for @targetReps.
  ///
  /// In en, this message translates to:
  /// **'Target: {reps} reps'**
  String targetReps(String reps);

  /// No description provided for @targetSetsReps.
  ///
  /// In en, this message translates to:
  /// **'Target: {sets} sets × {reps} reps = {total} total reps'**
  String targetSetsReps(String total, String reps, String sets);

  /// No description provided for @therapistChat.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist chat'**
  String get therapistChat;

  /// No description provided for @therapistValue.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapist: {name}'**
  String therapistValue(String name);

  /// No description provided for @therapists.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapists'**
  String get therapists;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisWeeksActivity.
  ///
  /// In en, this message translates to:
  /// **'This week\'s activity'**
  String get thisWeeksActivity;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @todayUpper.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get todayUpper;

  /// No description provided for @todaysExercises.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Exercises'**
  String get todaysExercises;

  /// No description provided for @todaysPlan.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Plan'**
  String get todaysPlan;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme'**
  String get toggleTheme;

  /// No description provided for @totalRepsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Total reps completed'**
  String get totalRepsCompleted;

  /// No description provided for @trackedArmLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get trackedArmLeft;

  /// No description provided for @trackedArmRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get trackedArmRight;

  /// No description provided for @trackedE1.
  ///
  /// In en, this message translates to:
  /// **'Forward elevation with a stick (both arms)'**
  String get trackedE1;

  /// No description provided for @trackedE2.
  ///
  /// In en, this message translates to:
  /// **'Arm abduction (one arm)'**
  String get trackedE2;

  /// No description provided for @trackedE3.
  ///
  /// In en, this message translates to:
  /// **'Arm rotation, elbow at the side (one arm)'**
  String get trackedE3;

  /// No description provided for @trackedE4.
  ///
  /// In en, this message translates to:
  /// **'Standing hip abduction (one leg)'**
  String get trackedE4;

  /// No description provided for @trackedInjuredArm.
  ///
  /// In en, this message translates to:
  /// **'Injured arm'**
  String get trackedInjuredArm;

  /// No description provided for @trackedLabel.
  ///
  /// In en, this message translates to:
  /// **'Live camera tracking'**
  String get trackedLabel;

  /// No description provided for @trackedLiftedLeg.
  ///
  /// In en, this message translates to:
  /// **'Lifted leg'**
  String get trackedLiftedLeg;

  /// No description provided for @trackedNone.
  ///
  /// In en, this message translates to:
  /// **'No live tracking'**
  String get trackedNone;

  /// No description provided for @trackedSummary.
  ///
  /// In en, this message translates to:
  /// **'{exercise} · {arm} arm'**
  String trackedSummary(String exercise, String arm);

  /// No description provided for @trackedSummaryLeg.
  ///
  /// In en, this message translates to:
  /// **'{exercise} · {leg} leg'**
  String trackedSummaryLeg(String exercise, String leg);

  /// No description provided for @trackedTargetAngle.
  ///
  /// In en, this message translates to:
  /// **'Target lift angle (°)'**
  String get trackedTargetAngle;

  /// No description provided for @trackedTargetAngleHelp.
  ///
  /// In en, this message translates to:
  /// **'Leg angle away from the body at the top of the lift. Leave empty to use {percent} % of the patient\'s usual lift (or the default angle of {deg}° until it is known).'**
  String trackedTargetAngleHelp(String percent, String deg);

  /// No description provided for @trackedTargetAngleInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an angle between 5 and 90°, or leave it empty'**
  String get trackedTargetAngleInvalid;

  /// No description provided for @trackedTargetShort.
  ///
  /// In en, this message translates to:
  /// **'target {deg}°'**
  String trackedTargetShort(String deg);

  /// No description provided for @trackedWorkingArm.
  ///
  /// In en, this message translates to:
  /// **'Arm that does the exercise'**
  String get trackedWorkingArm;

  /// No description provided for @trackingNotSet.
  ///
  /// In en, this message translates to:
  /// **'Your physiotherapist has not set up live camera tracking for this exercise yet.'**
  String get trackingNotSet;

  /// No description provided for @truncated.
  ///
  /// In en, this message translates to:
  /// **'...truncated...'**
  String get truncated;

  /// No description provided for @typeYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get typeYourMessage;

  /// No description provided for @unableToOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Unable to open camera: {error}'**
  String unableToOpenCamera(String error);

  /// No description provided for @unableToOpenDocument.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the document.'**
  String get unableToOpenDocument;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @unnamedAccount.
  ///
  /// In en, this message translates to:
  /// **'Unnamed account'**
  String get unnamedAccount;

  /// No description provided for @updateProgress.
  ///
  /// In en, this message translates to:
  /// **'Update Progress'**
  String get updateProgress;

  /// No description provided for @upgradeToPremium.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get upgradeToPremium;

  /// No description provided for @uploadJustificationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please upload your clinic justification file.'**
  String get uploadJustificationPrompt;

  /// No description provided for @useRegisteredCredentials.
  ///
  /// In en, this message translates to:
  /// **'Use your registered email and password.'**
  String get useRegisteredCredentials;

  /// No description provided for @verifyStripePayment.
  ///
  /// In en, this message translates to:
  /// **'Verify Stripe payment'**
  String get verifyStripePayment;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @videoRecordingLocked.
  ///
  /// In en, this message translates to:
  /// **'Video recording is locked: clinic subscription is inactive.'**
  String get videoRecordingLocked;

  /// No description provided for @viewComplaints.
  ///
  /// In en, this message translates to:
  /// **'View complaints'**
  String get viewComplaints;

  /// No description provided for @viewDocument.
  ///
  /// In en, this message translates to:
  /// **'View document'**
  String get viewDocument;

  /// No description provided for @voiceAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'The exercise is already running.'**
  String get voiceAlreadyRunning;

  /// No description provided for @voiceHelp.
  ///
  /// In en, this message translates to:
  /// **'You can say: repeat, I don\'t understand, pause, resume, help, or it hurts.'**
  String get voiceHelp;

  /// No description provided for @voiceLanguageFallback.
  ///
  /// In en, this message translates to:
  /// **'Voice is not available in your language on this phone: using English.'**
  String get voiceLanguageFallback;

  /// No description provided for @voiceMilestone.
  ///
  /// In en, this message translates to:
  /// **'You have completed {count} repetitions.'**
  String voiceMilestone(int count);

  /// No description provided for @voiceNotUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I did not understand. Say help to hear the commands.'**
  String get voiceNotUnderstood;

  /// No description provided for @voiceNothingToRepeat.
  ///
  /// In en, this message translates to:
  /// **'There is no instruction to repeat yet.'**
  String get voiceNothingToRepeat;

  /// No description provided for @voicePainClarify.
  ///
  /// In en, this message translates to:
  /// **'I paused the exercise to be safe. Are you feeling pain now? If yes, say: it hurts, or press I feel pain.'**
  String get voicePainClarify;

  /// No description provided for @voicePainHoldRefuse.
  ///
  /// In en, this message translates to:
  /// **'The exercise stays paused because you reported pain. Please follow your physiotherapist\'s guidance.'**
  String get voicePainHoldRefuse;

  /// No description provided for @voicePainResponse.
  ///
  /// In en, this message translates to:
  /// **'I heard that you are in pain. The exercise is paused. Please follow your physiotherapist\'s guidance before continuing.'**
  String get voicePainResponse;

  /// No description provided for @voicePaused.
  ///
  /// In en, this message translates to:
  /// **'The exercise is paused. Press resume when you are ready.'**
  String get voicePaused;

  /// No description provided for @voiceResumed.
  ///
  /// In en, this message translates to:
  /// **'Let\'s continue. Stand still first.'**
  String get voiceResumed;

  /// No description provided for @voiceSetDone.
  ///
  /// In en, this message translates to:
  /// **'The set is finished. Well done.'**
  String get voiceSetDone;

  /// No description provided for @voiceStandStill.
  ///
  /// In en, this message translates to:
  /// **'Stand still for two seconds.'**
  String get voiceStandStill;

  /// No description provided for @voiceStart.
  ///
  /// In en, this message translates to:
  /// **'You can start: {exercise}.'**
  String voiceStart(String exercise);

  /// No description provided for @voiceStepBack.
  ///
  /// In en, this message translates to:
  /// **'Please step back so your whole body is visible.'**
  String get voiceStepBack;

  /// No description provided for @voiceStepBackFeet.
  ///
  /// In en, this message translates to:
  /// **'Step back so the camera sees your whole body, feet included'**
  String get voiceStepBackFeet;

  /// No description provided for @voiceTtsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Spoken feedback is not available on this phone.'**
  String get voiceTtsUnavailable;

  /// No description provided for @voiceUncomfortable.
  ///
  /// In en, this message translates to:
  /// **'I paused the exercise. Are you in pain? If yes, say: it hurts, or press I feel pain.'**
  String get voiceUncomfortable;

  /// No description provided for @weekdayInitials.
  ///
  /// In en, this message translates to:
  /// **'M,T,W,T,F,S,S'**
  String get weekdayInitials;

  /// No description provided for @weekdayShortNames.
  ///
  /// In en, this message translates to:
  /// **'Mon,Tue,Wed,Thu,Fri,Sat,Sun'**
  String get weekdayShortNames;

  /// No description provided for @weeklyGoalPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Weekly Goal'**
  String weeklyGoalPercent(String percent);

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @yearlyPricingNote.
  ///
  /// In en, this message translates to:
  /// **'Yearly: 50 EUR + 0.10 EUR per patient'**
  String get yearlyPricingNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

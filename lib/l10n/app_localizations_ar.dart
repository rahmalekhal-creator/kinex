// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get accountDeleted => 'تم حذف الحساب';

  @override
  String accountRoleActive(String active, String role) {
    return 'الدور: $role | نشط: $active';
  }

  @override
  String get accounts => 'الحسابات';

  @override
  String get addMember => 'إضافة عضو';

  @override
  String get addNewMember => 'إضافة عضو جديد';

  @override
  String get address => 'العنوان';

  @override
  String get adminHome => 'لوحة المسؤول';

  @override
  String get aiCoachBanner =>
      'مدرّب Kinex الذكي: إرشاد أذكى لإعادة التأهيل كل يوم.';

  @override
  String get aiFeedback => 'تحليل الذكاء الاصطناعي';

  @override
  String aiFeedbackFor(String name) {
    return 'تحليل الذكاء الاصطناعي - $name';
  }

  @override
  String get all => 'الكل';

  @override
  String get allSetsDone => 'أنجزت كل المجموعات! ✓';

  @override
  String get approve => 'موافقة';

  @override
  String get armSideLeft => 'اليسرى';

  @override
  String get armSideRight => 'اليمنى';

  @override
  String get assign => 'تعيين';

  @override
  String get assignExercise => 'تعيين تمرين';

  @override
  String get assignExerciseTitle => 'تعيين تمرين';

  @override
  String get assignedBy => 'عيّنه';

  @override
  String get assignedExercises => 'التمارين المعيَّنة';

  @override
  String get assignedPatients => 'المرضى المعيَّنون';

  @override
  String get assignedPhysiotherapist => 'أخصائي العلاج الطبيعي المعيَّن';

  @override
  String get assistantAndroidOnly =>
      'يعمل مساعد التمارين المباشر على هواتف أندرويد.';

  @override
  String assistantArmLabel(String arm) {
    return 'الذراع: $arm';
  }

  @override
  String get assistantCamera => 'الكاميرا';

  @override
  String get assistantCameraBack => 'الخلفية';

  @override
  String get assistantCameraFront => 'الأمامية';

  @override
  String get assistantCameraNeeded =>
      'يحتاج مساعد التمارين إلى الوصول إلى الكاميرا.';

  @override
  String get assistantDevSettings => 'إعدادات المطوّر';

  @override
  String get assistantFullResolution => 'تحليل بالدقة الكاملة (1280 بكسل)';

  @override
  String get assistantFullResolutionHint =>
      'أبطأ. افتراضيًا تُحلَّل الصور بدقة 640 بكسل: نفس النقاط، وحساب أقل بكثير لكل صورة.';

  @override
  String assistantInjuredArmLabel(String arm) {
    return 'الذراع المصابة: $arm';
  }

  @override
  String assistantLegLabel(String leg) {
    return 'الرجل المرفوعة: $leg';
  }

  @override
  String get assistantModel => 'النموذج';

  @override
  String get assistantModelMultitask => 'شبكة متعددة المهام';

  @override
  String get assistantModelSeparate => 'شبكات منفصلة';

  @override
  String get assistantPlacementTip =>
      'ضع الهاتف بشكل عمودي أمامك على بعد 2 إلى 3 أمتار تقريبًا، بحيث يظهر جسمك كاملًا من الركبتين إلى الرأس. ابقَ ثابتًا لمدة ثانيتين عندما يُطلب منك ذلك، ثم ابدأ.';

  @override
  String get assistantPlacementTipLeg =>
      'ضع الهاتف عموديًا أمامك على مستوى الورك، على بعد 2-3 م تقريبًا، بحيث يظهر جسمك كاملًا بما في ذلك القدمان. ضع الكرسي بجانب الرجل التي تقف عليها وأمسكه. قف ثابتًا لمدة ثانيتين عندما يُطلب منك، ثم ابدأ.';

  @override
  String get assistantSetByPhysio => 'حدّده أخصائي العلاج الطبيعي';

  @override
  String get assistantShowTiming => 'عرض أوقات المعالجة';

  @override
  String get assistantStartSet => 'ابدأ المجموعة';

  @override
  String assistantTargetLabel(String deg) {
    return 'هدفك: $deg°';
  }

  @override
  String get assistantTitle => 'مساعد التمارين';

  @override
  String get assistantUseGpu => 'كشف الوضعية على معالج الرسوميات (للمطور)';

  @override
  String get assistantUseGpuHint =>
      'أسرع في كثير من الهواتف؛ ويُستخدم المعالج المركزي إن تعذر ذلك. يُظهر سطر القياس أيهما يعمل.';

  @override
  String get assistantVoice => 'المساعد الصوتي';

  @override
  String get assistantVoiceOn => 'تعليمات وتصحيحات صوتية';

  @override
  String get assistantVoiceRate => 'سرعة الكلام';

  @override
  String get becomePartnerClinic => 'انضم كعيادة شريكة';

  @override
  String get birthDate => 'تاريخ الميلاد';

  @override
  String get birthDateRequiredForPatients => 'تاريخ الميلاد مطلوب للمرضى.';

  @override
  String get bodyRegionHip => 'الورك';

  @override
  String get bodyRegionOther => 'تمارين أخرى';

  @override
  String get bodyRegionShoulder => 'الكتف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get changeLanguage => 'تغيير اللغة';

  @override
  String get clinic => 'عيادة';

  @override
  String get clinicComplaints => 'شكاوى العيادة';

  @override
  String get clinicDashboard => 'لوحة تحكم العيادة';

  @override
  String get clinicEmail => 'البريد الإلكتروني للعيادة';

  @override
  String clinicMembersCount(String count) {
    return 'أعضاء العيادة ($count)';
  }

  @override
  String get clinicName => 'اسم العيادة';

  @override
  String get clinicOnlySignupNote =>
      'التسجيل هنا متاح للعيادات فقط. يُنشأ المرضى وأخصائيو العلاج الطبيعي من لوحة تحكم العيادة بعد تسجيل دخولها.';

  @override
  String get clinicProfile => 'ملف العيادة';

  @override
  String get clinicProfileSubtitle => 'حدّث معلومات عيادتك وصورتها.';

  @override
  String get clinicRegistration => 'تسجيل العيادة';

  @override
  String get clinicRegistrationIntro =>
      'أنشئ حساب عيادة. ارفع ملف الإثبات المهني ليتمكن المسؤول من التحقق من تسجيلك بسرعة.';

  @override
  String clinicValue(String name) {
    return 'العيادة: $name';
  }

  @override
  String get clinics => 'العيادات';

  @override
  String comingSoon(String title) {
    return '$title قريبًا';
  }

  @override
  String get complaintSentSuccessfully => 'تم إرسال الشكوى بنجاح.';

  @override
  String get complaints => 'الشكاوى';

  @override
  String get completeLabel => 'مكتمل';

  @override
  String get completed => 'مكتمل';

  @override
  String completedOfAssigned(String completed, String assigned) {
    return '$completed مكتمل / $assigned معيَّن';
  }

  @override
  String completedRepsOf(String done, String target) {
    return 'مكتمل – $done$target تكرارات ✓';
  }

  @override
  String get continueLabel => 'متابعة';

  @override
  String get continueToLogin => 'المتابعة إلى تسجيل الدخول';

  @override
  String get createMember => 'إنشاء العضو';

  @override
  String get dailyCompletionPercent => 'نسبة الإنجاز اليومية %';

  @override
  String dateAtTime(String time, String date) {
    return '$date على الساعة $time';
  }

  @override
  String dateValue(String date) {
    return 'التاريخ: $date';
  }

  @override
  String get delete => 'حذف';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String deleteAccountConfirm(String id, String label) {
    return 'حذف «$label» (المعرّف: $id)؟';
  }

  @override
  String get deleteMember => 'حذف العضو';

  @override
  String deleteMemberConfirm(String name, String role) {
    return 'حذف $role «$name» من هذه العيادة؟';
  }

  @override
  String get describeYourComplaint => 'صِف شكواك';

  @override
  String get description => 'الوصف';

  @override
  String get descriptionRequired => 'الوصف مطلوب';

  @override
  String get documentAttached => 'مستند مرفق';

  @override
  String get done => 'تم';

  @override
  String get e4ProgressEmpty => 'لم تُسجَّل أي سلسلة لتبعيد الورك بعد.';

  @override
  String e4ProgressGoodShare(int percent) {
    return 'وضعية جيدة: $percent %';
  }

  @override
  String get e4ProgressMedian => 'الرفع الوسيط';

  @override
  String get e4ProgressPerClass => 'التكرارات حسب الفئة';

  @override
  String get e4ProgressTarget => 'الهدف';

  @override
  String get e4ProgressTitle => 'تبعيد الورك - المدى عبر الوقت';

  @override
  String e4ProgressUsualLift(String deg) {
    return 'الرفع المعتاد: $deg°';
  }

  @override
  String get editInformation => 'تعديل المعلومات';

  @override
  String get editInformationTitle => 'تعديل المعلومات';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get emailHint => 'name@example.com';

  @override
  String emailValue(String email) {
    return 'البريد الإلكتروني: $email';
  }

  @override
  String get enterValidEmail => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get enterValidNumber => 'أدخل رقمًا صحيحًا';

  @override
  String get enterYourPassword => 'أدخل كلمة المرور';

  @override
  String get error => 'خطأ';

  @override
  String get errorInvalidResponse => 'صيغة استجابة الخادم غير صالحة';

  @override
  String errorServerStatus(String code) {
    return 'خطأ في الخادم ($code).';
  }

  @override
  String get errorServerUnreachable =>
      'تعذّر الاتصال بالخادم. تحقق من اتصالك وحاول مرة أخرى.';

  @override
  String get errorTimeout => 'انتهت مهلة الطلب. يرجى المحاولة مرة أخرى.';

  @override
  String get exE1Desc =>
      'أمسك العصا بكلتا يديك وارفعها إلى الأمام وإلى الأعلى، ثم أنزلها إلى الأسفل بالكامل.';

  @override
  String get exE1Simple =>
      'أمسك العصا بيديك. ارفعها ببطء. ثم أنزلها إلى الأسفل تمامًا.';

  @override
  String get exE1Title => 'رفع الذراعين إلى الأمام بعصا';

  @override
  String get exE2Desc =>
      'ارفع ذراعًا مستقيمة إلى الجانب، ثم أعدها إلى الأسفل بجانب جسمك.';

  @override
  String get exE2Simple => 'أبقِ ذراعك مستقيمة. ارفعها إلى الجانب. ثم أنزلها.';

  @override
  String get exE2Title => 'إبعاد الذراع';

  @override
  String get exE3Desc =>
      'أبقِ المرفق ملاصقًا لجسمك ومثنيًا بزاوية 90 درجة، ثم دوّر الساعد إلى الخارج وأعده.';

  @override
  String get exE3Simple =>
      'أبقِ مرفقك ملاصقًا لجنبك. أدر يدك إلى الخارج. ثم أعدها.';

  @override
  String get exE3Title => 'تدوير الذراع مع إبقاء المرفق بجانب الجسم';

  @override
  String get exE4Desc =>
      'قف مقابل الهاتف وبجانبك كرسي، وأمسكه باليد التي في جهة الرجل التي تقف عليها. ارفع الرجل الأخرى إلى الجانب والركبة مستقيمة والجذع منتصب، ثم أنزلها ببطء وتحكم. ارفعها فقط بقدر ما تستطيع مع وضعية صحيحة: معالجك الفيزيائي يحدد هدفك.';

  @override
  String get exE4Simple =>
      'أمسك الكرسي. أبقِ ركبتك مستقيمة. ارفع رجلك إلى الجانب. ثم أنزلها ببطء.';

  @override
  String get exE4Title => 'تبعيد الورك وقوفًا';

  @override
  String get exercise => 'تمرين';

  @override
  String exerciseAnalysisFailed(String error) {
    return 'فشل تحليل التمرين: $error';
  }

  @override
  String get exerciseAssigned => 'تمرين معيَّن';

  @override
  String get exerciseAssignedSuccessfully => 'تم تعيين التمرين بنجاح.';

  @override
  String get exerciseCompletedCheck => 'اكتمل التمرين ✓';

  @override
  String get exerciseDataReady => 'بيانات التمرين جاهزة';

  @override
  String get exercises => 'التمارين';

  @override
  String exercisesLoggedOf(String reported, String total) {
    return '$reported / $total تمارين مسجّلة';
  }

  @override
  String fbBelowTarget(int target, int reached) {
    return 'وضعية جيدة - ارفع رجلك أعلى قليلًا: الهدف $target°، وصلت إلى $reached°';
  }

  @override
  String get fbBelowTargetSimple => 'جيد. ارفع رجلك الآن أعلى قليلًا.';

  @override
  String get fbE1Elb => 'أبقِ مرفقيك مستقيمين أثناء رفع العصا';

  @override
  String get fbE1ElbSimple => 'ذراعان مستقيمتان. لا تثنِ مرفقيك.';

  @override
  String fbE1Imb(String arm) {
    return 'ارفع العصا بشكل متوازن: ارفع ذراعك $arm بنفس ارتفاع الأخرى';
  }

  @override
  String get fbE1ImbSimple => 'ارفع يديك إلى نفس الارتفاع.';

  @override
  String get fbE1Rngdown => 'أنزل العصا إلى الأسفل تمامًا بين التكرارات';

  @override
  String get fbE1RngdownSimple => 'انزل إلى الأسفل تمامًا في كل مرة.';

  @override
  String get fbE2Elb => 'أبقِ مرفقك مستقيمًا';

  @override
  String get fbE2ElbSimple => 'ذراع مستقيمة. لا تثنِ مرفقك.';

  @override
  String get fbE2Lean => 'حافظ على استقامة جذعك: لا تمِل لرفع الذراع';

  @override
  String get fbE2LeanSimple => 'قف مستقيمًا. لا تمِل إلى الجانب.';

  @override
  String get fbE2Rngdown => 'أنزل ذراعك تمامًا بجانب جسمك بين التكرارات';

  @override
  String get fbE2RngdownSimple => 'أنزل ذراعك تمامًا في كل مرة.';

  @override
  String get fbE2Shld =>
      'لا ترفع كتفك: أبقِه منخفضًا بينما ترتفع الذراع إلى مستوى الكتف';

  @override
  String get fbE2ShldSimple => 'أبقِ كتفك منخفضًا ومرتخيًا.';

  @override
  String get fbE3Wrong => 'أبقِ مرفقك ملاصقًا لجسمك أثناء التدوير';

  @override
  String get fbE3WrongSimple => 'أبقِ مرفقك ملامسًا لجنبك.';

  @override
  String fbE4Knee(String leg) {
    return 'أبقِ الركبة $leg مستقيمة أثناء رفع الرجل';
  }

  @override
  String get fbE4KneeSimple => 'الركبة مستقيمة. لا تثنها.';

  @override
  String get fbE4Leanin => 'أبقِ جذعك منتصبًا - لا تمِل نحو الرجل التي ترفعها';

  @override
  String get fbE4LeaninSimple => 'قف مستقيمًا. لا تمِل نحو الرجل.';

  @override
  String get fbE4Leanout =>
      'أبقِ جذعك منتصبًا - لا تمِل بعيدًا عن الرجل (نحو الكرسي)';

  @override
  String get fbE4LeanoutSimple => 'قف مستقيمًا. لا تمِل نحو الكرسي.';

  @override
  String get fbE4Unsure =>
      'لست متأكدًا من هذا التكرار - تأكد من أن جسمك كاملًا بما في ذلك القدمان ظاهر';

  @override
  String get fbE4UnsureSimple => 'ارجع إلى الخلف حتى ترى الكاميرا قدميك.';

  @override
  String get fbGood => 'تكرار صحيح، أحسنت';

  @override
  String get fbPartial => 'تكرار مقطوع في بداية أو نهاية التسجيل - لم يُقيَّم';

  @override
  String get fbUnsure => 'غير متأكد من هذا التكرار: تأكد من ظهور جسمك بالكامل';

  @override
  String get fbUnsureSimple => 'ابتعد قليلًا حتى ترى الكاميرا جسمك بالكامل.';

  @override
  String fbWrongArm(String arm) {
    return 'الذراع الخطأ - استعمل الذراع $arm: هذا التكرار لا يُحتسب';
  }

  @override
  String fbWrongArmSimple(String arm) {
    return 'استعمل الذراع $arm.';
  }

  @override
  String fbWrongLeg(String leg) {
    return 'الرجل الخطأ - استعمل الرجل $leg: هذا التكرار لا يُحتسب';
  }

  @override
  String fbWrongLegSimple(String leg) {
    return 'ارفع الرجل $leg.';
  }

  @override
  String framesAnalyzed(String count) {
    return 'الإطارات المحلَّلة: $count';
  }

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get hiPatient => 'مرحبًا';

  @override
  String get history => 'السجل';

  @override
  String get home => 'الرئيسية';

  @override
  String get iPaidVerify => 'لقد دفعت — تحقّق من الدفع';

  @override
  String get invalidEmailFormat => 'صيغة البريد الإلكتروني غير صحيحة';

  @override
  String get invalidPhoneFormat => 'صيغة رقم الهاتف غير صحيحة';

  @override
  String get invalidVideoUrl => 'رابط الفيديو غير صالح أو غير مدعوم';

  @override
  String get justificationFile => 'ملف الإثبات ';

  @override
  String get justificationReviewNote =>
      'يراجع المسؤول هذا الملف قبل الموافقة على الحساب.';

  @override
  String keypointsExtracted(String count) {
    return 'النقاط الرئيسية المستخرجة: $count';
  }

  @override
  String latestRepsDone(String reps) {
    return 'الأخير: $reps تكرارات منجزة';
  }

  @override
  String get legSideLeft => 'اليسرى';

  @override
  String get legSideRight => 'اليمنى';

  @override
  String get liveArmAngle => 'زاوية الذراع';

  @override
  String liveArmMoving(String arm) {
    return 'الذراع $arm هي التي تتحرك: سيتم تقييمها';
  }

  @override
  String liveCameraProblem(String error) {
    return 'مشكلة في الكاميرا: $error';
  }

  @override
  String get liveDone => 'انتهى';

  @override
  String get liveFinishSet => 'إنهاء المجموعة';

  @override
  String get liveFinishing => 'جارٍ تقييم آخر التكرارات...';

  @override
  String get liveLegAngle => 'زاوية الرجل';

  @override
  String get livePainBody =>
      'لا تواصل هذا التمرين الآن. يُرجى اتباع إرشادات أخصائي العلاج الطبيعي قبل المتابعة. سيُرسل بلاغك إلى أخصائي العلاج الطبيعي، وهو ما أبلغت عنه وليس تشخيصًا طبيًا.';

  @override
  String get livePainTitle => 'توقف التمرين لأنك أبلغت عن ألم';

  @override
  String get livePause => 'إيقاف مؤقت';

  @override
  String get livePausedBody =>
      'اضغط على استئناف عندما تكون مستعدًا. سيُطلب منك البقاء ثابتًا قليلًا قبل البدء من جديد.';

  @override
  String get livePausedTitle => 'التمرين متوقف مؤقتًا';

  @override
  String get livePositioning =>
      'ابتعد حتى يظهر جسمك كاملًا من الركبتين إلى الرأس';

  @override
  String liveRep(int n) {
    return 'التكرار $n';
  }

  @override
  String get liveReportPain => 'أشعر بألم';

  @override
  String get liveReps => 'تكرارات';

  @override
  String get liveResume => 'استئناف';

  @override
  String liveStandStill(int seconds) {
    return 'ابقَ ثابتًا... $seconds';
  }

  @override
  String get liveStart => 'ابدأ!';

  @override
  String get liveStarting => 'جارٍ تشغيل الكاميرا...';

  @override
  String liveWrongArm(String moving, String arm) {
    return 'أنت تحرك الذراع $moving - استعمل الذراع $arm. هذه التكرارات لا تُحتسب.';
  }

  @override
  String liveWrongLeg(String moving, String leg) {
    return 'أنت ترفع الرجل $moving - استعمل الرجل $leg. هذه التكرارات لا تُحتسب.';
  }

  @override
  String get logOut => 'تسجيل الخروج';

  @override
  String get logProgress => 'تسجيل التقدّم';

  @override
  String logProgressFor(String name) {
    return 'تسجيل التقدّم – $name';
  }

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get loginFailedTitle => 'تعذّر تسجيل الدخول';

  @override
  String get loginIntro =>
      'تابع تعافيك واتبع إرشادات تمارين أذكى وابقَ على تواصل مع أخصائي العلاج الطبيعي الخاص بك.';

  @override
  String get loginSuccessBody => 'مرحبًا بعودتك إلى مساحة عملك في Kinex.';

  @override
  String get loginSuccessTitle => 'تم تسجيل الدخول بنجاح!';

  @override
  String get loginTagline =>
      'تابع رحلة إعادة التأهيل المدعومة بالذكاء الاصطناعي.';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String logsCount(String count) {
    return '$count سجلات';
  }

  @override
  String get manage => 'إدارة';

  @override
  String get manageDetailsAndClinic => 'أدِر بياناتك ووصولك إلى العيادة.';

  @override
  String get manageProfileAndSupport => 'أدِر معلوماتك الشخصية وخيارات الدعم.';

  @override
  String get me => 'أنا';

  @override
  String get members => 'الأعضاء';

  @override
  String get message => 'مراسلة';

  @override
  String get micError =>
      'حدث خطأ في الأمر الصوتي. حاول مرة أخرى أو استخدم الأزرار.';

  @override
  String micHeard(String text) {
    return 'سمعت: «$text»';
  }

  @override
  String get micListening => 'أستمع إليك...';

  @override
  String get micPermissionDenied =>
      'تم رفض إذن الميكروفون. اسمح به من إعدادات الهاتف لاستخدام الأوامر الصوتية.';

  @override
  String get micProcessing => 'جارٍ الفهم...';

  @override
  String get micReady => 'المس الميكروفون للتحدث';

  @override
  String get micSpeaking => 'أتحدث...';

  @override
  String get micTooltip => 'الميكروفون';

  @override
  String get micUnavailable =>
      'الأوامر الصوتية غير متوفرة على هذا الهاتف. استخدم الأزرار.';

  @override
  String get minSixCharacters => '6 أحرف على الأقل';

  @override
  String get minSixChars => '6 أحرف على الأقل';

  @override
  String get minThreeCharacters => '3 أحرف على الأقل';

  @override
  String get monthNames =>
      'جانفي,فيفري,مارس,أفريل,ماي,جوان,جويلية,أوت,سبتمبر,أكتوبر,نوفمبر,ديسمبر';

  @override
  String get monthShortNames =>
      'جانفي,فيفري,مارس,أفريل,ماي,جوان,جويلية,أوت,سبتمبر,أكتوبر,نوفمبر,ديسمبر';

  @override
  String monthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get monthly => 'شهري';

  @override
  String get monthlyPricingNote => 'شهري: 5 يورو + 0.10 يورو لكل مريض';

  @override
  String get myPatients => 'مرضاي';

  @override
  String get myTherapist => 'أخصائي العلاج الطبيعي الخاص بي';

  @override
  String get name => 'الاسم';

  @override
  String get nameAndPhoneRequired => 'الاسم ورقم الهاتف مطلوبان';

  @override
  String get nameRequired => 'الاسم مطلوب';

  @override
  String get newPasswordOptional => 'كلمة مرور جديدة (اختياري)';

  @override
  String get noAiFeedbackYet => 'لا يوجد تحليل بالذكاء الاصطناعي بعد.';

  @override
  String get noAssignedExercises => 'لا توجد تمارين معيَّنة بعد.';

  @override
  String get noAssignedPatients => 'لا يوجد مرضى معيَّنون بعد.';

  @override
  String get noAssignedTherapist => 'لا يوجد أخصائي علاج طبيعي معيَّن';

  @override
  String get noAssignment => 'بدون تعيين';

  @override
  String get noComplaintsFound => 'لا توجد شكاوى.';

  @override
  String get noExerciseDescription => 'لا يوجد وصف متاح لهذا التمرين.';

  @override
  String get noExerciseInCatalog => 'لا توجد تمارين متاحة في الكتالوج.';

  @override
  String get noExercisesForDay => 'لا توجد تمارين لليوم المحدد.';

  @override
  String get noExercisesForFilter => 'لا توجد تمارين لهذا التصنيف.';

  @override
  String get noExercisesToday => 'لا توجد تمارين معيَّنة لليوم بعد.';

  @override
  String get noJustificationFile => 'لا يوجد ملف إثبات متاح.';

  @override
  String get noMatchingAccounts => 'لا توجد حسابات مطابقة.';

  @override
  String get noMatchingClinics => 'لا توجد عيادات مطابقة.';

  @override
  String get noMembersYet => 'لا يوجد أعضاء بعد';

  @override
  String get noMessagesYet => 'لا توجد رسائل بعد. ابدأ المحادثة.';

  @override
  String get noPaymentReference =>
      'لا يوجد مرجع للدفع. ابدأ عملية الدفع أولًا.';

  @override
  String get noPendingClinics => 'لا توجد عيادات قيد الانتظار.';

  @override
  String get noProgressReportsForExercise =>
      'لا توجد تقارير تقدّم لهذا التمرين بعد.';

  @override
  String get noSets => 'بدون مجموعات';

  @override
  String get notesOptional => 'ملاحظات (اختياري)';

  @override
  String get notifAssistantNotes => 'ما سجله المساعد';

  @override
  String get notifCategoryAll => 'الكل';

  @override
  String get notifCategoryMessages => 'الرسائل';

  @override
  String get notifCategoryPain => 'بلاغات الألم';

  @override
  String get notifCategoryProgress => 'تقدم التمارين';

  @override
  String get notifCategoryRoutine => 'تحديثات البرنامج';

  @override
  String get notifCorrectReps => 'صحيحة';

  @override
  String get notifDay => 'اليوم';

  @override
  String get notifDetailTitle => 'إشعار';

  @override
  String get notifDoneThatDay => 'المسجل في ذلك اليوم';

  @override
  String get notifDraftHint =>
      'ستتم كتابة رسالة مقترحة في خانة الكتابة. لن يُرسل شيء حتى تضغط على إرسال.';

  @override
  String notifDraftInactivity(String name, String date) {
    return 'مرحبًا $name، لاحظت أنه لم تُسجَّل أي تمارين يوم $date. هل كل شيء على ما يرام؟';
  }

  @override
  String notifDraftIncorrect(String name, String exercise) {
    return 'مرحبًا $name، اطلعت على مجموعة $exercise: كثير من التكرارات لم تُنفَّذ كما هو مطلوب. لنراجع الحركة معًا.';
  }

  @override
  String notifDraftPain(String name, String exercise) {
    return 'مرحبًا $name، رأيت أنك أبلغت عن ألم أثناء $exercise. كيف تشعر الآن؟';
  }

  @override
  String get notifEmpty => 'لا توجد إشعارات بعد';

  @override
  String get notifEmptyCategory => 'لا شيء في هذه الفئة';

  @override
  String notifHoursAgo(int n) {
    return 'منذ $n س';
  }

  @override
  String notifInactivityBody(String date, int count) {
    return '$date · $count تمرين(ات) موصوفة';
  }

  @override
  String notifInactivityTitle(String name) {
    return 'لم يقم $name بأي تمرين';
  }

  @override
  String notifIncorrectBody(String exercise, int mistakes, int judged) {
    return '$exercise · $mistakes من $judged تكرارات مُقيَّمة غير صحيحة';
  }

  @override
  String get notifIncorrectReps => 'غير صحيحة';

  @override
  String notifIncorrectTitle(String name) {
    return '$name: معظم التكرارات غير صحيحة';
  }

  @override
  String get notifJustNow => 'الآن';

  @override
  String get notifLoadError =>
      'تعذر تحميل الإشعارات. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get notifLoadMore => 'تحميل المزيد';

  @override
  String get notifMarkAllRead => 'تعليم الكل كمقروء';

  @override
  String get notifMarkRead => 'تعليم كمقروء';

  @override
  String get notifMessagePatient => 'مراسلة المريض';

  @override
  String notifMessageTitle(String name) {
    return 'رسالة جديدة من $name';
  }

  @override
  String notifMinutesAgo(int n) {
    return 'منذ $n د';
  }

  @override
  String get notifNoLongerAssigned => 'هذا المريض لم يعد مُسندًا إليك.';

  @override
  String get notifNothingRecorded => 'لم يُسجَّل أي تمرين في ذلك اليوم.';

  @override
  String get notifOpenConversation => 'فتح المحادثة';

  @override
  String get notifOpenExercise => 'فتح التمرين';

  @override
  String get notifOpenPatient => 'فتح ملف المريض';

  @override
  String notifPainBodyDuring(String exercise) {
    return '$exercise · أُبلغ عنه أثناء التمرين';
  }

  @override
  String notifPainBodyLevel(String exercise, int level) {
    return '$exercise · ألم $level/10';
  }

  @override
  String get notifPainDuringSet => 'أُبلغ عنه أثناء التمرين';

  @override
  String notifPainEvent(String time, String source) {
    return 'عند $time من المجموعة، $source';
  }

  @override
  String get notifPainNoRating => 'لم يُعطَ تقييم بعد';

  @override
  String get notifPainRating => 'تقييم الألم';

  @override
  String notifPainTitle(String name) {
    return 'أبلغ $name عن ألم';
  }

  @override
  String get notifPatientNotes => 'ملاحظات المريض';

  @override
  String get notifPatientReportOnly =>
      'هذا بلاغ المريض نفسه، وليس تشخيصًا طبيًا.';

  @override
  String notifPatientWords(String words) {
    return 'قال المريض: \"$words\"';
  }

  @override
  String get notifPrefInactivity => 'لم يُنجَز أي تمرين';

  @override
  String get notifPrefInactivityHint =>
      'كان على المريض تمارين ولم يسجّل أيًّا منها في ذلك اليوم (يُفحص كل ليلة)';

  @override
  String get notifPrefIncorrect => 'تكرارات غير صحيحة في معظمها';

  @override
  String get notifPrefIncorrectHint =>
      'ما لا يقل عن 90٪ من التكرارات المُقيَّمة في مجموعة كانت غير صحيحة (8 أو أكثر مُقيَّمة)';

  @override
  String get notifPrefMessageHint => 'يرسل لك مريض رسالة';

  @override
  String get notifPrefPainHint =>
      'يبلغ مريض عن ألم أثناء تمرين، أو يقيّمه بـ 4/10 أو أكثر';

  @override
  String get notifPrefPainOffBody =>
      'لن يتم إبلاغك بعد الآن عندما يبلغ مريض عن ألم. تبقى البلاغات في سجل تقدمه.';

  @override
  String get notifPrefPainOffTitle => 'إيقاف تنبيهات الألم؟';

  @override
  String get notifPrefTurnOff => 'إيقاف';

  @override
  String get notifPrescribed => 'التمارين الموصوفة حينها';

  @override
  String get notifReportedAt => 'تاريخ البلاغ';

  @override
  String notifRepsDone(int reps) {
    return '$reps تكرارات';
  }

  @override
  String get notifResolved => 'تمت المعالجة';

  @override
  String get notifResumedSince => 'عاد المريض إلى التمارين منذ ذلك الحين.';

  @override
  String notifRoutineBody(String exercise, int sets, int reps) {
    return '$exercise: $sets مجموعات × $reps تكرارات';
  }

  @override
  String get notifRoutineTitle => 'تم تحديث برنامج تمارينك';

  @override
  String get notifSetResult => 'نتيجة المجموعة';

  @override
  String notifSetsReps(int sets, int reps) {
    return '$sets × $reps';
  }

  @override
  String get notifSettingsIntro =>
      'اختر ما تريد أن تُبلَّغ به. النوع المعطَّل لا يُسجَّل إطلاقًا: إعادة تفعيله لا تعيد ما حدث في الأثناء.';

  @override
  String get notifSettingsTitle => 'إعدادات الإشعارات';

  @override
  String get notifSignedOut =>
      'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String notifTrackingConfirmed(int judged) {
    return 'تم تقييم جميع التكرارات ($judged) بتتبع موثوق.';
  }

  @override
  String notifTrackingPartly(int unsure) {
    return '$unsure تكرار(ات) لم تتمكن الكاميرا من تقييمها بشكل موثوق ولا تُحتسب في هذا التنبيه.';
  }

  @override
  String get notifUnavailable => 'هذا العنصر لم يعد متاحًا.';

  @override
  String notifUnreadCount(int count) {
    return '$count غير مقروءة';
  }

  @override
  String get notifUnsureReps => 'غير مُقيَّمة';

  @override
  String get notifUrgent => 'عاجل';

  @override
  String get notifYesterday => 'أمس';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get notificationsComingSoon => 'تفضيلات الإشعارات ستتوفر قريبًا.';

  @override
  String get ok => 'حسنًا';

  @override
  String get onboardingAudience => 'مصمَّم للمرضى وأخصائيي العلاج الطبيعي';

  @override
  String get onboardingCardHelper => 'صُمِّم لجلسات تأهيل يومية أكثر أمانًا';

  @override
  String get onboardingEyebrow1 => 'ذكاء الحركة';

  @override
  String get onboardingEyebrow2 => 'تعافٍ موجَّه';

  @override
  String get onboardingEyebrow3 => 'تواصل مع أخصائي العلاج الطبيعي';

  @override
  String get onboardingFooter =>
      'تابع تمارينك وراقب تقدمك وابقَ على تواصل مع أخصائي العلاج الطبيعي الخاص بك في تطبيق واحد آمن.';

  @override
  String get onboardingHeadline => 'تعافَ بذكاء،\nوتحرّك بثقة.';

  @override
  String get onboardingIntro =>
      'إرشاد شخصي بالذكاء الاصطناعي لتمارين إعادة التأهيل ومتابعة التقدم والتعاون مع أخصائي العلاج الطبيعي.';

  @override
  String get onboardingSubtitle1 =>
      'تقنية متقدمة لتقدير وضعية الجسم تساعد المرضى على أداء كل تمرين بشكل أكثر أمانًا ودقة.';

  @override
  String get onboardingSubtitle2 =>
      'احصل على توجيهات تصحيحية واضحة وملاحظات تعزز ثقتك أثناء اتباع خطة إعادة التأهيل.';

  @override
  String get onboardingSubtitle3 =>
      'شارك تقدمك عن بُعد ليتمكن أخصائي العلاج الطبيعي من متابعة تعافيك وتخصيص خطواتك القادمة.';

  @override
  String get onboardingTitle1 => 'تحليل الحركة بالذكاء الاصطناعي';

  @override
  String get onboardingTitle2 => 'تصحيح فوري للوضعية';

  @override
  String get onboardingTitle3 => 'على اتصال بأخصائي العلاج الطبيعي';

  @override
  String oneSet(String count) {
    return '$count مجموعة';
  }

  @override
  String get openDoc => 'فتح المستند';

  @override
  String get overview => 'نظرة عامة';

  @override
  String get painLevel => 'مستوى الألم';

  @override
  String get painLevelLower => 'مستوى الألم';

  @override
  String painOutOfTen(String pain) {
    return '$pain/10';
  }

  @override
  String painOutOfTenSpaced(String pain) {
    return '$pain / 10';
  }

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordMinLength =>
      'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل';

  @override
  String get patient => 'مريض';

  @override
  String get patientChat => 'محادثة المريض';

  @override
  String get patientComplaints => 'شكاوى المرضى';

  @override
  String get patientProgress => 'تقدّم المريض';

  @override
  String get patients => 'المرضى';

  @override
  String get payMonthlyWithStripe => 'ادفع الاشتراك الشهري عبر Stripe';

  @override
  String get payYearlyWithStripe => 'ادفع الاشتراك السنوي عبر Stripe';

  @override
  String get payloadPreview =>
      'معاينة البيانات (جاهزة للإرسال إلى نموذج الذكاء الاصطناعي):';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get pendingClinics => 'العيادات قيد الانتظار';

  @override
  String percentValue(String percent) {
    return '$percent%';
  }

  @override
  String get phone => 'الهاتف';

  @override
  String get phoneRequired => 'رقم الهاتف مطلوب';

  @override
  String phoneValue(String phone) {
    return 'الهاتف: $phone';
  }

  @override
  String get physioAiBanner => 'لوحة Kinex AI Rehab لمتابعة أذكى للمرضى.';

  @override
  String get physioHome => 'الصفحة الرئيسية للمعالج';

  @override
  String get physioProfile => 'الملف الشخصي للمعالج';

  @override
  String get physiotherapist => 'أخصائي العلاج الطبيعي';

  @override
  String get physiotherapists => 'أخصائيو العلاج الطبيعي';

  @override
  String get pleaseEnterEmail => 'يرجى إدخال بريدك الإلكتروني';

  @override
  String get pleaseEnterPassword => 'يرجى إدخال كلمة المرور';

  @override
  String get premiumActive => 'الاشتراك المميز مفعّل';

  @override
  String get premiumActiveCheck => 'الاشتراك المميز مفعّل ✅';

  @override
  String get premiumLockedDescription =>
      'افتح تسجيل الفيديو مع تحليل الذكاء الاصطناعي والميزات المميزة لمرضاك.';

  @override
  String get premiumUnlockedDescription =>
      'رفع الفيديو وتحليل الذكاء الاصطناعي متاحان لمرضاك.';

  @override
  String get preparingExercise => 'جارٍ تجهيز التمرين...';

  @override
  String pricingMonthlyLine(String count, String total) {
    return 'شهري = 5.00 + (0.10 × $count) = $total يورو';
  }

  @override
  String pricingPatientsLine(String count) {
    return 'عدد المرضى: $count';
  }

  @override
  String pricingYearlyLine(String count, String total) {
    return 'سنوي = 50.00 + (0.10 × $count) = $total يورو';
  }

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get profilePhotoUpdated => 'تم تحديث صورة الملف الشخصي.';

  @override
  String get profileUpdatedSuccessfully => 'تم تحديث الملف الشخصي بنجاح.';

  @override
  String get progress => 'التقدّم';

  @override
  String progressReps(String current, String total) {
    return 'التقدّم: $current / $total تكرارات';
  }

  @override
  String progressRepsOf(String done, String target) {
    return 'التقدّم: $done$target تكرارات';
  }

  @override
  String get recordingLockedSubscription => 'التسجيل مقفل (يتطلب اشتراكًا)';

  @override
  String get refresh => 'تحديث';

  @override
  String get registerYourClinic => 'سجّل عيادتك';

  @override
  String get registrationFailed => 'فشل التسجيل';

  @override
  String get reject => 'رفض';

  @override
  String get repLabelBelowTarget => 'وضعية جيدة – أقل من المدى المستهدف';

  @override
  String get repLabelGood => 'جيد';

  @override
  String get repLabelKnee => 'ثني الركبة';

  @override
  String get repLabelLeanin => 'ميل نحو الرجل المرفوعة';

  @override
  String get repLabelLeanout => 'ميل بعيدًا عن الرجل المرفوعة';

  @override
  String get repLabelUnsure => 'غير متأكد';

  @override
  String get repLabelWrongSide => 'الجهة الخطأ – لا يُحتسب';

  @override
  String reportBelowTarget(int count) {
    return '$count تكرار(ات) صحيحة أقل من الهدف.';
  }

  @override
  String reportDiscomfort(String time) {
    return 'قال المريض إنه غير مرتاح عند $time. تم إيقاف المجموعة.';
  }

  @override
  String reportMistakes(String list) {
    return 'الأخطاء: $list.';
  }

  @override
  String reportNotes(String exercise, String arm, int judged, int good) {
    return 'مجموعة بالكاميرا - $exercise (الذراع $arm): $judged تكرارات مقيّمة، $good صحيحة.';
  }

  @override
  String reportNotesLeg(String exercise, String leg, int judged, int good) {
    return 'سلسلة بالكاميرا - $exercise (الرجل $leg): $judged تكرار مُقيَّم، $good جيد.';
  }

  @override
  String reportPainEvent(String time, String source) {
    return 'ألم أبلغ عنه المريض عند $time ($source) - بلاغ من المريض وليس تشخيصًا طبيًا. تم إيقاف المجموعة.';
  }

  @override
  String get reportSourceButton => 'بالزر';

  @override
  String get reportSourceVoice => 'بالصوت';

  @override
  String reportUnsure(int count) {
    return '$count غير مؤكدة.';
  }

  @override
  String reportWrongSide(int count) {
    return '$count تكرار(ات) بالجهة الخطأ، لم تُحتسب.';
  }

  @override
  String get reps => 'التكرارات';

  @override
  String repsBullet(String count) {
    return '• $count تكرارات';
  }

  @override
  String get repsCompleted => 'التكرارات المنجزة';

  @override
  String repsCount(String count) {
    return '$count تكرارات';
  }

  @override
  String get repsDone => 'تكرارات منجزة';

  @override
  String get requestSent => 'تم إرسال الطلب';

  @override
  String get required => 'مطلوب';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get role => 'الدور';

  @override
  String get roleAdmin => 'مسؤول';

  @override
  String get save => 'حفظ';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get saveProfile => 'حفظ الملف الشخصي';

  @override
  String get saveProfileLower => 'حفظ الملف الشخصي';

  @override
  String scoreValue(String score) {
    return 'النتيجة: $score';
  }

  @override
  String get searchAccountsByName => 'ابحث في الحسابات بالاسم فقط';

  @override
  String get searchClinics =>
      'ابحث في العيادات (الاسم، البريد، الهاتف، المعرّف)';

  @override
  String get searchMembers => 'ابحث عن مريض / أخصائي علاج طبيعي';

  @override
  String get searchPendingClinics =>
      'ابحث في العيادات قيد الانتظار (الاسم، البريد، الهاتف، المعرّف)';

  @override
  String get selectBirthDate => 'اختر تاريخ الميلاد';

  @override
  String get selectExerciseAndValidSetsReps =>
      'اختر تمرينًا وأدخل عددًا صحيحًا للمجموعات/التكرارات.';

  @override
  String get send => 'إرسال';

  @override
  String get sendComplaint => 'إرسال الشكوى';

  @override
  String sessionBelowTargetShort(int count) {
    return '$count أقل من الهدف';
  }

  @override
  String get sessionFeedbackTitle => 'ملاحظات الحصة';

  @override
  String sessionGoodShort(int count) {
    return '$count جيدة';
  }

  @override
  String get sessionHistory => 'سجل الجلسات';

  @override
  String get sessionManualReport => 'مُدخل يدويًا (بدون سلسلة بالكاميرا)';

  @override
  String sessionMistakesShort(int count) {
    return '$count للتصحيح';
  }

  @override
  String get sessionNoRepDetail =>
      'تفاصيل كل تكرار غير متوفرة لهذه السلسلة (سُجِّلت قبل التحديث).';

  @override
  String get sessionNoSets => 'لم تُسجَّل أي سلسلة بالكاميرا لهذه الحصة.';

  @override
  String get sessionNotes => 'ملاحظات';

  @override
  String get sessionOpenFeedback => 'ملاحظات الذكاء الاصطناعي';

  @override
  String get sessionPainDuring => 'تم الإبلاغ عن ألم أثناء السلسلة';

  @override
  String sessionPainLevel(String pain) {
    return 'الألم $pain/10';
  }

  @override
  String sessionScore(int percent) {
    return '$percent % جيدة';
  }

  @override
  String sessionSetTitle(int number, String time) {
    return 'السلسلة $number · $time';
  }

  @override
  String sessionWrongSideShort(int count) {
    return '$count بالجهة الخطأ';
  }

  @override
  String sessionsLogged(String count) {
    return '$count جلسات مسجّلة';
  }

  @override
  String get sets => 'المجموعات';

  @override
  String get setsCompleted => 'المجموعات المنجزة';

  @override
  String setsCount(String count) {
    return '$count مجموعات';
  }

  @override
  String get setsDoneLower => 'مجموعات منجزة';

  @override
  String setsTimesReps(String sets, String reps) {
    return '$sets مجموعات × $reps تكرارات';
  }

  @override
  String get settings => 'الإعدادات';

  @override
  String shortDate(String day, String month, String year) {
    return '$day $month $year';
  }

  @override
  String get signInToYourAccount => 'سجّل الدخول إلى حسابك';

  @override
  String get specialization => 'التخصص';

  @override
  String get srvAccountDeleted => 'تم حذف الحساب';

  @override
  String get srvAccountNotFound => 'الحساب غير موجود';

  @override
  String get srvAccountUpdated => 'تم تحديث الحساب';

  @override
  String get srvAdminNotDeletable => 'لا يمكن حذف حسابات المسؤولين';

  @override
  String get srvAdminRequired => 'يتطلب صلاحيات المسؤول';

  @override
  String get srvAiFeedbackSubscription =>
      'تحليل الذكاء الاصطناعي متاح فقط مع اشتراك عيادة مفعّل';

  @override
  String get srvAiVideoUploaded => 'تم رفع فيديو تحليل الذكاء الاصطناعي بنجاح';

  @override
  String get srvAssignmentNotFound => 'تعيين التمرين للمريض غير موجود';

  @override
  String get srvCannotDeleteSelf => 'لا يمكنك حذف حساب المسؤول الخاص بك';

  @override
  String get srvClinicApproved => 'تمت الموافقة على العيادة';

  @override
  String get srvClinicDeleted => 'تم حذف العيادة';

  @override
  String get srvClinicMovedToWaiting => 'أُعيدت العيادة إلى حالة الانتظار';

  @override
  String get srvClinicMustBeApproved =>
      'يجب الموافقة على حساب العيادة قبل استخدام هذه الميزة';

  @override
  String get srvClinicNameMin => 'يجب أن يتكون اسم العيادة من 3 أحرف على الأقل';

  @override
  String get srvClinicProfileNotFound => 'ملف العيادة غير موجود';

  @override
  String get srvClinicProfileUpdated => 'تم تحديث ملف العيادة بنجاح';

  @override
  String get srvClinicRegistered =>
      'تم تسجيل العيادة. في انتظار موافقة المسؤول.';

  @override
  String get srvClinicUpdated => 'تم تحديث العيادة';

  @override
  String get srvComplaintSubmitted => 'تم إرسال الشكوى بنجاح';

  @override
  String get srvDescriptionMin => 'يجب أن يتكون الوصف من 5 أحرف على الأقل';

  @override
  String get srvEmailExists => 'البريد الإلكتروني مستخدم بالفعل';

  @override
  String get srvEmailPasswordRequired =>
      'البريد الإلكتروني وكلمة المرور مطلوبان';

  @override
  String get srvExerciseAssigned => 'تم تعيين التمرين بنجاح';

  @override
  String get srvExerciseCompletedSaved => 'اكتمل التمرين وتم حفظ التقدّم';

  @override
  String get srvExerciseNotFound => 'التمرين غير موجود';

  @override
  String get srvExerciseRemoved => 'تمت إزالة التمرين بنجاح';

  @override
  String get srvInvalidPassword => 'كلمة المرور غير صحيحة';

  @override
  String get srvInvalidPhoneNumber => 'رقم الهاتف غير صحيح';

  @override
  String get srvJustifRequired => 'ملف الإثبات مطلوب';

  @override
  String get srvJustifSize => 'يجب ألا يتجاوز حجم ملف الإثبات 8 ميغابايت';

  @override
  String get srvJustifType => 'يجب أن يكون ملف الإثبات بصيغة PDF/JPG/PNG';

  @override
  String get srvJustifUploadFailed => 'فشل رفع ملف الإثبات';

  @override
  String get srvMemberNotFound => 'العضو غير موجود في عيادتك';

  @override
  String get srvMessageContentRequired => 'محتوى الرسالة مطلوب';

  @override
  String get srvMessageSent => 'تم إرسال الرسالة بنجاح';

  @override
  String get srvNameMin => 'يجب أن يتكون الاسم من حرفين على الأقل';

  @override
  String get srvNoAccountForEmail => 'لا يوجد حساب بهذا البريد الإلكتروني';

  @override
  String get srvNoPhysioAssigned => 'لم يُعيَّن لك معالج بعد';

  @override
  String get srvPatientCreated => 'تم إنشاء حساب المريض بنجاح';

  @override
  String get srvPatientDeleted => 'تم حذف المريض بنجاح';

  @override
  String get srvPatientNotAssignedToPhysio =>
      'هذا المريض غير معيَّن لهذا المعالج';

  @override
  String get srvPatientNotAssignedToPhysio2 =>
      'هذا المريض غير معيَّن لهذا المعالج';

  @override
  String get srvPatientProfileNotFound => 'ملف المريض غير موجود';

  @override
  String get srvPaymentConfirmed => 'تم تأكيد الدفع. تم تفعيل الاشتراك بنجاح.';

  @override
  String get srvPaymentNotCompleted =>
      'لم يكتمل الدفع بعد. أكمل عملية الدفع وحاول مرة أخرى.';

  @override
  String get srvPaymentRefNotFound => 'مرجع الدفع غير موجود لهذه العيادة';

  @override
  String get srvPhotoType => 'يجب أن تكون الصورة بصيغة JPG/PNG/WEBP';

  @override
  String get srvPhotoUploaded => 'تم رفع الصورة بنجاح';

  @override
  String get srvPhysioNotFound => 'المعالج غير موجود';

  @override
  String get srvPhysioProfileNotFound => 'ملف المعالج غير موجود';

  @override
  String get srvPremiumForVideo => 'يتطلب رفع الفيديو اشتراكًا مميزًا';

  @override
  String get srvProfileUpdated => 'تم تحديث الملف الشخصي بنجاح';

  @override
  String get srvProgressSaved => 'تم حفظ تقرير التقدّم';

  @override
  String get srvSetsRepsPositive =>
      'يجب أن تكون المجموعات والتكرارات أكبر من 0';

  @override
  String get srvStripeCheckoutReady =>
      'صفحة الدفع عبر Stripe جاهزة. أكمل الدفع ثم اضغط على تحقّق.';

  @override
  String get srvTherapistCreated => 'تم إنشاء حساب أخصائي العلاج الطبيعي بنجاح';

  @override
  String get srvTherapistDeleted => 'تم حذف أخصائي العلاج الطبيعي بنجاح';

  @override
  String get srvUnsupportedVideo => 'صيغة الفيديو غير مدعومة';

  @override
  String get srvWaitingForApproval => 'في انتظار الموافقة';

  @override
  String get standardPlan => 'الخطة العادية';

  @override
  String get startExercise => 'ابدأ التمرين';

  @override
  String get statsOverview => 'نظرة عامة على الإحصاءات';

  @override
  String statusValue(String status) {
    return 'الحالة: $status';
  }

  @override
  String get submitComplaint => 'تقديم شكوى';

  @override
  String get submitForApproval => 'إرسال للموافقة';

  @override
  String get subscription => 'الاشتراك';

  @override
  String get subscriptionActiveAiAvailable =>
      'الاشتراك مفعّل: تحليل الذكاء الاصطناعي متاح.';

  @override
  String get subscriptionActiveAiUnlocked =>
      'اشتراك العيادة مفعّل - تحليل الذكاء الاصطناعي متاح';

  @override
  String get subscriptionInactiveAiHidden =>
      'الاشتراك غير مفعّل: تحليل الذكاء الاصطناعي مخفي.';

  @override
  String get subscriptionInactiveAiLocked =>
      'اشتراك العيادة غير مفعّل - تحليل الذكاء الاصطناعي مقفل';

  @override
  String get success => 'تم بنجاح';

  @override
  String get summaryBelowTarget => 'وضعية جيدة، أقل من الهدف';

  @override
  String get summaryEveryRep => 'كل التكرارات';

  @override
  String get summaryGoodReps => 'تكرارات صحيحة';

  @override
  String get summaryMistakes => 'الأخطاء';

  @override
  String get summaryNoMistakes => 'لا توجد أخطاء، أحسنت!';

  @override
  String get summaryNoneScored => 'لم يتم تقييم أي تكرار.';

  @override
  String get summaryNotSent => 'لم يُرسل';

  @override
  String summaryNotSentError(String error) {
    return 'لم يُرسل: $error';
  }

  @override
  String get summaryPainQuestion =>
      'ما مدى الألم الذي شعرت به؟ (0 = لا ألم، 10 = أسوأ ألم)';

  @override
  String get summaryPainReported =>
      'أبلغت عن ألم أثناء هذه المجموعة. سيطّلع عليه أخصائي العلاج الطبيعي.';

  @override
  String summaryPeak(int deg, int target) {
    return 'رفع الرجل: الوسيط $deg° (الهدف $target°)';
  }

  @override
  String get summaryRepsCounted => 'تكرارات محسوبة';

  @override
  String get summaryRepsScored => 'تكرارات مقيّمة';

  @override
  String get summarySending => 'جارٍ الإرسال إلى أخصائي العلاج الطبيعي...';

  @override
  String get summarySent => 'تم الحفظ والإرسال إلى أخصائي العلاج الطبيعي';

  @override
  String get summaryTitle => 'ملخص المجموعة';

  @override
  String get summaryTryAgain => 'أعد المحاولة';

  @override
  String summaryUnsure(int count) {
    return '$count تكرار(ات) لم يتم تقييمها بثقة.';
  }

  @override
  String summaryWrongSideArm(int count) {
    return '$count تكرار(ات) بالذراع الأخرى لم تُحتسب.';
  }

  @override
  String summaryWrongSideLeg(int count) {
    return '$count تكرار(ات) بالرجل الأخرى لم تُحتسب.';
  }

  @override
  String get switchToDarkMode => 'التبديل إلى الوضع الداكن';

  @override
  String get switchToLightMode => 'التبديل إلى الوضع الفاتح';

  @override
  String get symptomsOptional => 'الأعراض (اختياري)';

  @override
  String symptomsValue(String symptoms) {
    return 'الأعراض: $symptoms';
  }

  @override
  String get tapButtonToAddMember => 'اضغط على الزر أدناه لإضافة عضو.';

  @override
  String get tapToStartLogging => 'اضغط أدناه لبدء تسجيل تقدّمك';

  @override
  String get tapToUploadDocument => 'اضغط للرفع (PDF/JPG/PNG)';

  @override
  String targetReps(String reps) {
    return 'الهدف: $reps تكرارات';
  }

  @override
  String targetSetsReps(String total, String reps, String sets) {
    return 'الهدف: $sets مجموعات × $reps تكرارات = $total تكرارًا إجمالًا';
  }

  @override
  String get therapistChat => 'محادثة أخصائي العلاج الطبيعي';

  @override
  String therapistValue(String name) {
    return 'أخصائي العلاج الطبيعي: $name';
  }

  @override
  String get therapists => 'أخصائيو العلاج الطبيعي';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get thisWeeksActivity => 'نشاط هذا الأسبوع';

  @override
  String get today => 'اليوم';

  @override
  String get todayUpper => 'اليوم';

  @override
  String get todaysExercises => 'تمارين اليوم';

  @override
  String get todaysPlan => 'خطة اليوم';

  @override
  String get toggleTheme => 'تبديل المظهر';

  @override
  String get totalRepsCompleted => 'إجمالي التكرارات المنجزة';

  @override
  String get trackedArmLeft => 'اليسرى';

  @override
  String get trackedArmRight => 'اليمنى';

  @override
  String get trackedE1 => 'رفع الذراعين إلى الأمام بعصا (الذراعان)';

  @override
  String get trackedE2 => 'إبعاد الذراع (ذراع واحدة)';

  @override
  String get trackedE3 => 'تدوير الذراع والمرفق بجانب الجسم (ذراع واحدة)';

  @override
  String get trackedE4 => 'تبعيد الورك وقوفًا (رجل واحدة)';

  @override
  String get trackedInjuredArm => 'الذراع المصابة';

  @override
  String get trackedLabel => 'المتابعة المباشرة بالكاميرا';

  @override
  String get trackedLiftedLeg => 'الرجل المرفوعة';

  @override
  String get trackedNone => 'بدون متابعة مباشرة';

  @override
  String trackedSummary(String exercise, String arm) {
    return '$exercise · الذراع $arm';
  }

  @override
  String trackedSummaryLeg(String exercise, String leg) {
    return '$exercise · الرجل $leg';
  }

  @override
  String get trackedTargetAngle => 'زاوية الرفع المستهدفة (°)';

  @override
  String trackedTargetAngleHelp(String percent, String deg) {
    return 'زاوية الرجل بعيدًا عن الجسم في أعلى الرفع. اتركه فارغًا لاستعمال $percent % من الرفع المعتاد للمريض (أو الزاوية الافتراضية $deg° إلى أن يُعرف).';
  }

  @override
  String get trackedTargetAngleInvalid =>
      'أدخل زاوية بين 5 و 90°، أو اتركه فارغًا';

  @override
  String trackedTargetShort(String deg) {
    return 'الهدف $deg°';
  }

  @override
  String get trackedWorkingArm => 'الذراع التي تؤدي التمرين';

  @override
  String get trackingNotSet =>
      'لم يقم أخصائي العلاج الطبيعي بإعداد المتابعة بالكاميرا لهذا التمرين بعد.';

  @override
  String get truncated => '...مقتطع...';

  @override
  String get typeYourMessage => 'اكتب رسالتك...';

  @override
  String unableToOpenCamera(String error) {
    return 'تعذّر فتح الكاميرا: $error';
  }

  @override
  String get unableToOpenDocument => 'تعذّر فتح المستند.';

  @override
  String get unassigned => 'غير معيَّن';

  @override
  String get unknownError => 'خطأ غير معروف';

  @override
  String get unnamedAccount => 'حساب بدون اسم';

  @override
  String get updateProgress => 'تحديث التقدّم';

  @override
  String get upgradeToPremium => 'الترقية إلى الاشتراك المميز';

  @override
  String get uploadJustificationPrompt => 'يرجى رفع ملف إثبات العيادة.';

  @override
  String get useRegisteredCredentials =>
      'استخدم بريدك الإلكتروني وكلمة المرور المسجلين.';

  @override
  String get verifyStripePayment => 'التحقق من الدفع عبر Stripe';

  @override
  String get video => 'فيديو';

  @override
  String get videoRecordingLocked =>
      'تسجيل الفيديو مقفل: اشتراك العيادة غير مفعّل.';

  @override
  String get viewComplaints => 'عرض الشكاوى';

  @override
  String get viewDocument => 'عرض المستند';

  @override
  String get voiceAlreadyRunning => 'التمرين جارٍ بالفعل.';

  @override
  String get voiceHelp =>
      'يمكنك أن تقول: أعد، لم أفهم، توقف، استمر، مساعدة، أو أشعر بألم.';

  @override
  String get voiceLanguageFallback =>
      'الصوت غير متوفر بلغتك على هذا الهاتف: سيتم استخدام الإنجليزية.';

  @override
  String voiceMilestone(int count) {
    return 'أكملت $count تكرارات.';
  }

  @override
  String get voiceNotUnderstood => 'عذرًا، لم أفهم. قل مساعدة لسماع الأوامر.';

  @override
  String get voiceNothingToRepeat => 'لا توجد تعليمات لإعادتها بعد.';

  @override
  String get voicePainClarify =>
      'أوقفت التمرين احتياطًا. هل تشعر بألم الآن؟ إذا كان الجواب نعم، قل: أشعر بألم، أو اضغط على زر أشعر بألم.';

  @override
  String get voicePainHoldRefuse =>
      'يبقى التمرين متوقفًا لأنك أبلغت عن ألم. يُرجى اتباع إرشادات أخصائي العلاج الطبيعي.';

  @override
  String get voicePainResponse =>
      'فهمت أنك تشعر بألم. تم إيقاف التمرين. يُرجى اتباع إرشادات أخصائي العلاج الطبيعي قبل المتابعة.';

  @override
  String get voicePaused =>
      'التمرين متوقف مؤقتًا. اضغط على استئناف عندما تكون مستعدًا.';

  @override
  String get voiceResumed => 'لنواصل. ابقَ ثابتًا أولًا.';

  @override
  String get voiceSetDone => 'انتهت المجموعة. أحسنت.';

  @override
  String get voiceStandStill => 'ابقَ ثابتًا لمدة ثانيتين.';

  @override
  String voiceStart(String exercise) {
    return 'يمكنك البدء: $exercise.';
  }

  @override
  String get voiceStepBack => 'من فضلك ابتعد قليلًا حتى يظهر جسمك بالكامل.';

  @override
  String get voiceStepBackFeet =>
      'ارجع إلى الخلف حتى ترى الكاميرا جسمك كاملًا بما في ذلك القدمين';

  @override
  String get voiceTtsUnavailable =>
      'الملاحظات الصوتية غير متوفرة على هذا الهاتف.';

  @override
  String get voiceUncomfortable =>
      'أوقفت التمرين مؤقتًا. هل تشعر بألم؟ إذا كان الجواب نعم، قل: أشعر بألم، أو اضغط على زر أشعر بألم.';

  @override
  String get weekdayInitials => 'ن,ث,ر,خ,ج,س,ح';

  @override
  String get weekdayShortNames => 'اثن,ثلا,أرب,خمي,جمع,سبت,أحد';

  @override
  String weeklyGoalPercent(String percent) {
    return '$percent% من الهدف الأسبوعي';
  }

  @override
  String get welcomeBack => 'مرحبًا بعودتك';

  @override
  String get yearly => 'سنوي';

  @override
  String get yearlyPricingNote => 'سنوي: 50 يورو + 0.10 يورو لكل مريض';
}

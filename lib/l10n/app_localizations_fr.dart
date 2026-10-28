// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get accountDeleted => 'Compte supprimé';

  @override
  String accountRoleActive(String active, String role) {
    return 'Rôle : $role | Actif : $active';
  }

  @override
  String get accounts => 'Comptes';

  @override
  String get addMember => 'Ajouter un membre';

  @override
  String get addNewMember => 'Ajouter un membre';

  @override
  String get address => 'Adresse';

  @override
  String get adminHome => 'Accueil administrateur';

  @override
  String get aiCoachBanner =>
      'Kinex AI Coach : un accompagnement de rééducation plus intelligent, chaque jour.';

  @override
  String get aiFeedback => 'Analyse IA';

  @override
  String aiFeedbackFor(String name) {
    return 'Analyse IA - $name';
  }

  @override
  String get all => 'Tout';

  @override
  String get allSetsDone => 'Toutes les séries sont faites ! ✓';

  @override
  String get approve => 'Approuver';

  @override
  String get armSideLeft => 'gauche';

  @override
  String get armSideRight => 'droit';

  @override
  String get assign => 'Assigner';

  @override
  String get assignExercise => 'Assigner un exercice';

  @override
  String get assignExerciseTitle => 'Assigner un exercice';

  @override
  String get assignedBy => 'Assigné par';

  @override
  String get assignedExercises => 'Exercices assignés';

  @override
  String get assignedPatients => 'Patients assignés';

  @override
  String get assignedPhysiotherapist => 'Kinésithérapeute assigné';

  @override
  String get assistantAndroidOnly =>
      'L\'assistant d\'exercice en direct fonctionne sur les téléphones Android.';

  @override
  String assistantArmLabel(String arm) {
    return 'Bras : $arm';
  }

  @override
  String get assistantCamera => 'Caméra';

  @override
  String get assistantCameraBack => 'Arrière';

  @override
  String get assistantCameraFront => 'Avant';

  @override
  String get assistantCameraNeeded =>
      'L\'accès à la caméra est nécessaire pour l\'assistant d\'exercice.';

  @override
  String get assistantDevSettings => 'Paramètres développeur';

  @override
  String get assistantFullResolution =>
      'Analyse en pleine résolution (1280 px)';

  @override
  String get assistantFullResolutionHint =>
      'Plus lent. Par défaut les images sont analysées à 640 px : mêmes repères, beaucoup moins de calcul.';

  @override
  String assistantInjuredArmLabel(String arm) {
    return 'Bras blessé : $arm';
  }

  @override
  String assistantLegLabel(String leg) {
    return 'Jambe levée : $leg';
  }

  @override
  String get assistantModel => 'Modèle';

  @override
  String get assistantModelMultitask => 'Réseau multi-tâches';

  @override
  String get assistantModelSeparate => 'Réseaux séparés';

  @override
  String get assistantPlacementTip =>
      'Posez le téléphone debout devant vous, à environ 2-3 m, pour que tout votre corps soit visible des genoux à la tête. Restez immobile 2 secondes quand on vous le demande, puis commencez.';

  @override
  String get assistantPlacementTipLeg =>
      'Posez le téléphone debout devant vous, à hauteur de hanche, à environ 2-3 m, pour que votre corps ENTIER soit visible, pieds compris. Mettez la chaise à côté de la jambe d\'appui et tenez-la. Restez immobile 2 secondes quand on vous le demande, puis commencez.';

  @override
  String get assistantSetByPhysio => 'choisi par votre kinésithérapeute';

  @override
  String get assistantShowTiming => 'Afficher les temps de calcul';

  @override
  String get assistantStartSet => 'Commencer la série';

  @override
  String assistantTargetLabel(String deg) {
    return 'Votre objectif : $deg°';
  }

  @override
  String get assistantTitle => 'Assistant d\'exercice';

  @override
  String get assistantUseGpu => 'Détection de pose sur le GPU (développeur)';

  @override
  String get assistantUseGpuHint =>
      'Plus rapide sur beaucoup de téléphones ; utilise le CPU sinon. La ligne de mesure indique lequel est utilisé.';

  @override
  String get assistantVoice => 'Assistant vocal';

  @override
  String get assistantVoiceOn => 'Instructions et corrections à voix haute';

  @override
  String get assistantVoiceRate => 'Vitesse de la voix';

  @override
  String get becomePartnerClinic => 'Devenez clinique partenaire';

  @override
  String get birthDate => 'Date de naissance';

  @override
  String get birthDateRequiredForPatients =>
      'La date de naissance est obligatoire pour les patients.';

  @override
  String get bodyRegionHip => 'Hanche';

  @override
  String get bodyRegionOther => 'Autres exercices';

  @override
  String get bodyRegionShoulder => 'Épaule';

  @override
  String get cancel => 'Annuler';

  @override
  String get changeLanguage => 'Changer de langue';

  @override
  String get clinic => 'Clinique';

  @override
  String get clinicComplaints => 'Réclamations de la clinique';

  @override
  String get clinicDashboard => 'Tableau de bord de la clinique';

  @override
  String get clinicEmail => 'E-mail de la clinique';

  @override
  String clinicMembersCount(String count) {
    return 'Membres de la clinique ($count)';
  }

  @override
  String get clinicName => 'Nom de la clinique';

  @override
  String get clinicOnlySignupNote =>
      'Seules les cliniques peuvent s\'inscrire ici. Les patients et les kinésithérapeutes sont créés depuis le tableau de bord de la clinique connectée.';

  @override
  String get clinicProfile => 'Profil de la clinique';

  @override
  String get clinicProfileSubtitle =>
      'Mettez à jour les informations et la photo de votre clinique.';

  @override
  String get clinicRegistration => 'Inscription de la clinique';

  @override
  String get clinicRegistrationIntro =>
      'Créez un compte clinique. Téléversez votre justificatif professionnel afin que l\'administrateur puisse valider rapidement votre inscription.';

  @override
  String clinicValue(String name) {
    return 'Clinique : $name';
  }

  @override
  String get clinics => 'Cliniques';

  @override
  String comingSoon(String title) {
    return '$title bientôt disponible';
  }

  @override
  String get complaintSentSuccessfully => 'Réclamation envoyée avec succès.';

  @override
  String get complaints => 'Réclamations';

  @override
  String get completeLabel => 'Terminé';

  @override
  String get completed => 'Terminé';

  @override
  String completedOfAssigned(String completed, String assigned) {
    return '$completed terminés / $assigned assignés';
  }

  @override
  String completedRepsOf(String done, String target) {
    return 'Terminé – $done$target répétitions ✓';
  }

  @override
  String get continueLabel => 'Continuer';

  @override
  String get continueToLogin => 'Continuer vers la connexion';

  @override
  String get createMember => 'Créer le membre';

  @override
  String get dailyCompletionPercent => 'Taux de réalisation quotidien %';

  @override
  String dateAtTime(String time, String date) {
    return '$date à $time';
  }

  @override
  String dateValue(String date) {
    return 'Date : $date';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String deleteAccountConfirm(String id, String label) {
    return 'Supprimer « $label » (ID : $id) ?';
  }

  @override
  String get deleteMember => 'Supprimer le membre';

  @override
  String deleteMemberConfirm(String name, String role) {
    return 'Supprimer $role « $name » de cette clinique ?';
  }

  @override
  String get describeYourComplaint => 'Décrivez votre réclamation';

  @override
  String get description => 'Description';

  @override
  String get descriptionRequired => 'La description est obligatoire';

  @override
  String get documentAttached => 'Document joint';

  @override
  String get done => 'Terminé';

  @override
  String get e4ProgressEmpty =>
      'Aucune série d\'abduction de hanche enregistrée.';

  @override
  String e4ProgressGoodShare(int percent) {
    return 'Bonne posture : $percent %';
  }

  @override
  String get e4ProgressMedian => 'Levée médiane';

  @override
  String get e4ProgressPerClass => 'Répétitions par classe';

  @override
  String get e4ProgressTarget => 'Objectif';

  @override
  String get e4ProgressTitle => 'Abduction de hanche - amplitude dans le temps';

  @override
  String e4ProgressUsualLift(String deg) {
    return 'Levée habituelle : $deg°';
  }

  @override
  String get editInformation => 'Modifier les informations';

  @override
  String get editInformationTitle => 'Modifier les informations';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get email => 'E-mail';

  @override
  String get emailAddress => 'Adresse e-mail';

  @override
  String get emailHint => 'nom@exemple.com';

  @override
  String emailValue(String email) {
    return 'E-mail : $email';
  }

  @override
  String get enterValidEmail => 'Saisissez une adresse e-mail valide';

  @override
  String get enterValidNumber => 'Saisissez un nombre valide';

  @override
  String get enterYourPassword => 'Saisissez votre mot de passe';

  @override
  String get error => 'Erreur';

  @override
  String get errorInvalidResponse => 'Format de réponse du serveur invalide';

  @override
  String errorServerStatus(String code) {
    return 'Erreur du serveur ($code).';
  }

  @override
  String get errorServerUnreachable =>
      'Impossible de joindre le serveur. Vérifiez votre connexion et réessayez.';

  @override
  String get errorTimeout => 'La requête a expiré. Veuillez réessayer.';

  @override
  String get exE1Desc =>
      'Tenez un bâton à deux mains, levez-le vers l\'avant et vers le haut, puis redescendez-le complètement.';

  @override
  String get exE1Simple =>
      'Tenez le bâton à deux mains. Levez-le doucement. Puis redescendez-le jusqu\'en bas.';

  @override
  String get exE1Title => 'Élévation antérieure avec un bâton';

  @override
  String get exE2Desc =>
      'Levez un bras tendu sur le côté, puis ramenez-le le long du corps.';

  @override
  String get exE2Simple =>
      'Gardez le bras tendu. Levez-le sur le côté. Puis redescendez-le.';

  @override
  String get exE2Title => 'Abduction du bras';

  @override
  String get exE3Desc =>
      'Gardez le coude contre le corps, plié à 90 degrés, et tournez l\'avant-bras vers l\'extérieur puis revenez.';

  @override
  String get exE3Simple =>
      'Gardez le coude contre vous. Tournez la main vers l\'extérieur. Puis revenez.';

  @override
  String get exE3Title => 'Rotation du bras, coude au corps';

  @override
  String get exE4Desc =>
      'Placez-vous face au téléphone, une chaise à côté de vous, tenue avec la main du côté de la jambe d\'appui. Levez l\'autre jambe sur le côté, genou tendu et tronc droit, puis redescendez-la en contrôlant. Levez-la seulement aussi haut que possible avec une bonne posture : votre kinésithérapeute fixe votre objectif.';

  @override
  String get exE4Simple =>
      'Tenez la chaise. Gardez le genou tendu. Levez la jambe sur le côté. Puis reposez-la doucement.';

  @override
  String get exE4Title => 'Abduction de hanche debout';

  @override
  String get exercise => 'Exercice';

  @override
  String exerciseAnalysisFailed(String error) {
    return 'Échec de l\'analyse de l\'exercice : $error';
  }

  @override
  String get exerciseAssigned => 'Exercice assigné';

  @override
  String get exerciseAssignedSuccessfully => 'Exercice assigné avec succès.';

  @override
  String get exerciseCompletedCheck => 'Exercice terminé ✓';

  @override
  String get exerciseDataReady => 'Données de l\'exercice prêtes';

  @override
  String get exercises => 'Exercices';

  @override
  String exercisesLoggedOf(String reported, String total) {
    return '$reported / $total exercices enregistrés';
  }

  @override
  String fbBelowTarget(int target, int reached) {
    return 'Bonne posture - levez la jambe un peu plus haut : objectif $target°, vous avez atteint $reached°';
  }

  @override
  String get fbBelowTargetSimple =>
      'Bien. Levez maintenant la jambe un peu plus haut.';

  @override
  String get fbE1Elb => 'Gardez les coudes tendus en levant le bâton';

  @override
  String get fbE1ElbSimple => 'Bras tendus. Ne pliez pas les coudes.';

  @override
  String fbE1Imb(String arm) {
    return 'Levez le bâton de façon égale : montez le bras $arm aussi haut que l\'autre';
  }

  @override
  String get fbE1ImbSimple => 'Montez les deux mains à la même hauteur.';

  @override
  String get fbE1Rngdown =>
      'Redescendez le bâton complètement entre les répétitions';

  @override
  String get fbE1RngdownSimple => 'Descendez jusqu\'en bas à chaque fois.';

  @override
  String get fbE2Elb => 'Gardez le coude tendu';

  @override
  String get fbE2ElbSimple => 'Bras tendu. Ne pliez pas le coude.';

  @override
  String get fbE2Lean =>
      'Gardez le tronc droit : ne vous penchez pas pour lever le bras';

  @override
  String get fbE2LeanSimple =>
      'Tenez-vous droit. Ne vous penchez pas sur le côté.';

  @override
  String get fbE2Rngdown =>
      'Ramenez le bras complètement le long du corps entre les répétitions';

  @override
  String get fbE2RngdownSimple =>
      'Redescendez le bras jusqu\'en bas à chaque fois.';

  @override
  String get fbE2Shld =>
      'Ne haussez pas l\'épaule : gardez-la basse pendant que le bras monte à hauteur d\'épaule';

  @override
  String get fbE2ShldSimple => 'Gardez l\'épaule basse et détendue.';

  @override
  String get fbE3Wrong => 'Gardez le coude contre le corps pendant la rotation';

  @override
  String get fbE3WrongSimple => 'Gardez le coude collé au corps.';

  @override
  String fbE4Knee(String leg) {
    return 'Gardez le genou $leg tendu pendant que vous levez la jambe';
  }

  @override
  String get fbE4KneeSimple => 'Genou tendu. Ne le pliez pas.';

  @override
  String get fbE4Leanin =>
      'Gardez le tronc droit - ne penchez pas vers la jambe que vous levez';

  @override
  String get fbE4LeaninSimple => 'Restez droit. Ne penchez pas vers la jambe.';

  @override
  String get fbE4Leanout =>
      'Gardez le tronc droit - ne penchez pas à l\'opposé de la jambe (vers la chaise)';

  @override
  String get fbE4LeanoutSimple =>
      'Restez droit. Ne penchez pas vers la chaise.';

  @override
  String get fbE4Unsure =>
      'Pas sûr de cette répétition - vérifiez que tout votre corps, pieds compris, est visible';

  @override
  String get fbE4UnsureSimple => 'Reculez pour que la caméra voie vos pieds.';

  @override
  String get fbGood => 'Bonne répétition, bravo';

  @override
  String get fbPartial =>
      'Répétition coupée au début ou à la fin - non évaluée';

  @override
  String get fbUnsure =>
      'Pas sûr pour cette répétition : vérifiez que tout votre corps est visible';

  @override
  String get fbUnsureSimple =>
      'Reculez pour que la caméra voie tout votre corps.';

  @override
  String fbWrongArm(String arm) {
    return 'Mauvais bras - passez au bras $arm : cette répétition ne compte pas';
  }

  @override
  String fbWrongArmSimple(String arm) {
    return 'Utilisez votre bras $arm.';
  }

  @override
  String fbWrongLeg(String leg) {
    return 'Mauvaise jambe - passez à la jambe $leg : cette répétition ne compte pas';
  }

  @override
  String fbWrongLegSimple(String leg) {
    return 'Levez votre jambe $leg.';
  }

  @override
  String framesAnalyzed(String count) {
    return 'Images analysées : $count';
  }

  @override
  String get fullName => 'Nom complet';

  @override
  String get hiPatient => 'Bonjour';

  @override
  String get history => 'Historique';

  @override
  String get home => 'Accueil';

  @override
  String get iPaidVerify => 'J\'ai payé — Vérifier mon paiement';

  @override
  String get invalidEmailFormat => 'Format d\'e-mail invalide';

  @override
  String get invalidPhoneFormat => 'Format de téléphone invalide';

  @override
  String get invalidVideoUrl => 'Lien vidéo invalide ou non pris en charge';

  @override
  String get justificationFile => 'Justificatif ';

  @override
  String get justificationReviewNote =>
      'Ce fichier est examiné par l\'administrateur avant l\'approbation du compte.';

  @override
  String keypointsExtracted(String count) {
    return 'Points clés extraits : $count';
  }

  @override
  String latestRepsDone(String reps) {
    return 'Dernier : $reps répétitions effectuées';
  }

  @override
  String get legSideLeft => 'gauche';

  @override
  String get legSideRight => 'droite';

  @override
  String get liveArmAngle => 'angle du bras';

  @override
  String liveArmMoving(String arm) {
    return 'Le bras $arm bouge : c\'est lui qui est évalué';
  }

  @override
  String liveCameraProblem(String error) {
    return 'Problème de caméra : $error';
  }

  @override
  String get liveDone => 'Terminé';

  @override
  String get liveFinishSet => 'Terminer la série';

  @override
  String get liveFinishing => 'Analyse des dernières répétitions...';

  @override
  String get liveLegAngle => 'angle de la jambe';

  @override
  String get livePainBody =>
      'Ne continuez pas cet exercice maintenant. Suivez les conseils de votre kinésithérapeute avant de reprendre. Votre signalement sera transmis à votre kinésithérapeute : il s\'agit de ce que vous avez signalé, pas d\'un diagnostic médical.';

  @override
  String get livePainTitle => 'En pause car vous avez signalé une douleur';

  @override
  String get livePause => 'Pause';

  @override
  String get livePausedBody =>
      'Appuyez sur Reprendre quand vous êtes prêt. Vous devrez rester immobile un instant avant de recommencer.';

  @override
  String get livePausedTitle => 'Exercice en pause';

  @override
  String get livePositioning =>
      'Reculez jusqu\'à ce que tout votre corps soit visible, des genoux à la tête';

  @override
  String liveRep(int n) {
    return 'Répétition $n';
  }

  @override
  String get liveReportPain => 'J\'ai mal';

  @override
  String get liveReps => 'répétitions';

  @override
  String get liveResume => 'Reprendre';

  @override
  String liveStandStill(int seconds) {
    return 'Restez immobile... $seconds';
  }

  @override
  String get liveStart => 'Commencez !';

  @override
  String get liveStarting => 'Démarrage de la caméra...';

  @override
  String liveWrongArm(String moving, String arm) {
    return 'Vous bougez le bras $moving - passez au bras $arm. Ces répétitions ne comptent pas.';
  }

  @override
  String liveWrongLeg(String moving, String leg) {
    return 'Vous levez la jambe $moving - passez à la jambe $leg. Ces répétitions ne comptent pas.';
  }

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get logProgress => 'Enregistrer la progression';

  @override
  String logProgressFor(String name) {
    return 'Enregistrer la progression – $name';
  }

  @override
  String get login => 'Se connecter';

  @override
  String get loginFailedTitle => 'Connexion impossible';

  @override
  String get loginIntro =>
      'Suivez votre rétablissement, bénéficiez de conseils d\'exercices plus intelligents et restez en contact avec votre kinésithérapeute.';

  @override
  String get loginSuccessBody => 'Bon retour dans votre espace Kinex.';

  @override
  String get loginSuccessTitle => 'Connexion réussie !';

  @override
  String get loginTagline => 'Poursuivez votre rééducation assistée par IA.';

  @override
  String get logout => 'Déconnexion';

  @override
  String logsCount(String count) {
    return '$count relevés';
  }

  @override
  String get manage => 'Gérer';

  @override
  String get manageDetailsAndClinic =>
      'Gérez vos informations et votre accès à la clinique.';

  @override
  String get manageProfileAndSupport =>
      'Gérez vos informations personnelles et vos options d\'assistance.';

  @override
  String get me => 'Moi';

  @override
  String get members => 'Membres';

  @override
  String get message => 'Message';

  @override
  String get micError =>
      'Erreur de commande vocale. Réessayez ou utilisez les boutons.';

  @override
  String micHeard(String text) {
    return 'Entendu : « $text »';
  }

  @override
  String get micListening => 'Je vous écoute...';

  @override
  String get micPermissionDenied =>
      'L\'accès au micro a été refusé. Autorisez-le dans les réglages du téléphone pour utiliser les commandes vocales.';

  @override
  String get micProcessing => 'Analyse...';

  @override
  String get micReady => 'Touchez le micro pour parler';

  @override
  String get micSpeaking => 'Je parle...';

  @override
  String get micTooltip => 'Micro';

  @override
  String get micUnavailable =>
      'Les commandes vocales ne sont pas disponibles sur ce téléphone. Utilisez les boutons.';

  @override
  String get minSixCharacters => '6 caractères minimum';

  @override
  String get minSixChars => '6 caractères min.';

  @override
  String get minThreeCharacters => '3 caractères minimum';

  @override
  String get monthNames =>
      'janvier,février,mars,avril,mai,juin,juillet,août,septembre,octobre,novembre,décembre';

  @override
  String get monthShortNames =>
      'janv.,févr.,mars,avr.,mai,juin,juil.,août,sept.,oct.,nov.,déc.';

  @override
  String monthYear(String month, String year) {
    return '$month $year';
  }

  @override
  String get monthly => 'Mensuel';

  @override
  String get monthlyPricingNote => 'Mensuel : 5 EUR + 0,10 EUR par patient';

  @override
  String get myPatients => 'Mes patients';

  @override
  String get myTherapist => 'Mon kinésithérapeute';

  @override
  String get name => 'Nom';

  @override
  String get nameAndPhoneRequired => 'Le nom et le téléphone sont obligatoires';

  @override
  String get nameRequired => 'Le nom est obligatoire';

  @override
  String get newPasswordOptional => 'Nouveau mot de passe (facultatif)';

  @override
  String get noAiFeedbackYet => 'Aucune analyse IA pour l\'instant.';

  @override
  String get noAssignedExercises => 'Aucun exercice assigné pour l\'instant.';

  @override
  String get noAssignedPatients => 'Aucun patient assigné pour l\'instant.';

  @override
  String get noAssignedTherapist => 'Aucun kinésithérapeute assigné';

  @override
  String get noAssignment => 'Aucune assignation';

  @override
  String get noComplaintsFound => 'Aucune réclamation trouvée.';

  @override
  String get noExerciseDescription =>
      'Aucune description disponible pour cet exercice.';

  @override
  String get noExerciseInCatalog =>
      'Aucun exercice disponible dans le catalogue.';

  @override
  String get noExercisesForDay => 'Aucun exercice pour le jour sélectionné.';

  @override
  String get noExercisesForFilter => 'Aucun exercice pour ce filtre.';

  @override
  String get noExercisesToday => 'Aucun exercice prévu pour aujourd\'hui.';

  @override
  String get noJustificationFile => 'Aucun justificatif disponible.';

  @override
  String get noMatchingAccounts => 'Aucun compte correspondant.';

  @override
  String get noMatchingClinics => 'Aucune clinique correspondante.';

  @override
  String get noMembersYet => 'Aucun membre pour l\'instant';

  @override
  String get noMessagesYet =>
      'Aucun message pour l\'instant. Commencez la conversation.';

  @override
  String get noPaymentReference =>
      'Aucune référence de paiement. Lancez d\'abord le paiement.';

  @override
  String get noPendingClinics => 'Aucune clinique en attente.';

  @override
  String get noProgressReportsForExercise =>
      'Aucun rapport de progression pour cet exercice.';

  @override
  String get noSets => 'Aucune série';

  @override
  String get notesOptional => 'Notes (facultatif)';

  @override
  String get notifAssistantNotes => 'Ce que l\'assistant a relevé';

  @override
  String get notifCategoryAll => 'Toutes';

  @override
  String get notifCategoryMessages => 'Messages';

  @override
  String get notifCategoryPain => 'Douleurs signalées';

  @override
  String get notifCategoryProgress => 'Progression';

  @override
  String get notifCategoryRoutine => 'Programme';

  @override
  String get notifCorrectReps => 'Correctes';

  @override
  String get notifDay => 'Jour';

  @override
  String get notifDetailTitle => 'Notification';

  @override
  String get notifDoneThatDay => 'Enregistré ce jour-là';

  @override
  String get notifDraftHint =>
      'Un message suggéré sera placé dans la zone de saisie. Rien n\'est envoyé avant que vous appuyiez sur Envoyer.';

  @override
  String notifDraftInactivity(String name, String date) {
    return 'Bonjour $name, je vois qu\'aucun exercice n\'a été enregistré le $date. Tout va bien ?';
  }

  @override
  String notifDraftIncorrect(String name, String exercise) {
    return 'Bonjour $name, j\'ai regardé votre série de $exercise : beaucoup de répétitions n\'étaient pas réalisées comme prévu. Revoyons le mouvement ensemble.';
  }

  @override
  String notifDraftPain(String name, String exercise) {
    return 'Bonjour $name, j\'ai vu que vous avez signalé une douleur pendant $exercise. Comment vous sentez-vous maintenant ?';
  }

  @override
  String get notifEmpty => 'Aucune notification pour le moment';

  @override
  String get notifEmptyCategory => 'Rien dans cette catégorie';

  @override
  String notifHoursAgo(int n) {
    return 'il y a $n h';
  }

  @override
  String notifInactivityBody(String date, int count) {
    return '$date · $count exercice(s) prescrit(s)';
  }

  @override
  String notifInactivityTitle(String name) {
    return '$name n\'a fait aucun exercice';
  }

  @override
  String notifIncorrectBody(String exercise, int mistakes, int judged) {
    return '$exercise · $mistakes sur $judged répétitions évaluées incorrectes';
  }

  @override
  String get notifIncorrectReps => 'Incorrectes';

  @override
  String notifIncorrectTitle(String name) {
    return '$name : la plupart des répétitions incorrectes';
  }

  @override
  String get notifJustNow => 'à l\'instant';

  @override
  String get notifLoadError =>
      'Impossible de charger les notifications. Vérifiez la connexion et réessayez.';

  @override
  String get notifLoadMore => 'Charger plus';

  @override
  String get notifMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notifMarkRead => 'Marquer comme lu';

  @override
  String get notifMessagePatient => 'Écrire au patient';

  @override
  String notifMessageTitle(String name) {
    return 'Nouveau message de $name';
  }

  @override
  String notifMinutesAgo(int n) {
    return 'il y a $n min';
  }

  @override
  String get notifNoLongerAssigned => 'Ce patient ne vous est plus attribué.';

  @override
  String get notifNothingRecorded =>
      'Aucun exercice n\'a été enregistré ce jour-là.';

  @override
  String get notifOpenConversation => 'Ouvrir la conversation';

  @override
  String get notifOpenExercise => 'Ouvrir l\'exercice';

  @override
  String get notifOpenPatient => 'Ouvrir le dossier du patient';

  @override
  String notifPainBodyDuring(String exercise) {
    return '$exercise · signalée pendant l\'exercice';
  }

  @override
  String notifPainBodyLevel(String exercise, int level) {
    return '$exercise · douleur $level/10';
  }

  @override
  String get notifPainDuringSet => 'Signalée pendant l\'exercice';

  @override
  String notifPainEvent(String time, String source) {
    return 'À $time de la série, $source';
  }

  @override
  String get notifPainNoRating => 'Pas encore de note';

  @override
  String get notifPainRating => 'Niveau de douleur';

  @override
  String notifPainTitle(String name) {
    return '$name a signalé une douleur';
  }

  @override
  String get notifPatientNotes => 'Notes du patient';

  @override
  String get notifPatientReportOnly =>
      'Il s\'agit du ressenti du patient, pas d\'un constat médical.';

  @override
  String notifPatientWords(String words) {
    return 'Le patient a dit : « $words »';
  }

  @override
  String get notifPrefInactivity => 'Aucun exercice fait';

  @override
  String get notifPrefInactivityHint =>
      'Un patient avait des exercices à faire et n\'en a enregistré aucun ce jour-là (vérifié chaque nuit)';

  @override
  String get notifPrefIncorrect => 'Répétitions surtout incorrectes';

  @override
  String get notifPrefIncorrectHint =>
      'Au moins 90 % des répétitions évaluées d\'une série étaient incorrectes (8 évaluées ou plus)';

  @override
  String get notifPrefMessageHint => 'Un patient vous envoie un message';

  @override
  String get notifPrefPainHint =>
      'Un patient signale une douleur pendant un exercice, ou la note 4/10 ou plus';

  @override
  String get notifPrefPainOffBody =>
      'Vous ne serez plus averti lorsqu\'un patient signale une douleur. Les signalements restent dans son historique.';

  @override
  String get notifPrefPainOffTitle => 'Désactiver les alertes de douleur ?';

  @override
  String get notifPrefTurnOff => 'Désactiver';

  @override
  String get notifPrescribed => 'Exercices prescrits à ce moment';

  @override
  String get notifReportedAt => 'Signalé le';

  @override
  String notifRepsDone(int reps) {
    return '$reps répétitions';
  }

  @override
  String get notifResolved => 'Résolu';

  @override
  String get notifResumedSince => 'Le patient a repris ses exercices depuis.';

  @override
  String notifRoutineBody(String exercise, int sets, int reps) {
    return '$exercise : $sets séries × $reps répétitions';
  }

  @override
  String get notifRoutineTitle => 'Votre programme a été mis à jour';

  @override
  String get notifSetResult => 'Résultat de la série';

  @override
  String notifSetsReps(int sets, int reps) {
    return '$sets × $reps';
  }

  @override
  String get notifSettingsIntro =>
      'Choisissez ce qui vous est notifié. Un type désactivé n\'est pas enregistré du tout : le réactiver ne fait pas revenir ce qui s\'est passé entre-temps.';

  @override
  String get notifSettingsTitle => 'Paramètres des notifications';

  @override
  String get notifSignedOut =>
      'Votre session a expiré. Veuillez vous reconnecter.';

  @override
  String notifTrackingConfirmed(int judged) {
    return 'Les $judged répétitions ont été évaluées avec un suivi fiable.';
  }

  @override
  String notifTrackingPartly(int unsure) {
    return '$unsure répétition(s) n\'ont pas pu être évaluées de façon fiable par la caméra et ne sont pas comptées.';
  }

  @override
  String get notifUnavailable => 'Cet élément n\'est plus disponible.';

  @override
  String notifUnreadCount(int count) {
    return '$count non lue(s)';
  }

  @override
  String get notifUnsureReps => 'Non évaluées';

  @override
  String get notifUrgent => 'Urgent';

  @override
  String get notifYesterday => 'Hier';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsComingSoon =>
      'Les préférences de notification arrivent bientôt.';

  @override
  String get ok => 'OK';

  @override
  String get onboardingAudience =>
      'Conçu pour les patients et les kinésithérapeutes';

  @override
  String get onboardingCardHelper =>
      'Pensé pour des séances de rééducation quotidiennes plus sûres';

  @override
  String get onboardingEyebrow1 => 'Intelligence du mouvement';

  @override
  String get onboardingEyebrow2 => 'Rééducation guidée';

  @override
  String get onboardingEyebrow3 => 'Lien avec le kinésithérapeute';

  @override
  String get onboardingFooter =>
      'Suivez vos exercices, mesurez vos progrès et restez en contact avec votre kinésithérapeute dans une seule application sécurisée.';

  @override
  String get onboardingHeadline => 'Récupérez mieux,\nbougez en confiance.';

  @override
  String get onboardingIntro =>
      'Un accompagnement personnalisé par IA pour vos exercices de rééducation, le suivi de vos progrès et la collaboration avec votre kinésithérapeute.';

  @override
  String get onboardingSubtitle1 =>
      'Une estimation avancée de la posture aide les patients à réaliser chaque exercice de façon plus sûre et plus précise.';

  @override
  String get onboardingSubtitle2 =>
      'Recevez des consignes de correction claires et des retours encourageants tout au long de votre programme de rééducation.';

  @override
  String get onboardingSubtitle3 =>
      'Partagez vos progrès à distance pour que votre kinésithérapeute suive votre rétablissement et adapte les prochaines étapes.';

  @override
  String get onboardingTitle1 => 'Analyse du mouvement par IA';

  @override
  String get onboardingTitle2 => 'Correction instantanée de la posture';

  @override
  String get onboardingTitle3 => 'Connecté à votre kinésithérapeute';

  @override
  String oneSet(String count) {
    return '$count série';
  }

  @override
  String get openDoc => 'Ouvrir le document';

  @override
  String get overview => 'Aperçu';

  @override
  String get painLevel => 'Niveau de douleur';

  @override
  String get painLevelLower => 'niveau de douleur';

  @override
  String painOutOfTen(String pain) {
    return '$pain/10';
  }

  @override
  String painOutOfTenSpaced(String pain) {
    return '$pain / 10';
  }

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordMinLength =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get patient => 'Patient';

  @override
  String get patientChat => 'Discussion avec le patient';

  @override
  String get patientComplaints => 'Réclamations des patients';

  @override
  String get patientProgress => 'Progression du patient';

  @override
  String get patients => 'Patients';

  @override
  String get payMonthlyWithStripe => 'Payer l\'abonnement mensuel avec Stripe';

  @override
  String get payYearlyWithStripe => 'Payer l\'abonnement annuel avec Stripe';

  @override
  String get payloadPreview =>
      'Aperçu des données (prêtes à être envoyées à votre modèle d\'IA) :';

  @override
  String get pending => 'En attente';

  @override
  String get pendingClinics => 'Cliniques en attente';

  @override
  String percentValue(String percent) {
    return '$percent %';
  }

  @override
  String get phone => 'Téléphone';

  @override
  String get phoneRequired => 'Le téléphone est obligatoire';

  @override
  String phoneValue(String phone) {
    return 'Téléphone : $phone';
  }

  @override
  String get physioAiBanner =>
      'Tableau de bord Kinex AI Rehab pour un suivi plus intelligent des patients.';

  @override
  String get physioHome => 'Accueil kinésithérapeute';

  @override
  String get physioProfile => 'Profil du kinésithérapeute';

  @override
  String get physiotherapist => 'Kinésithérapeute';

  @override
  String get physiotherapists => 'Kinésithérapeutes';

  @override
  String get pleaseEnterEmail => 'Veuillez saisir votre e-mail';

  @override
  String get pleaseEnterPassword => 'Veuillez saisir votre mot de passe';

  @override
  String get premiumActive => 'Premium actif';

  @override
  String get premiumActiveCheck => 'Premium actif ✅';

  @override
  String get premiumLockedDescription =>
      'Débloquez l\'enregistrement vidéo avec analyse IA et les fonctionnalités premium pour vos patients.';

  @override
  String get premiumUnlockedDescription =>
      'L\'envoi de vidéos et l\'analyse IA sont débloqués pour vos patients.';

  @override
  String get preparingExercise => 'Préparation de l\'exercice...';

  @override
  String pricingMonthlyLine(String count, String total) {
    return 'Mensuel = 5,00 + (0,10 x $count) = $total EUR';
  }

  @override
  String pricingPatientsLine(String count) {
    return 'Patients : $count';
  }

  @override
  String pricingYearlyLine(String count, String total) {
    return 'Annuel = 50,00 + (0,10 x $count) = $total EUR';
  }

  @override
  String get profile => 'Profil';

  @override
  String get profilePhotoUpdated => 'Photo de profil mise à jour.';

  @override
  String get profileUpdatedSuccessfully => 'Profil mis à jour avec succès.';

  @override
  String get progress => 'Progression';

  @override
  String progressReps(String current, String total) {
    return 'Progression : $current / $total répétitions';
  }

  @override
  String progressRepsOf(String done, String target) {
    return 'Progression : $done$target répétitions';
  }

  @override
  String get recordingLockedSubscription =>
      'Enregistrement verrouillé (abonnement requis)';

  @override
  String get refresh => 'Actualiser';

  @override
  String get registerYourClinic => 'Inscrire votre clinique';

  @override
  String get registrationFailed => 'Échec de l\'inscription';

  @override
  String get reject => 'Refuser';

  @override
  String get repLabelBelowTarget =>
      'Bonne posture – en dessous de votre objectif';

  @override
  String get repLabelGood => 'Bonne';

  @override
  String get repLabelKnee => 'Genou plié';

  @override
  String get repLabelLeanin => 'Penché vers la jambe levée';

  @override
  String get repLabelLeanout => 'Penché à l\'opposé de la jambe levée';

  @override
  String get repLabelUnsure => 'Incertaine';

  @override
  String get repLabelWrongSide => 'Mauvais côté – non comptée';

  @override
  String reportBelowTarget(int count) {
    return '$count répétition(s) correcte(s) sous l\'objectif.';
  }

  @override
  String reportDiscomfort(String time) {
    return 'Le patient a dit être mal à l\'aise à $time. Série mise en pause.';
  }

  @override
  String reportMistakes(String list) {
    return 'Erreurs : $list.';
  }

  @override
  String reportNotes(String exercise, String arm, int judged, int good) {
    return 'Série avec caméra - $exercise (bras $arm) : $judged répétitions évaluées, $good bonnes.';
  }

  @override
  String reportNotesLeg(String exercise, String leg, int judged, int good) {
    return 'Série caméra - $exercise (jambe $leg) : $judged répétitions jugées, $good bonnes.';
  }

  @override
  String reportPainEvent(String time, String source) {
    return 'Douleur signalée par le patient à $time ($source) - signalement du patient, pas un constat médical. Série mise en pause.';
  }

  @override
  String get reportSourceButton => 'avec le bouton';

  @override
  String get reportSourceVoice => 'à la voix';

  @override
  String reportUnsure(int count) {
    return '$count incertaine(s).';
  }

  @override
  String reportWrongSide(int count) {
    return '$count répétition(s) du mauvais côté, non comptée(s).';
  }

  @override
  String get reps => 'Répétitions';

  @override
  String repsBullet(String count) {
    return '• $count répétitions';
  }

  @override
  String get repsCompleted => 'Répétitions effectuées';

  @override
  String repsCount(String count) {
    return '$count répétitions';
  }

  @override
  String get repsDone => 'répétitions faites';

  @override
  String get requestSent => 'Demande envoyée';

  @override
  String get required => 'Obligatoire';

  @override
  String get retry => 'Réessayer';

  @override
  String get role => 'Rôle';

  @override
  String get roleAdmin => 'Administrateur';

  @override
  String get save => 'Enregistrer';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get saveProfile => 'Enregistrer le profil';

  @override
  String get saveProfileLower => 'Enregistrer le profil';

  @override
  String scoreValue(String score) {
    return 'Score : $score';
  }

  @override
  String get searchAccountsByName => 'Rechercher des comptes par nom';

  @override
  String get searchClinics =>
      'Rechercher des cliniques (nom, e-mail, téléphone, ID)';

  @override
  String get searchMembers => 'Rechercher un patient / kinésithérapeute';

  @override
  String get searchPendingClinics =>
      'Rechercher des cliniques en attente (nom, e-mail, téléphone, ID)';

  @override
  String get selectBirthDate => 'Choisir la date de naissance';

  @override
  String get selectExerciseAndValidSetsReps =>
      'Choisissez un exercice et des séries/répétitions valides.';

  @override
  String get send => 'Envoyer';

  @override
  String get sendComplaint => 'Envoyer la réclamation';

  @override
  String sessionBelowTargetShort(int count) {
    return '$count sous l\'objectif';
  }

  @override
  String get sessionFeedbackTitle => 'Retour de séance';

  @override
  String sessionGoodShort(int count) {
    return '$count bonnes';
  }

  @override
  String get sessionHistory => 'Historique des séances';

  @override
  String get sessionManualReport => 'Saisi à la main (sans série caméra)';

  @override
  String sessionMistakesShort(int count) {
    return '$count à corriger';
  }

  @override
  String get sessionNoRepDetail =>
      'Le détail par répétition n\'est pas disponible pour cette série (enregistrée avant la mise à jour).';

  @override
  String get sessionNoSets =>
      'Aucune série caméra n\'a été enregistrée pour cette séance.';

  @override
  String get sessionNotes => 'Notes';

  @override
  String get sessionOpenFeedback => 'Retour IA';

  @override
  String get sessionPainDuring => 'Douleur signalée pendant la série';

  @override
  String sessionPainLevel(String pain) {
    return 'Douleur $pain/10';
  }

  @override
  String sessionScore(int percent) {
    return '$percent % correctes';
  }

  @override
  String sessionSetTitle(int number, String time) {
    return 'Série $number · $time';
  }

  @override
  String sessionWrongSideShort(int count) {
    return '$count mauvais côté';
  }

  @override
  String sessionsLogged(String count) {
    return '$count séances enregistrées';
  }

  @override
  String get sets => 'Séries';

  @override
  String get setsCompleted => 'Séries terminées';

  @override
  String setsCount(String count) {
    return '$count séries';
  }

  @override
  String get setsDoneLower => 'séries faites';

  @override
  String setsTimesReps(String sets, String reps) {
    return '$sets séries × $reps répétitions';
  }

  @override
  String get settings => 'Paramètres';

  @override
  String shortDate(String day, String month, String year) {
    return '$day $month $year';
  }

  @override
  String get signInToYourAccount => 'Connectez-vous à votre compte';

  @override
  String get specialization => 'Spécialité';

  @override
  String get srvAccountDeleted => 'Compte supprimé';

  @override
  String get srvAccountNotFound => 'Compte introuvable';

  @override
  String get srvAccountUpdated => 'Compte mis à jour';

  @override
  String get srvAdminNotDeletable =>
      'Les comptes administrateur ne peuvent pas être supprimés';

  @override
  String get srvAdminRequired => 'Accès administrateur requis';

  @override
  String get srvAiFeedbackSubscription =>
      'L\'analyse IA n\'est disponible qu\'avec un abonnement actif de la clinique';

  @override
  String get srvAiVideoUploaded => 'Vidéo d\'analyse IA envoyée avec succès';

  @override
  String get srvAssignmentNotFound => 'Affectation d\'exercice introuvable';

  @override
  String get srvCannotDeleteSelf =>
      'Vous ne pouvez pas supprimer votre propre compte administrateur';

  @override
  String get srvClinicApproved => 'Clinique approuvée';

  @override
  String get srvClinicDeleted => 'Clinique supprimée';

  @override
  String get srvClinicMovedToWaiting => 'Clinique remise en attente';

  @override
  String get srvClinicMustBeApproved =>
      'Le compte de la clinique doit être approuvé avant d\'utiliser cette fonctionnalité';

  @override
  String get srvClinicNameMin =>
      'Le nom de la clinique doit contenir au moins 3 caractères';

  @override
  String get srvClinicProfileNotFound => 'Profil de la clinique introuvable';

  @override
  String get srvClinicProfileUpdated =>
      'Profil de la clinique mis à jour avec succès';

  @override
  String get srvClinicRegistered =>
      'Clinique inscrite. En attente de l\'approbation de l\'administrateur.';

  @override
  String get srvClinicUpdated => 'Clinique mise à jour';

  @override
  String get srvComplaintSubmitted => 'Réclamation envoyée avec succès';

  @override
  String get srvDescriptionMin =>
      'La description doit contenir au moins 5 caractères';

  @override
  String get srvEmailExists => 'Cet e-mail est déjà utilisé';

  @override
  String get srvEmailPasswordRequired =>
      'L\'e-mail et le mot de passe sont obligatoires';

  @override
  String get srvExerciseAssigned => 'Exercice assigné avec succès';

  @override
  String get srvExerciseCompletedSaved =>
      'Exercice terminé et progression enregistrée';

  @override
  String get srvExerciseNotFound => 'Exercice introuvable';

  @override
  String get srvExerciseRemoved => 'Exercice retiré avec succès';

  @override
  String get srvInvalidPassword => 'Mot de passe incorrect';

  @override
  String get srvInvalidPhoneNumber => 'Numéro de téléphone invalide';

  @override
  String get srvJustifRequired => 'Le justificatif est obligatoire';

  @override
  String get srvJustifSize => 'Le justificatif ne doit pas dépasser 8 Mo';

  @override
  String get srvJustifType => 'Le justificatif doit être au format PDF/JPG/PNG';

  @override
  String get srvJustifUploadFailed => 'Échec du téléversement du justificatif';

  @override
  String get srvMemberNotFound => 'Membre introuvable dans votre clinique';

  @override
  String get srvMessageContentRequired => 'Le message ne peut pas être vide';

  @override
  String get srvMessageSent => 'Message envoyé avec succès';

  @override
  String get srvNameMin => 'Le nom doit contenir au moins 2 caractères';

  @override
  String get srvNoAccountForEmail => 'Aucun compte n\'est associé à cet e-mail';

  @override
  String get srvNoPhysioAssigned =>
      'Aucun kinésithérapeute ne vous est encore assigné';

  @override
  String get srvPatientCreated => 'Compte patient créé avec succès';

  @override
  String get srvPatientDeleted => 'Patient supprimé avec succès';

  @override
  String get srvPatientNotAssignedToPhysio =>
      'Ce patient n\'est pas assigné à ce kinésithérapeute';

  @override
  String get srvPatientNotAssignedToPhysio2 =>
      'Ce patient n\'est pas assigné à ce kinésithérapeute';

  @override
  String get srvPatientProfileNotFound => 'Profil du patient introuvable';

  @override
  String get srvPaymentConfirmed =>
      'Paiement confirmé. Abonnement activé avec succès.';

  @override
  String get srvPaymentNotCompleted =>
      'Le paiement n\'est pas encore finalisé. Terminez le paiement puis réessayez.';

  @override
  String get srvPaymentRefNotFound =>
      'Référence de paiement introuvable pour cette clinique';

  @override
  String get srvPhotoType => 'La photo doit être au format JPG/PNG/WEBP';

  @override
  String get srvPhotoUploaded => 'Photo téléversée avec succès';

  @override
  String get srvPhysioNotFound => 'Kinésithérapeute introuvable';

  @override
  String get srvPhysioProfileNotFound =>
      'Profil du kinésithérapeute introuvable';

  @override
  String get srvPremiumForVideo =>
      'Un abonnement Premium est requis pour envoyer une vidéo';

  @override
  String get srvProfileUpdated => 'Profil mis à jour avec succès';

  @override
  String get srvProgressSaved => 'Rapport de progression enregistré';

  @override
  String get srvSetsRepsPositive =>
      'Les séries et répétitions doivent être supérieures à 0';

  @override
  String get srvStripeCheckoutReady =>
      'Paiement Stripe prêt. Finalisez le paiement puis appuyez sur Vérifier.';

  @override
  String get srvTherapistCreated => 'Compte kinésithérapeute créé avec succès';

  @override
  String get srvTherapistDeleted => 'Kinésithérapeute supprimé avec succès';

  @override
  String get srvUnsupportedVideo => 'Format vidéo non pris en charge';

  @override
  String get srvWaitingForApproval => 'En attente d\'approbation';

  @override
  String get standardPlan => 'Offre standard';

  @override
  String get startExercise => 'Commencer l\'exercice';

  @override
  String get statsOverview => 'Aperçu des statistiques';

  @override
  String statusValue(String status) {
    return 'Statut : $status';
  }

  @override
  String get submitComplaint => 'Déposer une réclamation';

  @override
  String get submitForApproval => 'Soumettre pour approbation';

  @override
  String get subscription => 'Abonnement';

  @override
  String get subscriptionActiveAiAvailable =>
      'Abonnement actif : analyse IA disponible.';

  @override
  String get subscriptionActiveAiUnlocked =>
      'Abonnement de la clinique actif - Analyse IA débloquée';

  @override
  String get subscriptionInactiveAiHidden =>
      'Abonnement inactif : analyse IA masquée.';

  @override
  String get subscriptionInactiveAiLocked =>
      'Abonnement de la clinique inactif - Analyse IA verrouillée';

  @override
  String get success => 'Succès';

  @override
  String get summaryBelowTarget => 'Bonne posture, sous l\'objectif';

  @override
  String get summaryEveryRep => 'Toutes les répétitions';

  @override
  String get summaryGoodReps => 'bonnes répétitions';

  @override
  String get summaryMistakes => 'Erreurs';

  @override
  String get summaryNoMistakes => 'Aucune erreur, bravo !';

  @override
  String get summaryNoneScored => 'Aucune répétition n\'a pu être évaluée.';

  @override
  String get summaryNotSent => 'Non envoyé';

  @override
  String summaryNotSentError(String error) {
    return 'Non envoyé : $error';
  }

  @override
  String get summaryPainQuestion =>
      'Quelle douleur avez-vous ressentie ? (0 = aucune, 10 = la pire)';

  @override
  String get summaryPainReported =>
      'Vous avez signalé une douleur pendant cette série. Votre kinésithérapeute le verra.';

  @override
  String summaryPeak(int deg, int target) {
    return 'Levée de jambe : médiane $deg° (objectif $target°)';
  }

  @override
  String get summaryRepsCounted => 'répétitions comptées';

  @override
  String get summaryRepsScored => 'répétitions évaluées';

  @override
  String get summarySending => 'Envoi à votre kinésithérapeute...';

  @override
  String get summarySent => 'Enregistré et envoyé à votre kinésithérapeute';

  @override
  String get summaryTitle => 'Résumé de la série';

  @override
  String get summaryTryAgain => 'Réessayer';

  @override
  String summaryUnsure(int count) {
    return '$count répétition(s) n\'ont pas pu être évaluées avec certitude.';
  }

  @override
  String summaryWrongSideArm(int count) {
    return '$count répétition(s) faite(s) avec l\'autre bras n\'ont pas été comptée(s).';
  }

  @override
  String summaryWrongSideLeg(int count) {
    return '$count répétition(s) faite(s) avec l\'autre jambe n\'ont pas été comptée(s).';
  }

  @override
  String get switchToDarkMode => 'Passer en mode sombre';

  @override
  String get switchToLightMode => 'Passer en mode clair';

  @override
  String get symptomsOptional => 'Symptômes (facultatif)';

  @override
  String symptomsValue(String symptoms) {
    return 'Symptômes : $symptoms';
  }

  @override
  String get tapButtonToAddMember =>
      'Appuyez sur le bouton ci-dessous pour en ajouter un.';

  @override
  String get tapToStartLogging =>
      'Appuyez ci-dessous pour enregistrer votre progression';

  @override
  String get tapToUploadDocument => 'Appuyez pour téléverser (PDF/JPG/PNG)';

  @override
  String targetReps(String reps) {
    return 'Objectif : $reps répétitions';
  }

  @override
  String targetSetsReps(String total, String reps, String sets) {
    return 'Objectif : $sets séries × $reps répétitions = $total répétitions au total';
  }

  @override
  String get therapistChat => 'Discussion avec le kinésithérapeute';

  @override
  String therapistValue(String name) {
    return 'Kinésithérapeute : $name';
  }

  @override
  String get therapists => 'Kinésithérapeutes';

  @override
  String get thisWeek => 'Cette semaine';

  @override
  String get thisWeeksActivity => 'Activité de la semaine';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get todayUpper => 'AUJOURD\'HUI';

  @override
  String get todaysExercises => 'Exercices du jour';

  @override
  String get todaysPlan => 'Programme du jour';

  @override
  String get toggleTheme => 'Changer de thème';

  @override
  String get totalRepsCompleted => 'Total des répétitions effectuées';

  @override
  String get trackedArmLeft => 'Gauche';

  @override
  String get trackedArmRight => 'Droite';

  @override
  String get trackedE1 => 'Élévation antérieure avec un bâton (deux bras)';

  @override
  String get trackedE2 => 'Abduction du bras (un bras)';

  @override
  String get trackedE3 => 'Rotation du bras, coude au corps (un bras)';

  @override
  String get trackedE4 => 'Abduction de hanche debout (une jambe)';

  @override
  String get trackedInjuredArm => 'Bras blessé';

  @override
  String get trackedLabel => 'Suivi par caméra en direct';

  @override
  String get trackedLiftedLeg => 'Jambe levée';

  @override
  String get trackedNone => 'Pas de suivi en direct';

  @override
  String trackedSummary(String exercise, String arm) {
    return '$exercise · bras $arm';
  }

  @override
  String trackedSummaryLeg(String exercise, String leg) {
    return '$exercise · jambe $leg';
  }

  @override
  String get trackedTargetAngle => 'Angle de levée visé (°)';

  @override
  String trackedTargetAngleHelp(String percent, String deg) {
    return 'Angle de la jambe par rapport au corps en haut de la levée. Laissez vide pour utiliser $percent % de la levée habituelle du patient (ou l\'angle par défaut de $deg° tant qu\'elle n\'est pas connue).';
  }

  @override
  String get trackedTargetAngleInvalid =>
      'Entrez un angle entre 5 et 90°, ou laissez vide';

  @override
  String trackedTargetShort(String deg) {
    return 'objectif $deg°';
  }

  @override
  String get trackedWorkingArm => 'Bras qui fait l\'exercice';

  @override
  String get trackingNotSet =>
      'Votre kinésithérapeute n\'a pas encore configuré le suivi par caméra pour cet exercice.';

  @override
  String get truncated => '...tronqué...';

  @override
  String get typeYourMessage => 'Écrivez votre message...';

  @override
  String unableToOpenCamera(String error) {
    return 'Impossible d\'ouvrir la caméra : $error';
  }

  @override
  String get unableToOpenDocument => 'Impossible d\'ouvrir le document.';

  @override
  String get unassigned => 'Non assigné';

  @override
  String get unknownError => 'Erreur inconnue';

  @override
  String get unnamedAccount => 'Compte sans nom';

  @override
  String get updateProgress => 'Mettre à jour la progression';

  @override
  String get upgradeToPremium => 'Passer à Premium';

  @override
  String get uploadJustificationPrompt =>
      'Veuillez téléverser le justificatif de votre clinique.';

  @override
  String get useRegisteredCredentials =>
      'Utilisez l\'e-mail et le mot de passe de votre compte.';

  @override
  String get verifyStripePayment => 'Vérifier le paiement Stripe';

  @override
  String get video => 'Vidéo';

  @override
  String get videoRecordingLocked =>
      'L\'enregistrement vidéo est verrouillé : l\'abonnement de la clinique est inactif.';

  @override
  String get viewComplaints => 'Voir les réclamations';

  @override
  String get viewDocument => 'Voir le document';

  @override
  String get voiceAlreadyRunning => 'L\'exercice est déjà en cours.';

  @override
  String get voiceHelp =>
      'Vous pouvez dire : répète, je ne comprends pas, pause, reprendre, aide, ou j\'ai mal.';

  @override
  String get voiceLanguageFallback =>
      'La voix n\'est pas disponible dans votre langue sur ce téléphone : anglais utilisé.';

  @override
  String voiceMilestone(int count) {
    return 'Vous avez fait $count répétitions.';
  }

  @override
  String get voiceNotUnderstood =>
      'Désolé, je n\'ai pas compris. Dites aide pour entendre les commandes.';

  @override
  String get voiceNothingToRepeat =>
      'Il n\'y a pas encore d\'instruction à répéter.';

  @override
  String get voicePainClarify =>
      'J\'ai mis l\'exercice en pause par précaution. Avez-vous mal maintenant ? Si oui, dites : j\'ai mal, ou appuyez sur J\'ai mal.';

  @override
  String get voicePainHoldRefuse =>
      'L\'exercice reste en pause car vous avez signalé une douleur. Suivez les conseils de votre kinésithérapeute.';

  @override
  String get voicePainResponse =>
      'J\'ai compris que vous avez mal. L\'exercice est en pause. Suivez les conseils de votre kinésithérapeute avant de continuer.';

  @override
  String get voicePaused =>
      'L\'exercice est en pause. Appuyez sur reprendre quand vous êtes prêt.';

  @override
  String get voiceResumed => 'On reprend. Restez d\'abord immobile.';

  @override
  String get voiceSetDone => 'La série est terminée. Bravo.';

  @override
  String get voiceStandStill => 'Restez immobile deux secondes.';

  @override
  String voiceStart(String exercise) {
    return 'Vous pouvez commencer : $exercise.';
  }

  @override
  String get voiceStepBack =>
      'Reculez un peu pour que tout votre corps soit visible.';

  @override
  String get voiceStepBackFeet =>
      'Reculez pour que la caméra voie tout votre corps, pieds compris';

  @override
  String get voiceTtsUnavailable =>
      'Le retour vocal n\'est pas disponible sur ce téléphone.';

  @override
  String get voiceUncomfortable =>
      'J\'ai mis l\'exercice en pause. Avez-vous mal ? Si oui, dites : j\'ai mal, ou appuyez sur J\'ai mal.';

  @override
  String get weekdayInitials => 'L,M,M,J,V,S,D';

  @override
  String get weekdayShortNames => 'Lun,Mar,Mer,Jeu,Ven,Sam,Dim';

  @override
  String weeklyGoalPercent(String percent) {
    return '$percent % de l\'objectif hebdo';
  }

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get yearly => 'Annuel';

  @override
  String get yearlyPricingNote => 'Annuel : 50 EUR + 0,10 EUR par patient';
}

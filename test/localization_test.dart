import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reeducation/features/auth/pages/login_screen.dart';
import 'package:reeducation/features/auth/pages/signup_screen.dart';
import 'package:reeducation/l10n/l10n.dart';
import 'package:reeducation/l10n/locale_controller.dart';
import 'package:reeducation/l10n/server_messages.dart';
import 'package:reeducation/main.dart';
import 'package:reeducation/widgets/language_button.dart';

const _languages = ['en', 'fr', 'ar'];

/// Phone-sized surface (Galaxy A21s is about 412 x 915 logical pixels).
void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(412 * 3, 915 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Lets menus and routes finish animating. pumpAndSettle can't be used because
/// the login logo pulses forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Widget _app(String code, Widget home) {
  return ProviderScope(
    overrides: [
      localeProvider.overrideWith((ref) => LocaleController(Locale(code))),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        locale: ref.watch(localeProvider),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          L10n.current = AppLocalizations.of(context);
          return child!;
        },
        home: home,
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Real app wiring (MyApp)', () {
    for (final code in _languages) {
      testWidgets('onboarding renders in $code', (tester) async {
        _usePhoneSize(tester);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) => LocaleController(Locale(code))),
          ],
          child: const MyApp(),
        ));
        await tester.pump();

        final l10n = lookupAppLocalizations(Locale(code));
        expect(find.text(l10n.continueToLogin), findsOneWidget);
        expect(find.text(l10n.onboardingHeadline), findsOneWidget);

        final direction = Directionality.of(tester.element(find.text(l10n.continueToLogin)));
        expect(direction, code == 'ar' ? TextDirection.rtl : TextDirection.ltr);

        // Stop the carousel's autoplay timer before the test ends.
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  });

  group('Screens in every language', () {
    for (final code in _languages) {
      testWidgets('login screen in $code', (tester) async {
        _usePhoneSize(tester);
        await tester.pumpWidget(_app(code, const LoginScreen()));
        await tester.pump();

        final l10n = lookupAppLocalizations(Locale(code));
        expect(find.text(l10n.welcomeBack), findsOneWidget);
        expect(find.text(l10n.login), findsOneWidget);
        expect(find.text(l10n.registerYourClinic), findsOneWidget);
        expect(find.byType(LanguageButton), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Validation messages are localized too.
        await tester.tap(find.text(l10n.login));
        await tester.pump();
        expect(find.text(l10n.pleaseEnterEmail), findsOneWidget);
        expect(find.text(l10n.pleaseEnterPassword), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('signup screen in $code', (tester) async {
        _usePhoneSize(tester);
        await tester.pumpWidget(_app(code, const SignupScreen()));
        await tester.pump();

        final l10n = lookupAppLocalizations(Locale(code));
        expect(find.text(l10n.clinicRegistration), findsOneWidget);
        await tester.scrollUntilVisible(find.text(l10n.submitForApproval), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text(l10n.submitForApproval), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('language button switches language and remembers it', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(_app('en', const LoginScreen()));
    await tester.pump();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.byType(LanguageButton));
    await _settle(tester);
    await tester.tap(find.text('Français'));
    await _settle(tester);

    expect(find.text('Bon retour'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'fr');

    await tester.tap(find.byType(LanguageButton));
    await _settle(tester);
    await tester.tap(find.text('العربية'));
    await _settle(tester);

    expect(find.text('مرحبًا بعودتك'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('مرحبًا بعودتك'))), TextDirection.rtl);
    expect(prefs.getString('app_language'), 'ar');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('Server message translation', () {
    tearDown(() => L10n.current = lookupAppLocalizations(const Locale('en')));

    test('English messages are returned unchanged', () {
      L10n.current = lookupAppLocalizations(const Locale('en'));
      for (final raw in [
        'Invalid password',
        'Unable to reach server while loading homepage',
        'Homepage request timed out',
        'Server error 500. Response: <html>',
      ]) {
        expect(localizeServerMessage(raw), raw);
      }
    });

    test('known messages are translated', () {
      L10n.current = lookupAppLocalizations(const Locale('fr'));
      expect(localizeServerMessage('Invalid password'), 'Mot de passe incorrect');
      L10n.current = lookupAppLocalizations(const Locale('ar'));
      expect(localizeServerMessage('Waiting for approval'), 'في انتظار الموافقة');
    });

    test('network errors are translated by pattern', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      L10n.current = fr;
      expect(localizeServerMessage('Unable to reach server while loading homepage'), fr.errorServerUnreachable);
      expect(localizeServerMessage('Homepage request timed out'), fr.errorTimeout);
      expect(localizeServerMessage('Server error 500. Response: <html>'), fr.errorServerStatus('500'));
      expect(localizeError(Exception('Profile request timed out')), fr.errorTimeout);
    });

    test('unknown messages pass through', () {
      L10n.current = lookupAppLocalizations(const Locale('ar'));
      expect(localizeServerMessage('Failed to prepare login lookup: x'), 'Failed to prepare login lookup: x');
    });
  });

  test('every language has the same keys and lists', () {
    for (final code in _languages) {
      final l10n = lookupAppLocalizations(Locale(code));
      expect(l10n.weekdayInitials.split(','), hasLength(7), reason: code);
      expect(l10n.weekdayShortNames.split(','), hasLength(7), reason: code);
      expect(l10n.monthNames.split(','), hasLength(12), reason: code);
      expect(l10n.monthShortNames.split(','), hasLength(12), reason: code);
    }
  });
}

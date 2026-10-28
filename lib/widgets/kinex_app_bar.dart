import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../login_provider.dart';
import 'kinex_logo.dart';
import 'language_button.dart';

AppBar kinexAppBar({
  required String title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  bool centerTitle = true,
  bool includeThemeToggle = true,
}) {
  final mergedActions = <Widget>[...?actions, const LanguageButton()];
  if (includeThemeToggle) {
    mergedActions.add(
      Builder(
        builder: (context) {
          final brightness = Theme.of(context).brightness;
          final isDark = brightness == Brightness.dark;
          return IconButton(
            tooltip: isDark ? context.l10n.switchToLightMode : context.l10n.switchToDarkMode,
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () {
              final container = ProviderScope.containerOf(context, listen: false);
              final current = container.read(themeModeProvider);
              container.read(themeModeProvider.notifier).state =
                  current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
          );
        },
      ),
    );
  }

  return AppBar(
    backgroundColor: const Color(0xFF071120),
    foregroundColor: Colors.white,
    centerTitle: centerTitle,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const KinexLogo(size: 20, radius: 6),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    actions: mergedActions,
    bottom: bottom,
  );
}


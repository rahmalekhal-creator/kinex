import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../l10n/locale_controller.dart';

/// Globe icon that opens a menu to switch between English, French and Arabic.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).languageCode;
    return PopupMenuButton<String>(
      tooltip: context.l10n.changeLanguage,
      icon: Icon(Icons.language_rounded, color: color),
      initialValue: current,
      onSelected: (code) => ref.read(localeProvider.notifier).setLanguage(code),
      itemBuilder: (context) => [
        for (final entry in kLanguageNames.entries)
          PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: entry.key == current
                      ? Icon(Icons.check_rounded, size: 18, color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                Text(entry.value),
              ],
            ),
          ),
      ],
    );
  }
}

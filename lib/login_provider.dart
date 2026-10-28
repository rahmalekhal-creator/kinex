import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

final AccountIdProvider = StateProvider<int?>((ref) => null);

final roleProvider = StateProvider<String>((ref) => '');

final isSubProvider = StateProvider<bool>((ref) => false);

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings.dart';
import 'features/home/home_screen.dart';

class SmartCompressApp extends ConsumerWidget {
  const SmartCompressApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(settingsProvider.select((s) => s.themeMode));
    const seed = Color(0xFF00696E); // deep teal

    ThemeData theme(Brightness brightness) => ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        );

    return MaterialApp(
      title: 'CompressX',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}

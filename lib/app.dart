import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/library/screens/library_screen.dart';
import 'features/scan/screens/scan_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'shared/theme/app_theme.dart';

final bottomNavProvider = StateProvider<int>((ref) => 0);

class DocVaultApp extends ConsumerWidget {
  const DocVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DocVault',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _screens = [
    LibraryScreen(),
    ScanScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(bottomNavProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.library_books), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.document_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onDestinationSelected: (value) =>
            ref.read(bottomNavProvider.notifier).state = value,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'pages/home_page.dart';

class ScanThisApp extends StatelessWidget {
  const ScanThisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B6CFF),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ScanThis',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: cs,
        scaffoldBackgroundColor: cs.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const HomePage(),
    );
  }
}

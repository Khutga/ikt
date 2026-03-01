import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar rengi
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MacroDashboardApp());
}

class MacroDashboardApp extends StatelessWidget {
  const MacroDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Makroekonomik Dashboard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4ECDC4), // Turkuaz
        brightness: Brightness.light,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4ECDC4),
        brightness: Brightness.dark,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      ),

      home: const DashboardScreen(),
    );
  }
}
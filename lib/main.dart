import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar — dark mode için açık ikonlar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
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
      themeMode: ThemeMode.dark, // Her zaman dark

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Inter',

        // Renk şeması
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4ECDC4),       // Turkuaz
          onPrimary: Colors.black,
          secondary: const Color(0xFF45B7D1),      // Açık mavi
          surface: const Color(0xFF1A1A2E),        // Koyu lacivert
          onSurface: const Color(0xFFE0E0E0),
          error: const Color(0xFFFF6B6B),
          outline: const Color(0xFF2A2A4A),
        ),

        // Scaffold arka planı
        scaffoldBackgroundColor: const Color(0xFF0F0F23),

        // AppBar
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Color(0xFF1A1A2E),
          foregroundColor: Color(0xFFE0E0E0),
        ),

        // Kartlar
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),

        // Divider
        dividerColor: const Color(0xFF2A2A4A),

        // Chip (periyot seçici)
        chipTheme: const ChipThemeData(
          backgroundColor: Color(0xFF1A1A2E),
          selectedColor: Color(0xFF4ECDC4),
        ),

        // Bottom Sheet
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1A1A2E),
        ),

        // Dialog
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1A1A2E),
        ),

        // Input
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF2A2A4A)),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: const Color(0xFF16213E),
        ),

        // FilledButton
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4ECDC4),
            foregroundColor: Colors.black,
          ),
        ),
      ),

      home: const DashboardScreen(),
    );
  }
}
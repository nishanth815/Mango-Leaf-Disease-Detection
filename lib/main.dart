import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MangoDiseaseApp());
}

class MangoDiseaseApp extends StatelessWidget {
  const MangoDiseaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    const leafGreen = Color(0xFF2E7D32);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mango Leaf Doctor',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: leafGreen,
          secondary: const Color(0xFFF9A825),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.green.shade100),
          ),
        ),
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const HomeScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'screens/operacion_screen.dart';
import 'theme/colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RuTechApp());
}

class RuTechApp extends StatelessWidget {
  const RuTechApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RUTECH',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.verde),
      useMaterial3: true,
    ),
    home: const OperacionScreen(),
  );
}

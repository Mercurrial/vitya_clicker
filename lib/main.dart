import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/screens/garage_screen.dart';
import 'ui/theme/garage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: VityaApp()));
}

class VityaApp extends StatelessWidget {
  const VityaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Витя гонит',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GColors.bg,
        fontFamily: GType.uiFamily,
        useMaterial3: true,
      ),
      home: const Scaffold(
        backgroundColor: GColors.bg,
        body: GarageScreen(),
      ),
    );
  }
}

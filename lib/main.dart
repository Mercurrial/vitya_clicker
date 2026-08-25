import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/screens/game_screen.dart';
import 'ui/theme/kardashev_tokens.dart';

void main() {
  runApp(const ProviderScope(child: KardashevApp()));
}

class KardashevApp extends StatelessWidget {
  const KardashevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KARDASHEV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: KColors.voidBg,
        fontFamily: KType.sansFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: KColors.accent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

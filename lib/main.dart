import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: VityaApp()));
}

/// Placeholder shell. The game UI is being rebuilt for the "Витя гонит"
/// concept; the idle engine under lib/engine + lib/models stays.
class VityaApp extends StatelessWidget {
  const VityaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Витя гонит',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('Витя разогревает аппарат…')),
      ),
    );
  }
}

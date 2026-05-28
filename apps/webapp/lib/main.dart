import 'package:flutter/material.dart';

// WebApp do Turni (Flutter Web no MVP — ADR-001).
// STORY-006: apenas um placeholder mínimo na rota raiz. O Design System
// (DDR-001) e o hello world de verdade entram na STORY-008.
void main() {
  runApp(const TurniApp());
}

class TurniApp extends StatelessWidget {
  const TurniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turni',
      debugShowCheckedModeBanner: false,
      home: const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Turni',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Hospitalidade on-demand — WebApp (placeholder STORY-006)'),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ds/tokens.dart';

/// STORY-046 CA-7 — destino após publicar. "Minhas vagas" completa é a STORY-047;
/// até lá este placeholder confirma a publicação (toast) e oferece publicar de novo.
/// O toast de sucesso vem por `extra` da navegação (Key `publicar-vaga-sucesso-toast`).
class MinhasVagasPlaceholderScreen extends StatefulWidget {
  const MinhasVagasPlaceholderScreen({super.key, this.successMessage});

  final String? successMessage;

  @override
  State<MinhasVagasPlaceholderScreen> createState() =>
      _MinhasVagasPlaceholderScreenState();
}

class _MinhasVagasPlaceholderScreenState
    extends State<MinhasVagasPlaceholderScreen> {
  @override
  void initState() {
    super.initState();
    final msg = widget.successMessage;
    if (msg != null && msg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('publicar-vaga-sucesso-toast'),
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas vagas')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(TurniSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 48),
              const SizedBox(height: TurniSpacing.md),
              Text(
                'Vaga publicada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: TurniSpacing.sm),
              const Text(
                'A lista completa de vagas chega na próxima estória.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: TurniSpacing.lg),
              FilledButton(
                key: const Key('minhas-vagas-publicar-outra-btn'),
                onPressed: () => context.go('/contratante/vagas/nova'),
                child: const Text('Publicar outra vaga'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

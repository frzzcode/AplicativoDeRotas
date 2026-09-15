import 'package:flutter/material.dart';

class EmBreveScreen extends StatelessWidget {
  final String titulo;
  final IconData icone;

  const EmBreveScreen({super.key, required this.titulo, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('$titulo em breve', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Esta área será construída nas próximas etapas do aplicativo.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

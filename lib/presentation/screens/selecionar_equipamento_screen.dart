import 'package:flutter/material.dart';

import '../../data/models/equipamento.dart';
import '../../data/repositories/equipamento_repository.dart';

class SelecionarEquipamentoScreen extends StatefulWidget {
  const SelecionarEquipamentoScreen({super.key});

  @override
  State<SelecionarEquipamentoScreen> createState() =>
      _SelecionarEquipamentoScreenState();
}

class _SelecionarEquipamentoScreenState
    extends State<SelecionarEquipamentoScreen> {
  final EquipamentoRepository _repository = EquipamentoRepository();
  final TextEditingController _pesquisaController = TextEditingController();
  late Future<List<Equipamento>> _equipamentosFuture;

  @override
  void initState() {
    super.initState();
    _equipamentosFuture = _repository.listarArCondicionados();
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  List<Equipamento> _filtrar(List<Equipamento> equipamentos) {
    final termo = _pesquisaController.text.trim().toLowerCase();
    if (termo.isEmpty) return equipamentos;
    return equipamentos.where((equipamento) {
      final texto = [
        equipamento.marca,
        equipamento.modelo,
        equipamento.capacidadeBtu?.toString(),
        equipamento.potencia,
        equipamento.tipo,
      ].whereType<String>().join(' ').toLowerCase();
      return texto.contains(termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar ar-condicionado')),
      body: FutureBuilder<List<Equipamento>>(
        future: _equipamentosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final equipamentos = _filtrar(snapshot.data ?? []);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _pesquisaController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Pesquisar equipamento',
                    hintText: 'Marca, modelo, BTUs ou potência',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Catálogo inicial de ar-condicionado',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: equipamentos.isEmpty
                    ? const Center(child: Text('Nenhum equipamento encontrado.'))
                    : ListView.separated(
                        itemCount: equipamentos.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final equipamento = equipamentos[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.ac_unit_outlined),
                            ),
                            title: Text(equipamento.descricao),
                            subtitle: Text(equipamento.especificacoes),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(context, equipamento),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

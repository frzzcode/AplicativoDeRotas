import 'package:flutter/material.dart';

import '../../data/models/ordem_servico.dart';
import '../../data/repositories/ordem_servico_repository.dart';
import 'nova_ordem_servico_screen.dart';

class OrdensServicoScreen extends StatefulWidget {
  const OrdensServicoScreen({super.key});

  @override
  State<OrdensServicoScreen> createState() => _OrdensServicoScreenState();
}

class _OrdensServicoScreenState extends State<OrdensServicoScreen> {
  final OrdemServicoRepository _repository = OrdemServicoRepository();
  final TextEditingController _pesquisaController = TextEditingController();
  late Future<List<OrdemServico>> _ordensFuture;
  String _filtroStatus = 'Todas';

  @override
  void initState() {
    super.initState();
    _carregarOrdens();
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  void _carregarOrdens() {
    // setState deve apenas atualizar o estado da tela. A consulta ao banco é
    // assíncrona, então guardamos o Future sem retorná-lo para o setState.
    setState(() {
      _ordensFuture = _repository.listarTodas();
    });
  }

  List<OrdemServico> _filtrar(List<OrdemServico> ordens) {
    final termo = _pesquisaController.text.trim().toLowerCase();
    return ordens.where((ordem) {
      final correspondeStatus =
          _filtroStatus == 'Todas' || ordem.status == _filtroStatus;
      final texto = [
        ordem.id?.toString(),
        ordem.clienteNome,
        ordem.equipamentoDescricao,
      ].whereType<String>().join(' ').toLowerCase();
      return correspondeStatus && (termo.isEmpty || texto.contains(termo));
    }).toList();
  }

  String _formatarData(String data) {
    final partes = data.split('-');
    return partes.length == 3 ? '${partes[2]}/${partes[1]}/${partes[0]}' : data;
  }

  Color _corStatus(BuildContext context, String status) {
    return switch (status) {
      'Finalizada' => Colors.green,
      'Cancelada' => Colors.red,
      'Aguardando peça' => Colors.orange,
      'Em atendimento' => Colors.blue,
      _ => Theme.of(context).colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ordens de serviço')),
      body: FutureBuilder<List<OrdemServico>>(
        future: _ordensFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final todasOrdens = snapshot.data ?? [];
          final ordens = _filtrar(todasOrdens);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _pesquisaController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Pesquisar ordens',
                    hintText: 'Cliente, equipamento ou número da OS',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _pesquisaController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Limpar pesquisa',
                            onPressed: () {
                              _pesquisaController.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: ['Todas', 'Aberta', 'Agendada', 'Em atendimento', 'Aguardando peça', 'Finalizada']
                      .map(
                        (status) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(status),
                            selected: _filtroStatus == status,
                            onSelected: (_) => setState(() => _filtroStatus = status),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(
                child: todasOrdens.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma ordem de serviço criada.\nToque no + para começar.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ordens.isEmpty
                    ? const Center(child: Text('Nenhuma ordem encontrada.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: ordens.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final ordem = ordens[index];
                          final cor = _corStatus(context, ordem.status);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'OS #${ordem.id}',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const Spacer(),
                                      Chip(
                                        label: Text(ordem.status),
                                        labelStyle: TextStyle(color: cor),
                                        side: BorderSide(color: cor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    ordem.clienteNome ?? 'Cliente não encontrado',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(ordem.equipamentoDescricao ?? 'Equipamento não encontrado'),
                                  const Divider(height: 24),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 18),
                                      const SizedBox(width: 6),
                                      Text(_formatarData(ordem.dataAtendimento)),
                                      const Spacer(),
                                      if (ordem.valor != null)
                                        Text(
                                          'R\$ ${ordem.valor!.toStringAsFixed(2).replaceAll('.', ',')}',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final criada = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const NovaOrdemServicoScreen()),
          );
          if (criada == true) _carregarOrdens();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova OS'),
      ),
    );
  }
}

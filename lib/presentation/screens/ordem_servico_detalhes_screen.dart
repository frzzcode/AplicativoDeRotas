import 'package:flutter/material.dart';

import '../../data/models/ordem_servico.dart';
import '../../data/repositories/ordem_servico_repository.dart';
import 'nova_ordem_servico_screen.dart';

class OrdemServicoDetalhesScreen extends StatefulWidget {
  final OrdemServico ordem;

  const OrdemServicoDetalhesScreen({super.key, required this.ordem});

  @override
  State<OrdemServicoDetalhesScreen> createState() =>
      _OrdemServicoDetalhesScreenState();
}

class _OrdemServicoDetalhesScreenState extends State<OrdemServicoDetalhesScreen> {
  final OrdemServicoRepository _repository = OrdemServicoRepository();
  late OrdemServico _ordem;

  @override
  void initState() {
    super.initState();
    _ordem = widget.ordem;
  }

  String _formatarData(String? data) {
    if (data == null || data.isEmpty) return 'Não informada';
    final partes = data.split('-');
    return partes.length == 3 ? '${partes[2]}/${partes[1]}/${partes[0]}' : data;
  }

  Future<void> _editar() async {
    final alterada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NovaOrdemServicoScreen(ordem: _ordem)),
    );
    if (alterada != true || !mounted) return;

    final atualizada = await _repository.buscarPorId(_ordem.id!);
    if (atualizada == null) return;
    setState(() => _ordem = atualizada);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OS #${_ordem.id}'),
        actions: [
          IconButton(
            tooltip: 'Editar OS',
            onPressed: _editar,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Chip(label: Text(_ordem.status)),
              const SizedBox(width: 8),
              Chip(label: Text('Prioridade: ${_ordem.prioridade}')),
            ],
          ),
          const SizedBox(height: 16),
          _InfoItem(
            icone: Icons.person_outline,
            titulo: 'Cliente',
            valor: _ordem.clienteNome ?? 'Cliente #${_ordem.clienteId}',
          ),
          _InfoItem(
            icone: Icons.ac_unit_outlined,
            titulo: 'Equipamento',
            valor: _ordem.equipamentoDescricao ?? 'Equipamento #${_ordem.equipamentoId}',
          ),
          _InfoItem(
            icone: Icons.calendar_today_outlined,
            titulo: 'Data do atendimento',
            valor: _formatarData(_ordem.dataAtendimento),
          ),
          _InfoItem(
            icone: Icons.report_problem_outlined,
            titulo: 'Problema informado',
            valor: _ordem.problema,
          ),
          if (_ordem.servicoRealizado?.isNotEmpty ?? false)
            _InfoItem(
              icone: Icons.build_outlined,
              titulo: 'Serviço realizado',
              valor: _ordem.servicoRealizado!,
            ),
          _InfoItem(
            icone: Icons.local_shipping_outlined,
            titulo: 'Atendimento / recolhimento',
            valor: _ordem.recolhimento,
          ),
          _InfoItem(
            icone: Icons.extension_outlined,
            titulo: 'Necessita de peça?',
            valor: _ordem.precisaPeca ? 'Sim' : 'Não',
          ),
          _InfoItem(
            icone: Icons.event_available_outlined,
            titulo: 'Previsão de conclusão',
            valor: _formatarData(_ordem.dataPrevista),
          ),
          if (_ordem.valor != null)
            _InfoItem(
              icone: Icons.attach_money_outlined,
              titulo: 'Valor do serviço',
              valor: 'R\$ ${_ordem.valor!.toStringAsFixed(2).replaceAll('.', ',')}',
            ),
          if (_ordem.observacoes?.isNotEmpty ?? false)
            _InfoItem(
              icone: Icons.notes_outlined,
              titulo: 'Observações',
              valor: _ordem.observacoes!,
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _editar,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar OS'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String valor;

  const _InfoItem({
    required this.icone,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(valor, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

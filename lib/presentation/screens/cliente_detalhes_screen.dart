import 'package:flutter/material.dart';

import '../../data/models/cliente.dart';
import '../../data/repositories/cliente_repository.dart';
import 'novo_cliente_screen.dart';

class ClienteDetalhesScreen extends StatefulWidget {
  final Cliente cliente;

  const ClienteDetalhesScreen({super.key, required this.cliente});

  @override
  State<ClienteDetalhesScreen> createState() => _ClienteDetalhesScreenState();
}

class _ClienteDetalhesScreenState extends State<ClienteDetalhesScreen> {
  final ClienteRepository _repository = ClienteRepository();
  late Cliente _cliente;

  @override
  void initState() {
    super.initState();
    _cliente = widget.cliente;
  }

  Future<void> _editarCliente() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NovoClienteScreen(cliente: _cliente)),
    );

    if (!mounted) return;
    final clienteAtualizado = await _repository.buscarPorId(_cliente.id!);
    if (clienteAtualizado == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _cliente = clienteAtualizado);
  }

  Future<void> _excluirCliente() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text('"${_cliente.nome}" será removido permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    await _repository.excluir(_cliente.id!);
    if (mounted) Navigator.pop(context, true);
  }

  String _enderecoCompleto() {
    final partes = [
      _cliente.endereco,
      _cliente.numero,
      _cliente.complemento,
      _cliente.bairro,
      _cliente.cidade,
    ].where((item) => item != null && item.trim().isNotEmpty);
    return partes.isEmpty ? 'Endereço não informado' : partes.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
        actions: [
          IconButton(
            tooltip: 'Excluir cliente',
            icon: const Icon(Icons.delete_outline),
            onPressed: _excluirCliente,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 34,
            child: Text(
              _cliente.nome.isEmpty ? '?' : _cliente.nome[0].toUpperCase(),
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _cliente.nome,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'ID do cliente: #${_cliente.id}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _InfoItem(
            icone: Icons.phone_outlined,
            titulo: 'Telefone',
            valor: _cliente.telefone ?? 'Não informado',
          ),
          _InfoItem(
            icone: Icons.location_on_outlined,
            titulo: 'Endereço',
            valor: _enderecoCompleto(),
          ),
          if (_cliente.observacoes?.trim().isNotEmpty ?? false)
            _InfoItem(
              icone: Icons.notes_outlined,
              titulo: 'Observações',
              valor: _cliente.observacoes!,
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _editarCliente,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar cliente', style: TextStyle(fontSize: 16)),
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

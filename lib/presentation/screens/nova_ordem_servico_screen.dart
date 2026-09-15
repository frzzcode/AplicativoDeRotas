import 'package:flutter/material.dart';

import '../../data/models/cliente.dart';
import '../../data/models/equipamento.dart';
import '../../data/models/ordem_servico.dart';
import '../../data/repositories/cliente_repository.dart';
import '../../data/repositories/ordem_servico_repository.dart';
import 'selecionar_equipamento_screen.dart';

class NovaOrdemServicoScreen extends StatefulWidget {
  const NovaOrdemServicoScreen({super.key});

  @override
  State<NovaOrdemServicoScreen> createState() => _NovaOrdemServicoScreenState();
}

class _NovaOrdemServicoScreenState extends State<NovaOrdemServicoScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClienteRepository _clienteRepository = ClienteRepository();
  final OrdemServicoRepository _ordemRepository = OrdemServicoRepository();
  final _problemaController = TextEditingController();
  final _servicoController = TextEditingController();
  final _valorController = TextEditingController();
  final _observacoesController = TextEditingController();

  late Future<List<Cliente>> _clientesFuture;
  Cliente? _cliente;
  Equipamento? _equipamento;
  DateTime _dataAtendimento = DateTime.now();
  DateTime? _dataPrevista;
  String _status = 'Aberta';
  String _prioridade = 'Normal';
  String _recolhimento = 'No local';
  bool _precisaPeca = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _clientesFuture = _clienteRepository.listarTodos();
  }

  @override
  void dispose() {
    _problemaController.dispose();
    _servicoController.dispose();
    _valorController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';

  String _dataBanco(DateTime data) =>
      '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';

  Future<void> _escolherData({required bool prevista}) async {
    final selecionada = await showDatePicker(
      context: context,
      initialDate: prevista ? (_dataPrevista ?? _dataAtendimento) : _dataAtendimento,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (selecionada == null) return;
    setState(() {
      if (prevista) {
        _dataPrevista = selecionada;
      } else {
        _dataAtendimento = selecionada;
      }
    });
  }

  Future<void> _selecionarEquipamento() async {
    final selecionado = await Navigator.push<Equipamento>(
      context,
      MaterialPageRoute(builder: (_) => const SelecionarEquipamentoScreen()),
    );
    if (selecionado != null) setState(() => _equipamento = selecionado);
  }

  double? _valorNumerico() {
    var texto = _valorController.text.trim();
    // Aceita tanto 180,50 (padrão brasileiro) quanto 180.50.
    if (texto.contains(',')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    }
    return texto.isEmpty ? null : double.tryParse(texto);
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cliente == null || _equipamento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o cliente e o equipamento.')),
      );
      return;
    }

    setState(() => _salvando = true);
    await _ordemRepository.inserir(
      OrdemServico(
        clienteId: _cliente!.id!,
        equipamentoId: _equipamento!.id!,
        dataAtendimento: _dataBanco(_dataAtendimento),
        problema: _problemaController.text.trim(),
        servicoRealizado: _textoOuNulo(_servicoController),
        valor: _valorNumerico(),
        prioridade: _prioridade,
        status: _status,
        precisaPeca: _precisaPeca,
        recolhimento: _recolhimento,
        dataPrevista: _dataPrevista == null ? null : _dataBanco(_dataPrevista!),
        observacoes: _textoOuNulo(_observacoesController),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  String? _textoOuNulo(TextEditingController controller) {
    final texto = controller.text.trim();
    return texto.isEmpty ? null : texto;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova ordem de serviço')),
      body: FutureBuilder<List<Cliente>>(
        future: _clientesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final clientes = snapshot.data ?? [];
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Cliente', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<Cliente>(
                  value: _cliente,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    hintText: 'Selecione o cliente',
                  ),
                  items: clientes
                      .map(
                        (cliente) => DropdownMenuItem(
                          value: cliente,
                          child: Text('ID #${cliente.id} — ${cliente.nome}'),
                        ),
                      )
                      .toList(),
                  onChanged: (cliente) => setState(() => _cliente = cliente),
                  validator: (valor) => valor == null ? 'Selecione um cliente' : null,
                ),
                if (clientes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Cadastre um cliente antes de criar uma OS.'),
                  ),
                const SizedBox(height: 24),
                Text('Equipamento', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _selecionarEquipamento,
                  icon: const Icon(Icons.ac_unit_outlined),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _equipamento == null
                          ? 'Selecionar ar-condicionado'
                          : '${_equipamento!.descricao}\n${_equipamento!.especificacoes}',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _problemaController,
                  decoration: const InputDecoration(
                    labelText: 'Defeito ou problema informado',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Descreva o problema informado'
                      : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Data do atendimento'),
                  subtitle: Text(_formatarData(_dataAtendimento)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _escolherData(prevista: false),
                ),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    'Aberta', 'Agendada', 'Em atendimento', 'Aguardando peça',
                    'Equipamento recolhido', 'Em manutenção', 'Finalizada', 'Cancelada',
                  ].map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                  onChanged: (valor) => setState(() => _status = valor!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _prioridade,
                  decoration: const InputDecoration(
                    labelText: 'Prioridade',
                    border: OutlineInputBorder(),
                  ),
                  items: const ['Baixa', 'Normal', 'Alta']
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (valor) => setState(() => _prioridade = valor!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _recolhimento,
                  decoration: const InputDecoration(
                    labelText: 'Atendimento / recolhimento',
                    border: OutlineInputBorder(),
                  ),
                  items: const ['No local', 'Recolher equipamento', 'Entregar posteriormente']
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (valor) => setState(() => _recolhimento = valor!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Necessita de peça?'),
                  value: _precisaPeca,
                  onChanged: (valor) => setState(() => _precisaPeca = valor),
                ),
                TextFormField(
                  controller: _valorController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor do serviço',
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _servicoController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Serviço realizado',
                    border: OutlineInputBorder(),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Previsão de conclusão'),
                  subtitle: Text(_dataPrevista == null ? 'Não informada' : _formatarData(_dataPrevista!)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _escolherData(prevista: true),
                ),
                TextFormField(
                  controller: _observacoesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _salvando ? null : _salvar,
                    icon: _salvando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Salvar ordem de serviço'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

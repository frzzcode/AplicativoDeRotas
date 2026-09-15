import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/parada_rota.dart';
import '../../data/repositories/cliente_repository.dart';
import '../../data/repositories/ordem_servico_repository.dart';
import '../../data/services/rota_service.dart';

class RotasScreen extends StatefulWidget {
  const RotasScreen({super.key});

  @override
  State<RotasScreen> createState() => _RotasScreenState();
}

class _RotasScreenState extends State<RotasScreen> {
  final _origem = TextEditingController();
  final _busca = TextEditingController();
  final _selecionadas = <String, ParadaRota>{};
  List<ParadaRota> _opcoes = [];
  String _modo = 'OS';
  String? _destino;
  String? _erro;
  bool _carregando = false;
  bool _gerando = false;
  int _versao = 0;
  ResultadoRota? _resultado;
  List<ParadaRota> _sequencia = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _origem.dispose();
    _busca.dispose();
    super.dispose();
  }

  void _invalidar() {
    _resultado = null;
    _sequencia = [];
  }

  Future<void> _carregar() async {
    final versao = ++_versao;
    setState(() {
      _carregando = true;
      _erro = null;
      _invalidar();
    });
    try {
      final clientes = await ClienteRepository().listarTodos();
      final porId = {for (final c in clientes) c.id: c};
      final opcoes = <ParadaRota>[];
      if (_modo == 'OS') {
        final ordens = await OrdemServicoRepository().listarTodas();
        for (final os in ordens) {
          final c = porId[os.clienteId];
          if (c != null) {
            opcoes.add(
              ParadaRota(
                chave: 'os:${os.id}',
                titulo: 'OS #${os.id} — ${c.nome}',
                cliente: c,
              ),
            );
          }
        }
      } else {
        for (final c in clientes) {
          opcoes.add(
            ParadaRota(
              chave: 'cliente:${c.id}',
              titulo: '#${c.id} — ${c.nome}',
              cliente: c,
            ),
          );
        }
      }
      if (!mounted || versao != _versao) return;
      setState(() {
        _opcoes = opcoes;
        final atuais = {for (final p in opcoes) p.chave: p};
        _selecionadas.removeWhere((id, _) => !atuais.containsKey(id));
        for (final id in _selecionadas.keys.toList()) {
          _selecionadas[id] = atuais[id]!;
        }
        if (!_selecionadas.containsKey(_destino)) _destino = null;
      });
    } catch (_) {
      if (mounted && versao == _versao) {
        setState(
          () => _erro =
              'Não foi possível carregar os cadastros. Tente atualizar.',
        );
      }
    } finally {
      if (mounted && versao == _versao) setState(() => _carregando = false);
    }
  }

  void _selecionar(ParadaRota parada, bool adicionar) {
    if (adicionar && _selecionadas.length >= 25) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O Google permite até 25 paradas nesta rota.'),
        ),
      );
      return;
    }
    setState(() {
      if (adicionar) {
        _selecionadas[parada.chave] = parada;
      } else {
        _selecionadas.remove(parada.chave);
      }
      if (!_selecionadas.containsKey(_destino)) _destino = null;
      _invalidar();
    });
  }

  Future<void> _gerar() async {
    if (_gerando) return;
    if (_origem.text.trim().isEmpty || _selecionadas.isEmpty) {
      setState(
        () => _erro =
            'Informe o endereço de origem e selecione pelo menos uma parada.',
      );
      return;
    }
    final paradas = _selecionadas.values.toList();
    if (paradas.any((p) => !p.enderecoValido)) {
      setState(
        () => _erro =
            'Complete rua e cidade no cadastro dos clientes selecionados.',
      );
      return;
    }
    setState(() {
      _gerando = true;
      _erro = null;
      _invalidar();
    });
    try {
      final fim = _destino == null
          ? null
          : paradas.indexWhere((p) => p.chave == _destino);
      final resultado = await RotaService().gerar(
        _origem.text.trim(),
        paradas.map((p) => p.endereco).toList(),
        fim,
      );
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _sequencia = resultado.ordem.map((i) => paradas[i]).toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Future<void> _abrirMaps(List<String> pontos) async {
    // No navegador móvel, Maps URLs aceita até 3 paradas intermediárias.
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': pontos.first,
      'destination': pontos.last,
      'travelmode': 'driving',
      if (pontos.length > 2)
        'waypoints': pontos.sublist(1, pontos.length - 1).join('|'),
    });
    try {
      if (url.toString().length > 2048) {
        throw Exception(
          'Endereços longos demais. Abra cada trecho separadamente.',
        );
      }
      await const MethodChannel('tcc_rotas/maps')
          .invokeMethod<void>('abrir', url.toString());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o Google Maps. Tente abrir um trecho individual.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final termo = _busca.text.trim().toLowerCase().replaceFirst('#', '');
    final opcoes = _opcoes
        .where(
          (p) =>
              termo.isEmpty ||
              (int.tryParse(termo) != null
                  ? p.chave.split(':').last == termo
                  : p.titulo.toLowerCase().contains(termo)),
        )
        .toList();
    final pontos = [
      _origem.text.trim(),
      ..._sequencia.map((p) => p.endereco),
      if (_destino == null) _origem.text.trim(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planejar rota'),
        actions: [
          IconButton(
            tooltip: 'Atualizar clientes e OS',
            onPressed: _gerando || _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Escolha os atendimentos e confira os endereços antes de gerar a rota.',
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'OS',
                label: Text('Por OS'),
                icon: Icon(Icons.build_outlined),
              ),
              ButtonSegment(
                value: 'Cliente',
                label: Text('Por cliente'),
                icon: Icon(Icons.people_outline),
              ),
            ],
            selected: {_modo},
            onSelectionChanged: _gerando
                ? null
                : (valores) {
                    setState(() {
                      _modo = valores.first;
                      _selecionadas.clear();
                      _destino = null;
                      _busca.clear();
                    });
                    _carregar();
                  },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _origem,
            enabled: !_gerando,
            onChanged: (_) => setState(_invalidar),
            decoration: const InputDecoration(
              labelText: 'Origem: casa ou oficina',
              hintText: 'Rua, número, cidade e UF',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _busca,
            enabled: !_gerando,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _modo == 'OS'
                  ? 'Selecionar OS pelo ID'
                  : 'Pesquisar cliente por ID ou nome',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_selecionadas.length}/25 selecionadas. Pesquise e marque uma por vez; a seleção é acumulada.',
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final p in _selecionadas.values)
                InputChip(
                  label: Text(p.titulo),
                  onDeleted: _gerando ? null : () => _selecionar(p, false),
                ),
            ],
          ),
          if (_carregando)
            const LinearProgressIndicator()
          else
            SizedBox(
              height: 240,
              child: opcoes.isEmpty
                  ? const Center(child: Text('Nenhum cadastro encontrado.'))
                  : ListView.builder(
                      itemCount: opcoes.length,
                      itemBuilder: (context, i) {
                        final p = opcoes[i];
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(p.titulo),
                          subtitle: Text(
                            p.enderecoValido ? p.endereco : 'Complete rua e cidade no cadastro do cliente.',
                          ),
                          value: _selecionadas.containsKey(p.chave),
                          onChanged: _gerando || !p.enderecoValido
                              ? null
                              : (v) => _selecionar(p, v!),
                        );
                      },
                    ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(_destino),
            initialValue: _destino ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Onde a rota termina?',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Voltar à origem')),
              for (final p in _selecionadas.values)
                DropdownMenuItem(
                  value: p.chave,
                  child: Text(p.titulo, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _gerando
                ? null
                : (v) => setState(() {
                    _destino = v == '' ? null : v;
                    _invalidar();
                  }),
          ),
          const SizedBox(height: 8),
          const Text(
            'O ponto final fica fixo. O Google reorganiza os demais atendimentos. Prioridades ainda não são consideradas.',
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _gerando || _carregando ? null : _gerar,
            icon: const Icon(Icons.route),
            label: Text(_gerando ? 'Calculando…' : 'Gerar rota otimizada'),
          ),
          if (_resultado != null) ...[
            const Divider(height: 32),
            Text(
              'Sequência recomendada pelo Google Maps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${(_resultado!.metros / 1000).toStringAsFixed(1)} km • ${(_resultado!.segundos / 60).ceil()} min de deslocamento',
            ),
            const Text(
              'Estimativa sem tempo de serviço ou trânsito em tempo real. Confira o destino no mapa antes de sair.',
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Origem'),
              subtitle: Text(_origem.text),
            ),
            for (var i = 0; i < _sequencia.length; i++)
              ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(_sequencia[i].titulo),
                subtitle: Text(_sequencia[i].endereco),
                trailing: IconButton(
                  tooltip: 'Abrir trecho no Maps',
                  icon: const Icon(Icons.directions),
                  onPressed: () => _abrirMaps([pontos[i], pontos[i + 1]]),
                ),
              ),
            if (_destino == null)
              ListTile(
                title: const Text('Retorno à origem'),
                subtitle: Text(_origem.text),
                trailing: IconButton(
                  tooltip: 'Abrir retorno no Maps',
                  icon: const Icon(Icons.directions),
                  onPressed: () =>
                      _abrirMaps([pontos[pontos.length - 2], pontos.last]),
                ),
              ),
            // Divide apenas a abertura no Maps. A otimização considera todas as paradas juntas.
            for (var inicio = 0; inicio < pontos.length - 1; inicio += 4)
              OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  pontos.length <= 5
                      ? 'Ver rota no Google Maps'
                      : 'Ver parte ${inicio ~/ 4 + 1} no Google Maps',
                ),
                onPressed: () => _abrirMaps(
                  pontos.sublist(inicio, (inicio + 5).clamp(0, pontos.length)),
                ),
              ),
            if (pontos.length > 5)
              const Text(
                'O Google Maps será aberto em partes para respeitar o limite de paradas dos links em celulares. Siga as partes em ordem.',
              ),
          ],
        ],
      ),
    );
  }
}

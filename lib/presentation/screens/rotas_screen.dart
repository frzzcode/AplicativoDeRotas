import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/parada_rota.dart';
import '../../data/models/rota_ativa.dart';
import '../../data/repositories/cliente_repository.dart';
import '../../data/repositories/ordem_servico_repository.dart';
import '../../data/repositories/rota_repository.dart';
import '../../data/services/navegacao_service.dart';
import '../../data/services/rota_service.dart';
import '../widgets/rota_mapa.dart';

class RotasScreen extends StatefulWidget {
  const RotasScreen({super.key});

  @override
  State<RotasScreen> createState() => _RotasScreenState();
}

class _RotasScreenState extends State<RotasScreen> {
  final _origem = TextEditingController();
  final _cepOrigem = TextEditingController();
  final _busca = TextEditingController();
  final _selecionadas = <String, ParadaRota>{};
  final _rotas = RotaRepository();
  final _navegacao = NavegacaoService();
  List<ParadaRota> _opcoes = [];
  String _modo = 'OS';
  String? _destino;
  String? _erro;
  bool _carregando = false;
  bool _gerando = false;
  bool _atualizandoRota = false;
  int _versao = 0;
  RotaAtiva? _rotaAtiva;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _origem.dispose();
    _cepOrigem.dispose();
    _busca.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _carregar();
    await _carregarRotaAtiva();
  }

  Future<void> _carregarRotaAtiva() async {
    try {
      final rota = await _rotas.buscarAtiva();
      if (!mounted || rota == null) return;
      setState(() {
        _rotaAtiva = rota;
        if (_origem.text.isEmpty) _origem.text = rota.origemDescricao;
        if (_cepOrigem.text.isEmpty) _cepOrigem.text = rota.cepOrigem;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro =
              'A rota salva não pôde ser carregada. Gere uma nova rota.',
        );
      }
    }
  }

  Future<void> _carregar() async {
    final versao = ++_versao;
    setState(() {
      _carregando = true;
      _erro = null;
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
    if (adicionar && _selecionadas.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione no máximo 20 paradas por rota.'),
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
    if (_cepOrigem.text.replaceAll(RegExp(r'\D'), '').length != 8) {
      setState(() => _erro = 'Informe os 8 números do CEP da origem.');
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
    });
    try {
      final fim = _destino == null
          ? null
          : paradas.indexWhere((p) => p.chave == _destino);
      final resultado = await RotaService().gerar(
        _origem.text.trim(),
        _cepOrigem.text.trim(),
        paradas,
        fim,
      );
      final sequencia = resultado.ordem.map((i) => paradas[i]).toList();
      final rota = await _rotas.salvarAtiva(
        RotaAtiva(
          criadaEm: DateTime.now(),
          modo: _modo,
          origemDescricao: _origem.text.trim(),
          cepOrigem: _cepOrigem.text.trim(),
          origem: resultado.origem,
          metros: resultado.metros,
          segundos: resultado.segundos,
          retornaOrigem: _destino == null,
          geometria: resultado.geometria,
          itens: [
            for (var i = 0; i < sequencia.length; i++)
              ItemRotaAtiva(
                posicao: i,
                chave: sequencia[i].chave,
                titulo: sequencia[i].titulo,
                endereco: sequencia[i].endereco,
                coordenada: resultado.coordenadasParadas[i],
              ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() {
        _rotaAtiva = rota;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  ResultadoRota _resultadoPersistido(RotaAtiva rota) {
    return ResultadoRota(
      ordem: List.generate(rota.itens.length, (indice) => indice),
      metros: rota.metros,
      segundos: rota.segundos,
      origem: rota.origem,
      coordenadasParadas: rota.itens.map((item) => item.coordenada).toList(),
      geometria: rota.geometria,
    );
  }

  Future<void> _abrirProximaParada() async {
    final rota = _rotaAtiva;
    if (rota == null || rota.concluida) return;
    final proxima = rota.proximaParada;
    final titulo = proxima?.titulo ?? 'Retorno à origem';
    final coordenada = proxima?.coordenada ?? rota.origem;
    final escolha = await showModalBottomSheet<_Navegador>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Navegar até $titulo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'O navegador usará sua localização atual e poderá ajustar o caminho conforme o trânsito.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _Navegador.googleMaps),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Abrir no Google Maps'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, _Navegador.waze),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Abrir no Waze'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || escolha == null) return;
    final uri = escolha == _Navegador.googleMaps
        ? _navegacao.googleMapsAte(coordenada)
        : _navegacao.wazeAte(coordenada);
    await _abrirNavegador(uri);
  }

  Future<void> _abrirRotaCompleta() async {
    final rota = _rotaAtiva;
    if (rota == null || !rota.permiteRotaCompletaGoogle) return;
    await _abrirNavegador(_navegacao.googleMapsRotaCompleta(rota));
  }

  Future<void> _abrirNavegador(Uri uri) async {
    try {
      await _navegacao.abrir(uri);
    } catch (erro) {
      if (!mounted) return;
      final mensagem = erro.toString().replaceFirst('Exception: ', '');
      setState(() => _erro = mensagem);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagem)));
    }
  }

  Future<void> _concluirProximaEtapa() async {
    final rota = _rotaAtiva;
    if (rota?.id == null || _atualizandoRota) return;
    setState(() {
      _atualizandoRota = true;
      _erro = null;
    });
    try {
      final atualizada = await _rotas.concluirProximaEtapa(rota!.id!);
      if (!mounted) return;
      setState(() => _rotaAtiva = atualizada);
      if (atualizada.concluida) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rota concluída com sucesso.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = 'Não foi possível atualizar o progresso da rota.',
        );
      }
    } finally {
      if (mounted) setState(() => _atualizandoRota = false);
    }
  }

  Future<void> _encerrarRota() async {
    final rota = _rotaAtiva;
    if (rota?.id == null) return;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encerrar rota?'),
        content: const Text(
          'A rota deixará de aparecer como ativa. Os clientes e ordens de serviço não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmou != true) return;
    try {
      await _rotas.encerrar(rota!.id!);
      if (mounted) setState(() => _rotaAtiva = null);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível encerrar a rota.');
      }
    }
  }

  Widget _painelNavegacao(RotaAtiva rota) {
    final proxima = rota.proximaParada;
    final titulo =
        proxima?.titulo ??
        (rota.aguardandoRetorno ? 'Retorno à origem' : 'Rota concluída');
    final descricao =
        proxima?.endereco ??
        (rota.aguardandoRetorno
            ? rota.origemDescricao
            : 'Todos os deslocamentos foram concluídos.');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  rota.concluida ? Icons.check_circle : Icons.navigation,
                  color: rota.concluida
                      ? const Color(0xFF2E7D32)
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(descricao),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: rota.concluida ? 1 : rota.progresso),
            const SizedBox(height: 6),
            Text(
              '${rota.paradasConcluidas}/${rota.itens.length} atendimentos concluídos',
            ),
            if (!rota.concluida) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _atualizandoRota ? null : _abrirProximaParada,
                icon: const Icon(Icons.navigation),
                label: Text(
                  rota.aguardandoRetorno
                      ? 'Navegar de volta à origem'
                      : 'Iniciar navegação',
                ),
              ),
              if (rota.etapasConcluidas == 0 &&
                  rota.permiteRotaCompletaGoogle) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _abrirRotaCompleta,
                  icon: const Icon(Icons.alt_route),
                  label: const Text('Abrir rota completa no Google Maps'),
                ),
              ] else if (rota.etapasConcluidas == 0) ...[
                const SizedBox(height: 8),
                const Text(
                  'Esta rota possui muitos pontos para um único link móvel. Navegue uma parada por vez para manter toda a sequência.',
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _atualizandoRota ? null : _concluirProximaEtapa,
                icon: const Icon(Icons.task_alt),
                label: Text(
                  rota.aguardandoRetorno
                      ? 'Finalizar retorno e encerrar'
                      : 'Marcar atendimento como concluído',
                ),
              ),
              TextButton(
                onPressed: _atualizandoRota ? null : _encerrarRota,
                child: const Text('Encerrar rota'),
              ),
            ] else
              TextButton(
                onPressed: () => setState(() => _rotaAtiva = null),
                child: const Text('Fechar resultado'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _secaoRotaAtiva(RotaAtiva rota, ResultadoRota resultado) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          rota.concluida ? 'Rota concluída' : 'Rota ativa',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${(rota.metros / 1000).toStringAsFixed(1)} km • ${(rota.segundos / 60).ceil()} min de deslocamento',
        ),
        const Text(
          'A sequência foi otimizada pelo aplicativo. Google Maps ou Waze podem ajustar as ruas conforme o trânsito em tempo real.',
        ),
        const SizedBox(height: 16),
        RotaMapa(
          resultado: resultado,
          onNavegar: rota.concluida ? null : _abrirProximaParada,
        ),
        const SizedBox(height: 12),
        _painelNavegacao(rota),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.home_outlined),
          title: const Text('Origem'),
          subtitle: Text(rota.origemDescricao),
        ),
        for (final item in rota.itens)
          ListTile(
            leading: CircleAvatar(
              child: item.concluido
                  ? const Icon(Icons.check, size: 20)
                  : Text('${item.posicao + 1}'),
            ),
            title: Text(item.titulo),
            subtitle: Text(item.endereco),
            trailing: !item.concluido && item.id == rota.proximaParada?.id
                ? const Chip(label: Text('Próxima'))
                : null,
          ),
        if (rota.retornaOrigem)
          ListTile(
            leading: CircleAvatar(
              child: rota.retornoConcluido
                  ? const Icon(Icons.check, size: 20)
                  : const Icon(Icons.home_outlined, size: 20),
            ),
            title: const Text('Retorno à origem'),
            subtitle: Text(rota.origemDescricao),
            trailing: rota.aguardandoRetorno
                ? const Chip(label: Text('Próxima'))
                : null,
          ),
      ],
    );
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
    final rota = _rotaAtiva;
    final resultado = rota == null ? null : _resultadoPersistido(rota);
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
          if (rota != null && resultado != null) ...[
            _secaoRotaAtiva(rota, resultado),
            const Divider(height: 40),
            Text(
              'Planejar nova rota',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
          ],
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
            decoration: const InputDecoration(
              labelText: 'Origem: casa ou oficina',
              hintText: 'Rua, número, cidade e UF',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cepOrigem,
            enabled: !_gerando,
            keyboardType: TextInputType.number,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'CEP da origem',
              hintText: 'Informe os 8 números',
              helperText:
                  'Necessário para localizar casa ou oficina com precisão.',
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
            '${_selecionadas.length}/20 selecionadas. Pesquise e marque uma por vez; a seleção é acumulada.',
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
                  }),
          ),
          const SizedBox(height: 8),
          const Text(
            'O ponto final fica fixo. O app reorganiza os demais atendimentos pela menor distância estimada nas ruas. Prioridades ainda não são consideradas.',
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
        ],
      ),
    );
  }
}

enum _Navegador { googleMaps, waze }

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/services/otimizador_rota.dart';
import '../models/coordenada.dart';
import '../models/parada_rota.dart';
import '../repositories/cliente_repository.dart';
import 'geocodificacao_service.dart';

class ResultadoRota {
  final List<int> ordem;
  final double metros;
  final double segundos;
  final Coordenada origem;
  final List<Coordenada> coordenadasParadas;
  final List<Coordenada> geometria;

  const ResultadoRota({
    required this.ordem,
    required this.metros,
    required this.segundos,
    required this.origem,
    required this.coordenadasParadas,
    required this.geometria,
  });
}

// Orquestra três tarefas independentes:
// 1. converte endereços em coordenadas (Nominatim/OpenStreetMap);
// 2. obtém distâncias rodoviárias e otimiza a sequência (OSRM);
// 3. pede ao OSRM o desenho final da rota para exibir no mapa.
class RotaService {
  static const _osrmHost = 'router.project-osrm.org';
  static const _headers = {
    'User-Agent': 'AplicativoDeRotas/1.0 (com.example.tcc_rotas_tecnico)',
  };

  final GeocodificacaoService _geocodificacao;
  final ClienteRepository _clientes;
  final OtimizadorRota _otimizador;

  RotaService({
    GeocodificacaoService? geocodificacao,
    ClienteRepository? clientes,
    OtimizadorRota? otimizador,
  }) : _geocodificacao = geocodificacao ?? GeocodificacaoService(),
       _clientes = clientes ?? ClienteRepository(),
       _otimizador = otimizador ?? OtimizadorRota();

  Future<ResultadoRota> gerar(
    String enderecoOrigem,
    List<ParadaRota> paradas,
    int? destino,
  ) async {
    if (enderecoOrigem.trim().isEmpty ||
        paradas.isEmpty ||
        paradas.length > 20 ||
        paradas.any((parada) => !parada.enderecoValido)) {
      throw Exception('Informe a origem e de 1 a 20 paradas válidas.');
    }
    if (destino != null && (destino < 0 || destino >= paradas.length)) {
      throw Exception('O destino final selecionado não é válido.');
    }

    try {
      final origem = await _localizarOrigem(enderecoOrigem);
      final cacheDaRota = <int, Coordenada>{};
      final coordenadas = <Coordenada>[];
      for (final parada in paradas) {
        coordenadas.add(await _localizarParada(parada, cacheDaRota));
      }

      final todosOsPontos = [origem, ...coordenadas];
      final matriz = await _consultarMatriz(todosOsPontos);
      final ordem = _otimizador.otimizar(matriz, destino: destino);
      final ordenadas = [for (final indice in ordem) coordenadas[indice]];
      final pontosDoTrajeto = [
        origem,
        ...ordenadas,
        if (destino == null) origem,
      ];
      final trajeto = await _consultarTrajeto(pontosDoTrajeto);

      return ResultadoRota(
        ordem: ordem,
        metros: trajeto.metros,
        segundos: trajeto.segundos,
        origem: origem,
        coordenadasParadas: ordenadas,
        geometria: trajeto.geometria,
      );
    } on TimeoutException {
      throw Exception('O cálculo demorou demais. Tente novamente.');
    } on http.ClientException {
      throw Exception(
        'Não foi possível acessar o serviço de rotas. Verifique a internet.',
      );
    } on FormatException {
      throw Exception('O serviço de rotas retornou dados inválidos.');
    }
  }

  Future<Coordenada> _localizarOrigem(String endereco) async {
    try {
      return await _geocodificacao.buscar(endereco.trim());
    } catch (erro) {
      throw Exception(
        'Não foi possível localizar a origem. Informe rua, número, cidade e, se possível, UF ou CEP. ${_mensagem(erro)}',
      );
    }
  }

  Future<Coordenada> _localizarParada(
    ParadaRota parada,
    Map<int, Coordenada> cacheDaRota,
  ) async {
    final cliente = parada.cliente;
    final id = cliente.id;
    if (id != null && cacheDaRota.containsKey(id)) return cacheDaRota[id]!;

    Coordenada coordenada;
    if (cliente.latitude != null && cliente.longitude != null) {
      coordenada = Coordenada(
        latitude: cliente.latitude!,
        longitude: cliente.longitude!,
      );
    } else {
      try {
        coordenada = await _geocodificacao.buscar(parada.endereco);
      } catch (erro) {
        throw Exception(
          'Não foi possível localizar ${parada.titulo}. Confira rua, número, cidade e, se possível, UF ou CEP. ${_mensagem(erro)}',
        );
      }
      if (id != null) {
        await _clientes.atualizarCoordenadas(
          id,
          coordenada.latitude,
          coordenada.longitude,
        );
      }
    }
    if (id != null) cacheDaRota[id] = coordenada;
    return coordenada;
  }

  Future<List<List<double>>> _consultarMatriz(List<Coordenada> pontos) async {
    final uri = Uri.https(
      _osrmHost,
      '/table/v1/driving/${pontos.map((ponto) => ponto.osrm).join(';')}',
      {'annotations': 'distance'},
    );
    final data = await _getJson(uri);
    _validarCodigo(data);
    final linhas = data['distances'] as List<dynamic>?;
    if (linhas == null || linhas.length != pontos.length) {
      throw const FormatException('Matriz ausente.');
    }
    return [
      for (final linha in linhas)
        [
          for (final valor in linha as List<dynamic>)
            if (valor == null)
              throw const FormatException('Trecho rodoviário inacessível.')
            else
              (valor as num).toDouble(),
        ],
    ];
  }

  Future<_TrajetoOsrm> _consultarTrajeto(List<Coordenada> pontos) async {
    final uri = Uri.https(
      _osrmHost,
      '/route/v1/driving/${pontos.map((ponto) => ponto.osrm).join(';')}',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'false'},
    );
    final data = await _getJson(uri);
    _validarCodigo(data);
    final rotas = data['routes'] as List<dynamic>?;
    if (rotas == null || rotas.isEmpty) {
      throw const FormatException('Rota ausente.');
    }
    final rota = rotas.first as Map<String, dynamic>;
    final geometria = rota['geometry'] as Map<String, dynamic>;
    final linhas = geometria['coordinates'] as List<dynamic>;
    return _TrajetoOsrm(
      metros: (rota['distance'] as num).toDouble(),
      segundos: (rota['duration'] as num).toDouble(),
      geometria: [
        for (final item in linhas)
          Coordenada(
            longitude: ((item as List<dynamic>)[0] as num).toDouble(),
            latitude: (item[1] as num).toDouble(),
          ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = http.Client();
    try {
      final resposta = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 35));
      if (resposta.statusCode == 429) {
        throw Exception(
          'O serviço público atingiu o limite de uso. Tente novamente mais tarde.',
        );
      }
      if (resposta.statusCode != 200) {
        throw Exception(
          'O serviço de rotas recusou o cálculo (${resposta.statusCode}).',
        );
      }
      return jsonDecode(resposta.body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  void _validarCodigo(Map<String, dynamic> data) {
    if (data['code'] != 'Ok') {
      throw Exception(
        data['code'] == 'NoRoute'
            ? 'Não existe um trajeto de carro entre todos os pontos.'
            : 'O serviço não conseguiu calcular essa rota.',
      );
    }
  }

  String _mensagem(Object erro) =>
      erro.toString().replaceFirst('Exception: ', '');
}

class _TrajetoOsrm {
  final double metros;
  final double segundos;
  final List<Coordenada> geometria;

  const _TrajetoOsrm({
    required this.metros,
    required this.segundos,
    required this.geometria,
  });
}

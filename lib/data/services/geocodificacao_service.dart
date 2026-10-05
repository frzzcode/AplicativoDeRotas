import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/coordenada.dart';

// Converte endereços em coordenadas sem exigir que o usuário conheça latitude
// e longitude. O CEP ajuda a completar o endereço, mas a coordenada final vem
// do Nominatim/OpenStreetMap para evitar pontos genéricos no centro da cidade.
class GeocodificacaoService {
  static DateTime? _ultimaConsultaNominatim;
  static const _headers = {
    'User-Agent': 'AplicativoDeRotas/1.0 (com.example.tcc_rotas_tecnico)',
    'Accept-Language': 'pt-BR,pt;q=0.9',
  };
  static const _nomesUf = {
    'AC': 'Acre',
    'AL': 'Alagoas',
    'AP': 'Amapá',
    'AM': 'Amazonas',
    'BA': 'Bahia',
    'CE': 'Ceará',
    'DF': 'Distrito Federal',
    'ES': 'Espírito Santo',
    'GO': 'Goiás',
    'MA': 'Maranhão',
    'MT': 'Mato Grosso',
    'MS': 'Mato Grosso do Sul',
    'MG': 'Minas Gerais',
    'PA': 'Pará',
    'PB': 'Paraíba',
    'PR': 'Paraná',
    'PE': 'Pernambuco',
    'PI': 'Piauí',
    'RJ': 'Rio de Janeiro',
    'RN': 'Rio Grande do Norte',
    'RS': 'Rio Grande do Sul',
    'RO': 'Rondônia',
    'RR': 'Roraima',
    'SC': 'Santa Catarina',
    'SP': 'São Paulo',
    'SE': 'Sergipe',
    'TO': 'Tocantins',
  };

  final http.Client? _client;

  // O nome público `client` deixa os testes legíveis; o campo permanece privado.
  // ignore: prefer_initializing_formals
  GeocodificacaoService({http.Client? client}) : _client = client;

  // A BrasilAPI é usada para transformar um CEP em rua, bairro, cidade e UF.
  // As coordenadas presentes na resposta não são usadas: alguns CEPs distintos
  // recebem o mesmo ponto aproximado, o que produz rotas falsas de 0 km.
  Future<Coordenada?> buscarPorCep(String cep) async {
    final dados = await _consultarCep(cep);
    if (dados == null || !dados.temEndereco) return null;

    final resultado = await _buscarEnderecoNoNominatim(
      logradouro: dados.logradouro!,
      bairro: dados.bairro,
      cidade: dados.cidade!,
      uf: dados.uf,
      cep: dados.cep,
    );
    if (resultado == null) {
      _log('CEP encontrado, mas o endereço não existe no OpenStreetMap.');
    }
    return resultado;
  }

  Future<Coordenada> buscarEndereco({
    required String logradouro,
    String? numero,
    String? bairro,
    required String cidade,
    String? uf,
    String? cep,
  }) async {
    // Primeiro tentamos o endereço completo digitado pelo usuário. Assim o
    // número do imóvel é preservado quando ele existe no OpenStreetMap.
    final peloEndereco = await _buscarEnderecoNoNominatim(
      logradouro: logradouro,
      numero: numero,
      bairro: bairro,
      cidade: cidade,
      uf: uf,
      cep: cep,
    );
    if (peloEndereco != null) return peloEndereco;

    // Se o texto cadastrado estiver incompleto ou com grafia diferente, o CEP
    // fornece os componentes oficiais do endereço para uma segunda tentativa.
    if (cep?.trim().isNotEmpty ?? false) {
      final porCep = await buscarPorCep(cep!);
      if (porCep != null) return porCep;
    }

    throw Exception('Endereço não encontrado. Confira rua, cidade, UF e CEP.');
  }

  Future<Coordenada> buscar(String endereco) async {
    final comBrasil = endereco.toLowerCase().contains('brasil')
        ? endereco.trim()
        : '${endereco.trim()}, Brasil';
    final expandido = _expandirUf(comBrasil);
    final semNumero = _removerNumeroDoImovel(expandido);
    final tentativas = <String>{expandido, comBrasil, semNumero};

    for (final tentativa in tentativas) {
      final resultado = await _consultarNominatim({'q': tentativa});
      if (resultado != null) return resultado;
    }
    throw Exception('Endereço não encontrado. Confira o CEP.');
  }

  Future<_DadosCep?> _consultarCep(String cep) async {
    final apenasNumeros = cep.replaceAll(RegExp(r'\D'), '');
    if (apenasNumeros.length != 8) {
      throw Exception('CEP inválido. Informe os 8 números do CEP.');
    }

    final uri = Uri.https('brasilapi.com.br', '/api/cep/v2/$apenasNumeros');
    final resposta = await _get(uri, const Duration(seconds: 20));
    if (resposta.statusCode == 404) {
      _log('BrasilAPI não encontrou o CEP.');
      return null;
    }
    if (resposta.statusCode != 200) {
      throw Exception(
        'O serviço de CEP recusou a consulta (${resposta.statusCode}).',
      );
    }

    final data = jsonDecode(resposta.body) as Map<String, dynamic>;
    final dados = _DadosCep(
      cep: apenasNumeros,
      logradouro: _texto(data['street']),
      bairro: _texto(data['neighborhood']),
      cidade: _texto(data['city']),
      uf: _texto(data['state']),
    );
    _log(
      dados.temEndereco
          ? 'BrasilAPI completou o endereço do CEP.'
          : 'BrasilAPI encontrou o CEP, mas não devolveu rua e cidade.',
    );
    return dados;
  }

  Future<Coordenada?> _buscarEnderecoNoNominatim({
    required String logradouro,
    String? numero,
    String? bairro,
    required String cidade,
    String? uf,
    String? cep,
  }) async {
    final rua = logradouro.trim();
    final cidadeLimpa = cidade.trim();
    final estado = uf?.trim().isNotEmpty ?? false
        ? _nomesUf[uf!.trim().toUpperCase()] ?? uf.trim()
        : null;
    final cepLimpo = cep?.trim();
    final numeroLimpo = numero?.trim();

    final tentativas = <Map<String, String>>[
      _consultaEstruturada(
        rua: [
          numeroLimpo,
          rua,
        ].whereType<String>().where((v) => v.isNotEmpty).join(' '),
        cidade: cidadeLimpa,
        estado: estado,
        cep: cepLimpo,
      ),
      _consultaEstruturada(
        rua: rua,
        cidade: cidadeLimpa,
        estado: estado,
        cep: cepLimpo,
      ),
      _consultaEstruturada(rua: rua, cidade: cidadeLimpa, estado: estado),
    ];

    final unicas = <String>{};
    for (final tentativa in tentativas) {
      final assinatura = tentativa.entries
          .map((item) => '${item.key}=${item.value}')
          .join('&');
      if (!unicas.add(assinatura)) continue;
      final resultado = await _consultarNominatim(tentativa);
      if (resultado != null) return resultado;
    }

    final livre = [
      rua,
      numeroLimpo,
      bairro,
      cidadeLimpa,
      estado,
      cepLimpo,
      'Brasil',
    ].whereType<String>().where((valor) => valor.trim().isNotEmpty).join(', ');
    return _consultarNominatim({'q': livre});
  }

  Map<String, String> _consultaEstruturada({
    required String rua,
    required String cidade,
    String? estado,
    String? cep,
  }) {
    final consulta = <String, String>{
      'street': rua,
      'city': cidade,
      'country': 'Brasil',
    };
    if (estado != null) consulta['state'] = estado;
    if (cep?.isNotEmpty ?? false) consulta['postalcode'] = cep!;
    return consulta;
  }

  Future<Coordenada?> _consultarNominatim(Map<String, String> consulta) async {
    await _respeitarIntervaloNominatim();
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      ...consulta,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': 'br',
    });

    _ultimaConsultaNominatim = DateTime.now();
    final resposta = await _get(uri, const Duration(seconds: 20));
    if (resposta.statusCode == 429) {
      throw Exception(
        'O serviço de localização está ocupado. Aguarde um minuto e tente novamente.',
      );
    }
    if (resposta.statusCode != 200) {
      throw Exception(
        'O serviço de localização recusou a consulta (${resposta.statusCode}).',
      );
    }

    final resultados = jsonDecode(resposta.body) as List<dynamic>;
    _log('Nominatim retornou ${resultados.length} resultado(s).');
    if (resultados.isEmpty) return null;
    final primeiro = resultados.first as Map<String, dynamic>;
    final latitude = _numero(primeiro['lat']);
    final longitude = _numero(primeiro['lon']);
    if (latitude == null || longitude == null) {
      throw const FormatException('Coordenadas inválidas na resposta.');
    }
    return Coordenada(latitude: latitude, longitude: longitude);
  }

  Future<http.Response> _get(Uri uri, Duration timeout) async {
    final client = _client ?? http.Client();
    try {
      return await client.get(uri, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw Exception('A consulta de localização demorou demais.');
    } on http.ClientException {
      throw Exception('Sem conexão com o serviço de localização.');
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<void> _respeitarIntervaloNominatim() async {
    final ultima = _ultimaConsultaNominatim;
    if (ultima == null) return;
    final restante =
        const Duration(milliseconds: 1100) - DateTime.now().difference(ultima);
    if (!restante.isNegative) await Future<void>.delayed(restante);
  }

  String _expandirUf(String endereco) {
    var resultado = endereco;
    for (final entry in _nomesUf.entries) {
      resultado = resultado.replaceAllMapped(
        RegExp('(^|,\\s*)${entry.key}(?=\\s*,|\$)', caseSensitive: false),
        (match) => '${match.group(1)}${entry.value}',
      );
    }
    return resultado;
  }

  String _removerNumeroDoImovel(String endereco) {
    final partes = endereco.split(',').map((parte) => parte.trim()).toList();
    if (partes.length > 1 && RegExp(r'^\d+[A-Za-z/-]*$').hasMatch(partes[1])) {
      partes.removeAt(1);
    }
    return partes.join(', ');
  }

  double? _numero(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '');
  }

  String? _texto(dynamic valor) {
    final texto = valor?.toString().trim() ?? '';
    return texto.isEmpty ? null : texto;
  }

  void _log(String mensagem) {
    developer.log(mensagem, name: 'geocodificacao');
  }
}

class _DadosCep {
  final String cep;
  final String? logradouro;
  final String? bairro;
  final String? cidade;
  final String? uf;

  const _DadosCep({
    required this.cep,
    this.logradouro,
    this.bairro,
    this.cidade,
    this.uf,
  });

  bool get temEndereco => logradouro != null && cidade != null;
}

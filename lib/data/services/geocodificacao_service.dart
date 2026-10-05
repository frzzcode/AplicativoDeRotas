import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/coordenada.dart';

// Converte endereços em coordenadas sem exigir que o usuário conheça latitude
// e longitude. Para endereços brasileiros, CEP é a fonte preferencial.
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

  GeocodificacaoService({http.Client? client}) : _client = client;

  // A BrasilAPI CEP V2 usa múltiplos provedores e, quando disponível, devolve
  // diretamente as coordenadas. null significa que o CEP existe, mas não tem
  // geolocalização, ou que não foi encontrado; nesse caso usamos o fallback.
  Future<Coordenada?> buscarPorCep(String cep) async {
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
    final location = data['location'] as Map<String, dynamic>?;
    final coordinates = location?['coordinates'] as Map<String, dynamic>?;
    final latitude = _numero(coordinates?['latitude']);
    final longitude = _numero(coordinates?['longitude']);
    if (latitude == null || longitude == null) {
      _log('BrasilAPI encontrou o CEP, mas não devolveu coordenadas.');
      return null;
    }
    _log('BrasilAPI localizou o CEP com coordenadas.');
    return Coordenada(latitude: latitude, longitude: longitude);
  }

  Future<Coordenada> buscarEndereco({
    required String logradouro,
    String? numero,
    String? bairro,
    required String cidade,
    String? uf,
    String? cep,
  }) async {
    if (cep?.trim().isNotEmpty ?? false) {
      final porCep = await buscarPorCep(cep!);
      if (porCep != null) return porCep;
    }

    final estruturado = <String, String>{
      'street': [
        numero,
        logradouro,
      ].whereType<String>().where((valor) => valor.trim().isNotEmpty).join(' '),
      'city': cidade,
      if (uf?.trim().isNotEmpty ?? false)
        'state': _nomesUf[uf!.trim().toUpperCase()] ?? uf.trim(),
      if (cep?.trim().isNotEmpty ?? false) 'postalcode': cep!.trim(),
      'country': 'Brasil',
    };
    final resultadoEstruturado = await _consultarNominatim(estruturado);
    if (resultadoEstruturado != null) return resultadoEstruturado;

    return buscar(
      [logradouro, numero, bairro, cidade, uf, cep, 'Brasil']
          .whereType<String>()
          .where((valor) => valor.trim().isNotEmpty)
          .join(', '),
    );
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

  void _log(String mensagem) {
    developer.log(mensagem, name: 'geocodificacao');
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/coordenada.dart';

// Converte um endereço comum em latitude/longitude usando Nominatim.
// A instância pública permite no máximo uma consulta por segundo; por isso as
// consultas são sequenciais e os resultados dos clientes ficam no banco local.
class GeocodificacaoService {
  static DateTime? _ultimaConsulta;
  static const _headers = {
    'User-Agent': 'AplicativoDeRotas/1.0 (com.example.tcc_rotas_tecnico)',
    'Accept-Language': 'pt-BR,pt;q=0.9',
  };

  Future<Coordenada> buscar(String endereco) async {
    await _respeitarIntervalo();
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': endereco,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': 'br',
    });

    final client = http.Client();
    try {
      _ultimaConsulta = DateTime.now();
      final resposta = await client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
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
      if (resultados.isEmpty) {
        throw Exception('Endereço não encontrado.');
      }
      final primeiro = resultados.first as Map<String, dynamic>;
      final latitude = double.tryParse(primeiro['lat'] as String? ?? '');
      final longitude = double.tryParse(primeiro['lon'] as String? ?? '');
      if (latitude == null || longitude == null) {
        throw const FormatException('Coordenadas inválidas na resposta.');
      }
      return Coordenada(latitude: latitude, longitude: longitude);
    } on TimeoutException {
      throw Exception('A localização do endereço demorou demais.');
    } on http.ClientException {
      throw Exception('Sem conexão com o serviço de localização.');
    } finally {
      client.close();
    }
  }

  Future<void> _respeitarIntervalo() async {
    final ultima = _ultimaConsulta;
    if (ultima == null) return;
    final restante =
        const Duration(milliseconds: 1100) - DateTime.now().difference(ultima);
    if (!restante.isNegative) await Future<void>.delayed(restante);
  }
}

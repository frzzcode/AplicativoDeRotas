import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ResultadoRota {
  final List<int> ordem;
  final int metros;
  final double segundos;

  const ResultadoRota(this.ordem, this.metros, this.segundos);

  factory ResultadoRota.fromJson(Map<String, dynamic> json, int quantidade) {
    final ordem = (json['ordem'] as List).cast<int>();
    if (ordem.length != quantidade ||
        ordem.toSet().length != quantidade ||
        ordem.any((i) => i < 0 || i >= quantidade)) {
      throw const FormatException('Sequência de paradas inválida.');
    }
    return ResultadoRota(
      ordem,
      json['metros'] as int,
      (json['segundos'] as num).toDouble(),
    );
  }
}

// Só esta classe conhece o serviço externo. A tela usa apenas gerar().
class RotaService {
  static const endpoint = String.fromEnvironment('ROTAS_API_URL');
  static const token = String.fromEnvironment('ROTAS_API_TOKEN');

  Future<ResultadoRota> gerar(
    String origem,
    List<String> enderecos,
    int? destino,
  ) async {
    if (endpoint.isEmpty || token.isEmpty) {
      throw Exception(
        'O cálculo de rotas ainda não foi configurado. Consulte o responsável pelo aplicativo.',
      );
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      return await (() async {
        final request = await client.postUrl(Uri.parse(endpoint));
        request.headers.contentType = ContentType.json;
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        request.write(
          jsonEncode({
            'origem': origem,
            'enderecos': enderecos,
            'destino': destino,
          }),
        );
        final response = await request.close();
        final data = jsonDecode(
          await utf8.decoder.bind(response).join(),
        ) as Map<String, dynamic>;
        if (response.statusCode != 200) {
          throw Exception(data['erro'] ?? 'Não foi possível calcular a rota.');
        }
        return ResultadoRota.fromJson(data, enderecos.length);
      })().timeout(const Duration(seconds: 45));
    } on SocketException {
      throw Exception(
        'Não foi possível conectar ao serviço de rotas. Verifique a internet e se o serviço está ligado.',
      );
    } on TimeoutException {
      throw Exception('O cálculo demorou demais. Tente novamente.');
    } finally {
      client.close(force: true);
    }
  }
}

import 'dart:convert';
import 'dart:io';

// Origem e destino são fixos na Routes API. Mantemos o mapa de índices
// para aplicar corretamente a ordem devolvida pelo Google aos clientes/OS.
Map<String, dynamic> montarPedido(
  String origem,
  List<String> enderecos,
  int? destino,
) {
  if (origem.trim().isEmpty ||
      enderecos.isEmpty ||
      enderecos.length > 25 ||
      enderecos.any((e) => e.trim().isEmpty) ||
      (destino != null && (destino < 0 || destino >= enderecos.length))) {
    throw const FormatException('Informe origem e de 1 a 25 paradas válidas.');
  }
  final intermediarios = [
    for (var i = 0; i < enderecos.length; i++)
      if (i != destino) {'address': enderecos[i]},
  ];
  return {
    'origin': {'address': origem},
    'destination': {'address': destino == null ? origem : enderecos[destino]},
    'intermediates': intermediarios,
    'travelMode': 'DRIVE',
    'routingPreference': 'TRAFFIC_UNAWARE',
    'optimizeWaypointOrder': intermediarios.length > 1,
    'languageCode': 'pt-BR',
    'regionCode': 'BR',
    'units': 'METRIC',
  };
}

Map<String, dynamic> interpretarResposta(
  Map<String, dynamic> data,
  int quantidade,
  int? destino,
) {
  final routes = data['routes'] as List?;
  if (routes == null || routes.isEmpty) {
    throw const FormatException(
      'Nenhuma rota encontrada. Confira os endereços.',
    );
  }
  final route = routes.first as Map<String, dynamic>;
  final indices = [
    for (var i = 0; i < quantidade; i++)
      if (i != destino) i,
  ];
  final ordemGoogle = indices.length <= 1
      ? List<int>.generate(indices.length, (i) => i)
      : (route['optimizedIntermediateWaypointIndex'] as List? ?? [])
            .cast<int>();
  if (ordemGoogle.length != indices.length ||
      ordemGoogle.toSet().length != indices.length ||
      ordemGoogle.any((i) => i < 0 || i >= indices.length)) {
    throw const FormatException(
      'O Google não retornou uma sequência completa.',
    );
  }
  final ordem = [for (final i in ordemGoogle) indices[i], ?destino];
  final segundos = double.parse(
    (route['duration'] as String).replaceFirst(RegExp(r's$'), ''),
  );
  return {
    'ordem': ordem,
    'metros': route['distanceMeters'] ?? 0,
    'segundos': segundos,
  };
}

Future<Map<String, dynamic>> calcularGoogle(
  String key,
  String origem,
  List<String> enderecos,
  int? destino,
) async {
  final pedido = montarPedido(origem, enderecos, destino);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    return await (() async {
      final req = await client.postUrl(
        Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
      );
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Goog-Api-Key', key);
      req.headers.set(
        'X-Goog-FieldMask',
        'routes.distanceMeters,routes.duration,routes.optimizedIntermediateWaypointIndex',
      );
      req.write(jsonEncode(pedido));
      final res = await req.close();
      final data = jsonDecode(
        await utf8.decoder.bind(res).join(),
      ) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        throw HttpException(
          res.statusCode == 429
              ? 'Limite do Google atingido. Tente mais tarde.'
              : 'Google recusou o cálculo (${res.statusCode}). Confira os endereços, a chave, a Routes API e o faturamento.',
        );
      }
      return interpretarResposta(data, enderecos.length, destino);
    })().timeout(const Duration(seconds: 35));
  } finally {
    client.close(force: true);
  }
}

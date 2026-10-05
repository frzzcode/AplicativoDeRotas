import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tcc_rotas_tecnico/data/services/geocodificacao_service.dart';

void main() {
  test('obtém coordenadas da BrasilAPI usando CEP formatado', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'brasilapi.com.br');
      expect(request.url.path, '/api/cep/v2/89282425');
      return http.Response('''{
          "cep": "89282425",
          "location": {
            "type": "Point",
            "coordinates": {
              "longitude": "-49.37861",
              "latitude": "-26.25028"
            }
          }
        }''', 200);
    });
    final service = GeocodificacaoService(client: client);

    final coordenada = await service.buscarPorCep('89282-425');

    expect(coordenada, isNotNull);
    expect(coordenada!.latitude, -26.25028);
    expect(coordenada.longitude, -49.37861);
    client.close();
  });

  test('usa fallback quando o CEP não possui coordenadas', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"cep":"89282425","location":{"coordinates":{}}}',
        200,
      ),
    );
    final service = GeocodificacaoService(client: client);

    expect(await service.buscarPorCep('89282425'), isNull);
    client.close();
  });

  test('rejeita CEP com quantidade inválida de números', () async {
    final service = GeocodificacaoService(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(() => service.buscarPorCep('123'), throwsA(isA<Exception>()));
  });
}

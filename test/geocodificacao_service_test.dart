import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tcc_rotas_tecnico/data/services/geocodificacao_service.dart';

void main() {
  test(
    'usa o endereço do CEP, mas não a coordenada genérica da BrasilAPI',
    () async {
      var chamadas = 0;
      final client = MockClient((request) async {
        chamadas++;
        if (request.url.host == 'brasilapi.com.br') {
          expect(request.url.path, '/api/cep/v2/89282425');
          return http.Response('''{
          "cep": "89282425",
          "state": "SC",
          "city": "São Bento do Sul",
          "neighborhood": "Vila São Paulo",
          "street": "Avenida Prefeito Ornith Bollmann",
          "location": {
            "type": "Point",
            "coordinates": {
              "longitude": "-49.37861",
              "latitude": "-26.25028"
            }
          }
        }''', 200);
        }
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(
          request.url.queryParameters['street'],
          'Avenida Prefeito Ornith Bollmann',
        );
        return http.Response('[{"lat":"-26.268","lon":"-49.363"}]', 200);
      });
      final service = GeocodificacaoService(client: client);

      final coordenada = await service.buscarPorCep('89282-425');

      expect(coordenada, isNotNull);
      expect(coordenada!.latitude, -26.268);
      expect(coordenada.longitude, -49.363);
      expect(chamadas, 2);
      client.close();
    },
  );

  test('retorna nulo quando o CEP não possui rua e cidade', () async {
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

  test(
    'prioriza o endereço completo do cliente antes de consultar o CEP',
    () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'nominatim.openstreetmap.org');
        expect(request.url.queryParameters['street'], '156 Avenida Teste');
        return http.Response('[{"lat":"-26.3","lon":"-49.4"}]', 200);
      });
      final service = GeocodificacaoService(client: client);

      final coordenada = await service.buscarEndereco(
        logradouro: 'Avenida Teste',
        numero: '156',
        bairro: 'Centro',
        cidade: 'São Bento do Sul',
        uf: 'SC',
        cep: '89282-425',
      );

      expect(coordenada.latitude, -26.3);
      expect(coordenada.longitude, -49.4);
      client.close();
    },
  );

  test('rejeita CEP com quantidade inválida de números', () async {
    final service = GeocodificacaoService(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(() => service.buscarPorCep('123'), throwsA(isA<Exception>()));
  });
}

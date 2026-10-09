import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_rotas_tecnico/data/models/coordenada.dart';
import 'package:tcc_rotas_tecnico/data/models/rota_ativa.dart';
import 'package:tcc_rotas_tecnico/data/services/navegacao_service.dart';

void main() {
  const origem = Coordenada(latitude: -26.25, longitude: -49.38);
  const parada1 = Coordenada(latitude: -26.26, longitude: -49.37);
  const parada2 = Coordenada(latitude: -26.27, longitude: -49.36);
  final service = NavegacaoService();

  test('abre Google Maps em modo de navegação até a próxima parada', () {
    final uri = service.googleMapsAte(parada1);

    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['destination'], '-26.26,-49.37');
    expect(uri.queryParameters['travelmode'], 'driving');
    expect(uri.queryParameters['dir_action'], 'navigate');
  });

  test('abre Waze em modo de navegação até a próxima parada', () {
    final uri = service.wazeAte(parada1);

    expect(uri.host, 'waze.com');
    expect(uri.queryParameters['ll'], '-26.26,-49.37');
    expect(uri.queryParameters['navigate'], 'yes');
  });

  test('rota completa preserva a ordem e termina novamente na origem', () {
    final rota = _rota(
      origem: origem,
      retornaOrigem: true,
      coordenadas: [parada1, parada2],
    );

    final uri = service.googleMapsRotaCompleta(rota);

    expect(uri.queryParameters['origin'], '-26.25,-49.38');
    expect(uri.queryParameters['destination'], '-26.25,-49.38');
    expect(uri.queryParameters['waypoints'], '-26.26,-49.37|-26.27,-49.36');
  });

  test('rota sem retorno usa a última parada como destino', () {
    final rota = _rota(
      origem: origem,
      retornaOrigem: false,
      coordenadas: [parada1, parada2],
    );

    final uri = service.googleMapsRotaCompleta(rota);

    expect(uri.queryParameters['destination'], '-26.27,-49.36');
    expect(uri.queryParameters['waypoints'], '-26.26,-49.37');
  });
}

RotaAtiva _rota({
  required Coordenada origem,
  required bool retornaOrigem,
  required List<Coordenada> coordenadas,
}) {
  return RotaAtiva(
    criadaEm: DateTime(2026),
    modo: 'Cliente',
    origemDescricao: 'Casa',
    cepOrigem: '00000000',
    origem: origem,
    metros: 1000,
    segundos: 600,
    retornaOrigem: retornaOrigem,
    geometria: [origem, ...coordenadas],
    itens: [
      for (var i = 0; i < coordenadas.length; i++)
        ItemRotaAtiva(
          posicao: i,
          chave: 'cliente:$i',
          titulo: 'Cliente $i',
          endereco: 'Endereço $i',
          coordenada: coordenadas[i],
        ),
    ],
  );
}

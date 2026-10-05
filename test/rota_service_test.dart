import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_rotas_tecnico/data/models/cliente.dart';
import 'package:tcc_rotas_tecnico/data/models/coordenada.dart';
import 'package:tcc_rotas_tecnico/data/models/parada_rota.dart';
import 'package:tcc_rotas_tecnico/data/services/geocodificacao_service.dart';
import 'package:tcc_rotas_tecnico/data/services/rota_service.dart';

class _GeocodificacaoNoMesmoPonto extends GeocodificacaoService {
  static const ponto = Coordenada(latitude: -26.25028, longitude: -49.37861);

  @override
  Future<Coordenada?> buscarPorCep(String cep) async => ponto;
}

void main() {
  test('rejeita CEPs diferentes localizados na mesma coordenada', () async {
    final cliente = Cliente(
      id: 1,
      nome: 'Cliente teste',
      endereco: 'Rua Teste',
      numero: '100',
      cidade: 'Cidade teste',
      uf: 'SC',
      cep: '22222-222',
      latitude: _GeocodificacaoNoMesmoPonto.ponto.latitude,
      longitude: _GeocodificacaoNoMesmoPonto.ponto.longitude,
    );
    final service = RotaService(geocodificacao: _GeocodificacaoNoMesmoPonto());

    final acao = service.gerar('casa', '11111-111', [
      ParadaRota(chave: 'cliente:1', titulo: '#1', cliente: cliente),
    ], null);

    await expectLater(
      acao,
      throwsA(
        predicate(
          (erro) => erro.toString().contains(
            'CEPs diferentes foram localizados no mesmo ponto',
          ),
        ),
      ),
    );
  });
}

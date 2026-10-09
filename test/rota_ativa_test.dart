import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_rotas_tecnico/data/models/coordenada.dart';
import 'package:tcc_rotas_tecnico/data/models/rota_ativa.dart';

void main() {
  const ponto = Coordenada(latitude: -26, longitude: -49);

  test('mantém o retorno como etapa depois do último atendimento', () {
    final rota = RotaAtiva(
      criadaEm: DateTime(2026),
      modo: 'OS',
      origemDescricao: 'Casa',
      cepOrigem: '00000000',
      origem: ponto,
      metros: 1000,
      segundos: 600,
      retornaOrigem: true,
      geometria: const [ponto],
      itens: const [
        ItemRotaAtiva(
          posicao: 0,
          chave: 'os:1',
          titulo: 'OS #1',
          endereco: 'Rua Teste',
          coordenada: ponto,
          concluido: true,
        ),
      ],
    );

    expect(rota.proximaParada, isNull);
    expect(rota.aguardandoRetorno, isTrue);
    expect(rota.concluida, isFalse);
    expect(rota.progresso, 0.5);
  });

  test('considera concluída somente depois do retorno à origem', () {
    final rota = RotaAtiva(
      criadaEm: DateTime(2026),
      modo: 'OS',
      origemDescricao: 'Casa',
      cepOrigem: '00000000',
      origem: ponto,
      metros: 1000,
      segundos: 600,
      retornaOrigem: true,
      retornoConcluido: true,
      ativa: false,
      geometria: const [ponto],
      itens: const [
        ItemRotaAtiva(
          posicao: 0,
          chave: 'os:1',
          titulo: 'OS #1',
          endereco: 'Rua Teste',
          coordenada: ponto,
          concluido: true,
        ),
      ],
    );

    expect(rota.aguardandoRetorno, isFalse);
    expect(rota.concluida, isTrue);
    expect(rota.progresso, 1);
  });

  test('limita rota completa aos três pontos intermediários móveis', () {
    final itens = List.generate(
      4,
      (i) => ItemRotaAtiva(
        posicao: i,
        chave: 'os:$i',
        titulo: 'OS #$i',
        endereco: 'Rua $i',
        coordenada: ponto,
      ),
    );
    final rota = RotaAtiva(
      criadaEm: DateTime(2026),
      modo: 'OS',
      origemDescricao: 'Casa',
      cepOrigem: '00000000',
      origem: ponto,
      metros: 1000,
      segundos: 600,
      retornaOrigem: true,
      geometria: const [ponto],
      itens: itens,
    );

    expect(rota.permiteRotaCompletaGoogle, isFalse);
  });
}

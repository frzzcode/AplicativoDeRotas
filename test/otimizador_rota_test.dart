import 'package:flutter_test/flutter_test.dart';
import 'package:tcc_rotas_tecnico/domain/services/otimizador_rota.dart';

void main() {
  final matriz = <List<double>>[
    [0, 10, 2, 9],
    [10, 0, 1, 1],
    [2, 1, 0, 8],
    [9, 1, 8, 0],
  ];

  test('visita todas as paradas e retorna à origem', () {
    final ordem = OtimizadorRota().otimizar(matriz);

    expect(ordem.toSet(), {0, 1, 2});
    expect(ordem.length, 3);
    final nos = [0, ...ordem.map((indice) => indice + 1), 0];
    var custo = 0.0;
    for (var i = 0; i < nos.length - 1; i++) {
      custo += matriz[nos[i]][nos[i + 1]];
    }
    expect(custo, 13);
  });

  test('mantém o destino escolhido como última parada', () {
    final ordem = OtimizadorRota().otimizar(matriz, destino: 2);

    expect(ordem, [1, 0, 2]);
  });

  test('heurística preserva todas as paradas e o destino final', () {
    const quantidade = 12;
    final grande = List.generate(
      quantidade + 1,
      (linha) => List.generate(
        quantidade + 1,
        (coluna) => (linha - coluna).abs().toDouble(),
      ),
    );

    final ordem = OtimizadorRota().otimizar(grande, destino: 5);

    expect(ordem.length, quantidade);
    expect(ordem.toSet().length, quantidade);
    expect(ordem.last, 5);
  });
}

// Decide a ordem das paradas usando a matriz de distâncias calculada pelo
// OSRM. O índice 0 da matriz é sempre a origem e os demais são atendimentos.
class OtimizadorRota {
  static const _limiteExato = 10;

  List<int> otimizar(List<List<double>> custos, {int? destino}) {
    _validar(custos, destino);
    final quantidade = custos.length - 1;
    final destinoNo = destino == null ? null : destino + 1;
    final candidatos = [
      for (var no = 1; no <= quantidade; no++)
        if (no != destinoNo) no,
    ];

    final nosOrdenados = candidatos.length <= _limiteExato
        ? _otimizarExato(custos, candidatos, destinoNo)
        : _otimizarHeuristico(custos, candidatos, destinoNo);

    return [
      for (final no in nosOrdenados)
        if (no != 0) no - 1,
    ];
  }

  List<int> _otimizarExato(
    List<List<double>> custos,
    List<int> candidatos,
    int? destinoNo,
  ) {
    final memo = <int, double>{};
    final escolhas = <int, int>{};

    double resolver(int atual, int mascara) {
      if (mascara == 0) return custos[atual][destinoNo ?? 0];
      final chave = (mascara << 6) | atual;
      final salvo = memo[chave];
      if (salvo != null) return salvo;

      var melhor = double.infinity;
      var melhorIndice = -1;
      for (var i = 0; i < candidatos.length; i++) {
        final bit = 1 << i;
        if ((mascara & bit) == 0) continue;
        final proximo = candidatos[i];
        final custo =
            custos[atual][proximo] + resolver(proximo, mascara & ~bit);
        if (custo < melhor) {
          melhor = custo;
          melhorIndice = i;
        }
      }
      memo[chave] = melhor;
      escolhas[chave] = melhorIndice;
      return melhor;
    }

    var mascara = (1 << candidatos.length) - 1;
    var atual = 0;
    resolver(atual, mascara);
    final ordem = <int>[];
    while (mascara != 0) {
      final chave = (mascara << 6) | atual;
      final indice = escolhas[chave]!;
      atual = candidatos[indice];
      ordem.add(atual);
      mascara &= ~(1 << indice);
    }
    if (destinoNo != null) ordem.add(destinoNo);
    return ordem;
  }

  List<int> _otimizarHeuristico(
    List<List<double>> custos,
    List<int> candidatos,
    int? destinoNo,
  ) {
    final restantes = candidatos.toSet();
    final rota = <int>[0];
    var atual = 0;
    while (restantes.isNotEmpty) {
      final proximo = restantes.reduce(
        (a, b) => custos[atual][a] <= custos[atual][b] ? a : b,
      );
      rota.add(proximo);
      restantes.remove(proximo);
      atual = proximo;
    }
    rota.add(destinoNo ?? 0);

    // 2-opt melhora a solução gulosa. Como a matriz rodoviária pode não ser
    // simétrica, comparamos o custo da rota inteira após cada inversão.
    var melhorou = true;
    var repeticoes = 0;
    while (melhorou && repeticoes++ < 20) {
      melhorou = false;
      final custoAtual = _custoTotal(custos, rota);
      for (var inicio = 1; inicio < rota.length - 2; inicio++) {
        for (var fim = inicio + 1; fim < rota.length - 1; fim++) {
          final tentativa = [
            ...rota.take(inicio),
            ...rota.sublist(inicio, fim + 1).reversed,
            ...rota.skip(fim + 1),
          ];
          if (_custoTotal(custos, tentativa) + 0.01 < custoAtual) {
            rota
              ..clear()
              ..addAll(tentativa);
            melhorou = true;
            break;
          }
        }
        if (melhorou) break;
      }
    }
    return destinoNo == null
        ? rota.sublist(1, rota.length - 1)
        : rota.sublist(1);
  }

  double _custoTotal(List<List<double>> custos, List<int> rota) {
    var total = 0.0;
    for (var i = 0; i < rota.length - 1; i++) {
      total += custos[rota[i]][rota[i + 1]];
    }
    return total;
  }

  void _validar(List<List<double>> custos, int? destino) {
    if (custos.length < 2 ||
        custos.any((linha) => linha.length != custos.length) ||
        custos.expand((linha) => linha).any((valor) => !valor.isFinite)) {
      throw const FormatException('Matriz de distâncias inválida.');
    }
    final quantidade = custos.length - 1;
    if (destino != null && (destino < 0 || destino >= quantidade)) {
      throw const FormatException('Destino final inválido.');
    }
  }
}

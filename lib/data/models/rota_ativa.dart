import 'coordenada.dart';

class ItemRotaAtiva {
  final int? id;
  final int posicao;
  final String chave;
  final String titulo;
  final String endereco;
  final Coordenada coordenada;
  final bool concluido;

  const ItemRotaAtiva({
    this.id,
    required this.posicao,
    required this.chave,
    required this.titulo,
    required this.endereco,
    required this.coordenada,
    this.concluido = false,
  });

  factory ItemRotaAtiva.fromMap(Map<String, dynamic> map) {
    return ItemRotaAtiva(
      id: map['id'] as int?,
      posicao: map['posicao'] as int,
      chave: map['chave'] as String,
      titulo: map['titulo'] as String,
      endereco: map['endereco'] as String,
      coordenada: Coordenada(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
      ),
      concluido: map['concluido'] == 1,
    );
  }
}

class RotaAtiva {
  final int? id;
  final DateTime criadaEm;
  final String modo;
  final String origemDescricao;
  final String cepOrigem;
  final Coordenada origem;
  final double metros;
  final double segundos;
  final bool retornaOrigem;
  final bool retornoConcluido;
  final bool ativa;
  final List<Coordenada> geometria;
  final List<ItemRotaAtiva> itens;

  const RotaAtiva({
    this.id,
    required this.criadaEm,
    required this.modo,
    required this.origemDescricao,
    required this.cepOrigem,
    required this.origem,
    required this.metros,
    required this.segundos,
    required this.retornaOrigem,
    this.retornoConcluido = false,
    this.ativa = true,
    required this.geometria,
    required this.itens,
  });

  ItemRotaAtiva? get proximaParada {
    for (final item in itens) {
      if (!item.concluido) return item;
    }
    return null;
  }

  int get paradasConcluidas => itens.where((item) => item.concluido).length;

  bool get aguardandoRetorno =>
      proximaParada == null && retornaOrigem && !retornoConcluido;

  bool get concluida => proximaParada == null && !aguardandoRetorno;

  int get totalEtapas => itens.length + (retornaOrigem ? 1 : 0);

  int get etapasConcluidas => paradasConcluidas + (retornoConcluido ? 1 : 0);

  double get progresso => totalEtapas == 0 ? 0 : etapasConcluidas / totalEtapas;

  List<Coordenada> get pontosIntermediariosGoogle {
    if (retornaOrigem) return itens.map((item) => item.coordenada).toList();
    if (itens.length <= 1) return const [];
    return itens.take(itens.length - 1).map((item) => item.coordenada).toList();
  }

  Coordenada get destinoFinalGoogle =>
      retornaOrigem ? origem : itens.last.coordenada;

  bool get permiteRotaCompletaGoogle =>
      itens.isNotEmpty && pontosIntermediariosGoogle.length <= 3;
}

class Equipamento {
  final int? id;
  final String categoria;
  final String marca;
  final String modelo;
  final int? capacidadeBtu;
  final String? potencia;
  final String? tipo;

  const Equipamento({
    this.id,
    required this.categoria,
    required this.marca,
    required this.modelo,
    this.capacidadeBtu,
    this.potencia,
    this.tipo,
  });

  String get descricao => '$marca $modelo';

  String get especificacoes {
    final itens = <String>[
      if (capacidadeBtu != null) '${capacidadeBtu!} BTUs',
      if (potencia?.isNotEmpty ?? false) potencia!,
      if (tipo?.isNotEmpty ?? false) tipo!,
    ];
    return itens.join(' • ');
  }

  factory Equipamento.fromMap(Map<String, dynamic> map) => Equipamento(
    id: map['id'] as int?,
    categoria: map['categoria'] as String,
    marca: map['marca'] as String,
    modelo: map['modelo'] as String,
    capacidadeBtu: map['capacidade_btu'] as int?,
    potencia: map['potencia'] as String?,
    tipo: map['tipo'] as String?,
  );
}

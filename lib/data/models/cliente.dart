// Esse "model" não fala com o banco - ele só descreve o FORMATO
// de um cliente dentro do app. É a tradução da tabela SQL para
// um objeto Dart que o resto do código consegue usar.
class Cliente {
  final int? id; // nulo antes de salvar (o banco gera o id sozinho)
  final String nome;
  final String? telefone;
  final String? endereco;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? observacoes;

  Cliente({
    this.id,
    required this.nome,
    this.telefone,
    this.endereco,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.observacoes,
  });

  // toMap: transforma o objeto Cliente em algo que o sqflite entende
  // (um Map, parecido com um dicionário chave->valor) para SALVAR.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'telefone': telefone,
      'endereco': endereco,
      'numero': numero,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'observacoes': observacoes,
    };
  }

  // fromMap: faz o caminho inverso - pega o que veio do banco
  // (um Map) e transforma de volta em um objeto Cliente para LER.
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      nome: map['nome'],
      telefone: map['telefone'],
      endereco: map['endereco'],
      numero: map['numero'],
      complemento: map['complemento'],
      bairro: map['bairro'],
      cidade: map['cidade'],
      observacoes: map['observacoes'],
    );
  }
}

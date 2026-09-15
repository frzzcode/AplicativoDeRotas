class OrdemServico {
  final int? id;
  final int clienteId;
  final int equipamentoId;
  final String dataAtendimento;
  final String problema;
  final String? servicoRealizado;
  final double? valor;
  final String prioridade;
  final String status;
  final bool precisaPeca;
  final String recolhimento;
  final String? dataPrevista;
  final String? observacoes;
  final String? clienteNome;
  final String? equipamentoDescricao;

  const OrdemServico({
    this.id,
    required this.clienteId,
    required this.equipamentoId,
    required this.dataAtendimento,
    required this.problema,
    this.servicoRealizado,
    this.valor,
    required this.prioridade,
    required this.status,
    required this.precisaPeca,
    required this.recolhimento,
    this.dataPrevista,
    this.observacoes,
    this.clienteNome,
    this.equipamentoDescricao,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'cliente_id': clienteId,
    'equipamento_id': equipamentoId,
    'data_atendimento': dataAtendimento,
    'problema': problema,
    'servico_realizado': servicoRealizado,
    'valor': valor,
    'prioridade': prioridade,
    'status': status,
    'precisa_peca': precisaPeca ? 1 : 0,
    'recolhimento': recolhimento,
    'data_prevista': dataPrevista,
    'observacoes': observacoes,
  };

  factory OrdemServico.fromMap(Map<String, dynamic> map) => OrdemServico(
    id: map['id'] as int?,
    clienteId: map['cliente_id'] as int,
    equipamentoId: map['equipamento_id'] as int,
    dataAtendimento: map['data_atendimento'] as String,
    problema: map['problema'] as String,
    servicoRealizado: map['servico_realizado'] as String?,
    valor: (map['valor'] as num?)?.toDouble(),
    prioridade: map['prioridade'] as String,
    status: map['status'] as String,
    precisaPeca: (map['precisa_peca'] as int? ?? 0) == 1,
    recolhimento: map['recolhimento'] as String,
    dataPrevista: map['data_prevista'] as String?,
    observacoes: map['observacoes'] as String?,
    clienteNome: map['cliente_nome'] as String?,
    equipamentoDescricao: map['equipamento_descricao'] as String?,
  );
}

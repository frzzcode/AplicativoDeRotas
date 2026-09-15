import 'google_routes.dart';

import 'dart:io';

// Testes sem internet/chave: verificam contratos reais da API e índices.
void main() {
  void verificar(bool condicao, String nome) {
    if (!condicao) throw StateError('Falhou: $nome');
    stdout.writeln('OK: $nome');
  }

  final pedido = montarPedido('Oficina', ['A', 'B', 'C'], null);
  verificar(
    (pedido['destination'] as Map)['address'] == 'Oficina',
    'retorno à origem',
  );
  verificar(pedido['optimizeWaypointOrder'] == true, 'otimização habilitada');
  final resposta = {
    'routes': [
      {
        'optimizedIntermediateWaypointIndex': [2, 0, 1],
        'distanceMeters': 21400,
        'duration': '2580s',
      },
    ],
  };
  final resultado = interpretarResposta(resposta, 3, null);
  verificar(
    resultado['ordem'].toString() == '[2, 0, 1]',
    'ordem não segue entrada',
  );
  verificar(
    resultado['metros'] == 21400 && resultado['segundos'] == 2580,
    'distância e duração',
  );
  final destinoFixo = montarPedido('Oficina', ['A', 'B', 'C'], 1);
  verificar(
    (destinoFixo['destination'] as Map)['address'] == 'B',
    'destino escolhido fixo',
  );
  verificar(
    (destinoFixo['intermediates'] as List).length == 2,
    'destino excluído dos intermediários',
  );
  final fixo = interpretarResposta(
    {
      'routes': [
        {
          'optimizedIntermediateWaypointIndex': [1, 0],
          'distanceMeters': 9000,
          'duration': '600s',
        },
      ],
    },
    3,
    1,
  );
  verificar(
    fixo['ordem'].toString() == '[2, 0, 1]',
    'índices originais com destino intermediário',
  );
  final unica = interpretarResposta(
    {
      'routes': [
        {'distanceMeters': 10, 'duration': '1s'},
      ],
    },
    1,
    0,
  );
  verificar(
    unica['ordem'].toString() == '[0]',
    'um único atendimento como destino',
  );
  var rejeitou = false;
  try {
    interpretarResposta(
      {
        'routes': [
          {
            'optimizedIntermediateWaypointIndex': [0, 0],
            'duration': '1s',
          },
        ],
      },
      2,
      null,
    );
  } on FormatException {
    rejeitou = true;
  }
  verificar(rejeitou, 'rejeita duplicação/perda de parada na resposta');
  rejeitou = false;
  try {
    montarPedido('Oficina', List.filled(26, 'A'), null);
  } on FormatException {
    rejeitou = true;
  }
  verificar(rejeitou, 'limite de paradas');
}

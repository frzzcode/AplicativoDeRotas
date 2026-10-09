import 'dart:convert';

import '../database/db_helper.dart';
import '../models/coordenada.dart';
import '../models/rota_ativa.dart';

class RotaRepository {
  Future<RotaAtiva> salvarAtiva(RotaAtiva rota) async {
    final db = await DBHelper.instance.database;
    final id = await db.transaction((txn) async {
      await txn.update('rotas', {'ativa': 0}, where: 'ativa = 1');
      final rotaId = await txn.insert('rotas', _rotaParaMap(rota));
      for (final item in rota.itens) {
        await txn.insert('itens_rota', _itemParaMap(item, rotaId));
      }
      return rotaId;
    });
    return (await buscarPorId(id))!;
  }

  Future<RotaAtiva?> buscarAtiva() async {
    final db = await DBHelper.instance.database;
    final resultado = await db.query(
      'rotas',
      where: 'ativa = 1',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (resultado.isEmpty) return null;
    return _montarRota(resultado.first);
  }

  Future<RotaAtiva?> buscarPorId(int id) async {
    final db = await DBHelper.instance.database;
    final resultado = await db.query(
      'rotas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (resultado.isEmpty) return null;
    return _montarRota(resultado.first);
  }

  Future<RotaAtiva> concluirProximaEtapa(int rotaId) async {
    final db = await DBHelper.instance.database;
    await db.transaction((txn) async {
      final pendentes = await txn.query(
        'itens_rota',
        columns: ['id'],
        where: 'rota_id = ? AND concluido = 0',
        whereArgs: [rotaId],
        orderBy: 'posicao',
        limit: 1,
      );
      if (pendentes.isNotEmpty) {
        await txn.update(
          'itens_rota',
          {'concluido': 1},
          where: 'id = ?',
          whereArgs: [pendentes.first['id']],
        );
      } else {
        await txn.update(
          'rotas',
          {'retorno_concluido': 1},
          where: 'id = ?',
          whereArgs: [rotaId],
        );
      }

      final restantes = await txn.rawQuery(
        'SELECT COUNT(*) AS quantidade FROM itens_rota '
        'WHERE rota_id = ? AND concluido = 0',
        [rotaId],
      );
      final rota = await txn.query(
        'rotas',
        columns: ['retorna_origem', 'retorno_concluido'],
        where: 'id = ?',
        whereArgs: [rotaId],
        limit: 1,
      );
      final semParadas = (restantes.first['quantidade'] as int) == 0;
      final retorna = rota.first['retorna_origem'] == 1;
      final retornoConcluido = rota.first['retorno_concluido'] == 1;
      if (semParadas && (!retorna || retornoConcluido)) {
        await txn.update(
          'rotas',
          {'ativa': 0},
          where: 'id = ?',
          whereArgs: [rotaId],
        );
      }
    });
    return (await buscarPorId(rotaId))!;
  }

  Future<void> encerrar(int rotaId) async {
    final db = await DBHelper.instance.database;
    await db.update(
      'rotas',
      {'ativa': 0},
      where: 'id = ?',
      whereArgs: [rotaId],
    );
  }

  Future<RotaAtiva> _montarRota(Map<String, dynamic> map) async {
    final db = await DBHelper.instance.database;
    final itensMap = await db.query(
      'itens_rota',
      where: 'rota_id = ?',
      whereArgs: [map['id']],
      orderBy: 'posicao',
    );
    final geometriaJson = jsonDecode(map['geometria_json'] as String) as List;
    return RotaAtiva(
      id: map['id'] as int,
      criadaEm: DateTime.parse(map['criada_em'] as String),
      modo: map['modo'] as String,
      origemDescricao: map['origem_descricao'] as String,
      cepOrigem: map['cep_origem'] as String,
      origem: Coordenada(
        latitude: (map['origem_latitude'] as num).toDouble(),
        longitude: (map['origem_longitude'] as num).toDouble(),
      ),
      metros: (map['distancia_total'] as num).toDouble(),
      segundos: (map['tempo_estimado'] as num).toDouble(),
      retornaOrigem: map['retorna_origem'] == 1,
      retornoConcluido: map['retorno_concluido'] == 1,
      ativa: map['ativa'] == 1,
      geometria: [
        for (final ponto in geometriaJson)
          Coordenada(
            latitude: ((ponto as List)[0] as num).toDouble(),
            longitude: (ponto[1] as num).toDouble(),
          ),
      ],
      itens: itensMap.map(ItemRotaAtiva.fromMap).toList(),
    );
  }

  Map<String, Object?> _rotaParaMap(RotaAtiva rota) {
    return {
      'criada_em': rota.criadaEm.toIso8601String(),
      'modo': rota.modo,
      'origem_descricao': rota.origemDescricao,
      'cep_origem': rota.cepOrigem,
      'origem_latitude': rota.origem.latitude,
      'origem_longitude': rota.origem.longitude,
      'distancia_total': rota.metros,
      'tempo_estimado': rota.segundos,
      'retorna_origem': rota.retornaOrigem ? 1 : 0,
      'retorno_concluido': rota.retornoConcluido ? 1 : 0,
      'geometria_json': jsonEncode([
        for (final ponto in rota.geometria) [ponto.latitude, ponto.longitude],
      ]),
      'ativa': rota.ativa ? 1 : 0,
    };
  }

  Map<String, Object?> _itemParaMap(ItemRotaAtiva item, int rotaId) {
    return {
      'rota_id': rotaId,
      'posicao': item.posicao,
      'chave': item.chave,
      'titulo': item.titulo,
      'endereco': item.endereco,
      'latitude': item.coordenada.latitude,
      'longitude': item.coordenada.longitude,
      'concluido': item.concluido ? 1 : 0,
    };
  }
}

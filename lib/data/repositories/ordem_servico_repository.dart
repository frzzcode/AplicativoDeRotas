import '../database/db_helper.dart';
import '../models/ordem_servico.dart';

class OrdemServicoRepository {
  Future<int> inserir(OrdemServico ordem) async {
    final db = await DBHelper.instance.database;
    return db.insert('ordens_servico', ordem.toMap()..remove('id'));
  }

  Future<List<OrdemServico>> listarTodas() async {
    final db = await DBHelper.instance.database;
    final resultado = await db.rawQuery(
      '$_consultaBase ORDER BY os.data_atendimento DESC, os.id DESC',
    );
    return resultado.map(OrdemServico.fromMap).toList();
  }

  Future<OrdemServico?> buscarPorId(int id) async {
    final db = await DBHelper.instance.database;
    final resultado = await db.rawQuery(
      '$_consultaBase WHERE os.id = ?',
      [id],
    );
    if (resultado.isEmpty) return null;
    return OrdemServico.fromMap(resultado.first);
  }

  Future<int> atualizar(OrdemServico ordem) async {
    final db = await DBHelper.instance.database;
    final dados = ordem.toMap()..remove('id');
    return db.update(
      'ordens_servico',
      dados,
      where: 'id = ?',
      whereArgs: [ordem.id],
    );
  }

  static const String _consultaBase = '''
      SELECT os.*, c.nome AS cliente_nome,
             e.marca || ' ' || e.modelo AS equipamento_descricao
      FROM ordens_servico os
      INNER JOIN clientes c ON c.id = os.cliente_id
      INNER JOIN equipamentos_catalogo e ON e.id = os.equipamento_id
    ''';
}

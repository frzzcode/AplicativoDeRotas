import '../database/db_helper.dart';
import '../models/equipamento.dart';

class EquipamentoRepository {
  Future<List<Equipamento>> listarArCondicionados() async {
    final db = await DBHelper.instance.database;
    final resultado = await db.query(
      'equipamentos_catalogo',
      where: 'categoria = ?',
      whereArgs: ['Ar-condicionado'],
      orderBy: 'marca, modelo',
    );
    return resultado.map(Equipamento.fromMap).toList();
  }

  // Usado ao editar uma OS para recuperar o equipamento já selecionado.
  Future<Equipamento?> buscarPorId(int id) async {
    final db = await DBHelper.instance.database;
    final resultado = await db.query(
      'equipamentos_catalogo',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (resultado.isEmpty) return null;
    return Equipamento.fromMap(resultado.first);
  }
}

import '../database/db_helper.dart';
import '../models/cliente.dart';

// O repositório é a "porta de entrada" para a tabela clientes.
// A tela (presentation/) nunca escreve SQL - ela só chama
// ClienteRepository().inserir(...), .listarTodos(), etc.
// Isso é o que te dá a separação de camadas do documento do TCC.
class ClienteRepository {
  // CREATE - salva um cliente novo e devolve o id que o banco gerou
  Future<int> inserir(Cliente cliente) async {
    final db = await DBHelper.instance.database;
    return await db.insert('clientes', cliente.toMap());
  }

  // READ - lista todos os clientes, ordenados por nome
  Future<List<Cliente>> listarTodos() async {
    final db = await DBHelper.instance.database;
    final resultado = await db.query('clientes', orderBy: 'nome');
    return resultado.map((linha) => Cliente.fromMap(linha)).toList();
  }

  // READ - busca um cliente específico pelo id
  // (vamos usar isso depois, na tela de Ordem de Serviço)
  Future<Cliente?> buscarPorId(int id) async {
    final db = await DBHelper.instance.database;
    final resultado = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (resultado.isEmpty) return null;
    return Cliente.fromMap(resultado.first);
  }

  // UPDATE - atualiza um cliente existente (usa o id dele)
  Future<int> atualizar(Cliente cliente) async {
    final db = await DBHelper.instance.database;
    // O id identifica o registro no WHERE e não deve ser regravado.
    // Assim evitamos qualquer tentativa de alterar a chave primária.
    final dados = cliente.toMap()..remove('id');
    return await db.update(
      'clientes',
      dados,
      where: 'id = ?',
      whereArgs: [cliente.id],
    );
  }

  // DELETE - remove um cliente pelo id
  Future<int> excluir(int id) async {
    final db = await DBHelper.instance.database;
    return await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
  }
}

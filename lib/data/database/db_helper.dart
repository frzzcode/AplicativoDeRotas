import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Essa classe tem UMA responsabilidade: abrir o arquivo do banco
// e garantir que ele só seja aberto UMA vez (padrão "singleton").
// Nenhum outro arquivo do app deve chamar openDatabase() diretamente -
// todo mundo passa por aqui.
class DBHelper {
  DBHelper._(); // construtor privado - ninguém pode fazer "DBHelper()" direto
  static final DBHelper instance = DBHelper._();

  static Database? _database;

  // Sempre que algum repositório precisar do banco, chama "database".
  // Se já estiver aberto, devolve o mesmo; se não, abre pela primeira vez.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tcc_rotas.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate, // só roda na primeira vez que o app abre
    );
  }

  // Aqui é onde "nasce" a estrutura do banco.
  // Por enquanto só a tabela clientes - as outras (categorias, marcas,
  // modelos, ordens_servico, rotas, itens_rota) entram aqui quando
  // formos construir os próximos módulos, dentro do mesmo _onCreate.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        telefone TEXT,
        endereco TEXT,
        numero TEXT,
        complemento TEXT,
        bairro TEXT,
        cidade TEXT,
        observacoes TEXT
      )
    ''');
  }
}

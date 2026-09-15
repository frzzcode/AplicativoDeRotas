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
      version: 2,
      onCreate: _onCreate, // só roda na primeira vez que o app abre
      onUpgrade: _onUpgrade,
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
    await _criarTabelasOS(db);
    await _popularCatalogoArCondicionado(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _criarTabelasOS(db);
      await _popularCatalogoArCondicionado(db);
    }
  }

  Future<void> _criarTabelasOS(Database db) async {
    await db.execute('''
      CREATE TABLE equipamentos_catalogo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria TEXT NOT NULL,
        marca TEXT NOT NULL,
        modelo TEXT NOT NULL,
        capacidade_btu INTEGER,
        potencia TEXT,
        tipo TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE ordens_servico (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        equipamento_id INTEGER NOT NULL,
        data_atendimento TEXT NOT NULL,
        problema TEXT NOT NULL,
        servico_realizado TEXT,
        valor REAL,
        prioridade TEXT NOT NULL DEFAULT 'Normal',
        status TEXT NOT NULL DEFAULT 'Aberta',
        precisa_peca INTEGER NOT NULL DEFAULT 0,
        recolhimento TEXT NOT NULL DEFAULT 'No local',
        data_prevista TEXT,
        observacoes TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id),
        FOREIGN KEY (equipamento_id) REFERENCES equipamentos_catalogo(id)
      )
    ''');
  }

  Future<void> _popularCatalogoArCondicionado(Database db) async {
    final modelos = [
      ['Samsung', 'WindFree AR12BSEAAWK', 12000, '1.080 W', 'Split Inverter'],
      ['Samsung', 'WindFree AR18BSEAAWK', 18000, '1.620 W', 'Split Inverter'],
      ['LG', 'Dual Inverter S3-Q12JA31A', 12000, '1.085 W', 'Split Inverter'],
      ['LG', 'Dual Inverter S3-Q18KL31A', 18000, '1.670 W', 'Split Inverter'],
      ['Daikin', 'EcoSwing RHP12S5VL', 12000, '1.040 W', 'Split Inverter'],
      ['Midea', 'Xtreme Save Connect 42AGVQI12M5', 12000, '1.090 W', 'Split Inverter'],
      ['Gree', 'G-Top Auto 12.000', 12000, '1.100 W', 'Split'],
      ['Elgin', 'Eco Inverter II HJFI12C2IA', 12000, '1.090 W', 'Split Inverter'],
      ['Consul', 'Bem Estar CBF12CB', 12000, '1.110 W', 'Split'],
      ['Springer Midea', 'AirVolution 42AFFCI18S5', 18000, '1.650 W', 'Split Inverter'],
    ];
    final batch = db.batch();
    for (final modelo in modelos) {
      batch.insert('equipamentos_catalogo', {
        'categoria': 'Ar-condicionado',
        'marca': modelo[0],
        'modelo': modelo[1],
        'capacidade_btu': modelo[2],
        'potencia': modelo[3],
        'tipo': modelo[4],
      });
    }
    await batch.commit(noResult: true);
  }
}

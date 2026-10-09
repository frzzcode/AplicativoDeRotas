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
      version: 5,
      onCreate: _onCreate, // só roda na primeira vez que o app abre
      onUpgrade: _onUpgrade,
    );
  }

  // Aqui é onde "nasce" a estrutura completa do banco em instalações novas.
  // Em celulares que já possuem dados, o onUpgrade acrescenta somente as
  // estruturas novas sem apagar clientes ou ordens de serviço existentes.
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
        uf TEXT,
        cep TEXT,
        latitude REAL,
        longitude REAL,
        observacoes TEXT
      )
    ''');
    await _criarTabelasOS(db);
    await _popularCatalogoArCondicionado(db);
    await _criarTabelasRotas(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _criarTabelasOS(db);
      await _popularCatalogoArCondicionado(db);
    }
    if (oldVersion < 3) {
      // Migração não destrutiva: mantém os clientes já cadastrados e
      // acrescenta os dados usados pela nova integração de rotas.
      await db.execute('ALTER TABLE clientes ADD COLUMN uf TEXT');
      await db.execute('ALTER TABLE clientes ADD COLUMN cep TEXT');
      await db.execute('ALTER TABLE clientes ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE clientes ADD COLUMN longitude REAL');
    }
    if (oldVersion < 4) {
      // A versão anterior aceitava uma coordenada aproximada da BrasilAPI.
      // CEPs diferentes podiam receber o mesmo ponto. Limpamos apenas esse
      // cache automático para que seja recalculado corretamente; nenhum dado
      // digitado pelo usuário e nenhuma OS são removidos.
      await db.update('clientes', {'latitude': null, 'longitude': null});
    }
    if (oldVersion < 5) {
      // A rota ativa e seus itens passam a ser persistidos para o aplicativo
      // continuar do mesmo ponto depois de abrir Google Maps ou Waze.
      await _criarTabelasRotas(db);
    }
  }

  Future<void> _criarTabelasRotas(Database db) async {
    await db.execute('''
      CREATE TABLE rotas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        criada_em TEXT NOT NULL,
        modo TEXT NOT NULL,
        origem_descricao TEXT NOT NULL,
        cep_origem TEXT NOT NULL,
        origem_latitude REAL NOT NULL,
        origem_longitude REAL NOT NULL,
        distancia_total REAL NOT NULL,
        tempo_estimado REAL NOT NULL,
        retorna_origem INTEGER NOT NULL DEFAULT 1,
        retorno_concluido INTEGER NOT NULL DEFAULT 0,
        geometria_json TEXT NOT NULL,
        ativa INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE itens_rota (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rota_id INTEGER NOT NULL,
        posicao INTEGER NOT NULL,
        chave TEXT NOT NULL,
        titulo TEXT NOT NULL,
        endereco TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        concluido INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (rota_id) REFERENCES rotas(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_itens_rota_rota_posicao '
      'ON itens_rota (rota_id, posicao)',
    );
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
      [
        'Midea',
        'Xtreme Save Connect 42AGVQI12M5',
        12000,
        '1.090 W',
        'Split Inverter',
      ],
      ['Gree', 'G-Top Auto 12.000', 12000, '1.100 W', 'Split'],
      [
        'Elgin',
        'Eco Inverter II HJFI12C2IA',
        12000,
        '1.090 W',
        'Split Inverter',
      ],
      ['Consul', 'Bem Estar CBF12CB', 12000, '1.110 W', 'Split'],
      [
        'Springer Midea',
        'AirVolution 42AFFCI18S5',
        18000,
        '1.650 W',
        'Split Inverter',
      ],
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

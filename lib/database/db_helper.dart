import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'rutech.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _crearTablas,
    );
  }
  static Future<void> resetDB() async {
    final path = join(await getDatabasesPath(), 'rutech.db');
    await deleteDatabase(path);
    _db = null;
  }

  static Future<void> _crearTablas(Database db, int version) async {
    // Tabla clientes
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dni TEXT,
        nombre TEXT NOT NULL,
        tipo TEXT,
        prioridad TEXT DEFAULT 'media',
        lat_casa REAL,
        lng_casa REAL,
        lat_negocio REAL,
        lng_negocio REAL,
        tipo_ubicacion TEXT,
        caserio TEXT,
        estado TEXT DEFAULT 'activo',
        notas TEXT,
        creado_en TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE caserios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        lat_centro REAL,
        lng_centro REAL,
        notas TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE tacticos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dni TEXT,
        nombre TEXT,
        campana TEXT,
        tipo_campana TEXT,
        tipo_cliente TEXT,
        direccion TEXT,
        tasa REAL,
        saldo REAL,
        morosidad INTEGER DEFAULT 0,
        prioridad TEXT,
        mes TEXT,
        lat REAL,
        lng REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE visitas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER,
        fecha TEXT,
        hora TEXT,
        encontrado INTEGER,
        interesado INTEGER,
        resultado TEXT,
        lat_visita REAL,
        lng_visita REAL,
        ruta_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE rutas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT,
        tipo TEXT,
        clientes_json TEXT,
        distancia_km REAL,
        hora_inicio TEXT,
        hora_fin TEXT,
        estado TEXT DEFAULT 'pendiente'
      )
    ''');
  //caserios reales
    await db.execute('''
  INSERT INTO caserios (nombre, lat_centro, lng_centro) VALUES
  ('Oficina Principal Mi Banco', -5.238109, -79.451223),
  ('Caserío Cabeza',    -5.239914, -79.426675),
  ('Tayapampa',         -5.243605, -79.406617),
  ('Comenderos',        -5.211001, -79.433143),
  ('Chontapampa',       -5.212892, -79.439631),
  ('Tierra Negra',      -5.231399, -79.422371),
  ('Aterrizaje',        -5.258456, -79.442114),
  ('Yumbe',             -5.158862, -79.448086),
  ('Ñangaly',           -5.175335, -79.451303),
  ('Sapun Bajo',        -5.143327, -79.453139),
  ('San Antonio',       -5.110605, -79.462424),
  ('Salala',            -5.114010, -79.461000),
  ('Putaga',            -5.107000, -79.464580),
  ('El Porvenir',       -5.070640, -79.515010),
  ('Selva Andina',      -5.071920, -79.506600),
  ('Talaneo',           -5.061430, -79.536530),
  ('Sicce Quisterios',  -5.040256, -79.550886),
  ('Cruz Grande',       -5.217021, -79.457669),
  ('Lucho',             -5.204955, -79.458356),
  ('Laumache',          -5.186929, -79.464988),
  ('Quispe Bajo',       -5.184127, -79.484030),
  ('Quispe Alto',       -5.177373, -79.490919),
  ('Catulun',           -5.170609, -79.471757),
  ('Huambanaca',        -5.168480, -79.457160),
  ('Jicate Bajo',       -5.175234, -79.501480),
  ('Jicate Alto',       -5.145400, -79.512730),
  ('El Espino',         -5.167030, -79.533680),
  ('Huancacarpa Bajo',  -5.153520, -79.538780),
  ('Huancacarpa Alto',  -5.137070, -79.524620),
  ('Pariamarca Alto',   -5.160700, -79.550220),
  ('Puente Piedra',     -5.146736, -79.550564),
  ('Huamani',           -5.136836, -79.553456),
  ('Pariamarca Centro', -5.164506, -79.587530),
  ('Córdova',           -5.142248, -79.582365),
  ('Pasapampa',         -5.119284, -79.589231),
  ('Ramada del Inca',   -5.106950, -79.556940),
  ('Chulucanas Alto',   -5.087650, -79.545910),
  ('Chulucana Bajo',    -5.071960, -79.566040),
  ('Monte Grande',      -5.120270, -79.514750),
  ('Sapalache',         -5.148567, -79.428904),
  ('Pulun',             -5.137655, -79.432936),
  ('Cajas Canchaque',   -5.170512, -79.426881),
  ('Santa Rosa',        -5.156288, -79.436947),
  ('Cajas Shapaya',     -5.188558, -79.426807),
  ('Tres Acequias',     -5.199125, -79.431660),
  ('Shapaya',           -5.190177, -79.427011),
  ('Cajas Ajumbre',     -5.178650, -79.438150),
  ('Habaspite',         -5.080386, -79.344125),
  ('Huachumo',          -5.024210, -79.326420),
  ('Carmen de la Frontera', -5.007509, -79.325902),
  ('Rosarios Bajo',     -4.962089, -79.325168),
  ('Rosarios Alto',     -4.970710, -79.337880),
  ('Pan de Azúcar',     -4.950145, -79.318360),
  ('Mochoruco',         -4.962780, -79.312020),
  ('Peña Blanca',       -4.970260, -79.257300),
  ('Hormiguero',        -4.973810, -79.219750),
  ('Loma de la Esperanza', -4.986980, -79.227300),
  ('El Tambo',          -5.213528, -79.478434),
  ('Ayuran del Carmen', -5.202070, -79.489560),
  ('Matara',            -5.196182, -79.502392),
  ('Jacocha',           -5.190020, -79.530840),
  ('Los Lirios',        -5.204660, -79.531059),
  ('La Laguna',         -5.219223, -79.518861),
  ('Calderon',          -5.233740, -79.527780),
  ('El Botonal',        -5.175020, -79.527540),
  ('Sauce Chiquito',    -5.241795, -79.484862),
  ('Pundin',            -5.231390, -79.494750),
  ('Succhil',           -5.254384, -79.530780),
  ('Rodeopampa',        -5.273570, -79.533030),
  ('El Alumbre',        -5.278702, -79.513193),
  ('Quispampa Bajo',    -5.251038, -79.449693),
  ('Cajas Capsol',      -5.266469, -79.457410),
  ('Juzgara',           -5.295202, -79.471437),
  ('Singo',             -5.284510, -79.479950),
  ('Nueva Esperanza',   -5.306915, -79.483963),
  ('Mitupampa',         -5.331139, -79.482146),
  ('Huaylas',           -5.313902, -79.470397),
  ('Nuevo Porvenir',    -5.316790, -79.479811),
  ('Cielo Azul',        -5.320008, -79.478981),
  ('Siclamache',        -5.318933, -79.441992),
  ('La Soccha',         -5.326382, -79.437456),
  ('Vilelapampa',       -5.340598, -79.448857),
  ('Lacchan Alto',      -5.352697, -79.459004),
  ('Lacchan Bajo',      -5.358752, -79.449683),
  ('Limon',             -5.328445, -79.462733),
  ('Lanche',            -5.344890, -79.478750),
  ('Ulpamache',         -5.335750, -79.489350),
  ('Cusmilan',          -5.352900, -79.480850),
  ('Sicur',             -5.355190, -79.470830),
  ('Tierra Negra Sondorillo', -5.377920, -79.468790),
  ('Las Pampas',        -5.378970, -79.458400),
  ('Uchupata',          -5.382181, -79.479958),
  ('La Lima',           -5.396100, -79.470030),
  ('Ingano',            -5.354120, -79.506000),
  ('Laguna Amarilla',   -5.331473, -79.509301),
  ('Cashacoto',         -5.290798, -79.422880),
  ('Sondor',            -5.315582, -79.410104),
  ('Lagunas',           -5.349531, -79.403478),
  ('Shilcaya',          -5.339618, -79.400514),
  ('Agupampa',          -5.365835, -79.398106),
  ('Tacarpo',           -5.393784, -79.396203),
  ('Mancucur',          -5.402107, -79.360420),
  ('Chirimoyo',         -5.432723, -79.386834),
  ('Chonta',            -5.429531, -79.379147),
  ('Imbo',              -5.444578, -79.366810),
  ('Guardalapa',        -5.460314, -79.356176),
  ('Tuluce',            -5.469282, -79.351036),
  ('Churipampa',        -5.483267, -79.344458),
  ('Cashaynamo',        -5.497946, -79.330141),
  ('Quevedos',          -5.513557, -79.319702),
  ('Yangua',            -5.505160, -79.361099),
  ('Señor Cautivo',     -5.517995, -79.340428),
  ('La perla',          -5.234781, -79.456417),
  ('Jimaca',            -5.221958, -79.448571),
  ('San Miguel de Cumbicus', -5.19791, -79.44214)
  
''');

    // ── Clientes de prueba vinculados a los caseríos ──
    await db.execute('''
      INSERT INTO clientes (dni, nombre, tipo, prioridad, lat_casa, lng_casa, tipo_ubicacion, caserio, estado, creado_en)
      VALUES
        ('11111111', 'Cliente Cabeza',      'Agricultor',   'alta',  -5.239914, -79.426675, 'casa', 'Caserío Cabeza',   'activo', '2025-01-01'),
        ('22222222', 'Cliente Tayapampa',   'Microempresa', 'alta',  -5.243605, -79.406617, 'casa', 'Tayapampa',        'activo', '2025-01-01'),
        ('33333333', 'Cliente Comenderos',  'Comerciante',  'media', -5.211001, -79.433143, 'casa', 'Comenderos',       'activo', '2025-01-01'),
        ('44444444', 'Cliente Chontapampa', 'Agricultor',   'media', -5.212892, -79.439631, 'casa', 'Chontapampa',      'activo', '2025-01-01'),
        ('55555555', 'Cliente Tierra Negra','Pecuario',     'alta',  -5.231399, -79.422371, 'casa', 'Tierra Negra',     'activo', '2025-01-01'),
        ('66666666', 'Cliente Aterrizaje',  'Comerciante',  'baja',  -5.258456, -79.442114, 'casa', 'Aterrizaje',       'activo', '2025-01-01'),
        ('77777777', 'Cliente Cruz Grande', 'Agricultor',   'media', -5.217021, -79.457669, 'casa', 'Cruz Grande',      'activo', '2025-01-01'),
        ('88888888', 'Cliente Laumache',    'Microempresa', 'alta',  -5.186929, -79.464988, 'casa', 'Laumache',         'activo', '2025-01-01'),
        ('99999999', 'Cliente Ñangaly',     'Agricultor',   'baja',  -5.175335, -79.451303, 'casa', 'Ñangaly',          'activo', '2025-01-01'),
        ('10101010', 'Cliente Sapalache',   'Pecuario',     'media', -5.148567, -79.428904, 'casa', 'Sapalache',        'activo', '2025-01-01'),
        ('12121212', 'Cliente Cajas Canch', 'Agricultor',   'alta',  -5.170512, -79.426881, 'casa', 'Cajas Canchaque',  'activo', '2025-01-01'),
        ('13131313', 'Cliente Tres Aceq',   'Comerciante',  'media', -5.199125, -79.431660, 'casa', 'Tres Acequias',    'activo', '2025-01-01'),
        ('14141414', 'Cliente Quispe Bajo', 'Microempresa', 'alta',  -5.184127, -79.484030, 'casa', 'Quispe Bajo',      'activo', '2025-01-01'),
        ('15151515', 'Cliente Quispe Alto', 'Agricultor',   'baja',  -5.177373, -79.490919, 'casa', 'Quispe Alto',      'activo', '2025-01-01'),
        ('16161616', 'Cliente Catulun',     'Pecuario',     'baja',  -5.170609, -79.471757, 'casa', 'Catulun',          'activo', '2025-01-01')
    ''');
  }

  // ─── CLIENTES ───────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getClientes() async {
    final db = await database;
    return await db.query('clientes', orderBy: 'nombre ASC');
  }

  static Future<int> insertClienteDesdeMap({
    required String nombre,
    required double lat,
    required double lng,
    required String tipoUbicacion,
    String? dni,
  }) async {
    final db = await database;
    final ahora = DateTime.now().toIso8601String().substring(0, 10);
    return await db.insert('clientes', {
      'dni': dni ?? '',
      'nombre': nombre,
      'tipo': 'Prospecto',
      'prioridad': 'media',
      'lat_casa': tipoUbicacion != 'negocio' ? lat : null,
      'lng_casa': tipoUbicacion != 'negocio' ? lng : null,
      'lat_negocio': tipoUbicacion != 'casa' ? lat : null,
      'lng_negocio': tipoUbicacion != 'casa' ? lng : null,
      'tipo_ubicacion': tipoUbicacion,
      'caserio': '',
      'estado': 'activo',
      'creado_en': ahora,
    });
  }
  static Future<List<Map<String, dynamic>>> getClientesConUbicacion() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT * FROM clientes
      WHERE (lat_casa IS NOT NULL OR lat_negocio IS NOT NULL)
    ''');
  }

  static Future<List<Map<String, dynamic>>> buscarCaseriosPorNombre(
      String texto) async {
    final db = await database;
    return await db.query(
      'caserios',
      where: 'nombre LIKE ?',
      whereArgs: ['%$texto%'],
    );
  }

  static Future<int> insertCliente(Map<String, dynamic> cliente) async {
    final db = await database;
    return await db.insert('clientes', cliente);
  }

  static Future<int> updateUbicacionCliente({
    required int id,
    required double lat,
    required double lng,
    required String tipoUbicacion,
  }) async {
    final db = await database;
    Map<String, dynamic> data = {};
    if (tipoUbicacion == 'casa' || tipoUbicacion == 'casa y negocio') {
      data['lat_casa'] = lat;
      data['lng_casa'] = lng;
    }
    if (tipoUbicacion == 'negocio' || tipoUbicacion == 'casa y negocio') {
      data['lat_negocio'] = lat;
      data['lng_negocio'] = lng;
    }
    data['tipo_ubicacion'] = tipoUbicacion;
    return await db.update('clientes', data, where: 'id = ?', whereArgs: [id]);
  }

  static Future<Map<String, dynamic>?> buscarClientePorDni(String dni) async {
    final db = await database;
    final result = await db.query('clientes', where: 'dni = ?', whereArgs: [dni]);
    return result.isNotEmpty ? result.first : null;
  }

  static Future<List<Map<String, dynamic>>> buscarClientesPorNombre(String texto) async {
    final db = await database;
    return await db.query(
      'clientes',
      where: 'nombre LIKE ? OR caserio LIKE ?',
      whereArgs: ['%$texto%', '%$texto%'],
    );
  }

  // ─── CASERIOS ────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCaserios() async {
    final db = await database;
    return await db.query('caserios', orderBy: 'nombre ASC');
  }

  static Future<int> insertCaserio(Map<String, dynamic> caserio) async {
    final db = await database;
    return await db.insert('caserios', caserio);
  }

  // ─── VISITAS ─────────────────────────────────────────

  static Future<int> insertVisita(Map<String, dynamic> visita) async {
    final db = await database;
    return await db.insert('visitas', visita);
  }

  static Future<List<Map<String, dynamic>>> getVisitasHoy() async {
    final db = await database;
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    return await db.query('visitas', where: 'fecha = ?', whereArgs: [hoy]);
  }
  static Future<List<Map<String, dynamic>>> getTacticos() async {
    final db = await database;
    return await db.query('tacticos', orderBy: 'nombre ASC');
  }

  static Future<void> limpiarTacticos() async {
    final db = await database;
    await db.delete('tacticos');
  }

  static Future<void> insertarTacticosBatch(
      List<Map<String, dynamic>> lista) async {
    final db = await database;
    final batch = db.batch();
    for (final t in lista) {
      batch.insert('tacticos', t,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
  static Future<void> migrarTablas() async {
    final db = await database;
    final columnas = await db.rawQuery('PRAGMA table_info(tacticos)');
    final nombres = columnas.map((c) => c['name'].toString()).toList();

    if (!nombres.contains('tipo_cliente')) {
      await db.execute('ALTER TABLE tacticos ADD COLUMN tipo_cliente TEXT');
    }
    if (!nombres.contains('direccion')) {
      await db.execute('ALTER TABLE tacticos ADD COLUMN direccion TEXT');
    }
    if (!nombres.contains('lat')) {
      await db.execute('ALTER TABLE tacticos ADD COLUMN lat REAL');
    }
    if (!nombres.contains('lng')) {
      await db.execute('ALTER TABLE tacticos ADD COLUMN lng REAL');
    }
  }
  static Future<List<Map<String, dynamic>>> getVisitasConCliente() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT v.*, c.nombre, c.tipo, c.caserio, c.morosidad
    FROM visitas v
    LEFT JOIN clientes c ON v.cliente_id = c.id
    ORDER BY v.fecha DESC, v.hora DESC
  ''');
  }
}
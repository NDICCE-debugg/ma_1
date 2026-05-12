import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ma_1/models/service_log.dart';
import 'package:ma_1/models/spare_part.dart';
import 'package:ma_1/models/chat_models.dart';
import 'package:ma_1/models/ai_request.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('biomed_offline_v4.db'); // Forced v4 schema reset
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 4, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // 1. Existing Tables
    await db.execute('''
    CREATE TABLE logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT, machine_model TEXT, error_code TEXT,
      notes TEXT, timestamp TEXT, is_synced INTEGER DEFAULT 0
    )''');

    await db.execute('''
    CREATE TABLE manual_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, machine_model TEXT, category TEXT,
      title TEXT, content TEXT
    )''');

    await db.execute('''
    CREATE TABLE spare_parts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, compatible_model TEXT,
      quantity INTEGER, reorder_threshold INTEGER, location TEXT, unit TEXT,
      last_restocked TEXT, notes TEXT
    )''');

    await db.execute('''
    CREATE TABLE contacts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, reg_number TEXT, created_at TEXT
    )''');

    await db.execute('''
    CREATE TABLE messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT, contact_id INTEGER, message_text TEXT,
      is_sent INTEGER, timestamp TEXT, sync_status TEXT,
      FOREIGN KEY (contact_id) REFERENCES contacts (id)
    )''');

    // 2. NEW AI REQUESTS TABLE
    await db.execute('''
    CREATE TABLE ai_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      input_text TEXT,
      input_type TEXT,
      image_path TEXT,
      timestamp TEXT,
      status TEXT
    )''');

    // NEW ASSET FAULT LOG TABLE
    await db.execute('''
    CREATE TABLE fault_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_id INTEGER,
      fault_description TEXT,
      severity TEXT,
      logged_by TEXT,
      logged_date TEXT,
      resolved INTEGER DEFAULT 0,
      resolved_date TEXT,
      is_synced INTEGER DEFAULT 0
    )''');

    await _seedData(db);
  }

  Future _seedData(Database db) async {
    // Seed Inventory Data
    List<Map<String, dynamic>> parts = [
      {'name': 'Turbine (210003677)', 'compatible_model': 'Aeonmed VG70', 'quantity': 0, 'reorder_threshold': 1, 'location': 'Shelf B2', 'unit': 'pcs', 'last_restocked': '2026-02-15', 'notes': ''},
      {'name': 'Flow Sensor TSI (210002403)', 'compatible_model': 'Aeonmed VG70', 'quantity': 5, 'reorder_threshold': 3, 'location': 'Drawer A', 'unit': 'pcs', 'last_restocked': '2026-03-01', 'notes': ''},
      {'name': 'O2 Sensor (210001975)', 'compatible_model': 'Aeonmed VG70', 'quantity': 3, 'reorder_threshold': 2, 'location': 'Fridge', 'unit': 'pcs', 'last_restocked': '2026-01-10', 'notes': 'Keep refrigerated'},
      {'name': 'Lithium-Ion Battery (210003734)', 'compatible_model': 'Aeonmed VG70', 'quantity': 4, 'reorder_threshold': 2, 'location': 'Battery Store', 'unit': 'units', 'last_restocked': '2025-11-20', 'notes': ''},
      {'name': 'Sodalime Canister', 'compatible_model': 'Mindray A5', 'quantity': 20, 'reorder_threshold': 5, 'location': 'Store Room', 'unit': 'cans', 'last_restocked': '2026-02-28', 'notes': ''},
    ];
    for (var p in parts) { await db.insert('spare_parts', p); }
  }

  // --- AI REQUESTS CRUD ---
  Future<List<AiRequest>> getAiRequests() async {
    final db = await instance.database;
    final result = await db.query('ai_requests', orderBy: 'timestamp ASC');
    return result.map((json) => AiRequest.fromMap(json)).toList();
  }

  Future<int> addAiRequest(AiRequest request) async {
    final db = await instance.database;
    return await db.insert('ai_requests', request.toMap());
  }

  // --- EXISTING CRUD METHODS ---
  Future<List<SparePart>> getInventory() async {
    final db = await instance.database;
    final result = await db.query('spare_parts');
    return result.map((json) => SparePart.fromMap(json)).toList();
  }
  Future<int> updateSparePart(SparePart part) async {
    final db = await instance.database;
    return await db.update('spare_parts', part.toMap(), where: 'id = ?', whereArgs: [part.id]);
  }
  Future<int> addSparePart(SparePart part) async {
    final db = await instance.database;
    return await db.insert('spare_parts', part.toMap());
  }

  Future<List<Contact>> getContacts() async {
    final db = await instance.database;
    final result = await db.query('contacts', orderBy: 'created_at DESC');
    return result.map((json) => Contact.fromMap(json)).toList();
  }
  Future<int> addContact(Contact contact) async {
    final db = await instance.database;
    return await db.insert('contacts', contact.toMap());
  }
  Future<List<ChatMessage>> getMessagesForContact(int contactId) async {
    final db = await instance.database;
    final result = await db.query('messages', where: 'contact_id = ?', whereArgs: [contactId], orderBy: 'timestamp ASC');
    return result.map((json) => ChatMessage.fromMap(json)).toList();
  }
  Future<ChatMessage?> getLastMessageForContact(int contactId) async {
    final db = await instance.database;
    final result = await db.query('messages', where: 'contact_id = ?', whereArgs: [contactId], orderBy: 'timestamp DESC', limit: 1);
    if (result.isNotEmpty) return ChatMessage.fromMap(result.first);
    return null;
  }
  Future<int> addMessage(ChatMessage message) async {
    final db = await instance.database;
    return await db.insert('messages', message.toMap());
  }
  Future<List<ServiceLog>> getAllLogs() async {
    final db = await instance.database;
    final result = await db.query('logs', orderBy: 'timestamp DESC');
    return result.map((json) => ServiceLog.fromMap(json)).toList();
  }
}
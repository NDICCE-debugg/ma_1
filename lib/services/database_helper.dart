import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:ma_1/models/service_log.dart';
import 'package:ma_1/models/spare_part.dart';
import 'package:ma_1/models/chat_models.dart';
import 'package:ma_1/models/ai_request.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final _client = sb.Supabase.instance.client;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('biomed_offline_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 4, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // Local AI request history & local client cache tables
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

    await db.execute('''
    CREATE TABLE ai_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      input_text TEXT,
      input_type TEXT,
      image_path TEXT,
      timestamp TEXT,
      status TEXT
    )''');

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
  }

  // --- AI REQUESTS CRUD (Kept Local) ---
  Future<List<AiRequest>> getAiRequests() async {
    final db = await instance.database;
    final result = await db.query('ai_requests', orderBy: 'timestamp ASC');
    return result.map((json) => AiRequest.fromMap(json)).toList();
  }

  Future<int> addAiRequest(AiRequest request) async {
    final db = await instance.database;
    return await db.insert('ai_requests', request.toMap());
  }

  // --- SPARE PARTS (INVENTORY) - DIRECT SUPABASE ---
  Future<List<SparePart>> getInventory() async {
    try {
      final response = await _client.from('spare_parts').select();
      return response.map<SparePart>((json) => SparePart.fromMap(json)).toList();
    } catch (e) {
      // Offline fallback: Query local SQLite cache
      final db = await instance.database;
      final result = await db.query('spare_parts');
      return result.map((json) => SparePart.fromMap(json)).toList();
    }
  }

  Future<int> updateSparePart(SparePart part) async {
    try {
      await _client.from('spare_parts').update({
        'name': part.name,
        'compatible_model': part.compatibleModel,
        'quantity': part.quantity,
        'reorder_threshold': part.reorderThreshold,
        'location': part.location,
        'unit': part.unit,
        'last_restocked': part.lastRestocked,
        'notes': part.notes,
      }).eq('id', part.id);
      
      // Update local cache as well
      final db = await instance.database;
      await db.update('spare_parts', part.toMap(), where: 'id = ?', whereArgs: [part.id]);
      return 1;
    } catch (e) {
      // Local only write if offline (will be synced later)
      final db = await instance.database;
      return await db.update('spare_parts', part.toMap(), where: 'id = ?', whereArgs: [part.id]);
    }
  }

  Future<int> addSparePart(SparePart part) async {
    try {
      await _client.from('spare_parts').insert({
        'name': part.name,
        'compatible_model': part.compatibleModel,
        'quantity': part.quantity,
        'reorder_threshold': part.reorderThreshold,
        'location': part.location,
        'unit': part.unit,
        'last_restocked': part.lastRestocked,
        'notes': part.notes,
      });

      // Insert into local cache
      final db = await instance.database;
      return await db.insert('spare_parts', part.toMap());
    } catch (e) {
      final db = await instance.database;
      return await db.insert('spare_parts', part.toMap());
    }
  }

  // --- SERVICE LOGS - DIRECT SUPABASE ---
  Future<List<ServiceLog>> getAllLogs() async {
    try {
      final response = await _client
          .from('service_logs')
          .select('*, machines(model_name)')
          .order('timestamp', descending: true);
      
      return response.map<ServiceLog>((json) {
        final machineData = json['machines'] as Map<String, dynamic>?;
        final modelName = machineData != null ? machineData['model_name'] ?? 'Unknown Machine' : 'Unknown Machine';
        
        return ServiceLog(
          id: json['id'],
          machineModel: modelName,
          errorCode: json['error_code'] ?? '',
          notes: json['notes'] ?? '',
          timestamp: json['timestamp'] ?? '',
          isSynced: 1,
        );
      }).toList();
    } catch (e) {
      // Offline fallback
      final db = await instance.database;
      final result = await db.query('logs', orderBy: 'timestamp DESC');
      return result.map((json) => ServiceLog.fromMap(json)).toList();
    }
  }

  // --- CONTACTS & CHAT CACHE (MIGRATING TO SUPABASE REALTIME IN PHASE 5) ---
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
}
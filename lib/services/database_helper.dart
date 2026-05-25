import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:ma_1/models/service_log.dart';
import 'package:ma_1/models/spare_part.dart';
import 'package:ma_1/models/chat_models.dart';
import 'package:ma_1/models/ai_request.dart';
import 'package:ma_1/models/hospital_asset.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const String _inventoryImagesBucket = 'inventory-images';
  final _client = sb.Supabase.instance.client;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('biomed_offline_v4.db');
    await checkAndSeedLocalData(_database!);
    return _database!;
  }

  Future<Uint8List?> _loadAssetBytes(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> checkAndSeedLocalData(Database db) async {
    final countParts = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM spare_parts')) ??
        0;
    if (countParts == 0) {
      await db.insert('spare_parts', {
        'name': 'Turbine (210003677)',
        'compatible_model': 'Aeonmed VG70',
        'quantity': 2,
        'reorder_threshold': 1,
        'location': 'Shelf B2',
        'unit': 'pcs',
        'last_restocked': '2026-05-01',
        'notes': 'Critical part. High replacement rate.'
      });
      await db.insert('spare_parts', {
        'name': 'Flow Sensor TSI (210002403)',
        'compatible_model': 'Aeonmed VG70',
        'quantity': 5,
        'reorder_threshold': 3,
        'location': 'Drawer A',
        'unit': 'pcs',
        'last_restocked': '2026-05-10',
        'notes': 'Handle with care. Calibration required after install.'
      });
      await db.insert('spare_parts', {
        'name': 'O2 Sensor (210001975)',
        'compatible_model': 'Aeonmed VG70',
        'quantity': 3,
        'reorder_threshold': 2,
        'location': 'Fridge',
        'unit': 'pcs',
        'last_restocked': '2026-05-12',
        'notes': 'Keep refrigerated between 2-8 degrees Celsius.'
      });
      await db.insert('spare_parts', {
        'name': 'Lithium-Ion Battery (210003734)',
        'compatible_model': 'Aeonmed VG70',
        'quantity': 4,
        'reorder_threshold': 2,
        'location': 'Battery Store',
        'unit': 'units',
        'last_restocked': '2026-05-15',
        'notes': 'Ensure fully charged prior to storage.'
      });
      await db.insert('spare_parts', {
        'name': 'Sodalime Canister',
        'compatible_model': 'Mindray A5',
        'quantity': 20,
        'reorder_threshold': 5,
        'location': 'Store Room',
        'unit': 'cans',
        'last_restocked': '2026-05-18',
        'notes': 'CO2 absorbent consumable.'
      });
    }

    final countMachines = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM machines')) ??
        0;
    if (countMachines == 0) {
      final vg70Bytes = await _loadAssetBytes('assets/aeonmed_vg70.png');
      final evitaBytes = await _loadAssetBytes('assets/drager_evita.png');
      final mindrayBytes = await _loadAssetBytes('assets/mindray_a5.png');
      final watoBytes = await _loadAssetBytes('assets/wato_ex35.png');

      await db.insert(
          'machines',
          {
            'asset_type': 'ventilator',
            'model_name': 'Aeonmed VG70',
            'serial_number': 'SN-VG70-441',
            'hospital_unit': 'MAIN - ICU 1',
            'ward_location': 'Bed 1',
            'status': 'OPERATIONAL',
            'date_acquired': '2024-01-01',
            'last_service_date': '2024-04-01',
            'service_interval': '6 Months',
            'notes': 'Operational',
            'image_file_name':
                'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=500&auto=format&fit=crop&q=60',
            'image_bytes': vg70Bytes,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert(
          'machines',
          {
            'asset_type': 'ventilator',
            'model_name': 'Aeonmed VG70',
            'serial_number': 'SN-VG70-442',
            'hospital_unit': 'MAIN - ICU 2',
            'ward_location': 'Bed 2',
            'status': 'MAINTENANCE',
            'date_acquired': '2024-01-01',
            'last_service_date': '2024-04-01',
            'service_interval': '6 Months',
            'notes': 'Needs Maintenance',
            'image_file_name':
                'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?w=500&auto=format&fit=crop&q=60',
            'image_bytes': vg70Bytes,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert(
          'machines',
          {
            'asset_type': 'ventilator',
            'model_name': 'Drager Evita V500',
            'serial_number': 'SN-DR-092',
            'hospital_unit': 'PAEDIATRIC - ICU 3',
            'ward_location': 'Bed 1',
            'status': 'OPERATIONAL',
            'date_acquired': '2024-01-01',
            'last_service_date': '2024-04-01',
            'service_interval': '6 Months',
            'notes': 'Operational',
            'image_file_name':
                'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=500&auto=format&fit=crop&q=60',
            'image_bytes': evitaBytes,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert(
          'machines',
          {
            'asset_type': 'anaesthetic_machine',
            'model_name': 'Mindray A5',
            'serial_number': 'SN-MA5-998',
            'hospital_unit': 'MATERNITY - Theatre 1',
            'ward_location': 'OT Room 1',
            'status': 'OPERATIONAL',
            'date_acquired': '2024-01-01',
            'last_service_date': '2024-04-01',
            'service_interval': '6 Months',
            'notes': 'Operational',
            'image_file_name':
                'https://images.unsplash.com/photo-1516613975432-f22787d55f07?w=500&auto=format&fit=crop&q=60',
            'image_bytes': mindrayBytes,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert(
          'machines',
          {
            'asset_type': 'anaesthetic_machine',
            'model_name': 'WATO EX-35',
            'serial_number': 'SN-W35-102',
            'hospital_unit': 'MAIN - Theatre 2',
            'ward_location': 'OT Room 2',
            'status': 'MAINTENANCE',
            'date_acquired': '2024-01-01',
            'last_service_date': '2024-04-01',
            'service_interval': '6 Months',
            'notes': 'Needs Maintenance',
            'image_file_name':
                'https://images.unsplash.com/photo-1516549655169-df83a0774514?w=500&auto=format&fit=crop&q=60',
            'image_bytes': watoBytes,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Self-healing / Dynamic Upgrade: Populate generated asset images into the SQLite BLOB column for any matching serial numbers in existing databases
    final existingList = await db.query('machines');
    for (var row in existingList) {
      final serial = row['serial_number'] as String?;
      final currentBytes = row['image_bytes'] as Uint8List?;
      if (serial != null && (currentBytes == null || currentBytes.isEmpty)) {
        Uint8List? bytes;
        if (serial == 'SN-VG70-441' || serial == 'SN-VG70-442') {
          bytes = await _loadAssetBytes('assets/aeonmed_vg70.png');
        } else if (serial == 'SN-DR-092') {
          bytes = await _loadAssetBytes('assets/drager_evita.png');
        } else if (serial == 'SN-MA5-998') {
          bytes = await _loadAssetBytes('assets/mindray_a5.png');
        } else if (serial == 'SN-W35-102') {
          bytes = await _loadAssetBytes('assets/wato_ex35.png');
        }

        if (bytes != null) {
          await db.update(
            'machines',
            {'image_bytes': bytes},
            where: 'serial_number = ?',
            whereArgs: [serial],
          );
        }
      }
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 9,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
      title TEXT, content TEXT, file_name TEXT, file_type TEXT, file_size INTEGER,
      file_bytes BLOB, uploaded_at TEXT
    )''');

    await db.execute('''
    CREATE TABLE spare_parts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, compatible_model TEXT,
      quantity INTEGER, reorder_threshold INTEGER, location TEXT, unit TEXT,
      last_restocked TEXT, notes TEXT, image_file_name TEXT, image_url TEXT,
      image_bytes BLOB
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

    await _ensureAiConversationTables(db);

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

    await db.execute('''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action TEXT NOT NULL,
      target_table TEXT NOT NULL,
      record_id TEXT NOT NULL,
      payload TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''');

    await db.execute('''
    CREATE TABLE machines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_type TEXT,
      model_name TEXT,
      serial_number TEXT UNIQUE,
      hospital_unit TEXT,
      ward_location TEXT,
      status TEXT,
      date_acquired TEXT,
      last_service_date TEXT,
      service_interval TEXT,
      notes TEXT,
      image_file_name TEXT,
      image_url TEXT,
      image_bytes BLOB
    )''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS machines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_type TEXT,
        model_name TEXT,
        serial_number TEXT UNIQUE,
        hospital_unit TEXT,
        ward_location TEXT,
        status TEXT,
        date_acquired TEXT,
        last_service_date TEXT,
        service_interval TEXT,
        notes TEXT
      )''');
    }
    if (oldVersion < 6) {
      await _ensureManualEntryColumns(db);
    }
    if (oldVersion < 7) {
      await _ensureImageColumns(db);
    }
    if (oldVersion < 8) {
      await _ensureAiConversationTables(db);
    }
    if (oldVersion < 9) {
      await _ensureImageColumns(db);
    }
  }

  Future<void> _ensureAiConversationTables(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_conversations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      preview TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS ai_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL,
      role TEXT NOT NULL,
      text TEXT NOT NULL,
      attachments_json TEXT,
      timestamp TEXT NOT NULL,
      FOREIGN KEY (conversation_id) REFERENCES ai_conversations (id)
        ON DELETE CASCADE
    )''');
  }

  Future<void> _ensureImageColumns(Database db) async {
    Future<void> addMissingColumns(
      String table,
      Map<String, String> definitions,
    ) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final names = columns.map((column) => column['name'] as String).toSet();
      for (final entry in definitions.entries) {
        if (!names.contains(entry.key)) {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN ${entry.key} ${entry.value}');
        }
      }
    }

    await addMissingColumns('spare_parts', {
      'image_file_name': 'TEXT',
      'image_url': 'TEXT',
      'image_bytes': 'BLOB',
    });
    await addMissingColumns('machines', {
      'image_file_name': 'TEXT',
      'image_url': 'TEXT',
      'image_bytes': 'BLOB',
    });
  }

  Future<void> _ensureManualEntryColumns(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS manual_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, machine_model TEXT, category TEXT,
      title TEXT, content TEXT
    )''');

    final columns = await db.rawQuery('PRAGMA table_info(manual_entries)');
    final names = columns.map((column) => column['name'] as String).toSet();

    Future<void> addColumn(String name, String definition) async {
      if (!names.contains(name)) {
        await db
            .execute('ALTER TABLE manual_entries ADD COLUMN $name $definition');
      }
    }

    await addColumn('file_name', 'TEXT');
    await addColumn('file_type', 'TEXT');
    await addColumn('file_size', 'INTEGER');
    await addColumn('file_bytes', 'BLOB');
    await addColumn('uploaded_at', 'TEXT');
  }

  // --- MACHINES CACHE CRUD ---
  Future<List<HospitalAsset>> getCachedAssets() async {
    final db = await instance.database;
    final result = await db.query('machines');
    return result.map((json) => HospitalAsset.fromMap(json)).toList();
  }

  Future<void> cacheAssets(List<HospitalAsset> assets) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Clear out obsolete cache items safely
      await txn.delete('machines');
      for (var asset in assets) {
        await txn.insert(
          'machines',
          asset.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> upsertCachedAssets(List<HospitalAsset> assets) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (var asset in assets) {
        await txn.insert(
          'machines',
          asset.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<int> updateCachedAsset(HospitalAsset asset) async {
    final db = await instance.database;
    return await db.update(
      'machines',
      asset.toMap(),
      where: 'id = ?',
      whereArgs: [asset.id],
    );
  }

  Future<int> addCachedAsset(HospitalAsset asset) async {
    final db = await instance.database;
    return await db.insert(
      'machines',
      asset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteCachedAsset(HospitalAsset asset) async {
    final db = await instance.database;
    if (asset.id != null) {
      return db.delete('machines', where: 'id = ?', whereArgs: [asset.id]);
    }
    return db.delete(
      'machines',
      where: 'serial_number = ?',
      whereArgs: [asset.serialNumber],
    );
  }

  // --- SYNC QUEUE CRUD (Local transaction logs) ---
  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await instance.database;
    return await db.query('sync_queue', orderBy: 'id ASC');
  }

  Future<int> enqueueChange(String action, String targetTable, String recordId,
      Map<String, dynamic> payload) async {
    final db = await instance.database;
    return await db.insert('sync_queue', {
      'action': action,
      'target_table': targetTable,
      'record_id': recordId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int> deleteQueueItem(int id) async {
    final db = await instance.database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  // --- MANUAL ENTRIES CRUD ---
  Future<int> addManualEntry(Map<String, dynamic> entry) async {
    final db = await instance.database;
    return await db.insert('manual_entries', entry);
  }

  Future<List<Map<String, dynamic>>> getManualEntries() async {
    final db = await instance.database;
    return await db.query('manual_entries',
        orderBy: 'uploaded_at DESC, id DESC');
  }

  Future<List<Map<String, dynamic>>> getManualEntriesForModel(
      String machineModel) async {
    final db = await instance.database;
    return await db.query(
      'manual_entries',
      where: 'LOWER(machine_model) = ?',
      whereArgs: [machineModel.toLowerCase()],
      orderBy: 'uploaded_at DESC, id DESC',
    );
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

  Future<int> createAiConversation({
    required String title,
    required String preview,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return db.insert('ai_conversations', {
      'title': title,
      'preview': preview,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<List<Map<String, dynamic>>> getAiConversations() async {
    final db = await instance.database;
    return db.query(
      'ai_conversations',
      orderBy: 'updated_at DESC, id DESC',
      limit: 40,
    );
  }

  Future<List<Map<String, dynamic>>> getAiConversationMessages(
      int conversationId) async {
    final db = await instance.database;
    return db.query(
      'ai_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC, id ASC',
    );
  }

  Future<int> addAiConversationMessage({
    required int conversationId,
    required String role,
    required String text,
    String? attachmentsJson,
    DateTime? timestamp,
  }) async {
    final db = await instance.database;
    return db.insert('ai_messages', {
      'conversation_id': conversationId,
      'role': role,
      'text': text,
      'attachments_json': attachmentsJson,
      'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
    });
  }

  Future<int> updateAiConversation({
    required int id,
    required String title,
    required String preview,
  }) async {
    final db = await instance.database;
    return db.update(
      'ai_conversations',
      {
        'title': title,
        'preview': preview,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAiConversation(int id) async {
    final db = await instance.database;
    return db.transaction((txn) async {
      await txn.delete(
        'ai_messages',
        where: 'conversation_id = ?',
        whereArgs: [id],
      );
      return txn.delete('ai_conversations', where: 'id = ?', whereArgs: [id]);
    });
  }

  // --- SPARE PARTS (INVENTORY) - DIRECT SUPABASE ---
  Future<List<SparePart>> getInventory() async {
    try {
      final response = await _client.from('spare_parts').select();
      if (response.isEmpty) {
        final db = await instance.database;
        final result = await db.query('spare_parts');
        if (result.isNotEmpty) {
          return result.map((json) => SparePart.fromMap(json)).toList();
        }
      }
      final remote = await _attachInventoryImageUrls(
        response.map<SparePart>((json) => SparePart.fromMap(json)).toList(),
      );
      final db = await instance.database;
      final local = (await db.query('spare_parts'))
          .map((json) => SparePart.fromMap(json))
          .toList();
      return _mergeLocalInventoryImages(remote, local);
    } catch (e) {
      // Offline fallback: Query local SQLite cache
      final db = await instance.database;
      final result = await db.query('spare_parts');
      return result.map((json) => SparePart.fromMap(json)).toList();
    }
  }

  List<SparePart> _mergeLocalInventoryImages(
    List<SparePart> remote,
    List<SparePart> local,
  ) {
    String key(SparePart part) =>
        '${part.name.trim().toLowerCase()}|${part.compatibleModel.trim().toLowerCase()}';

    final localById = {
      for (final part in local)
        if (part.id != null) part.id!: part,
    };
    final localByKey = {for (final part in local) key(part): part};

    return remote.map((part) {
      final localMatch = (part.id == null ? null : localById[part.id]) ??
          localByKey[key(part)];
      if (localMatch?.imageBytes == null) return part;
      return part.copyWith(
        imageFileName: localMatch!.imageFileName,
        imageUrl:
            part.imageUrl.isNotEmpty ? part.imageUrl : localMatch.imageUrl,
        imageBytes: localMatch.imageBytes,
      );
    }).toList();
  }

  Future<int> updateSparePart(SparePart part) async {
    try {
      final imageReference = await _prepareInventoryImageReference(part);
      await _client.from('spare_parts').update({
        'name': part.name,
        'compatible_model': part.compatibleModel,
        'quantity': part.quantity,
        'reorder_threshold': part.reorderThreshold,
        'location': part.location,
        'unit': part.unit,
        'last_restocked': part.lastRestocked,
        'notes': part.notes,
        'image_file_name': imageReference,
      }).eq('id', part.id!);

      // Update local cache as well
      final db = await instance.database;
      await db.update(
          'spare_parts',
          part.copyWith(imageFileName: imageReference).toMap()
            ..remove('image_url'),
          where: 'id = ?',
          whereArgs: [part.id]);
      return 1;
    } catch (e) {
      // Local only write if offline (will be synced later)
      final db = await instance.database;
      await enqueueChange(
          'UPDATE', 'spare_parts', part.id.toString(), part.toMap());
      return await db.update('spare_parts', part.toMap(),
          where: 'id = ?', whereArgs: [part.id]);
    }
  }

  Future<int> addSparePart(SparePart part) async {
    try {
      final imageReference = await _prepareInventoryImageReference(part);
      final inserted = await _client
          .from('spare_parts')
          .insert({
            'name': part.name,
            'compatible_model': part.compatibleModel,
            'quantity': part.quantity,
            'reorder_threshold': part.reorderThreshold,
            'location': part.location,
            'unit': part.unit,
            'last_restocked': part.lastRestocked,
            'notes': part.notes,
            'image_file_name': imageReference,
          })
          .select()
          .maybeSingle();

      // Insert into local cache
      final db = await instance.database;
      final cachedPart = part.copyWith(
        id: (inserted?['id'] as num?)?.toInt(),
        imageFileName: imageReference,
      );
      return await db.insert(
        'spare_parts',
        cachedPart.toMap()..remove('image_url'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      final db = await instance.database;
      await enqueueChange(
          'INSERT', 'spare_parts', part.id.toString(), part.toMap());
      return await db.insert('spare_parts', part.toMap()..remove('image_url'));
    }
  }

  Future<List<SparePart>> _attachInventoryImageUrls(
      List<SparePart> parts) async {
    return Future.wait(parts.map((part) async {
      final ref = part.imageFileName.trim();
      if (ref.isEmpty || ref.startsWith('http')) return part;
      try {
        final signedUrl = await _client.storage
            .from(_inventoryImagesBucket)
            .createSignedUrl(ref, 60 * 60);
        return part.copyWith(imageUrl: signedUrl);
      } catch (_) {
        return part;
      }
    }));
  }

  Future<String> _prepareInventoryImageReference(SparePart part) async {
    final currentReference = part.imageFileName.trim();
    final hasNewLocalImage =
        part.imageBytes != null && !_isStorageImageReference(currentReference);
    if (!hasNewLocalImage) return currentReference;

    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return currentReference;

    final fileName = _safeStorageFileName(
      currentReference.isEmpty ? '${part.name}.jpg' : currentReference,
    );
    final storagePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from(_inventoryImagesBucket).uploadBinary(
          storagePath,
          part.imageBytes!,
          fileOptions: sb.FileOptions(
            upsert: true,
            contentType: _imageContentType(fileName),
            cacheControl: '3600',
          ),
        );
    return storagePath;
  }

  bool _isStorageImageReference(String value) =>
      value.isNotEmpty && !value.startsWith('http') && value.contains('/');

  String _safeStorageFileName(String value) {
    final safe = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return safe.isEmpty ? 'inventory_item.jpg' : safe;
  }

  String _imageContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  // --- SERVICE LOGS - DIRECT SUPABASE ---
  Future<List<ServiceLog>> getAllLogs() async {
    try {
      final response = await _client
          .from('service_logs')
          .select('*, machines(model_name)')
          .order('timestamp', ascending: false);

      if (response.isEmpty) {
        final db = await instance.database;
        final result = await db.query('logs', orderBy: 'timestamp DESC');
        if (result.isNotEmpty) {
          return result.map((json) => ServiceLog.fromMap(json)).toList();
        }
      }

      return response.map<ServiceLog>((json) {
        final machineData = json['machines'] as Map<String, dynamic>?;
        final modelName = machineData != null
            ? machineData['model_name'] ?? 'Unknown Machine'
            : 'Unknown Machine';

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

  Future<void> logFault({
    required int assetId,
    required String description,
    required String severity,
  }) async {
    final Map<String, dynamic> payload = {
      'machine_id': assetId,
      'error_code': severity.toUpperCase(),
      'notes': description,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      // 1. Try direct Supabase insertion
      await _client.from('service_logs').insert(payload);
    } catch (e) {
      // 2. Offline fallback: Write to local SQLite logs and enqueue in transaction queue
      final db = await instance.database;
      await db.insert('logs', {
        'machine_model': 'Machine ID: $assetId',
        'error_code': severity.toUpperCase(),
        'notes': description,
        'timestamp': payload['timestamp'],
        'is_synced': 0,
      });

      // Centralized sync queue registration
      await enqueueChange(
          'INSERT', 'service_logs', assetId.toString(), payload);
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
    final result = await db.query('messages',
        where: 'contact_id = ?',
        whereArgs: [contactId],
        orderBy: 'timestamp ASC');
    return result.map((json) => ChatMessage.fromMap(json)).toList();
  }

  Future<ChatMessage?> getLastMessageForContact(int contactId) async {
    final db = await instance.database;
    final result = await db.query('messages',
        where: 'contact_id = ?',
        whereArgs: [contactId],
        orderBy: 'timestamp DESC',
        limit: 1);
    if (result.isNotEmpty) return ChatMessage.fromMap(result.first);
    return null;
  }

  Future<int> addMessage(ChatMessage message) async {
    final db = await instance.database;
    return await db.insert('messages', message.toMap());
  }
}

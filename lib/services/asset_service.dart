import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:ma_1/models/hospital_asset.dart';

class AssetService {
  static final AssetService instance = AssetService._init();
  static Database? _database;

  AssetService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // CHANGED: Renamed the database file to force a fresh initialization
    // and wipe out the old Puritan Bennett data.
    _database = await _initDB('hud_assets_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE hospital_assets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      asset_type TEXT,
      model_name TEXT,
      serial_number TEXT,
      hospital_unit TEXT,
      ward_location TEXT,
      status TEXT,
      date_acquired TEXT,
      last_service_date TEXT,
      service_interval TEXT,
      notes TEXT
    )
    ''');

    // Seed initial demo data for the HUD
    await _seedInitialData(db);
  }

  Future _seedInitialData(Database db) async {
    List<Map<String, dynamic>> seedAssets = [
      // VENTILATORS
      {'asset_type': 'ventilator', 'model_name': 'Aeonmed VG70', 'serial_number': 'VG70-A-442', 'hospital_unit': 'MAIN', 'ward_location': 'ICU 1', 'status': 'OPERATIONAL', 'date_acquired': '2021-05-20', 'last_service_date': '2023-10-12', 'service_interval': '12 MONTHS', 'notes': 'Routine check normal.'},
      {'asset_type': 'ventilator', 'model_name': 'Dräger Infinity', 'serial_number': 'DR-INF-09', 'hospital_unit': 'PAEDIATRIC', 'ward_location': 'ICU 3', 'status': 'OFFLINE', 'date_acquired': '2019-11-20', 'last_service_date': '2023-08-30', 'service_interval': '12 MONTHS', 'notes': 'O2 cell depleted. Do not use.'},
      
      // ANAESTHETIC MACHINES
      {'asset_type': 'anaesthetic_machine', 'model_name': 'Mindray A5', 'serial_number': 'MA5-998', 'hospital_unit': 'MATERNITY', 'ward_location': 'THEATRE 1', 'status': 'OPERATIONAL', 'date_acquired': '2023-02-10', 'last_service_date': '2024-01-05', 'service_interval': '6 MONTHS', 'notes': 'All systems nominal.'},
      {'asset_type': 'anaesthetic_machine', 'model_name': 'WATO EX-35', 'serial_number': 'W35-102', 'hospital_unit': 'MAIN', 'ward_location': 'THEATRE 2', 'status': 'MAINTENANCE', 'date_acquired': '2022-08-15', 'last_service_date': '2023-11-20', 'service_interval': '6 MONTHS', 'notes': 'Valve anomaly detected. Awaiting parts.'},
      {'asset_type': 'anaesthetic_machine', 'model_name': 'WATO EX-65', 'serial_number': 'W65-404', 'hospital_unit': 'MAIN', 'ward_location': 'THEATRE 3', 'status': 'OPERATIONAL', 'date_acquired': '2023-01-10', 'last_service_date': '2024-02-01', 'service_interval': '6 MONTHS', 'notes': 'Newly installed. Operational.'},
    ];
    
    for (var asset in seedAssets) {
      await db.insert('hospital_assets', asset);
    }
  }

  Future<int> registerAsset(HospitalAsset asset) async {
    final db = await instance.database;
    return await db.insert('hospital_assets', asset.toMap());
  }

  Future<int> updateAsset(HospitalAsset asset) async {
    final db = await instance.database;
    return await db.update('hospital_assets', asset.toMap(), where: 'id = ?', whereArgs: [asset.id]);
  }

  Future<List<HospitalAsset>> getAssetsByUnit(String unit) async {
    final db = await instance.database;
    final result = await db.query('hospital_assets', where: 'hospital_unit = ?', whereArgs: [unit]);
    return result.map((json) => HospitalAsset.fromMap(json)).toList();
  }

  Future<List<HospitalAsset>> getAllAssets() async {
    final db = await instance.database;
    final result = await db.query('hospital_assets');
    return result.map((json) => HospitalAsset.fromMap(json)).toList();
  }
}
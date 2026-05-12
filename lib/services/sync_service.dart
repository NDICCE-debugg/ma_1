import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ma_1/services/database_helper.dart';

class SyncService {
  // Your active local Wi-Fi IP Address
  static const String _pcIpAddress = "10.160.120.215"; 
  final String serverUrl = "http://$_pcIpAddress:5000/api/sync";

  Future<void> syncData() async {
    try {
      // Connect to local SQLite DB
      final db = await DatabaseHelper.instance.database;
      
      // 1. Get Unsynced Service Logs (Existing functionality)
      List<Map<String, dynamic>> unsyncedLogs = await db.query(
        'logs', 
        where: 'is_synced = ?', 
        whereArgs: [0]
      );
      
      // 2. Get Unsynced Fault Logs (NEW QR SCANNER FUNCTIONALITY)
      List<Map<String, dynamic>> unsyncedFaults = await db.query(
        'fault_log', 
        where: 'is_synced = ?', 
        whereArgs: [0]
      );

      // If nothing to sync, stop here to save battery/bandwidth
      if (unsyncedLogs.isEmpty && unsyncedFaults.isEmpty) {
        debugPrint("Sync Service: All local data is already synced.");
        return;
      }

      // 3. Prepare combined JSON payload
      Map<String, dynamic> payload = {
        "logs": unsyncedLogs.map((log) => {
          "id": log['id'],
          "machine_model": log['machine_model'],
          "error_code": log['error_code'],
          "notes": log['notes'],
          "timestamp": log['timestamp']
        }).toList(),
        
        "faults": unsyncedFaults.map((fault) => {
          "id": fault['id'],
          "asset_id": fault['asset_id'],
          "fault_description": fault['fault_description'],
          "severity": fault['severity'],
          "logged_by": fault['logged_by'],
          "logged_date": fault['logged_date']
        }).toList()
      };

      // 4. Send to Flask Backend
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // 5. Update Local DB on Success (Mark all as synced)
        for (var log in unsyncedLogs) {
          await db.update('logs', {'is_synced': 1}, where: 'id = ?', whereArgs: [log['id']]);
        }
        for (var fault in unsyncedFaults) {
          await db.update('fault_log', {'is_synced': 1}, where: 'id = ?', whereArgs: [fault['id']]);
        }
        
        debugPrint("Sync Successful: Uploaded ${unsyncedLogs.length} standard logs and ${unsyncedFaults.length} critical fault logs.");
      } else {
        debugPrint("Sync Failed: Server returned status ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Sync Failed (Network or Timeout): $e");
    }
  }
}
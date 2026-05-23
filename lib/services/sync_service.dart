import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_1/services/database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  final _client = Supabase.instance.client;
  bool _isSyncing = false;

  SyncService._init();

  Future<void> syncData() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // 1. Fetch FIFO sorted offline transactions
      final queue = await DatabaseHelper.instance.getSyncQueue();
      if (queue.isEmpty) {
        debugPrint("Sync Service: All offline logs are synchronized.");
        _isSyncing = false;
        return;
      }

      debugPrint("Sync Service: Initiating replay of ${queue.length} offline transactions...");

      for (var item in queue) {
        final int id = item['id'];
        final String action = item['action'];
        final String targetTable = item['target_table'];
        final String recordId = item['record_id'];
        final Map<String, dynamic> payload = jsonDecode(item['payload']);

        bool replaySuccess = false;

        try {
          // 2. Map target tables to direct Supabase PostgreSQL transactions
          if (targetTable == 'service_logs') {
            if (action == 'INSERT') {
              await _client.from('service_logs').insert({
                'machine_id': payload['machine_id'],
                'error_code': payload['error_code'],
                'notes': payload['notes'],
                'timestamp': payload['timestamp'],
              });
            }
            replaySuccess = true;
          } 
          else if (targetTable == 'machines') {
            if (action == 'UPDATE') {
              await _client.from('machines').update({
                'model_name': payload['model_name'],
                'serial_number': payload['serial_number'],
                'location': payload['location'],
                'status': payload['status'],
              }).eq('id', recordId);
            } else if (action == 'INSERT') {
              await _client.from('machines').insert({
                'model_name': payload['model_name'],
                'serial_number': payload['serial_number'],
                'location': payload['location'],
                'status': payload['status'],
              });
            }
            replaySuccess = true;
          } 
          else if (targetTable == 'spare_parts') {
            if (action == 'UPDATE') {
              await _client.from('spare_parts').update({
                'name': payload['name'],
                'compatible_model': payload['compatible_model'],
                'quantity': payload['quantity'],
                'reorder_threshold': payload['reorder_threshold'],
                'location': payload['location'],
                'unit': payload['unit'],
                'last_restocked': payload['last_restocked'],
                'notes': payload['notes'],
              }).eq('id', recordId);
            } else if (action == 'INSERT') {
              await _client.from('spare_parts').insert({
                'name': payload['name'],
                'compatible_model': payload['compatible_model'],
                'quantity': payload['quantity'],
                'reorder_threshold': payload['reorder_threshold'],
                'location': payload['location'],
                'unit': payload['unit'],
                'last_restocked': payload['last_restocked'],
                'notes': payload['notes'],
              });
            }
            replaySuccess = true;
          }

          if (replaySuccess) {
            // 3. Delete replayed transaction from local queue
            await DatabaseHelper.instance.deleteQueueItem(id);
            debugPrint("Sync Service: Successfully replayed $targetTable $action transaction.");
          }
        } on PostgrestException catch (pe) {
          // If it's a conflict or table error, we log it and skip to prevent deadlocks
          debugPrint("Sync Service DB Error on item $id: ${pe.message}");
          await DatabaseHelper.instance.deleteQueueItem(id);
        } catch (e) {
          // Transient network error: halt replay to preserve sequence order
          debugPrint("Sync Service transient network error: $e");
          break;
        }
      }
    } catch (e) {
      debugPrint("Sync Service general error: $e");
    } finally {
      _isSyncing = false;
    }
  }
}
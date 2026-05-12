import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ma_1/theme/app_theme.dart';
import 'package:ma_1/services/database_helper.dart';
import 'package:ma_1/models/service_log.dart';

class LogsView extends StatelessWidget {
  const LogsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold( 
      appBar: AppBar(title: const Text("Maintenance Logs")),
      body: Container(
        decoration: AppTheme.cosmicBackground,
        child: FutureBuilder<List<ServiceLog>>(
          future: DatabaseHelper.instance.getAllLogs(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final logs = snapshot.data!;

            return ListView.builder(
              padding: const EdgeInsets.only(top: 10),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                bool isSynced = log.isSynced == 1;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: AppTheme.glassDecoration,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSynced ? AppTheme.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isSynced ? Icons.cloud_done : Icons.cloud_off,
                        color: isSynced ? AppTheme.success : Colors.grey,
                      ),
                    ),
                    title: Text(log.machineModel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(log.errorCode, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(log.notes, style: const TextStyle(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: Text(
                      DateFormat('MM/dd').format(DateTime.parse(log.timestamp)),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
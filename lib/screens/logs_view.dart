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
      // F4F6F9 - Professional medical background
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Service History"),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<List<ServiceLog>>(
        future: DatabaseHelper.instance.getAllLogs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          
          final logs = snapshot.data!;
          
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    "No maintenance logs found",
                    style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Inter'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              bool isSynced = log.isSynced == 1;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSynced 
                          ? AppTheme.success.withValues(alpha: 0.08) 
                          : AppTheme.neutral.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: isSynced ? AppTheme.success : AppTheme.textSecondary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    log.machineModel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Inter',
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        log.errorCode,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.notes,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('MMM dd').format(DateTime.parse(log.timestamp)),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy').format(DateTime.parse(log.timestamp)),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

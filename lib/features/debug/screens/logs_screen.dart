import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/log_service.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  List<String> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    setState(() => _isLoading = true);
    _logs = LogService.getLogs();
    setState(() => _isLoading = false);
  }

  void _clearLogs() async {
    await LogService.clearLogs();
    _refreshLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => LogService.exportLogs(),
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('Clear Logs?'),
                  content: const Text('This will delete all system activity logs permanently.'),
                  actions: [
                    TextButton(onPressed: () => Get.back(), child: const Text('CANCEL')),
                    TextButton(
                      onPressed: () {
                        _clearLogs();
                        Get.back();
                      },
                      child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('No logs found.'))
              : RefreshIndicator(
                  onRefresh: () async => _refreshLogs(),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      
                      Color color = isDark ? Colors.white70 : Colors.black87;
                      
                      if (log.contains('[ERROR]') || log.contains('⚠️') || log.contains('❌')) {
                        color = isDark ? Colors.redAccent[100]! : Colors.red[800]!;
                      } else if (log.contains('✅') || log.contains('🚀')) {
                        color = isDark ? Colors.greenAccent[200]! : Colors.green[700]!;
                      } else if (log.contains('📍')) {
                        color = isDark ? Colors.blueAccent[100]! : Colors.blue[700]!;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: color,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

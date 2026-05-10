import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LogService {
  static const String logBoxName = 'debug_logs';
  
  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(logBoxName)) {
        await Hive.openBox(logBoxName);
      }
    } catch (e) {
      print("Error initializing LogService: $e");
    }
  }

  static Future<void> log(String message, {String level = 'INFO'}) async {
    try {
      if (!Hive.isBoxOpen(logBoxName)) {
        // If box is not open, we can't log to Hive yet
        print('${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())} [$level] (Buffer) $message');
        return;
      }
      
      final box = Hive.box(logBoxName);
      final timestamp = DateTime.now();
      final logEntry = '${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)} [$level] $message';
      
      await box.add(logEntry);
      print(logEntry);

      // Keep only last 1000 logs
      if (box.length > 1000) {
        await box.deleteAt(0);
      }
    } catch (e) {
      print("Failed to write to debug log: $e");
    }
  }

  static List<String> getLogs() {
    final box = Hive.box(logBoxName);
    return box.values.cast<String>().toList().reversed.toList();
  }

  static Future<void> clearLogs() async {
    final box = Hive.box(logBoxName);
    await box.clear();
  }

  static Future<void> exportLogs() async {
    final logs = getLogs();
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/debug_logs_${DateTime.now().millisecondsSinceEpoch}.txt');
    
    await file.writeAsString(logs.join('\n'));
    
    await Share.shareXFiles([XFile(file.path)], text: 'Field GPS Log Debug Report');
  }
}

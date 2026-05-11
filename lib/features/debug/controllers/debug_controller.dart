import 'package:get/get.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../../services/database_service.dart';
import '../../../services/log_service.dart';
import '../../tracking/controllers/tracking_controller.dart';
import '../../analytics/controllers/analytics_controller.dart';
import '../../dashboard/controllers/dashboard_map_controller.dart';

class DebugController extends GetxController {
  final DatabaseService db = Get.find<DatabaseService>();
  
  // Stats Observables
  var vehicleCount = 0.obs;
  var gpsLogCount = 0.obs;
  var workLocationCount = 0.obs;
  var activityLogCount = 0.obs;
  
  // Tracking Observables
  var isBackgroundRunning = false.obs;
  var activeTripId = (-1).obs;
  var activePointsCount = 0.obs;
  
  @override
  void onInit() {
    super.onInit();
    refreshDbStats();
    _checkBackgroundService();
  }

  void refreshDbStats() {
    try {
      vehicleCount.value = db.vehicleBox.length;
      gpsLogCount.value = db.gpsLogBox.length;
      workLocationCount.value = db.workLocationBox.length;
      activityLogCount.value = db.activityLogBox.length;
      
      // Get latest active trip info
      final logs = db.getAllLogs();
      if (logs.isNotEmpty) {
        final latest = logs.first;
        activeTripId.value = latest.id;
        activePointsCount.value = latest.points.length;
      }
    } catch (e) {
      LogService.log("DebugController: Error refreshing DB stats: $e");
    }
  }

  Future<void> _checkBackgroundService() async {
    final service = FlutterBackgroundService();
    isBackgroundRunning.value = await service.isRunning();
  }

  // Helper to get raw logs for the UI
  List<String> getRawLogs() {
    return LogService.getLogs();
  }
  
  void clearLogs() {
    LogService.clearLogs();
    update(['logs']); // trigger builder update
  }
}

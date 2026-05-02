import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../../services/database_service.dart';
import '../../../models/gps_log.dart';
import '../../../models/vehicle.dart';
import 'package:isar/isar.dart';

class TrackingController extends GetxController {
  final DatabaseService _db = Get.find<DatabaseService>();
  
  var isTracking = false.obs;
  var totalDistance = 0.0.obs;
  var totalFare = 0.0.obs;
  var selectedVehicle = Rxn<Vehicle>();
  
  StreamSubscription? _serviceSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadDefaultVehicle();
    _listenToServiceUpdates();
  }

  Future<void> _loadDefaultVehicle() async {
    // Manual filtering in Dart to bypass missing generated filter methods
    try {
      final allVehicles = await _db.isar.collection<Vehicle>().where().findAll();
      final vehicle = allVehicles.cast<Vehicle?>().firstWhere(
        (v) => v?.isDefault ?? false, 
        orElse: () => null
      );
      selectedVehicle.value = vehicle;
    } catch (e) {
      print("Error loading vehicle: $e");
    }
  }

  void _listenToServiceUpdates() {
    _serviceSubscription = FlutterBackgroundService().on('update').listen((event) {
      if (event != null) {
        totalDistance.value = event['distance'] ?? 0.0;
        totalFare.value = event['fare'] ?? 0.0;
      }
    });
  }

  Future<void> startTracking() async {
    if (selectedVehicle.value == null) {
      Get.snackbar("Error", "Please select a vehicle in settings first");
      return;
    }

    final newLog = GpsLog()
      ..startTime = DateTime.now()
      ..vehicleId = selectedVehicle.value!.id
      ..rateApplied = selectedVehicle.value!.ratePerKm;

    await _db.isar.writeTxn(() async {
      await _db.isar.collection<GpsLog>().put(newLog);
    });

    final service = FlutterBackgroundService();
    await service.startService();
    service.invoke('startTracking', {'logId': newLog.id});
    
    isTracking.value = true;
  }

  Future<void> stopTracking() async {
    final service = FlutterBackgroundService();
    service.invoke('stopTracking');
    isTracking.value = false;
    
    Get.snackbar("Success", "Trip saved successfully");
  }

  @override
  void onClose() {
    _serviceSubscription?.cancel();
    super.onClose();
  }
}

import 'dart:async';
import 'dart:developer' as developer;

import 'package:get/get.dart';

import '../../../models/vehicle.dart';
import '../../../services/database_service.dart';

class VehicleController extends GetxController {
  final DatabaseService _db = Get.find<DatabaseService>();

  var vehicles = <Vehicle>[].obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadVehicles());
  }

  Future<void> loadVehicles() async {
    try {
      var list = _db.getAllVehicles();

      if (list.isEmpty) {
        await addVehicle('Activa', 2.5, true, refreshAfterSave: false);
        list = _db.getAllVehicles();
      }

      vehicles.assignAll(list);
    } catch (e, stackTrace) {
      developer.log(
        'Error loading vehicles',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> addVehicle(
    String name,
    double rate,
    bool isDefault, {
    bool refreshAfterSave = true,
  }) async {
    final vehicle = Vehicle()
      ..name = name.trim()
      ..ratePerKm = rate
      ..isDefault = isDefault;

    if (isDefault) {
      await _clearDefaultVehicle();
    }

    await _db.saveVehicle(vehicle);

    if (refreshAfterSave) {
      await loadVehicles();
    }
  }

  Future<void> updateVehicle(
    Vehicle vehicle,
    String name,
    double rate,
    bool isDefault,
  ) async {
    if (isDefault) {
      await _clearDefaultVehicle(exceptKey: vehicle.id);
    }

    vehicle
      ..name = name.trim()
      ..ratePerKm = rate
      ..isDefault = isDefault;

    await _db.saveVehicle(vehicle);
    await loadVehicles();
  }

  Future<void> deleteVehicle(Vehicle vehicle) async {
    final wasDefault = vehicle.isDefault;
    if (vehicle.id != -1) {
      await _db.deleteVehicle(vehicle.id);
    }

    final remainingVehicles = _db.getAllVehicles();
    if (wasDefault && remainingVehicles.isNotEmpty) {
      remainingVehicles.first.isDefault = true;
      await _db.saveVehicle(remainingVehicles.first);
    }

    await loadVehicles();
  }

  Future<void> _clearDefaultVehicle({int? exceptKey}) async {
    for (final vehicle in _db.getAllVehicles()) {
      if (vehicle.id == exceptKey || !vehicle.isDefault) {
        continue;
      }

      vehicle.isDefault = false;
      await _db.saveVehicle(vehicle);
    }
  }
}

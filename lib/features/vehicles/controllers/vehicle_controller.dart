import 'package:get/get.dart';
import 'package:isar/isar.dart';
import '../../../models/vehicle.dart';
import '../../../services/database_service.dart';

class VehicleController extends GetxController {
  final DatabaseService _db = Get.find<DatabaseService>();
  
  var vehicles = <Vehicle>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    // Fixed: Using collection<Vehicle>() instead of .vehicles
    try {
      final list = await _db.isar.collection<Vehicle>().where().findAll();
      vehicles.assignAll(list);
      
      if (list.isEmpty) {
        await addVehicle("Activa", 2.5, true);
      }
    } catch (e) {
      print("Error loading vehicles: $e");
    }
  }

  Future<void> addVehicle(String name, double rate, bool isDefault) async {
    final vehicle = Vehicle()
      ..name = name
      ..ratePerKm = rate
      ..isDefault = isDefault;

    await _db.isar.writeTxn(() async {
      final collection = _db.isar.collection<Vehicle>();
      if (isDefault) {
        // Use standard where().findAll() and filter in Dart to avoid missing generated filter methods
        final all = await collection.where().findAll();
        for (var v in all) {
          if (v.isDefault) {
            v.isDefault = false;
            await collection.put(v);
          }
        }
      }
      await collection.put(vehicle);
    });
    
    _loadVehicles();
  }
}

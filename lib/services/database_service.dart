import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/vehicle.dart';
import '../models/gps_log.dart';

class DatabaseService {
  late Isar isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    
    // Note: The schemas (VehicleSchema, GpsLogSchema) are generated.
    // If you see errors here, you must run:
    // dart run build_runner build --delete-conflicting-outputs
    isar = await Isar.open(
      [VehicleSchema, GpsLogSchema],
      directory: dir.path,
    );
  }
}

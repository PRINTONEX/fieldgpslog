import 'package:get/get.dart';

import 'database_service.dart';
import 'location_service.dart';

class ServiceLocator {
  const ServiceLocator._();

  static DatabaseService get database => Get.find<DatabaseService>();

  static LocationService get location {
    if (!Get.isRegistered<LocationService>()) {
      Get.put(LocationService(), permanent: true);
    }

    return Get.find<LocationService>();
  }
}

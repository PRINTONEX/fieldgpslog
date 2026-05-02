import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';
import 'location_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

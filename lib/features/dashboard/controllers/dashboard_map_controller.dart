import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import '../../../services/database_service.dart';
import '../../../models/gps_log.dart';
import 'package:isar/isar.dart';

class DashboardMapController extends GetxController {
  final DatabaseService _db = Get.find<DatabaseService>();
  
  GoogleMapController? mapController;
  final LatLng initialPosition = const LatLng(20.5937, 78.9629); // Default India
  
  var markers = <Marker>{}.obs;
  var polylines = <Polyline>{}.obs;

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Method to load and show routes for a specific date
  Future<void> loadRoute(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Using generic findAll and filtering in Dart to bypass missing generated filter methods
    final allLogs = await _db.isar.collection<GpsLog>().where().findAll();
    
    final logs = allLogs.where((log) {
      return log.startTime.isAfter(startOfDay) && log.startTime.isBefore(endOfDay);
    }).toList();

    _drawLogs(logs);
  }

  void _drawLogs(List<GpsLog> logs) {
    markers.clear();
    polylines.clear();

    List<LatLng> routePoints = [];
    
    for (var log in logs) {
      final points = log.points.map((p) => LatLng(p.latitude!, p.longitude!)).toList();
      routePoints.addAll(points);

      // Add markers for stays
      for (var stay in log.stays) {
        markers.add(Marker(
          markerId: MarkerId('stay_${stay.arrivalTime.toString()}'),
          position: LatLng(stay.latitude!, stay.longitude!),
          infoWindow: InfoWindow(
            title: "Stay Point",
            snippet: "Duration: ${stay.durationMinutes} mins",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ));
      }
    }

    if (routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: Get.theme.colorScheme.primary,
        width: 5,
      ));
      
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(routePoints.last, 14));
    }
  }
}

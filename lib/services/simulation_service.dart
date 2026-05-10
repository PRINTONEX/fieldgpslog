import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SimulationService {
  static Timer? _timer;
  static bool isSimulating = false;

  // Predefined routes (e.g., Shifting from Home to Road)
  static final List<LatLng> shillongRoute = [
    const LatLng(25.5788, 91.8933), // Home (POI)
    const LatLng(25.5795, 91.8940),
    const LatLng(25.5810, 91.8955),
    const LatLng(25.5830, 91.8980), // Leaving Home
    const LatLng(25.5850, 91.9000),
    const LatLng(25.5870, 91.9050),
    const LatLng(25.5900, 91.9100), // Petrol Pump (POI)
    const LatLng(25.5905, 91.9110), // Short stop
    const LatLng(25.5950, 91.9200),
    const LatLng(25.6000, 91.9300), // Office (POI)
  ];

  static void startMovementSimulation({double speedKmh = 30.0}) {
    if (isSimulating) return;
    isSimulating = true;

    int index = 0;
    final service = FlutterBackgroundService();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (index >= shillongRoute.length) {
        stopSimulation();
        return;
      }

      final pos = shillongRoute[index];
      
      // We invoke the 'update' event just like the real GPS stream would
      service.invoke('update', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': (speedKmh / 3.6), // Convert km/h to m/s
        'distance': 0.0, // Background service calculates delta
        'fare': 0.0,
      });

      index++;
    });
  }

  static void stopSimulation() {
    _timer?.cancel();
    isSimulating = false;
  }
}

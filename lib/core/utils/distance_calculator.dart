import 'dart:math' show cos, sqrt, asin;
import 'package:geolocator/geolocator.dart';

class DistanceCalculator {
  /// Calculates distance between two points in Kilometers
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  /// Returns distance in km using Geolocator
  static double getDistanceBetween(Position start, Position end) {
    return Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude,
        ) /
        1000;
  }
}

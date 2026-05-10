import '../../models/gps_log.dart';
import '../../models/delivery_analytics.dart';
import 'distance_calculator.dart';

class DeliveryAnalyticsHelper {
  /// Detect delivery stops from GPS points OR use recorded StayPoints
  static List<DeliveryStop> detectDeliveryStops(
    GpsLog log, {
    double radiusMeters = 50,
    int minStayMinutes = 5,
  }) {
    // 1. Priority: Use recorded StayPoints if they exist
    if (log.stays.isNotEmpty) {
      return log.stays.map((stay) {
        return DeliveryStop()
          ..latitude = stay.latitude ?? 0
          ..longitude = stay.longitude ?? 0
          ..arrivalTime = stay.arrivalTime ?? DateTime.now()
          ..departureTime = stay.departureTime ?? DateTime.now()
          ..stopType = stay.label?.toLowerCase() ?? 'delivery'
          ..note = stay.note;
      }).toList();
    }

    // 2. Fallback: Detect from points if no stays recorded
    final points = log.points;
    if (points.isEmpty) return [];

    List<DeliveryStop> stops = [];
    List<GpsPoint> currentCluster = [];

    for (int i = 0; i < points.length; i++) {
      if (currentCluster.isEmpty) {
        currentCluster.add(points[i]);
      } else {
        final distance = DistanceCalculator.calculateDistance(
          currentCluster[0].latitude ?? 0,
          currentCluster[0].longitude ?? 0,
          points[i].latitude ?? 0,
          points[i].longitude ?? 0,
        );

        if (distance * 1000 <= radiusMeters) {
          // Still within radius
          currentCluster.add(points[i]);
        } else {
          // Check if cluster is a stop
          if (currentCluster.isNotEmpty) {
            final stop = _createStopFromCluster(currentCluster, minStayMinutes);
            if (stop != null) {
              stops.add(stop);
            }
          }
          currentCluster = [points[i]];
        }
      }
    }

    // Don't forget last cluster
    if (currentCluster.isNotEmpty) {
      final stop = _createStopFromCluster(currentCluster, minStayMinutes);
      if (stop != null) {
        stops.add(stop);
      }
    }

    return stops;
  }

  /// Create a stop from a cluster of points
  static DeliveryStop? _createStopFromCluster(
    List<GpsPoint> cluster,
    int minStayMinutes,
  ) {
    if (cluster.isEmpty) return null;

    final start = cluster.first.timestamp ?? DateTime.now();
    final end = cluster.last.timestamp ?? DateTime.now();
    final duration = end.difference(start).inMinutes;

    if (duration < minStayMinutes) return null;

    // Calculate center of cluster
    double avgLat = 0, avgLon = 0;
    for (final point in cluster) {
      avgLat += point.latitude ?? 0;
      avgLon += point.longitude ?? 0;
    }
    avgLat /= cluster.length;
    avgLon /= cluster.length;

    return DeliveryStop()
      ..latitude = avgLat
      ..longitude = avgLon
      ..arrivalTime = start
      ..departureTime = end;
  }

  /// Calculate total distance from GPS points
  static double calculateTotalDistance(List<GpsPoint> points) {
    double totalDistance = 0.0;
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      if (prev.latitude != null &&
          prev.longitude != null &&
          curr.latitude != null &&
          curr.longitude != null) {
        totalDistance += DistanceCalculator.calculateDistance(
          prev.latitude!,
          prev.longitude!,
          curr.latitude!,
          curr.longitude!,
        );
      }
    }
    return totalDistance;
  }

  /// Calculate idle time (when speed is near zero)
  static int calculateIdleMinutes(
    List<GpsPoint> points, {
    double maxSpeedMsForIdle = 0.5, // 0.5 m/s = ~1.8 km/h
  }) {
    if (points.isEmpty) return 0;

    int idleMinutes = 0;
    DateTime? idleStart;

    for (int i = 0; i < points.length; i++) {
      final speed = points[i].speed ?? 0;

      if (speed <= maxSpeedMsForIdle) {
        // Start of idle
        idleStart ??= points[i].timestamp;
      } else {
        // End of idle
        if (idleStart != null && points[i].timestamp != null) {
          idleMinutes += points[i].timestamp!.difference(idleStart).inMinutes;
          idleStart = null;
        }
      }
    }

    // Handle unclosed idle period
    if (idleStart != null && points.isNotEmpty) {
      final lastTime = points.last.timestamp ?? DateTime.now();
      idleMinutes += lastTime.difference(idleStart).inMinutes;
    }

    return idleMinutes;
  }

  /// Calculate average speed in km/h from GPS points
  static double calculateAverageSpeed(List<GpsPoint> points) {
    if (points.length < 2) return 0;

    double totalDistance = calculateTotalDistance(points);
    final firstTime = points.first.timestamp ?? DateTime.now();
    final lastTime = points.last.timestamp ?? DateTime.now();

    final durationHours = lastTime.difference(firstTime).inMinutes / 60.0;

    if (durationHours <= 0) return 0;
    return totalDistance / durationHours;
  }

  /// Calculate max speed from GPS points (convert from m/s to km/h)
  static int calculateMaxSpeed(List<GpsPoint> points) {
    double maxSpeed = 0;
    for (final point in points) {
      if (point.speed != null && point.speed! > maxSpeed) {
        maxSpeed = point.speed!;
      }
    }
    // Convert m/s to km/h: multiply by 3.6
    return (maxSpeed * 3.6).toInt();
  }

  /// Calculate fuel consumption
  /// mileage: km/liter (e.g., 40 km/l)
  static double calculateFuelUsed(double distanceKm, double mileageKmPerLiter) {
    if (mileageKmPerLiter <= 0) return 0;
    return distanceKm / mileageKmPerLiter;
  }

  /// Calculate fuel cost
  static double calculateFuelCost(
    double fuelLiters,
    double fuelPricePerLiter,
  ) {
    return fuelLiters * fuelPricePerLiter;
  }

  /// Detect stop types (home, office, delivery) based on recurring stops
  /// For now, first stop = home, last stop = home, others = delivery
  static void identifyStopTypes(List<DeliveryStop> stops) {
    if (stops.isEmpty) return;

    for (var stop in stops) {
      // If label is already set and valid, keep it
      if (stop.stopType != 'delivery' && stop.stopType.isNotEmpty) {
        continue;
      }
      
      // Default logic for unlabeled stops
      if (stops.length == 1) {
        stop.stopType = 'office';
      }
    }

    // Only apply start/end defaults if they aren't already set
    if (stops.length > 1) {
      if (stops[0].stopType == 'delivery') stops[0].stopType = 'home';
      if (stops[stops.length - 1].stopType == 'delivery') stops[stops.length - 1].stopType = 'home';
      
      for (int i = 1; i < stops.length - 1; i++) {
        if (stops[i].stopType == 'delivery' || stops[i].stopType.isEmpty) {
           stops[i].stopType = 'delivery';
        }
      }
    }
  }

  /// Calculate distance between two consecutive stops
  static double calculateInterStopDistance(
    DeliveryStop stop1,
    DeliveryStop stop2,
  ) {
    return DistanceCalculator.calculateDistance(
      stop1.latitude,
      stop1.longitude,
      stop2.latitude,
      stop2.longitude,
    );
  }

  /// Create a comprehensive daily summary from GPS log
  static DailyTravelSummary generateDailySummary(
    GpsLog log, {
    double mileageKmPerLiter = 40.0,
    double fuelPricePerLiter = 100.0,
  }) {
    final stops = detectDeliveryStops(log);
    identifyStopTypes(stops);

    final totalDistance = calculateTotalDistance(log.points);
    final totalIdleMinutes = calculateIdleMinutes(log.points);

    final startTime = log.startTime;
    final endTime = log.endTime ?? DateTime.now();
    final totalWorkingMinutes = endTime.difference(startTime).inMinutes;

    final fuelUsed = calculateFuelUsed(totalDistance, mileageKmPerLiter);
    final fuelCost = calculateFuelCost(fuelUsed, fuelPricePerLiter);

    // Calculate distances between stops
    for (int i = 1; i < stops.length; i++) {
      stops[i].distanceFromPreviousStop = calculateInterStopDistance(
        stops[i - 1],
        stops[i],
      );
    }

    return DailyTravelSummary()
      ..date = DateTime(startTime.year, startTime.month, startTime.day)
      ..totalDistanceKm = totalDistance
      ..totalWorkingMinutes = totalWorkingMinutes
      ..totalIdleMinutes = totalIdleMinutes
      ..totalFuelLiters = fuelUsed
      ..totalFuelCost = fuelCost
      ..totalStops = stops.length
      ..stops = stops
      ..averageSpeed = calculateAverageSpeed(log.points)
      ..maxSpeed = calculateMaxSpeed(log.points)
      ..startTime = startTime
      ..endTime = endTime;
  }
}

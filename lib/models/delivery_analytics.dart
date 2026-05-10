import 'package:hive/hive.dart';

part 'delivery_analytics.g.dart';

/// Represents a single delivery stop/location
@HiveType(typeId: 4)
class DeliveryStop extends HiveObject {
  @HiveField(0)
  double latitude = 0.0;

  @HiveField(1)
  double longitude = 0.0;

  @HiveField(2)
  DateTime arrivalTime = DateTime.now();

  @HiveField(3)
  DateTime departureTime = DateTime.now();

  @HiveField(4)
  String stopType = 'delivery'; // 'home', 'office', 'delivery', 'unknown'

  @HiveField(5)
  double distanceFromPreviousStop = 0.0; // in km

  @HiveField(6)
  String? address; // optional address

  @HiveField(7)
  int? parcelsDelivered = 0;

  @HiveField(8)
  String? note;

  /// Get duration at this stop in minutes
  int get durationMinutes {
    return departureTime.difference(arrivalTime).inMinutes;
  }

  /// Get duration as formatted string "HH:mm"
  String get formattedDuration {
    final minutes = durationMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '$hours h ${mins}m';
    }
    return '${mins}m';
  }

  /// Check if this is a significant stop (>5 minutes)
  bool get isSignificantStop => durationMinutes > 5;
}

/// Daily travel summary with all analytics
@HiveType(typeId: 5)
class DailyTravelSummary extends HiveObject {
  @HiveField(0)
  DateTime date = DateTime.now();

  @HiveField(1)
  double totalDistanceKm = 0.0;

  @HiveField(2)
  int totalWorkingMinutes = 0; // start to end time

  @HiveField(3)
  int totalIdleMinutes = 0; // stopped/no movement

  @HiveField(4)
  double totalFuelLiters = 0.0;

  @HiveField(5)
  double totalFuelCost = 0.0;

  @HiveField(6)
  int totalStops = 0;

  @HiveField(7)
  int totalDeliveriesCompleted = 0;

  @HiveField(8)
  List<DeliveryStop> stops = [];

  @HiveField(9)
  double averageSpeed = 0.0; // km/h

  @HiveField(10)
  int maxSpeed = 0; // km/h

  @HiveField(11)
  DateTime? startTime;

  @HiveField(12)
  DateTime? endTime;

  /// Calculate efficiency percentage (0-100)
  double get efficiencyPercentage {
    if (totalWorkingMinutes == 0) return 0;
    final movingMinutes = totalWorkingMinutes - totalIdleMinutes;
    return (movingMinutes / totalWorkingMinutes) * 100;
  }

  /// Get formatted working time "HH:mm"
  String get formattedWorkingTime {
    final minutes = totalWorkingMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// Get formatted idle time
  String get formattedIdleTime {
    final minutes = totalIdleMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }
}

/// Route leg from one stop to another
@HiveType(typeId: 6)
class RouteLeg extends HiveObject {
  @HiveField(0)
  DeliveryStop fromStop = DeliveryStop();

  @HiveField(1)
  DeliveryStop toStop = DeliveryStop();

  @HiveField(2)
  double distanceKm = 0.0;

  @HiveField(3)
  int durationMinutes = 0;

  /// Calculate average speed for this leg
  double get averageSpeedKmh {
    if (durationMinutes == 0) return 0;
    final hours = durationMinutes / 60;
    return distanceKm / hours;
  }
}

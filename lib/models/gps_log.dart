import 'package:hive/hive.dart';

part 'gps_log.g.dart';

@HiveType(typeId: 1)
class GpsLog extends HiveObject {
  @HiveField(0)
  late DateTime startTime;

  @HiveField(1)
  DateTime? endTime;

  @HiveField(2)
  double totalDistance = 0.0; // in km

  @HiveField(3)
  double totalFare = 0.0;

  @HiveField(4)
  late int vehicleId;

  @HiveField(5)
  late double rateApplied;

  @HiveField(6)
  List<GpsPoint> points = [];

  @HiveField(7)
  List<StayPoint> stays = [];

  int get id => key as int? ?? -1;
}

@HiveType(typeId: 2)
class GpsPoint {
  @HiveField(0)
  double? latitude;

  @HiveField(1)
  double? longitude;

  @HiveField(2)
  DateTime? timestamp;

  @HiveField(3)
  double? speed; // m/s
}

@HiveType(typeId: 3)
class StayPoint {
  @HiveField(0)
  double? latitude;

  @HiveField(1)
  double? longitude;

  @HiveField(2)
  DateTime? arrivalTime;

  @HiveField(3)
  DateTime? departureTime;

  @HiveField(4)
  String? label; // e.g., Delivery, Rest, Office, Home

  @HiveField(5)
  String? note;

  int get durationMinutes {
    if (arrivalTime == null || departureTime == null) return 0;
    return departureTime!.difference(arrivalTime!).inMinutes;
  }
}

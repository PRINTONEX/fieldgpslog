import 'package:isar/isar.dart';

part 'gps_log.g.dart';

@collection
class GpsLog {
  Id id = Isar.autoIncrement;
  
  late DateTime startTime;
  DateTime? endTime;
  
  double totalDistance = 0.0; // in km
  double totalFare = 0.0;
  
  late int vehicleId;
  late double rateApplied;
  
  List<GpsPoint> points = [];
  List<StayPoint> stays = [];
}

@embedded
class GpsPoint {
  double? latitude;
  double? longitude;
  DateTime? timestamp;
  double? speed; // m/s
}

@embedded
class StayPoint {
  double? latitude;
  double? longitude;
  DateTime? arrivalTime;
  DateTime? departureTime;
  
  // Duration in minutes
  int get durationMinutes {
    if (arrivalTime == null || departureTime == null) return 0;
    return departureTime!.difference(arrivalTime!).inMinutes;
  }
}

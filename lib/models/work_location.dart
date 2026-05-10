import 'package:hive/hive.dart';

part 'work_location.g.dart';

@HiveType(typeId: 7)
class WorkLocation extends HiveObject {
  @HiveField(0)
  late String name; // 'Home' or 'Office'

  @HiveField(1)
  late double latitude;

  @HiveField(2)
  late double longitude;

  @HiveField(3)
  double radius; // in meters, default 100m

  WorkLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radius = 100.0,
  });
}

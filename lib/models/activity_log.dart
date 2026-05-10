import 'package:hive/hive.dart';

part 'activity_log.g.dart';

@HiveType(typeId: 10)
class ActivityLog extends HiveObject {
  @HiveField(0)
  late DateTime timestamp;

  @HiveField(1)
  late String event; // e.g., "Left Home", "Reached Office", "Delivery Stop"

  @HiveField(2)
  double? latitude;

  @HiveField(3)
  double? longitude;

  @HiveField(4)
  String? note;

  int get id => (key as int?) ?? -1;
}

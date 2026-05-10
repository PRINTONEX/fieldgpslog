import 'package:hive/hive.dart';

part 'vehicle.g.dart';

@HiveType(typeId: 0)
class Vehicle extends HiveObject {
  @HiveField(0)
  late String name; // e.g., Activa, Bike, Car

  @HiveField(1)
  late double ratePerKm; // e.g., 2.5

  @HiveField(3)
  double? ratePerDelivery; // e.g., ₹40 per delivery

  @HiveField(2)
  bool isDefault = false;

  double get deliveryRate => ratePerDelivery ?? 40.0;

  // Hive uses the key property from HiveObject
  int get id => (key as int?) ?? -1;
}

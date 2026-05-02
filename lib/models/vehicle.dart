import 'package:isar/isar.dart';

part 'vehicle.g.dart';

@collection
class Vehicle {
  Id id = Isar.autoIncrement;
  
  late String name; // e.g., Activa, Bike, Car
  late double ratePerKm; // e.g., 2.5
  bool isDefault = false;
}

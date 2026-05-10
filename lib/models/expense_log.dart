import 'package:hive/hive.dart';

part 'expense_log.g.dart';

@HiveType(typeId: 8)
class ExpenseLog extends HiveObject {
  @HiveField(0)
  late DateTime date;

  @HiveField(1)
  late double amount;

  @HiveField(2)
  late String category; // Fuel, Food, Toll, Parking, Maintenance, Other

  @HiveField(3)
  String? note;

  @HiveField(4)
  int? vehicleId;

  int get id => (key as int?) ?? -1;
}

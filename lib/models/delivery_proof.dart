import 'package:hive/hive.dart';

part 'delivery_proof.g.dart';

@HiveType(typeId: 9)
class DeliveryProof extends HiveObject {
  @HiveField(0)
  late DateTime timestamp;

  @HiveField(1)
  String? imagePath; // Path to local photo

  @HiveField(2)
  String? signaturePath; // Path to local signature image

  @HiveField(3)
  String? otp;

  @HiveField(4)
  String? customerNote;

  @HiveField(5)
  double? paymentCollected;

  @HiveField(6)
  late int stayPointId; // Linking to a specific delivery stop

  @HiveField(7)
  String status = 'Pending'; // Pending, Completed, Failed

  int get id => (key as int?) ?? -1;
}

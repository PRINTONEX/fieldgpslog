// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_proof.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeliveryProofAdapter extends TypeAdapter<DeliveryProof> {
  @override
  final int typeId = 6;

  @override
  DeliveryProof read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeliveryProof()
      ..timestamp = fields[0] as DateTime
      ..imagePath = fields[1] as String?
      ..signaturePath = fields[2] as String?
      ..otp = fields[3] as String?
      ..customerNote = fields[4] as String?
      ..paymentCollected = fields[5] as double?
      ..stayPointId = fields[6] as int
      ..status = fields[7] as String;
  }

  @override
  void write(BinaryWriter writer, DeliveryProof obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.signaturePath)
      ..writeByte(3)
      ..write(obj.otp)
      ..writeByte(4)
      ..write(obj.customerNote)
      ..writeByte(5)
      ..write(obj.paymentCollected)
      ..writeByte(6)
      ..write(obj.stayPointId)
      ..writeByte(7)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryProofAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

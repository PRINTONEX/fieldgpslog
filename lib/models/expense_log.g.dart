// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseLogAdapter extends TypeAdapter<ExpenseLog> {
  @override
  final int typeId = 5;

  @override
  ExpenseLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseLog()
      ..date = fields[0] as DateTime
      ..amount = fields[1] as double
      ..category = fields[2] as String
      ..note = fields[3] as String?
      ..vehicleId = fields[4] as int?;
  }

  @override
  void write(BinaryWriter writer, ExpenseLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.note)
      ..writeByte(4)
      ..write(obj.vehicleId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

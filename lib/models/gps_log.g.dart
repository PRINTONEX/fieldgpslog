// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gps_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GpsLogAdapter extends TypeAdapter<GpsLog> {
  @override
  final int typeId = 1;

  @override
  GpsLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GpsLog()
      ..startTime = fields[0] as DateTime
      ..endTime = fields[1] as DateTime?
      ..totalDistance = fields[2] as double
      ..totalFare = fields[3] as double
      ..vehicleId = fields[4] as int
      ..rateApplied = fields[5] as double
      ..points = (fields[6] as List).cast<GpsPoint>()
      ..stays = (fields[7] as List).cast<StayPoint>();
  }

  @override
  void write(BinaryWriter writer, GpsLog obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.startTime)
      ..writeByte(1)
      ..write(obj.endTime)
      ..writeByte(2)
      ..write(obj.totalDistance)
      ..writeByte(3)
      ..write(obj.totalFare)
      ..writeByte(4)
      ..write(obj.vehicleId)
      ..writeByte(5)
      ..write(obj.rateApplied)
      ..writeByte(6)
      ..write(obj.points)
      ..writeByte(7)
      ..write(obj.stays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpsLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GpsPointAdapter extends TypeAdapter<GpsPoint> {
  @override
  final int typeId = 2;

  @override
  GpsPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GpsPoint()
      ..latitude = fields[0] as double?
      ..longitude = fields[1] as double?
      ..timestamp = fields[2] as DateTime?
      ..speed = fields[3] as double?;
  }

  @override
  void write(BinaryWriter writer, GpsPoint obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.speed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpsPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StayPointAdapter extends TypeAdapter<StayPoint> {
  @override
  final int typeId = 3;

  @override
  StayPoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StayPoint()
      ..latitude = fields[0] as double?
      ..longitude = fields[1] as double?
      ..arrivalTime = fields[2] as DateTime?
      ..departureTime = fields[3] as DateTime?
      ..label = fields[4] as String?
      ..note = fields[5] as String?;
  }

  @override
  void write(BinaryWriter writer, StayPoint obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.arrivalTime)
      ..writeByte(3)
      ..write(obj.departureTime)
      ..writeByte(4)
      ..write(obj.label)
      ..writeByte(5)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StayPointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

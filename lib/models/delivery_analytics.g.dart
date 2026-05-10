// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_analytics.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DeliveryStopAdapter extends TypeAdapter<DeliveryStop> {
  @override
  final int typeId = 4;

  @override
  DeliveryStop read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DeliveryStop()
      ..latitude = fields[0] as double
      ..longitude = fields[1] as double
      ..arrivalTime = fields[2] as DateTime
      ..departureTime = fields[3] as DateTime
      ..stopType = fields[4] as String
      ..distanceFromPreviousStop = fields[5] as double
      ..address = fields[6] as String?
      ..parcelsDelivered = fields[7] as int?
      ..note = fields[8] as String?;
  }

  @override
  void write(BinaryWriter writer, DeliveryStop obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.arrivalTime)
      ..writeByte(3)
      ..write(obj.departureTime)
      ..writeByte(4)
      ..write(obj.stopType)
      ..writeByte(5)
      ..write(obj.distanceFromPreviousStop)
      ..writeByte(6)
      ..write(obj.address)
      ..writeByte(7)
      ..write(obj.parcelsDelivered)
      ..writeByte(8)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryStopAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyTravelSummaryAdapter extends TypeAdapter<DailyTravelSummary> {
  @override
  final int typeId = 5;

  @override
  DailyTravelSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyTravelSummary()
      ..date = fields[0] as DateTime
      ..totalDistanceKm = fields[1] as double
      ..totalWorkingMinutes = fields[2] as int
      ..totalIdleMinutes = fields[3] as int
      ..totalFuelLiters = fields[4] as double
      ..totalFuelCost = fields[5] as double
      ..totalStops = fields[6] as int
      ..totalDeliveriesCompleted = fields[7] as int
      ..stops = (fields[8] as List).cast<DeliveryStop>()
      ..averageSpeed = fields[9] as double
      ..maxSpeed = fields[10] as int
      ..startTime = fields[11] as DateTime?
      ..endTime = fields[12] as DateTime?;
  }

  @override
  void write(BinaryWriter writer, DailyTravelSummary obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.totalDistanceKm)
      ..writeByte(2)
      ..write(obj.totalWorkingMinutes)
      ..writeByte(3)
      ..write(obj.totalIdleMinutes)
      ..writeByte(4)
      ..write(obj.totalFuelLiters)
      ..writeByte(5)
      ..write(obj.totalFuelCost)
      ..writeByte(6)
      ..write(obj.totalStops)
      ..writeByte(7)
      ..write(obj.totalDeliveriesCompleted)
      ..writeByte(8)
      ..write(obj.stops)
      ..writeByte(9)
      ..write(obj.averageSpeed)
      ..writeByte(10)
      ..write(obj.maxSpeed)
      ..writeByte(11)
      ..write(obj.startTime)
      ..writeByte(12)
      ..write(obj.endTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyTravelSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RouteLegAdapter extends TypeAdapter<RouteLeg> {
  @override
  final int typeId = 6;

  @override
  RouteLeg read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RouteLeg()
      ..fromStop = fields[0] as DeliveryStop
      ..toStop = fields[1] as DeliveryStop
      ..distanceKm = fields[2] as double
      ..durationMinutes = fields[3] as int;
  }

  @override
  void write(BinaryWriter writer, RouteLeg obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.fromStop)
      ..writeByte(1)
      ..write(obj.toStop)
      ..writeByte(2)
      ..write(obj.distanceKm)
      ..writeByte(3)
      ..write(obj.durationMinutes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteLegAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

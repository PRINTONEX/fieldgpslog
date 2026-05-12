import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/delivery_analytics.dart';
import '../models/gps_log.dart';
import 'database_service.dart';
import '../core/utils/delivery_analytics_helper.dart';

class AnalyticsService {
  static const String dailySummaryBoxName = 'daily_summaries';

  final DatabaseService _db;
  Box<DailyTravelSummary>? _summaryBox;

  AnalyticsService(this._db);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(DeliveryStopAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(DailyTravelSummaryAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(RouteLegAdapter());
    }

    _summaryBox = Hive.isBoxOpen(dailySummaryBoxName)
        ? Hive.box<DailyTravelSummary>(dailySummaryBoxName)
        : await Hive.openBox<DailyTravelSummary>(dailySummaryBoxName);
  }

  Box<DailyTravelSummary> get summaryBox {
    final box = _summaryBox;
    if (box == null || !box.isOpen) {
      throw StateError('Daily summary box has not been opened.');
    }
    return box;
  }

  /// Generate analytics for a specific GPS log
  DailyTravelSummary generateAnalyticsForLog(
    GpsLog log, {
    double mileageKmPerLiter = 40.0,
    double fuelPricePerLiter = 100.0,
  }) {
    return DeliveryAnalyticsHelper.generateDailySummary(
      log,
      mileageKmPerLiter: mileageKmPerLiter,
      fuelPricePerLiter: fuelPricePerLiter,
    );
  }

  /// Get or generate analytics for a specific date
  Future<DailyTravelSummary?> getAnalyticsForDate(
    DateTime date, {
    double mileageKmPerLiter = 40.0,
    double fuelPricePerLiter = 100.0,
  }) async {
    // Check if already cached
    debugPrint(
      "CACHE BYPASSED FOR DEBUG",
    );
    debugPrint(
      "FETCHING LOGS FROM DATABASE",
    );
    // Generate from logs
    var logs = await _db.getLogsForDate(date);

    // ✅ Filter out "junk" logs (no points recorded) to keep stats accurate
    logs = logs.where((log) => log.points.isNotEmpty).toList();

    debugPrint("====================================");
    debugPrint("ANALYTICS SERVICE DEBUG");

    debugPrint(
      "SELECTED DATE: "
          "${DateFormat('dd-MM-yyyy').format(date)}",
    );

    debugPrint(
      "TOTAL LOGS FOUND: ${logs.length}",
    );

// CHECK ALL LOGS
    for (final log in logs) {

      debugPrint("========= INCLUDED =========");

      debugPrint("ID: ${log.id}");

      debugPrint(
        "START: ${log.startTime}",
      );

      debugPrint(
        "END: ${log.endTime}",
      );

      debugPrint(
        "DISTANCE: ${log.totalDistance}",
      );

      debugPrint(
        "POINTS: ${log.points.length}",
      );

      debugPrint(
        "STOPS: ${log.stays.length}",
      );

      if (log.endTime == null) {

        debugPrint(
          "WARNING: endTime NULL",
        );
      }

      if (log.points.isEmpty) {

        debugPrint(
          "WARNING: NO GPS POINTS",
        );
      }
    }

    if (logs.isEmpty) {

      debugPrint("NO LOGS FOUND");

      return null;
    }
    // Combine all logs from that day
    final combined = _combineLogs(logs);
    debugPrint("========= COMBINED =========");

    debugPrint(
      "COMBINED DISTANCE: "
          "${combined.totalDistance}",
    );

    debugPrint(
      "COMBINED POINTS: "
          "${combined.points.length}",
    );

    debugPrint(
      "COMBINED STOPS: "
          "${combined.stays.length}",
    );

    debugPrint(
      "COMBINED ENDTIME: "
          "${combined.endTime}",
    );
    final summary = generateAnalyticsForLog(
      combined,
      mileageKmPerLiter: mileageKmPerLiter,
      fuelPricePerLiter: fuelPricePerLiter,
    );
    debugPrint("========= SUMMARY =========");

    debugPrint(
      "SUMMARY DISTANCE: "
          "${summary.totalDistanceKm}",
    );

    debugPrint(
      "SUMMARY STOPS: "
          "${summary.totalStops}",
    );

    debugPrint(
      "SUMMARY WORKING TIME: "
          "${summary.formattedWorkingTime}",
    );

    debugPrint(
      "SUMMARY FUEL: "
          "${summary.totalFuelLiters}",
    );

    debugPrint("====================================");
    // Cache it
    await saveSummary(summary);
    return summary;
  }

  /// Get all daily summaries for a date range
  Future<List<DailyTravelSummary>> getAnalyticsRange(
    DateTime start,
    DateTime end,
  ) async {
    final summaries = <DailyTravelSummary>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDate)) {
      final summary = await getAnalyticsForDate(current);
      if (summary != null) {
        summaries.add(summary);
      }
      current = current.add(const Duration(days: 1));
    }

    return summaries;
  }

  /// Save daily summary to cache
  Future<int> saveSummary(DailyTravelSummary summary) async {
    if (summary.isInBox) {
      await summary.save();
      return summary.key as int;
    }
    return await summaryBox.add(summary);
  }

  /// Combine multiple GPS logs into one
  GpsLog _combineLogs(List<GpsLog> logs) {
    if (logs.isEmpty) {
      return GpsLog()
        ..startTime = DateTime.now()
        ..points = []
        ..stays = [];
    }

    if (logs.length == 1) return logs.first;

    // Sort by start time
    logs.sort((a, b) => a.startTime.compareTo(b.startTime));

    final combined = GpsLog()
      ..startTime = logs.first.startTime
      ..endTime = logs.last.endTime ?? DateTime.now()
      ..totalDistance = logs.fold(0.0, (sum, log) => sum + log.totalDistance)
      ..totalFare = logs.fold(0.0, (sum, log) => sum + log.totalFare)
      ..vehicleId = logs.first.vehicleId
      ..rateApplied = logs.first.rateApplied
      ..points = []
      ..stays = [];

    for (final log in logs) {
      combined.points.addAll(log.points);
      combined.stays.addAll(log.stays);
    }

    return combined;
  }

  /// Get stop details for a specific delivery stop
  Map<String, dynamic> getStopDetails(DeliveryStop stop) {
    return {
      'latitude': stop.latitude,
      'longitude': stop.longitude,
      'arrivalTime': stop.arrivalTime,
      'departureTime': stop.departureTime,
      'durationMinutes': stop.durationMinutes,
      'formattedDuration': stop.formattedDuration,
      'stopType': stop.stopType,
      'address': stop.address,
      'parcelsDelivered': stop.parcelsDelivered ?? 0,
      'isSignificantStop': stop.isSignificantStop,
    };
  }

  /// Get summary statistics
  Map<String, dynamic> getSummaryStatistics(DailyTravelSummary summary) {
    return {
      'date': summary.date,
      'totalDistance': summary.totalDistanceKm.toStringAsFixed(2),
      'totalWorkingTime': summary.formattedWorkingTime,
      'totalIdleTime': summary.formattedIdleTime,
      'totalStops': summary.totalStops,
      'efficiencyPercentage': summary.efficiencyPercentage.toStringAsFixed(1),
      'averageSpeed': summary.averageSpeed.toStringAsFixed(2),
      'maxSpeed': summary.maxSpeed,
      'totalFuel': summary.totalFuelLiters.toStringAsFixed(2),
      'totalFuelCost': summary.totalFuelCost.toStringAsFixed(2),
      'deliveriesCompleted': summary.totalDeliveriesCompleted,
    };
  }

  /// Clear all cached analytics (use when settings change)
  Future<void> clearAnalytics() async {
    await summaryBox.clear();
  }
}

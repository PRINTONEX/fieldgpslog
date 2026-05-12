import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../../models/delivery_analytics.dart';
import '../../../models/activity_log.dart';
import '../../../services/analytics_service.dart';
import '../../../services/expense_service.dart';
import '../../../services/database_service.dart';

class AnalyticsController extends GetxController {
  // Use the registered singleton instance
  FlutterBackgroundService get _backgroundService => Get.find<FlutterBackgroundService>();

  final AnalyticsService _analyticsService =
  Get.find<AnalyticsService>();

  final DatabaseService _db = Get.find<DatabaseService>();

  final ExpenseService _expenseService = Get.isRegistered<ExpenseService>() 
      ? Get.find<ExpenseService>() 
      : Get.put(ExpenseService());

  // ================= OBSERVABLES =================

  final Rx<DateTime> selectedDate =
      DateTime.now().obs;

  final Rx<DailyTravelSummary?> dailySummary =
  Rxn<DailyTravelSummary>();

  final RxList<DeliveryStop> deliveryStops =
      <DeliveryStop>[].obs;

  final RxList<ActivityLog> activityLogs =
      <ActivityLog>[].obs;

  // ================= SETTINGS =================

  final RxDouble mileageKmPerLiter = 40.0.obs;
  final RxDouble fuelPricePerLiter = 100.0.obs;
  final RxDouble ratePerDelivery = 40.0.obs;

  // ================= FINANCIALS =================

  final RxDouble totalEarnings = 0.0.obs;
  final RxDouble totalExpenses = 0.0.obs;
  final RxDouble netProfit = 0.0.obs;

  // ================= STATES =================

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  StreamSubscription? _updateSubscription;

  @override
  void onInit() {
    super.onInit();

    // Initial load like History Page
    loadAnalyticsForDate(selectedDate.value);
    _listenToBackgroundService();
  }

  @override
  void onClose() {
    _updateSubscription?.cancel();
    super.onClose();
  }

  void _listenToBackgroundService() {
    _updateSubscription = _backgroundService.on('update').listen((event) {
      // If we are looking at today's data, reload it to show live updates
      final today = DateTime.now();
      if (selectedDate.value.year == today.year &&
          selectedDate.value.month == today.month &&
          selectedDate.value.day == today.day) {
        
        // We reload without showing full screen loading for smooth UI
        loadAnalyticsForDate(selectedDate.value, showLoading: false);
      }
    });
  }

  // =========================================================
  // PUBLIC METHOD
  // =========================================================

  Future<void> loadAnalyticsForDate(DateTime date, {bool showLoading = true}) async {

    try {

      if (showLoading) isLoading.value = true;

      debugPrint(
        "===================================",
      );

      debugPrint(
        "ANALYTICS DATE: "
            "${date.toString()}",
      );

      selectedDate.value = DateTime(
        date.year,
        date.month,
        date.day,
      );
      // Load analytics
      final normalized = DateTime(
        date.year,
        date.month,
        date.day,
      );

      final summary =
      await _analyticsService.getAnalyticsForDate(
        normalized,
        mileageKmPerLiter:
        mileageKmPerLiter.value,
        fuelPricePerLiter:
        fuelPricePerLiter.value,
      );

      // Load activity logs (Left Home, Reached Office, etc.)
      activityLogs.value = _db.getActivityLogsForDate(normalized);
      activityLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (summary != null) {

        dailySummary.value = summary;

        deliveryStops.value = summary.stops;
        
        // Calculate financial metrics
        totalExpenses.value = _expenseService.getTotalExpenseForDate(normalized);
        
        // Use vehicle rate if available, fallback to 2.0
        final kmRate = summary.stops.isNotEmpty ? 2.0 : 2.0; 
        
        final deliveryEarnings = summary.totalDeliveriesCompleted * ratePerDelivery.value;
        final distanceEarnings = summary.totalDistanceKm * kmRate;
        
        totalEarnings.value = deliveryEarnings + distanceEarnings;
        netProfit.value = totalEarnings.value - totalExpenses.value;

        debugPrint(
          "TOTAL STOPS: "
              "${summary.totalStops}",
        );

        debugPrint(
          "TOTAL DISTANCE: "
              "${summary.totalDistanceKm}",
        );

        debugPrint(
          "WORKING TIME: "
              "${summary.formattedWorkingTime}",
        );

        debugPrint(
          "TOTAL FUEL: "
              "${summary.totalFuelLiters}",
        );

      } else {

        dailySummary.value = null;

        deliveryStops.clear();
        
        totalEarnings.value = 0;
        totalExpenses.value = 0;
        netProfit.value = 0;

        errorMessage.value =
        'No analytics found for selected date';

        debugPrint(
          "NO DATA FOUND",
        );
      }

    } catch (e) {

      debugPrint(
        "ANALYTICS ERROR: $e",
      );

      errorMessage.value =
      'Error loading analytics';

    } finally {

      if (showLoading) isLoading.value = false;

      debugPrint(
        "===================================",
      );
    }
  }

  // =========================================================
  // DATE NAVIGATION
  // =========================================================

  void goToNextDay() {

    final next =
    selectedDate.value.add(
      const Duration(days: 1),
    );

    loadAnalyticsForDate(next);
  }

  void goToPreviousDay() {

    final previous =
    selectedDate.value.subtract(
      const Duration(days: 1),
    );

    loadAnalyticsForDate(previous);
  }

  void goToToday() {

    loadAnalyticsForDate(
      DateTime.now(),
    );
  }

  Future<void> selectDate(
      DateTime date) async {

    await loadAnalyticsForDate(date);
  }

  // =========================================================
  // SETTINGS
  // =========================================================

  void updateFuelSettings(
      double mileage,
      double pricePerLiter,
      ) {

    mileageKmPerLiter.value = mileage;

    fuelPricePerLiter.value =
        pricePerLiter;

    loadAnalyticsForDate(
      selectedDate.value,
    );

    _analyticsService.clearAnalytics();
  }

  // =========================================================
  // HELPERS
  // =========================================================

  Map<String, dynamic>
  getFormattedStats() {

    final summary =
        dailySummary.value;

    if (summary == null) return {};

    return _analyticsService
        .getSummaryStatistics(summary);
  }

  int getEfficiencyRating() {

    final summary =
        dailySummary.value;

    if (summary == null) return 0;

    final efficiency =
        summary.efficiencyPercentage;

    if (efficiency >= 80) return 5;
    if (efficiency >= 70) return 4;
    if (efficiency >= 60) return 3;
    if (efficiency >= 40) return 2;

    return 1;
  }

  String getEfficiencyColor() {

    final efficiency =
        dailySummary.value
            ?.efficiencyPercentage ?? 0;

    if (efficiency >= 80) {
      return '#4CAF50';
    }

    if (efficiency >= 60) {
      return '#8BC34A';
    }

    if (efficiency >= 40) {
      return '#FFC107';
    }

    return '#F44336';
  }

  double getCostPerDelivery() {

    final summary =
        dailySummary.value;

    if (summary == null ||
        summary.totalDeliveriesCompleted == 0) {
      return 0;
    }

    return summary.totalFuelCost /
        summary.totalDeliveriesCompleted;
  }

  // =========================================================
  // EXPORT
  // =========================================================

  Map<String, dynamic>
  exportAnalyticsData() {

    final summary =
        dailySummary.value;

    if (summary == null) return {};

    return {

      'date':
      summary.date.toIso8601String(),

      'summary':
      getFormattedStats(),

      'stops':
      deliveryStops.map((stop) {

        return {

          'type':
          stop.stopType,

          'latitude':
          stop.latitude,

          'longitude':
          stop.longitude,

          'arrivalTime':
          stop.arrivalTime
              .toIso8601String(),

          'departureTime':
          stop.departureTime
              .toIso8601String(),

          'duration':
          stop.formattedDuration,

          'distance':
          stop.distanceFromPreviousStop
              .toStringAsFixed(2),

          'parcels':
          stop.parcelsDelivered,
        };

      }).toList(),
    };
  }
}

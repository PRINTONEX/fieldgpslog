import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../models/delivery_analytics.dart';
import '../controllers/analytics_controller.dart';
import 'route_timeline_screen.dart';

class DailyTravelSummaryScreen extends StatefulWidget {
  const DailyTravelSummaryScreen({super.key});

  @override
  State<DailyTravelSummaryScreen> createState() =>
      _DailyTravelSummaryScreenState();
}

class _DailyTravelSummaryScreenState extends State<DailyTravelSummaryScreen> {
  late final AnalyticsController analyticsCtrl;

  @override
  void initState() {
    super.initState();
    analyticsCtrl = Get.isRegistered<AnalyticsController>()
        ? Get.find<AnalyticsController>()
        : Get.put(AnalyticsController());
  }

  @override
  Widget build(BuildContext context) {
    // 7. Helper theme variables at top of build()
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyLarge?.color;
    final subTextColor = theme.textTheme.bodyMedium?.color;
    final dividerColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'Daily Analytics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cardColor,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Obx(() {
        if (analyticsCtrl.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        if (analyticsCtrl.dailySummary.value == null) {
          return Column(
            children: [
              // ALWAYS SHOW DATE SELECTOR
              _buildDateSelector(context, primaryColor, cardColor, subTextColor),

              // EMPTY STATE
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 100,
                        color: subTextColor?.withValues(alpha: 0.2) ?? dividerColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        analyticsCtrl.errorMessage.value.isNotEmpty
                            ? analyticsCtrl.errorMessage.value
                            : 'No analytics found for selected date',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: analyticsCtrl.selectedDate.value,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );

                          if (picked != null) {
                            await analyticsCtrl.loadAnalyticsForDate(picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: const Text("Select Date"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final summary = analyticsCtrl.dailySummary.value!;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ================= DATE SELECTOR =================
              _buildDateSelector(context, primaryColor, cardColor, subTextColor),

              // ================= PRIMARY METRICS =================
              _buildPrimaryMetrics(summary, cardColor, subTextColor),

              // ================= EFFICIENCY CARD =================
              _buildEfficiencyCard(context, summary, subTextColor),

              // ================= STOPS TIMELINE =================
              _buildStopsSection(context, summary, primaryColor, subTextColor),

              // ================= FUEL ANALYTICS =================
              _buildFuelAnalytics(context, summary, subTextColor),

              // ================= ROUTE TIMELINE BUTTON =================
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Get.to(() => const RouteTimelineScreen());
                  },
                  icon: const Icon(Icons.timeline),
                  label: const Text('View Route Timeline'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: primaryColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      }),
    );
  }

  // ================= DATE SELECTOR =================
  Widget _buildDateSelector(BuildContext context, Color primaryColor, Color cardColor, Color? subTextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: cardColor,
      child: Row(
        children: [
          // PREVIOUS
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: analyticsCtrl.goToPreviousDay,
            color: primaryColor,
          ),

          // DATE BUTTON
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: analyticsCtrl.selectedDate.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );

                if (picked != null) {
                  await analyticsCtrl.loadAnalyticsForDate(picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE').format(analyticsCtrl.selectedDate.value),
                          style: TextStyle(
                            fontSize: 11,
                            color: subTextColor ?? Colors.grey,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(analyticsCtrl.selectedDate.value),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // NEXT
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: analyticsCtrl.goToNextDay,
            color: primaryColor,
          ),
        ],
      ),
    );
  }

  // ================= PRIMARY METRICS =================
  Widget _buildPrimaryMetrics(DailyTravelSummary summary, Color cardColor, Color? subTextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildMetricCard(
                '📍 Distance',
                '${summary.totalDistanceKm.toStringAsFixed(2)} km',
                Colors.blue,
                subTextColor,
              ),
              _buildMetricCard(
                '⏱️ Working Time',
                summary.formattedWorkingTime,
                Colors.green,
                subTextColor,
              ),
              _buildMetricCard(
                '🛑 Total Stops',
                '${summary.totalStops}',
                Colors.orange,
                subTextColor,
              ),
              _buildMetricCard(
                '📦 Speed (Avg)',
                '${summary.averageSpeed.toStringAsFixed(1)} km/h',
                Colors.purple,
                subTextColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= METRIC CARD =================
  Widget _buildMetricCard(String title, String value, Color accentColor, Color? subTextColor) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: accentColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: subTextColor ?? Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= EFFICIENCY CARD =================
  Widget _buildEfficiencyCard(BuildContext context, DailyTravelSummary summary, Color? subTextColor) {
    final efficiency = summary.efficiencyPercentage;
    final rating = analyticsCtrl.getEfficiencyRating();
    final dividerColor = Theme.of(context).dividerColor;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Efficiency',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: index < rating ? Colors.amber : (subTextColor?.withValues(alpha: 0.2) ?? Colors.grey.withValues(alpha: 0.2)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: efficiency / 100,
                      minHeight: 10,
                      backgroundColor: subTextColor?.withValues(alpha: 0.1) ?? Colors.grey.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        efficiency >= 80
                            ? Colors.green
                            : efficiency >= 60
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${efficiency.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildEfficiencyMetric('Active',
                      (summary.totalWorkingMinutes - summary.totalIdleMinutes), subTextColor),
                  VerticalDivider(color: dividerColor.withValues(alpha: 0.2), indent: 4, endIndent: 4),
                  _buildEfficiencyMetric('Idle', summary.totalIdleMinutes, subTextColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEfficiencyMetric(String label, int minutes, Color? subTextColor) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: subTextColor ?? Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          '$hours:${mins.toString().padLeft(2, '0')}h',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  // ================= STOPS SECTION =================
  Widget _buildStopsSection(BuildContext context, DailyTravelSummary summary, Color primaryColor, Color? subTextColor) {
    final dividerColor = Theme.of(context).dividerColor;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Delivery Stops',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${summary.totalStops} stops',
                    style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...summary.stops.map((stop) => _buildStopItem(context, stop, subTextColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildStopItem(BuildContext context, DeliveryStop stop, Color? subTextColor) {
    final stopEmoji = stop.stopType == 'home'
        ? '🏠'
        : stop.stopType == 'office'
            ? '🏢'
            : '📦';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: subTextColor?.withValues(alpha: 0.03) ?? Colors.grey.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
            ),
            child: Text(stopEmoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.stopType.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      color: subTextColor ?? Colors.grey,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8),
                ),
                const SizedBox(height: 2),
                Text(
                  '${stop.durationMinutes} min stay',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${DateFormat('hh:mm a').format(stop.arrivalTime)} → ${DateFormat('hh:mm a').format(stop.departureTime)}',
                  style: TextStyle(fontSize: 11, color: subTextColor ?? Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                stop.distanceFromPreviousStop.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'km',
                style: TextStyle(fontSize: 10, color: subTextColor ?? Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= FUEL ANALYTICS =================
  Widget _buildFuelAnalytics(BuildContext context, DailyTravelSummary summary, Color? subTextColor) {
    final dividerColor = Theme.of(context).dividerColor;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dividerColor.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fuel & Cost Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFuelMetric(
                  '⛽ Fuel Used',
                  '${summary.totalFuelLiters.toStringAsFixed(2)} L',
                  subTextColor,
                ),
                _buildFuelMetric(
                  '💰 Total Cost',
                  '₹${summary.totalFuelCost.toStringAsFixed(2)}',
                  subTextColor,
                ),
                _buildFuelMetric(
                  '🎯 Mileage',
                  '${(summary.totalDistanceKm / (summary.totalFuelLiters > 0 ? summary.totalFuelLiters : 1)).toStringAsFixed(1)} km/l',
                  subTextColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuelMetric(String label, String value, Color? subTextColor) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: subTextColor ?? Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}

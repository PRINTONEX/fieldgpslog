import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/debug_controller.dart';
import '../../tracking/controllers/tracking_controller.dart';
import '../../analytics/controllers/analytics_controller.dart';
import '../../dashboard/controllers/dashboard_map_controller.dart';
import '../../../services/log_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DebugController debugCtrl = Get.put(DebugController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Debug & Inspector'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              debugCtrl.refreshDbStats();
              if (Get.isRegistered<AnalyticsController>()) {
                Get.find<AnalyticsController>().loadAnalyticsForDate(DateTime.now(), showLoading: false);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => LogService.exportLogs(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Database'),
            Tab(text: 'Live GPS'),
            Tab(text: 'Polyline'),
            Tab(text: 'Analytics'),
            Tab(text: 'Tracking State'),
            Tab(text: 'Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDatabaseTab(),
          _buildLiveGpsTab(),
          _buildPolylineTab(),
          _buildAnalyticsTab(),
          _buildStateTab(),
          _buildLogsTab(),
        ],
      ),
    );
  }

  Widget _buildDatabaseTab() {
    return Obx(() => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Hive Boxes (Local Storage)'),
        _buildDataRow('GpsLogs (Trips)', '${debugCtrl.gpsLogCount.value} records'),
        _buildDataRow('Vehicles', '${debugCtrl.vehicleCount.value} records'),
        _buildDataRow('Work Locations', '${debugCtrl.workLocationCount.value} records'),
        _buildDataRow('Activity Logs', '${debugCtrl.activityLogCount.value} records'),
        const Divider(height: 32),
        _buildSectionHeader('Latest Trip Data'),
        _buildDataRow('Active Trip ID', '${debugCtrl.activeTripId.value}'),
        _buildDataRow('Saved Route Points', '${debugCtrl.activePointsCount.value}'),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: debugCtrl.refreshDbStats,
          icon: const Icon(Icons.sync),
          label: const Text('Refresh DB Stats'),
        ),
      ],
    ));
  }

  Widget _buildLiveGpsTab() {
    if (!Get.isRegistered<TrackingController>()) {
      return const Center(child: Text("TrackingController not initialized"));
    }
    final trackingCtrl = Get.find<TrackingController>();
    
    return Obx(() => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Realtime Values'),
        _buildDataRow('Is Tracking Active', '${trackingCtrl.isTracking.value}'),
        _buildDataRow('Status', trackingCtrl.trackingStatus.value),
        _buildDataRow('Activity Type', trackingCtrl.currentActivity.value),
        _buildDataRow('Speed', '${trackingCtrl.currentSpeed.value.toStringAsFixed(2)} km/h'),
        _buildDataRow('Bearing', '${trackingCtrl.currentBearing.value.toStringAsFixed(1)}°'),
        _buildDataRow('Distance Calculated', '${trackingCtrl.totalDistance.value.toStringAsFixed(3)} km'),
        _buildDataRow('Session Duration', trackingCtrl.tripDuration.value),
      ],
    ));
  }

  Widget _buildPolylineTab() {
    if (!Get.isRegistered<DashboardMapController>()) {
      return const Center(child: Text("DashboardMapController not initialized"));
    }
    final mapCtrl = Get.find<DashboardMapController>();
    
    return Obx(() => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Route Rendering State'),
        _buildDataRow('Total Polylines', '${mapCtrl.polylines.length}'),
        _buildDataRow('Total Markers', '${mapCtrl.markers.length}'),
        _buildDataRow('In-Memory Route Points', '${mapCtrl.routePoints.length}'),
        _buildDataRow('Navigation Mode', '${mapCtrl.isNavMode.value}'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
             Get.snackbar("Polyline Debug", "Polylines: ${mapCtrl.polylines.map((p) => p.polylineId.value).join(', ')}");
          },
          child: const Text('Inspect Polyline IDs'),
        )
      ],
    ));
  }

  Widget _buildAnalyticsTab() {
    if (!Get.isRegistered<AnalyticsController>()) {
      return const Center(child: Text("AnalyticsController not initialized"));
    }
    final analyticsCtrl = Get.find<AnalyticsController>();
    
    return Obx(() {
      final summary = analyticsCtrl.dailySummary.value;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Current Aggregation'),
          _buildDataRow('Selected Date', DateFormat('yyyy-MM-dd').format(analyticsCtrl.selectedDate.value)),
          _buildDataRow('Is Loading', '${analyticsCtrl.isLoading.value}'),
          _buildDataRow('Error Message', analyticsCtrl.errorMessage.value.isEmpty ? 'None' : analyticsCtrl.errorMessage.value),
          const Divider(height: 32),
          _buildSectionHeader('Calculated Metrics'),
          _buildDataRow('Total Distance', '${summary?.totalDistanceKm.toStringAsFixed(2) ?? '0.00'} km'),
          _buildDataRow('Total Stops', '${summary?.totalStops ?? 0}'),
          _buildDataRow('Deliveries Completed', '${summary?.totalDeliveriesCompleted ?? 0}'),
          _buildDataRow('Net Profit', '₹${analyticsCtrl.netProfit.value.toStringAsFixed(2)}'),
          _buildDataRow('Activity Logs Count', '${analyticsCtrl.activityLogs.length}'),
        ],
      );
    });
  }

  Widget _buildStateTab() {
    return Obx(() => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('System States'),
        _buildDataRow('Background Service', debugCtrl.isBackgroundRunning.value ? 'RUNNING' : 'STOPPED'),
        _buildDataRow('Foreground Service', debugCtrl.isBackgroundRunning.value ? 'ACTIVE' : 'INACTIVE'),
      ],
    ));
  }

  Widget _buildLogsTab() {
    return GetBuilder<DebugController>(
      id: 'logs',
      builder: (_) {
        final logs = debugCtrl.getRawLogs();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Logs: ${logs.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: debugCtrl.clearLogs,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Clear', style: TextStyle(color: Colors.red)),
                  )
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  Color color = Colors.black87;
                  if (log.contains('[ERROR]') || log.contains('⚠️') || log.contains('❌')) color = Colors.red;
                  else if (log.contains('✅') || log.contains('🚀')) color = Colors.green[700]!;
                  else if (log.contains('📍')) color = Colors.blue[700]!;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                    child: Text(
                      log,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: color),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }
}

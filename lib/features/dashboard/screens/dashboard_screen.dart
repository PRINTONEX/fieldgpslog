import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_map_controller.dart';
import '../../tracking/controllers/tracking_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controllers
    final trackingCtrl = Get.put(TrackingController());
    final mapCtrl = Get.put(DashboardMapController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field GPS Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.toNamed('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLiveStats(trackingCtrl),
          Expanded(
            child: Obx(() => GoogleMap(
              initialCameraPosition: CameraPosition(
                target: mapCtrl.initialPosition,
                zoom: 15,
              ),
              onMapCreated: mapCtrl.onMapCreated,
              myLocationEnabled: true,
              markers: mapCtrl.markers.value,
              polylines: mapCtrl.polylines.value,
            )),
          ),
          _buildControlPanel(trackingCtrl),
        ],
      ),
    );
  }

  Widget _buildLiveStats(TrackingController ctrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Get.theme.colorScheme.surfaceVariant,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statBox("Distance", ctrl.totalDistance, "km"),
          _statBox("Current Fare", ctrl.totalFare, "₹"),
          Obx(() => _statBox("Vehicle", ctrl.selectedVehicle.value?.name ?? "None", "")),
        ],
      ),
    );
  }

  Widget _statBox(String label, dynamic value, String unit) {
    return Column(
      children: [
        Text(label, style: Get.textTheme.labelSmall),
        Obx(() {
          String displayValue = value is RxDouble ? value.value.toStringAsFixed(2) : value.toString();
          return Text(
            "$displayValue $unit",
            style: Get.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Get.theme.colorScheme.primary,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildControlPanel(TrackingController ctrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Obx(() => ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
          backgroundColor: ctrl.isTracking.value ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: ctrl.isTracking.value ? ctrl.stopTracking : ctrl.startTracking,
        child: Text(
          ctrl.isTracking.value ? "STOP TRACKING" : "START TRACKING",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      )),
    );
  }
}

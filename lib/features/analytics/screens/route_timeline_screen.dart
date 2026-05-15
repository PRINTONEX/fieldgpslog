import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/delivery_analytics.dart';
import '../../../models/work_location.dart';
import '../../../services/database_service.dart';
import '../../../core/utils/distance_calculator.dart';
import '../controllers/analytics_controller.dart';
import '../controllers/replay_controller.dart';

class RouteTimelineScreen extends StatefulWidget {
  const RouteTimelineScreen({super.key});

  @override
  State<RouteTimelineScreen> createState() => _RouteTimelineScreenState();
}

class _RouteTimelineScreenState extends State<RouteTimelineScreen> {
  late final ReplayController controller;
  final Completer<GoogleMapController> _mapCompleter = Completer();
  final RxBool _isFullScreen = false.obs;
  WorkLocation? _officeLocation;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ReplayController());
    _loadOfficeLocation();
  }

  void _loadOfficeLocation() {
    final db = Get.find<DatabaseService>();
    try {
      _officeLocation = db.workLocationBox.values.firstWhere(
        (loc) => loc.name.toLowerCase() == 'office',
      );
    } catch (_) {
      _officeLocation = null;
    }
  }

  double _getDistanceFromOffice(double lat, double lng) {
    if (_officeLocation == null) return 0.0;
    return DistanceCalculator.calculateDistance(
      lat,
      lng,
      _officeLocation!.latitude,
      _officeLocation!.longitude,
    );
  }

  Future<void> _zoomToStop(DeliveryStop stop) async {
    final GoogleMapController mapCtrl = await _mapCompleter.future;
    mapCtrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(stop.latitude, stop.longitude),
          zoom: 18,
          tilt: 0,
        ),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<ReplayController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Route Timeline'),
        actions: [
          IconButton(
            icon: Obx(() => Icon(_isFullScreen.value ? Icons.fullscreen_exit : Icons.fullscreen)),
            onPressed: () => _isFullScreen.toggle(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Map Section
            Expanded(
              flex: _isFullScreen.value ? 10 : 4,
              child: Stack(
                children: [
                  _buildMap(),
                  if (!_isFullScreen.value)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        onPressed: () async {
                          final map = await _mapCompleter.future;
                          map.animateCamera(CameraUpdate.zoomIn());
                        },
                        child: const Icon(Icons.add),
                      ),
                    ),
                  if (!_isFullScreen.value)
                    Positioned(
                      bottom: 70,
                      right: 16,
                      child: FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        onPressed: () async {
                          final map = await _mapCompleter.future;
                          map.animateCamera(CameraUpdate.zoomOut());
                        },
                        child: const Icon(Icons.remove),
                      ),
                    ),
                ],
              ),
            ),

            // Timeline Section
            if (!_isFullScreen.value)
              Expanded(
                flex: 6,
                child: _buildTimelineList(),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: controller.allPoints.isNotEmpty ? controller.allPoints.first : const LatLng(0, 0),
        zoom: 15,
      ),
      onMapCreated: (mapCtrl) => _mapCompleter.complete(mapCtrl),
      markers: controller.markers,
      polylines: controller.polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: true,
    );
  }

  Widget _buildTimelineList() {
    if (controller.stops.isEmpty) {
      return const Center(child: Text("No stops detected for this trip."));
    }

    // Calculate totals for the 4 categories
    int homeMinutes = 0;
    int officeMinutes = 0;
    int deliveryMinutes = 0;
    int restMinutes = 0;

    for (var stop in controller.stops) {
      final type = stop.stopType.toLowerCase();
      debugPrint("🔍 RouteTimeline: Found stop type: '$type' | Duration: ${stop.durationMinutes} min");
      
      if (type == 'home') homeMinutes += stop.durationMinutes;
      else if (type == 'office') officeMinutes += stop.durationMinutes;
      else if (type == 'rest') restMinutes += stop.durationMinutes;
      else if (type == 'delivery') deliveryMinutes += stop.durationMinutes;
    }

    return Column(
      children: [
        // Summary Card for the 4 Categories
        _buildCategorySummary(homeMinutes, officeMinutes, deliveryMinutes, restMinutes),
        
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text("Timeline Detail", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),

        // Timeline List with the dot-and-line style
        Expanded(
          child: ListView.builder(
            itemCount: controller.stops.length,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemBuilder: (context, index) {
              final stop = controller.stops[index];
              final time = "${DateFormat('hh:mm a').format(stop.arrivalTime)} - ${DateFormat('hh:mm a').format(stop.departureTime)}";
              final distFromOffice = _getDistanceFromOffice(stop.latitude, stop.longitude);

              return IntrinsicHeight(
                child: Row(
                  children: [
                    // Dot and Line Column
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStopColor(stop.stopType),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (index != controller.stops.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    
                    // Content Column
                    Expanded(
                      child: InkWell(
                        onTap: () => _zoomToStop(stop),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(stop.stopType.toUpperCase(), 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text("${stop.durationMinutes} min", 
                                    style: TextStyle(color: _getStopColor(stop.stopType), fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                "Last Stop: ${stop.distanceFromPreviousStop.toStringAsFixed(1)} km | Office: ${distFromOffice.toStringAsFixed(1)} km",
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySummary(int home, int office, int delivery, int rest) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Time Breakdown", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCategoryItem("🏠 Home", home, Colors.green),
              _buildCategoryItem("🏢 Office", office, Colors.blue),
              _buildCategoryItem("📦 Delivery", delivery, Colors.deepPurple),
              _buildCategoryItem("☕ Rest", rest, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String label, int minutes, Color color) {
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    final timeStr = hours > 0 ? "${hours}h ${remainingMins}m" : "${remainingMins}m";

    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          timeStr,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getStopColor(String type) {
    switch (type.toLowerCase()) {
      case 'home': return Colors.green;
      case 'office': return Colors.blue;
      case 'rest': return Colors.orange;
      default: return Colors.deepPurple;
    }
  }

  IconData _getStopIcon(String type) {
    switch (type.toLowerCase()) {
      case 'home': return Icons.home_rounded;
      case 'office': return Icons.business_rounded;
      case 'rest': return Icons.coffee_rounded;
      default: return Icons.local_shipping_rounded;
    }
  }
}

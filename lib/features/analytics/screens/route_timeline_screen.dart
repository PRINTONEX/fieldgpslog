import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/delivery_analytics.dart';
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
  DateTime? _lastCameraUpdate;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ReplayController());
    
    // Add camera listener to the animation
    controller.animationController.addListener(_updateCameraIfNeeded);
  }

  void _updateCameraIfNeeded() async {
    if (!controller.isAutoFollowing.value || controller.currentPosition.value == null) return;
    
    final now = DateTime.now();
    if (_lastCameraUpdate == null || now.difference(_lastCameraUpdate!) > const Duration(milliseconds: 300)) {
      _lastCameraUpdate = now;
      final GoogleMapController mapCtrl = await _mapCompleter.future;
      
      double speed = controller.currentSpeed.value;
      double zoom = 17.5;
      if (speed > 40) zoom = 16.0;
      else if (speed < 5) zoom = 18.5;

      mapCtrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: controller.currentPosition.value!,
            zoom: zoom,
            bearing: controller.currentRotation.value,
            tilt: 45,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    Get.delete<ReplayController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        }
        return Stack(
          children: [
            _buildMap(),
            _buildHUD(),
            _buildTimelineDrawer(),
            _buildBottomControls(),
            _buildTopBar(),
          ],
        );
      }),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Get.back(),
            ),
          ),
          _buildGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              DateFormat('dd MMM yyyy').format(Get.find<AnalyticsController>().selectedDate.value),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Obx(() => CircleAvatar(
            backgroundColor: controller.isAutoFollowing.value ? Colors.cyanAccent : Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: Icon(
                controller.isAutoFollowing.value ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                color: controller.isAutoFollowing.value ? Colors.black : Colors.white,
              ),
              onPressed: () => controller.isAutoFollowing.toggle(),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: controller.allPoints.isNotEmpty ? controller.allPoints.first : const LatLng(0, 0),
        zoom: 17,
        tilt: 45,
      ),
      onMapCreated: (mapCtrl) => _mapCompleter.complete(mapCtrl),
      markers: controller.markers,
      polylines: controller.polylines,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      style: _darkMapStyle,
      onCameraMoveStarted: () {
        // Optional: If you want manual move to disable auto-follow temporarily
        // But for "driving" feel, we can keep it active unless user taps a button
      },
    );
  }

  Widget _buildHUD() {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildGlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.navigation_rounded, color: Colors.cyanAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Obx(() => Text(controller.currentStatus.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                            Text("JOURNEY IN PROGRESS", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildGlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(() => Text("${controller.currentSpeed.value.toStringAsFixed(0)}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold))),
                    const Text("km/h", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Obx(() => _buildHUDStat("Distance", "${controller.currentDistance.value.toStringAsFixed(1)} km")),
                Obx(() => _buildHUDStat("Stops", "${controller.stops.where(_isStopReached).length} / ${controller.stops.length}")),
                _buildHUDStat("Total", "${Get.find<AnalyticsController>().dailySummary.value?.totalDistanceKm.toStringAsFixed(1)} km"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHUDStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Obx(() {
                  final duration = controller.animationController.duration ?? Duration.zero;
                  final currentSeconds = (controller.progress.value * duration.inSeconds).toInt();
                  return Text(
                    _formatDuration(Duration(seconds: currentSeconds)),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                  );
                }),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.cyanAccent,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: Colors.white,
                      trackHeight: 2,
                    ),
                    child: Obx(() => Slider(
                      value: controller.progress.value.clamp(0.0, 1.0),
                      onChanged: (val) {
                        controller.animationController.value = val;
                      },
                    )),
                  ),
                ),
                Obx(() {
                  // Access playbackSpeed to ensure this updates when duration changes via speed change
                  controller.playbackSpeed.value;
                  return Text(
                    _formatDuration(controller.animationController.duration ?? Duration.zero),
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                  );
                }),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildIconButton(Icons.replay_rounded, () => controller.animationController.reset()),
                Obx(() => _buildIconButton(
                  controller.isPlaying.value ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  controller.togglePlay,
                  isLarge: true,
                )),
                Obx(() => _buildTextButton("${controller.playbackSpeed.value.toInt()}x", controller.changeSpeed)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {bool isLarge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: isLarge ? 30 : 22,
        backgroundColor: isLarge ? Colors.cyanAccent : Colors.white.withOpacity(0.1),
        child: Icon(icon, color: isLarge ? Colors.black : Colors.white),
      ),
    );
  }

  Widget _buildTextButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTimelineDrawer() {
    return Positioned(
      top: 180,
      right: 16,
      bottom: 150,
      width: 60,
      child: SingleChildScrollView(
        child: Column(
          children: List.generate(controller.stops.length, (index) {
            final stop = controller.stops[index];
            return Obx(() {
              final bool isReached = _isStopReached(stop);
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isReached ? Colors.cyanAccent : Colors.white10,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Center(
                      child: Icon(
                        _getStopIcon(stop.stopType),
                        size: 20,
                        color: isReached ? Colors.black : Colors.white54,
                      ),
                    ),
                  ),
                  if (index < controller.stops.length - 1)
                    Container(width: 2, height: 40, color: Colors.white10),
                ],
              );
            });
          }),
        ),
      ),
    );
  }

  bool _isStopReached(DeliveryStop stop) {
    if (controller.allGpsPoints.isEmpty) return false;
    final currentIndex = (controller.progress.value * (controller.allGpsPoints.length - 1)).floor();
    final currentTime = controller.allGpsPoints[currentIndex].timestamp;
    return currentTime != null && currentTime.isAfter(stop.arrivalTime);
  }

  IconData _getStopIcon(String type) {
    switch (type) {
      case 'home': return Icons.home_rounded;
      case 'office': return Icons.business_rounded;
      default: return Icons.local_shipping_rounded;
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  final String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]}
]
''';
}

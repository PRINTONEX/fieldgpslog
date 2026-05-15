import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/gps_log.dart';
import '../../../models/delivery_analytics.dart';
import '../../../services/database_service.dart';
import '../../../services/image_marker.dart';
import '../controllers/analytics_controller.dart';

class ReplayController extends GetxController with GetSingleTickerProviderStateMixin {
  late AnimationController animationController;
  
  // Data
  final RxList<GpsPoint> allGpsPoints = <GpsPoint>[].obs;
  final RxList<LatLng> allPoints = <LatLng>[].obs;
  final RxList<DeliveryStop> stops = <DeliveryStop>[].obs;
  final RxBool isLoading = true.obs;
  
  // Map Elements (Reactive Sets)
  final RxSet<Marker> markers = <Marker>{}.obs;
  final RxSet<Polyline> polylines = <Polyline>{}.obs;
  
  // Replay State
  final RxDouble playbackSpeed = 1.0.obs;
  final RxBool isAutoFollowing = true.obs;
  final RxBool isPlaying = false.obs;
  
  // Animated Values (Reactive)
  final Rxn<LatLng> currentPosition = Rxn<LatLng>();
  final RxDouble currentRotation = 0.0.obs;
  final RxDouble currentSpeed = 0.0.obs;
  final RxDouble currentDistance = 0.0.obs;
  final RxString currentStatus = "Starting Journey".obs;
  final RxDouble progress = 0.0.obs;

  BitmapDescriptor? bikeIcon;

  @override
  void onInit() {
    super.onInit();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(_onAnimationUpdate);
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final analyticsCtrl = Get.find<AnalyticsController>();
    bikeIcon = await bitmapFromAsset("assets/images/gpsMarker.png", targetWidth: 60);
    
    try {
      final db = Get.find<DatabaseService>();
      final logs = await db.getLogsForDate(analyticsCtrl.selectedDate.value);
      
      List<GpsPoint> gpsPoints = [];
      for (var log in logs) {
        gpsPoints.addAll(log.points.where((p) => p.latitude != null && p.longitude != null));
      }
      gpsPoints.sort((a, b) => (a.timestamp ?? DateTime.now()).compareTo(b.timestamp ?? DateTime.now()));

      allGpsPoints.assignAll(gpsPoints);
      allPoints.assignAll(gpsPoints.map((p) => LatLng(p.latitude!, p.longitude!)).toList());
      stops.assignAll(analyticsCtrl.dailySummary.value?.stops ?? []);
      
      if (allPoints.isNotEmpty) {
        currentPosition.value = allPoints.first;
        animationController.duration = Duration(seconds: (gpsPoints.length / 10).clamp(10, 300).toInt());
        
        // Initial Map Setup
        _updateStaticMapElements();
      }
      isLoading.value = false;
    } catch (e) {
      isLoading.value = false;
    }
  }

  void _updateStaticMapElements() {
    polylines.clear();
    markers.clear();

    // Background full route
    polylines.add(Polyline(
      polylineId: const PolylineId('route_bg'),
      points: allPoints,
      color: Colors.white.withOpacity(0.15),
      width: 3,
    ));

    // Stop markers
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      markers.add(Marker(
        markerId: MarkerId('stop_$i'),
        position: LatLng(stop.latitude, stop.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          stop.stopType == 'home' ? BitmapDescriptor.hueGreen : 
          stop.stopType == 'office' ? BitmapDescriptor.hueBlue : 
          BitmapDescriptor.hueOrange
        ),
      ));
    }
  }

  int _lastPolylineUpdateIndex = -1;
  double _smoothedBearing = 0.0;

  void _onAnimationUpdate() {
    if (allPoints.isEmpty) return;

    final double value = animationController.value;
    progress.value = value;
    final double indexFloat = value * (allPoints.length - 1);
    final int index = indexFloat.floor();
    final double fraction = indexFloat - index;

    LatLng newPos;
    double targetBearing = currentRotation.value;

    if (index >= allPoints.length - 1) {
      newPos = allPoints.last;
    } else {
      final start = allPoints[index];
      final end = allPoints[index + 1];
      
      // Smooth linear interpolation for position
      newPos = LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction
      );

      // Calculate bearing and smooth it
      targetBearing = _calculateBearing(start, end);
      // Simple LERP for bearing to avoid rapid jitter
      _smoothedBearing = _interpolateBearing(_smoothedBearing, targetBearing, 0.2);
      currentRotation.value = _smoothedBearing;
    }

    currentPosition.value = newPos;
    final speedKmh = (allGpsPoints[index].speed ?? 0.0) * 3.6;
    currentSpeed.value = speedKmh;
    
    _updateStatus(index);
    
    final totalDist = Get.find<AnalyticsController>().dailySummary.value?.totalDistanceKm ?? 0;
    currentDistance.value = (index / allPoints.length) * totalDist;

    // PERFORMANCE OPTIMIZATION: 
    // Only update polyline every 5 points to reduce Map render load
    // But always update bike marker position for visual smoothness
    if (index != _lastPolylineUpdateIndex && index % 5 == 0) {
      _updateDynamicPolylines(index);
      _lastPolylineUpdateIndex = index;
    }
    
    _updateBikeMarker();
  }

  void _updateDynamicPolylines(int index) {
    // 1. Update Animated Route Polyline
    final traveledPoints = allPoints.sublist(0, index + 1);
    
    polylines.removeWhere((p) => p.polylineId.value == 'route_traveled' || p.polylineId.value == 'route_traveled_glow');
    
    polylines.add(Polyline(
      polylineId: const PolylineId('route_traveled_glow'),
      points: traveledPoints,
      color: const Color(0x4000FFFF),
      width: 12,
      jointType: JointType.round,
    ));
    polylines.add(Polyline(
      polylineId: const PolylineId('route_traveled'),
      points: traveledPoints,
      color: const Color(0xFF00E5FF),
      width: 5,
      jointType: JointType.round,
    ));
  }

  void _updateBikeMarker() {
    if (currentPosition.value == null) return;
    
    markers.removeWhere((m) => m.markerId.value == 'bike');
    markers.add(Marker(
      markerId: const MarkerId('bike'),
      position: currentPosition.value!,
      rotation: currentRotation.value,
      anchor: const Offset(0.5, 0.5),
      flat: true,
      zIndexInt: 100,
      icon: bikeIcon ?? BitmapDescriptor.defaultMarker,
    ));
  }

  double _interpolateBearing(double start, double end, double fraction) {
    double diff = end - start;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (start + diff * fraction + 360) % 360;
  }

  void _updateStatus(int index) {
    String status = "Driving...";
    final pointTime = allGpsPoints[index].timestamp;
    if (pointTime != null) {
      for (var stop in stops) {
        if (pointTime.isAfter(stop.arrivalTime) && pointTime.isBefore(stop.departureTime)) {
          status = "At ${stop.stopType.toUpperCase()}";
          break;
        }
      }
    }
    if (currentStatus.value != status) currentStatus.value = status;
  }



  double _calculateBearing(LatLng start, LatLng end) {
    if (start == end) return currentRotation.value;
    double lat1 = start.latitude * math.pi / 180;
    double lon1 = start.longitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double lon2 = end.longitude * math.pi / 180;
    double dLon = lon2 - lon1;
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void togglePlay() {
    if (animationController.isAnimating) {
      animationController.stop();
      isPlaying.value = false;
    } else {
      if (animationController.value >= 1.0) animationController.reset();
      animationController.forward();
      isPlaying.value = true;
    }
  }

  void changeSpeed() {
    if (playbackSpeed.value == 1.0) playbackSpeed.value = 2.0;
    else if (playbackSpeed.value == 2.0) playbackSpeed.value = 4.0;
    else if (playbackSpeed.value == 4.0) playbackSpeed.value = 8.0;
    else playbackSpeed.value = 1.0;
    
    animationController.duration = Duration(
      seconds: (allPoints.length / (10 * playbackSpeed.value)).clamp(5, 300).toInt()
    );
    if (isPlaying.value) animationController.forward();
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}

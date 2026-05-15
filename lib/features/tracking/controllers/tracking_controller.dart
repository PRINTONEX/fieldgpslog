import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart' as ar;
import '../../../services/database_service.dart';
import '../../../services/location_service.dart';
import '../../../models/gps_log.dart';
import '../../../models/vehicle.dart';
import '../../analytics/controllers/analytics_controller.dart';
import 'dart:developer' as developer;

import '../../dashboard/controllers/dashboard_map_controller.dart';

class TrackingController extends GetxController {
  final DatabaseService _db = Get.find<DatabaseService>();
  final LocationService _locationService = LocationService();
  
  // Use the registered singleton instance
  FlutterBackgroundService get _backgroundService => Get.find<FlutterBackgroundService>();

  var isTracking = false.obs;
  var totalDistance = 0.0.obs;
  var totalFare = 0.0.obs;
  var currentSpeed = 0.0.obs;
  var currentBearing = 0.0.obs;
  var currentActivity = "STILL".obs;
  var tripDuration = "00:00:00".obs;
  var trackingStatus = "Monitoring...".obs;
  var selectedVehicle = Rxn<Vehicle>();
  LatLng? _lastPosition;
  StreamSubscription? _serviceSubscription;
  StreamSubscription? _activitySubscription;
  Timer? _durationTimer;
  DateTime? _startTime;

  @override
  void onInit() {
    super.onInit();
    _loadDefaultVehicle();
    _listenToServiceUpdates();
    _initUiActivityRecognition();
  }

  void _initUiActivityRecognition() {
    try {
      ar.ActivityRecognition().activityStream(runForegroundService: false).listen((event) {
        _backgroundService.invoke('activityUpdate', {'type': event.type.name});
        currentActivity.value = event.type.name.toUpperCase();
      }, onError: (e) => developer.log("⚠️ UI Activity Recognition error: $e"));
    } catch (e) {
      developer.log("⚠️ UI Activity Recognition setup error: $e");
    }
  }

  double _getBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180;
    double lon1 = start.longitude * math.pi / 180;

    double lat2 = end.latitude * math.pi / 180;
    double lon2 = end.longitude * math.pi / 180;

    double dLon = lon2 - lon1;

    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi);
  }

  Future<void> _loadDefaultVehicle() async {
    try {
      final allVehicles = _db.getAllVehicles();
      var vehicle = allVehicles.firstWhereOrNull((v) => v.isDefault);
      if (vehicle == null && allVehicles.isNotEmpty) {
        vehicle = allVehicles.first;
      }
      selectedVehicle.value = vehicle;
    } catch (e) {
      developer.log("Error loading vehicle", error: e);
    }
  }

  void _listenToServiceUpdates() {
    // Listen to Activity Updates from Background
    _activitySubscription = _backgroundService.on('activityUpdate').listen((event) {
      if (event != null) {
        final type = event['type'] as String?;
        if (type != null) {
          currentActivity.value = type.toUpperCase();
          developer.log("📡 Activity Update from BG: $type");
        }
      }
    });

    _serviceSubscription = _backgroundService.on('update').listen((event) {
      developer.log("📡 RAW EVENT: $event");

      if (event != null) {
        // ✅ Sync tracking state
        final serviceIsTracking = event['isTracking'] as bool? ?? false;
        if (isTracking.value != serviceIsTracking) {
          isTracking.value = serviceIsTracking;
          if (isTracking.value) {
            _startDurationTimer();
            _restorePolylineIfEmpty();
          } else {
            _durationTimer?.cancel();
          }
        }

        // ✅ SAFE conversion
        final distance = (event['distance'] as num?)?.toDouble() ?? 0.0;
        final fare = (event['fare'] as num?)?.toDouble() ?? 0.0;
        final speed = (event['speed'] as num?)?.toDouble() ?? 0.0;

        final startTimeStr = event['startTime'] as String?;
        if (startTimeStr != null) {
          _startTime = DateTime.tryParse(startTimeStr);
          if (isTracking.value) {
            _startDurationTimer();
          }
        }

        totalDistance.value = distance;
        totalFare.value = fare;
        currentSpeed.value = speed * 3.6; // Convert m/s to km/h

        final status = event['status'] as String?;
        if (status != null) {
          trackingStatus.value = status;
        }

        final lat = (event['latitude'] as num?)?.toDouble();
        final lng = (event['longitude'] as num?)?.toDouble();

        developer.log("📍 Parsed Location -> lat: $lat, lng: $lng");

        if (lat != null && lng != null) {
          final current = LatLng(lat, lng);

          // Skip UI/Map updates if speed is extremely low and we aren't tracking
          if (speed < 0.1 && !isTracking.value) {
            return;
          }

          if (!Get.isRegistered<DashboardMapController>()) {
            return;
          }

          final mapCtrl = Get.find<DashboardMapController>();

          double rotation = currentBearing.value;

          if (_lastPosition != null && speed > 0.5) {
            rotation = _getBearing(_lastPosition!, current);
            currentBearing.value = rotation;
          }

          _lastPosition = current;

          mapCtrl.updateCamera(current, bearing: rotation, speedKmh: currentSpeed.value);
          if (isTracking.value) {
            mapCtrl.updateRoute(current);
          }
          mapCtrl.updateBikeMarker(current, rotation: rotation);
        }
      }
    });

    _backgroundService.on('stopped').listen((event) {
      developer.log("📡 Service signaled STOPPED");
      if (Get.isRegistered<AnalyticsController>()) {
        Get.find<AnalyticsController>().loadAnalyticsForDate(DateTime.now());
      }
    });
  }

  void _restorePolylineIfEmpty() {
    if (!Get.isRegistered<DashboardMapController>()) return;
    final mapCtrl = Get.find<DashboardMapController>();
    
    // Only restore if the map is currently empty
    if (mapCtrl.routePoints.isEmpty) {
      _loadActiveTripPoints();
    }
  }

  Future<void> _loadActiveTripPoints() async {
    try {
      // Find the most recent unfinished log
      final logs = _db.getAllLogs();
      final activeLog = logs.firstWhereOrNull((l) => l.endTime == null);
      
      if (activeLog != null && Get.isRegistered<DashboardMapController>()) {
        final mapCtrl = Get.find<DashboardMapController>();
        final points = activeLog.points
            .where((p) => p.latitude != null && p.longitude != null)
            .map((p) => LatLng(p.latitude!, p.longitude!))
            .toList();
            
        if (points.isNotEmpty) {
          mapCtrl.routePoints.assignAll(points);
          // Manually trigger the polyline update
          mapCtrl.updateRoute(points.last);
          developer.log("🔄 Restored ${points.length} points from active log ID: ${activeLog.id}");
        }
      }
    } catch (e) {
      developer.log("⚠️ Error restoring active trip points: $e");
    }
  }

  void _startDurationTimer() {
    if (_durationTimer != null && _durationTimer!.isActive) return;

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        final diff = DateTime.now().difference(_startTime!);
        final h = diff.inHours.toString().padLeft(2, '0');
        final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
        tripDuration.value = "$h:$m:$s";
      } else {
        tripDuration.value = "00:00:00";
      }
    });
  }

  Future<void> startTracking() async {
    if (selectedVehicle.value == null) {
      Get.snackbar("Error", "Please select a vehicle in settings first");
      return;
    }

    final hasPermission = await _locationService.handlePermission();
    if (!hasPermission) {
      Get.snackbar("Permission Denied", "Please grant all required permissions to start tracking.");
      return;
    }

    final now = DateTime.now();
    final newLog = GpsLog()
      ..startTime = now
      ..vehicleId = selectedVehicle.value!.id
      ..rateApplied = selectedVehicle.value!.ratePerKm
      ..points = []
      ..stays = [];

    final logId = await _db.saveLog(newLog);
    
    bool isRunning = await _backgroundService.isRunning();
    if (!isRunning) {
      await _backgroundService.startService();
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    _backgroundService.invoke('startTracking', {'logId': logId});

    _startTime = now;
    isTracking.value = true;
    _startDurationTimer();

    totalDistance.value = 0.0;
    totalFare.value = 0.0;

    if (Get.isRegistered<DashboardMapController>()) {
      Get.find<DashboardMapController>().routePoints.clear();
      Get.find<DashboardMapController>().polylines.clear();
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (Get.context != null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          const SnackBar(content: Text("Tracking Started"), duration: Duration(seconds: 2)),
        );
      }
    });
  }

  Future<void> stopTracking() async {
    _backgroundService.invoke('stopTracking');
    isTracking.value = false;
    _durationTimer?.cancel();
    _startTime = null;
    tripDuration.value = "00:00:00";

    if (Get.isRegistered<AnalyticsController>()) {
      Get.find<AnalyticsController>().loadAnalyticsForDate(DateTime.now());
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (Get.context != null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          const SnackBar(content: Text("Tracking Stopped. Trip saved."), duration: Duration(seconds: 2)),
        );
      }
    });
  }

  @override
  void onClose() {
    _serviceSubscription?.cancel();
    _activitySubscription?.cancel();
    _durationTimer?.cancel();
    super.onClose();
  }
}

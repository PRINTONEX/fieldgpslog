import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../core/utils/distance_calculator.dart';
import '../models/gps_log.dart';
import 'database_service.dart';
import 'log_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'gps_tracker_enterprise_v1',
    'GPS Enterprise Tracker',
    description: 'Persistent background tracking for professional delivery.',
    importance: Importance.low,
    showBadge: false,
    enableVibration: false,
    playSound: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.actionId != null) {
        service.invoke('notificationAction', {'actionId': response.actionId, 'input': response.input});
      }
    },
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // ✅ Disable auto-start to prevent permission crashes on boot
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: 'gps_tracker_enterprise_v1',
      initialNotificationTitle: 'Field GPS Log',
      initialNotificationContent: 'System active: Monitoring workflow...',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: const [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  DatabaseService? dbService;
  int? currentLogId;
  GpsLog? activeLog;
  Position? lastPosition;
  StreamSubscription<Position>? positionSubscription;
  Timer? flushTimer;
  int changeVersion = 0;
  int persistedVersion = 0;

  // Workflow State
  String? currentPOIName;
  DateTime? stopDetectedTime;
  bool stopLogged = false;
  bool isMovingVehicular = false;

  Future<DatabaseService> ensureDatabase() async {
    if (dbService != null) return dbService!;
    final database = DatabaseService();
    await database.init();
    await LogService.init();
    dbService = database;
    return database;
  }

  void updateNotification(String title, String content) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(title: title, content: content);
    }
  }

  Future<void> handlePosition(Position position) async {
    final db = await ensureDatabase();
    final speed = position.speed;
    final accuracy = position.accuracy;

    LogService.log("📍 Location Received: lat=${position.latitude}, lng=${position.longitude}, speed=${speed.toStringAsFixed(1)}, accuracy=${accuracy.toStringAsFixed(1)}");

    if (accuracy > 50) {
      LogService.log("⚠️ Skipping inaccurate point (accuracy: $accuracy)");
      return; 
    }

    // 1. POI DETECTION (Dynamic based on saved locations)
    final allLocations = db.workLocationBox.values.toList();
    
    String? matchedPOI;
    for (var loc in allLocations) {
      final dist = DistanceCalculator.getDistanceBetween(
        Position(latitude: loc.latitude, longitude: loc.longitude, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0),
        position
      );
      if (dist < loc.radius / 1000) {
        matchedPOI = loc.name;
        break;
      }
    }

    if (matchedPOI != currentPOIName) {
      if (matchedPOI != null) {
        await db.logActivity("Reached $matchedPOI", lat: position.latitude, lng: position.longitude);
        LogService.log("🏢 Workflow: Reached $matchedPOI");
        updateNotification("At $matchedPOI", "Location reached.");
        // We don't auto-stop anymore to prevent issues when starting at a POI
      } else if (currentPOIName != null) {
        await db.logActivity("Left $currentPOIName", lat: position.latitude, lng: position.longitude);
        LogService.log("🚗 Workflow: Left $currentPOIName");
        updateNotification("Left $currentPOIName", "Resuming movement...");
      }
      currentPOIName = matchedPOI;
    }

    // 2. STOP CLASSIFICATION
    if (speed < 0.8) {
       stopDetectedTime ??= DateTime.now();
       if (!stopLogged && DateTime.now().difference(stopDetectedTime!).inMinutes >= 2) {
          String type = currentPOIName ?? "Delivery Stop";
          if (currentPOIName == null && speed < 0.1) type = "Rest/Traffic Stop";
          await db.logActivity(type, lat: position.latitude, lng: position.longitude);
          LogService.log("🛑 Auto-Detect: $type");
          stopLogged = true;
       }
    } else {
       stopDetectedTime = null;
       stopLogged = false;
    }

    // 3. LOGGING POINTS
    if (activeLog != null) {
      double distGained = 0;
      if (lastPosition != null) {
        distGained = DistanceCalculator.getDistanceBetween(lastPosition!, position);
      }

      // Log point if moved more than 10 meters or significant speed
      if (speed > 0.5 || distGained > 0.010) {
        activeLog!.points = [...activeLog!.points, GpsPoint()
          ..latitude = position.latitude
          ..longitude = position.longitude
          ..timestamp = DateTime.now()
          ..speed = speed];
        activeLog!.totalDistance += distGained;
        activeLog!.totalFare = activeLog!.totalDistance * activeLog!.rateApplied;
        changeVersion++;
        lastPosition = position;
        
        LogService.log("📈 Recorded point. Total distance: ${activeLog!.totalDistance.toStringAsFixed(2)} km");
      }
    }

    // Broadcast to UI
    service.invoke('update', {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed': speed,
      'distance': activeLog?.totalDistance ?? 0.0,
      'fare': activeLog?.totalFare ?? 0.0,
      'status': currentPOIName != null ? "At $currentPOIName" : (activeLog != null ? "Tracking Active" : "Monitoring..."),
      'startTime': activeLog?.startTime.toIso8601String(),
      'isTracking': activeLog != null,
    });
  }

  Future<void> initStreams() async {
    if (positionSubscription != null) return;

    LogService.log("Initializing GPS and Activity streams in background...");

    // GPS Stream
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        positionSubscription = Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationText: "Delivery tracking system active in background.",
              notificationTitle: "GPS Enterprise Active",
              enableWakeLock: true,
            ),
          ),
        ).listen(handlePosition);
      } else {
        LogService.log("❌ Cannot start GPS stream: Missing permissions in service.");
      }
    } catch (e) {
      LogService.log("⚠️ GPS stream error: $e");
    }

    // Note: Activity recognition is now handled by the UI isolate to avoid NO_ACTIVITY errors.
  }

  Future<void> startTracking(int logId) async {
    final db = await ensureDatabase();
    activeLog = db.getLog(logId);
    currentLogId = logId;
    lastPosition = null;
    changeVersion = 0;
    persistedVersion = 0;

    await initStreams(); // Ensure streams are running
    
    // ✅ PRE-INITIALIZE POI
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      final allLocations = db.workLocationBox.values.toList();
      for (var loc in allLocations) {
        final dist = DistanceCalculator.getDistanceBetween(
          Position(latitude: loc.latitude, longitude: loc.longitude, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0),
          pos
        );
        if (dist < loc.radius / 1000) {
          currentPOIName = loc.name;
          break;
        }
      }
    } catch (e) {
      LogService.log("⚠️ Could not pre-detect POI: $e");
    }
    
    flushTimer?.cancel();
    flushTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
       if (activeLog != null && changeVersion != persistedVersion) {
         await db.saveLog(activeLog!);
         persistedVersion = changeVersion;
       }
    });
    
    LogService.log("Tracking started for log $logId");
  }

  Future<void> stopTracking() async {
    if (activeLog != null) {
      activeLog!.endTime = DateTime.now();
      final db = await ensureDatabase();
      await db.saveLog(activeLog!);
      LogService.log("✅ Final log saved for trip ${activeLog!.id}. Distance: ${activeLog!.totalDistance.toStringAsFixed(2)} km");
    }
    activeLog = null;
    currentLogId = null;
    flushTimer?.cancel();
    
    service.invoke('stopped');
  }

  // Manual listeners
  service.on('startTracking').listen((event) {
    LogService.log("🚀 Service received startTracking command for log ${event!['logId']}");
    startTracking(event['logId']);
  });
  
  service.on('stopTracking').listen((event) {
    LogService.log("🛑 Service received stopTracking command");
    stopTracking();
  });

  service.on('activityUpdate').listen((event) {
    if (event != null) {
      final type = event['type'] as String?;
      if (type != null) {
        isMovingVehicular = (type == 'inVehicle' || type == 'onBicycle');
        // We could also broadcast this back or use it for stop detection logic refinement
      }
    }
  });

  service.on('notificationAction').listen((event) async {
    final db = await ensureDatabase();
    final action = event!['actionId'];
    final input = event['input'];
    await db.logActivity("Manual: $action", note: input);
    LogService.log("Notification Action: $action");
  });
}

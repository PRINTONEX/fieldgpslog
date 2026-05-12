import 'dart:async';
import 'dart:ui';
import 'dart:isolate';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../core/utils/distance_calculator.dart';
import '../models/gps_log.dart';
import '../models/vehicle.dart';
import 'database_service.dart';
import 'log_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Immediately handle the notification dismissal to stop the 'loading' spinner on Android
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  
  // NotificationResponse uses 'id' instead of 'notificationId'
  if (response.id != null) {
    localNotifications.cancel(response.id!);
  }

  if (response.actionId != null) {
    final SendPort? sendPort = IsolateNameServer.lookupPortByName('background_service_port');
    sendPort?.send({
      'actionId': response.actionId,
      'input': response.input,
      'notificationId': response.id,
    });
  }
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'gps_tracker_enterprise_v1',
    'Field GPS Live Tracking',
    description: 'Real-time professional delivery tracking.',
    importance: Importance.low, // Use low importance for persistent notification to stay silent
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
        service.invoke('notificationAction', {
          'actionId': response.actionId, 
          'input': response.input,
          'notificationId': response.id,
        });
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true, 
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

  final receivePort = ReceivePort();
  IsolateNameServer.removePortNameMapping('background_service_port');
  IsolateNameServer.registerPortWithName(receivePort.sendPort, 'background_service_port');
  
  final tracker = BackgroundTracker(service);
  
  receivePort.listen((message) {
    if (message is Map) {
      service.invoke('notificationAction', Map<String, dynamic>.from(message));
    }
  });

  await tracker.initialize();
}

class BackgroundTracker {
  final ServiceInstance service;
  final localNotifications = FlutterLocalNotificationsPlugin();
  
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

  BackgroundTracker(this.service);

  Future<void> initialize() async {
    await ensureDatabase();
    
    // Initialize notifications for the background isolate
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await localNotifications.initialize(initializationSettings);

    await initStreams();

    service.on('startTracking').listen((event) {
      startTracking(event!['logId']);
    });
    
    service.on('stopTracking').listen((event) {
      stopTracking();
    });

    service.on('activityUpdate').listen((event) {
      if (event != null) {
        final type = event['type'] as String?;
        if (type != null) {
          isMovingVehicular = (type == 'inVehicle' || type == 'onBicycle');
        }
      }
    });

    service.on('notificationAction').listen((event) async {
      final db = await ensureDatabase();
      final action = event!['actionId'] as String;
      final input = event['input'] as String?;
      
      LogService.log("🔔 Notification Action: $action, Input: $input");

      await db.logActivity("Category: ${_capitalize(action)}", note: input);

      if (activeLog != null) {
        final stay = StayPoint()
          ..latitude = lastPosition?.latitude
          ..longitude = lastPosition?.longitude
          ..arrivalTime = stopDetectedTime ?? DateTime.now()
          ..departureTime = DateTime.now()
          ..label = _capitalize(action)
          ..note = input;
        
        activeLog!.stays = [...activeLog!.stays, stay];
        changeVersion++;
        
        LogService.log("✅ Activity saved to log: ${_capitalize(action)}");
      }
      
      _cancelStopNotification();
    });

    LogService.log("Background Service Monitoring Active");
  }

  String _capitalize(String s) => s.isEmpty ? s : s.replaceAll('_', ' ').split(' ').map((word) => word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');

  Future<DatabaseService> ensureDatabase() async {
    if (dbService != null) return dbService!;
    final database = DatabaseService();
    await database.init();
    await LogService.init();
    dbService = database;
    return database;
  }

  void updateNotification(String status) {
    if (activeLog == null) return;
    
    final distance = activeLog!.totalDistance.toStringAsFixed(1);
    final speedKmh = ((lastPosition?.speed ?? 0.0) * 3.6).toStringAsFixed(0);
    
    final duration = DateTime.now().difference(activeLog!.startTime);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    
    final content = "KM: $distance km | Speed: $speedKmh km/h\nDuration: ${hours}h ${minutes}m | GPS: Active";

    localNotifications.show(
      888,
      "Field GPS Log - $status",
      content,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'gps_tracker_enterprise_v1',
          'Field GPS Live Tracking',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          showWhen: false,
          onlyAlertOnce: true,
          styleInformation: BigTextStyleInformation(content),
        ),
      ),
    );
  }

  void _cancelStopNotification() {
    localNotifications.cancel(890);
  }

  void _showStopNotification(double lat, double lng) {
    localNotifications.show(
      890,
      "Stop Detected",
      "Where are you?",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gps_tracker_enterprise_v1',
          'Field GPS Live Tracking',
          importance: Importance.high,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'delivery',
              'Delivery',
              inputs: [
                AndroidNotificationActionInput(
                  label: 'Add delivery note...',
                  allowFreeFormInput: true,
                )
              ],
            ),
            AndroidNotificationAction(
              'oil_pump',
              'Oil Pump',
            ),
            AndroidNotificationAction(
              'rest',
              'Rest',
            ),
            AndroidNotificationAction(
              'office',
              'Office',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> handlePosition(Position position) async {
    final db = await ensureDatabase();
    final speed = position.speed;
    final accuracy = position.accuracy;

    LogService.log("📍 Location: lat=${position.latitude.toStringAsFixed(4)}, lng=${position.longitude.toStringAsFixed(4)}, speed=${speed.toStringAsFixed(1)}, accuracy=${accuracy.toStringAsFixed(1)}");

    if (accuracy > 50) return;
    
    lastPosition = position;

    // POI DETECTION
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
      } else if (currentPOIName != null) {
        await db.logActivity("Left $currentPOIName", lat: position.latitude, lng: position.longitude);
      }
      currentPOIName = matchedPOI;
    }

    // STOP CLASSIFICATION
    if (speed < 0.8) {
       stopDetectedTime ??= DateTime.now();
       if (!stopLogged && DateTime.now().difference(stopDetectedTime!).inMinutes >= 2) {
          _showStopNotification(position.latitude, position.longitude);
          stopLogged = true;
       }
    } else {
       if (stopLogged) _cancelStopNotification();
       stopDetectedTime = null;
       stopLogged = false;
    }

    // AUTO-START TRACKING
    if (activeLog == null && speed > 4.5) { // ~16 km/h
      final vehicles = db.getAllVehicles();
      var vehicle = vehicles.firstWhere((v) => v.isDefault, orElse: () => vehicles.isNotEmpty ? vehicles.first : Vehicle());
      
      if (vehicle.id != -1 || vehicles.isNotEmpty) {
        final now = DateTime.now();
        final newLog = GpsLog()
          ..startTime = now
          ..vehicleId = vehicle.id
          ..rateApplied = vehicle.ratePerKm
          ..points = []
          ..stays = [];
        final logId = await db.saveLog(newLog);
        await startTracking(logId);
      }
    }

    // LOGGING POINTS
    if (activeLog != null) {
      double distGained = 0;
      if (lastPosition != null && activeLog!.points.isNotEmpty) {
        final lastPoint = activeLog!.points.last;
        distGained = DistanceCalculator.getDistanceBetween(
          Position(latitude: lastPoint.latitude!, longitude: lastPoint.longitude!, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0),
          position
        );
      }

      if (speed > 0.5 || distGained > 0.010 || activeLog!.points.isEmpty) {
        activeLog!.points = [...activeLog!.points, GpsPoint()
          ..latitude = position.latitude
          ..longitude = position.longitude
          ..timestamp = DateTime.now()
          ..speed = speed];
        activeLog!.totalDistance += distGained;
        activeLog!.totalFare = activeLog!.totalDistance * activeLog!.rateApplied;
        changeVersion++;
        LogService.log("📈 Distance: ${activeLog!.totalDistance.toStringAsFixed(3)} km");
      }
      
      updateNotification(currentPOIName != null ? "At $currentPOIName" : "Tracking Active");
    }

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
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        positionSubscription = Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 5),
            // Explicitly NO foregroundNotificationConfig here to avoid duplicate notifications
          ),
        ).listen(handlePosition);
      }
    } catch (e) {
      LogService.log("⚠️ GPS stream error: $e");
    }
  }

  Future<void> startTracking(int logId) async {
    final db = await ensureDatabase();
    activeLog = db.getLog(logId);
    currentLogId = logId;
    lastPosition = null;
    changeVersion = 0;
    persistedVersion = 0;

    await initStreams();
    
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
      // Ignore errors during initial POI check
    }
    
    flushTimer?.cancel();
    flushTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
       if (activeLog != null && changeVersion != persistedVersion) {
         await db.saveLog(activeLog!);
         persistedVersion = changeVersion;
       }
    });
    
    updateNotification("Tracking Active");
    LogService.log("Tracking started for log $logId");
  }

  Future<void> stopTracking() async {
    if (activeLog != null) {
      activeLog!.endTime = DateTime.now();
      final db = await ensureDatabase();
      await db.saveLog(activeLog!);
    }
    activeLog = null;
    currentLogId = null;
    flushTimer?.cancel();
    
    // Clear live tracking notification
    localNotifications.cancel(888);
    
    service.invoke('stopped');
  }
}

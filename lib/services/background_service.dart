import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:activity_recognition_flutter/activity_recognition_flutter.dart' as ar;

import '../core/utils/distance_calculator.dart';
import '../models/gps_log.dart';
import '../models/vehicle.dart';
import 'database_service.dart';
import 'log_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'gps_tracker_channel_v3', // Incremented version
    'GPS Tracker Service',
    description: 'This channel is used for live GPS tracking and quick actions.',
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
        String? label;
        String? note = response.input;

        if (response.actionId == 'delivery') {
          label = 'Delivery';
        } else if (response.actionId == 'rest') {
          label = 'Rest';
        } else if (response.actionId == 'office') {
          label = 'Office';
        } else if (response.actionId == 'home') {
          label = 'Home';
        } else if (response.actionId == 'note') {
           service.invoke('addQuickNote', {'note': note});
           return;
        }
        
        if (label != null) {
          service.invoke('setStayLabel', {'label': label, 'note': note});
        }
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
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: 'gps_tracker_channel_v3',
      initialNotificationTitle: 'GPS Tracker',
      initialNotificationContent: 'Monitoring for driving activity...',
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
  // 1. CRITICAL ISOLATE INITIALIZATION
  DartPluginRegistrant.ensureInitialized();
  
  DatabaseService? dbService;
  var pluginsInitialized = false;
  int? currentLogId;
  GpsLog? activeLog;
  Position? lastPosition;
  DateTime? stayStartTime;
  StreamSubscription<Position>? positionSubscription;
  StreamSubscription<ar.ActivityEvent>? activitySubscription;
  Timer? flushTimer;
  Future<void>? activeFlush;
  int changeVersion = 0;
  int persistedVersion = 0;
  int pendingPointCount = 0;

  // Activity tracking state
  bool isMovingVehicular = false;
  String currentActivityType = "STILL";

  // Auto-tracking thresholds
  const double drivingStartThreshold = 4.0; // ~14.4 km/h to start auto-log
  const double drivingKeepThreshold = 0.8; // ~2.8 km/h to keep saving points
  const double driftDistanceThreshold = 0.010; // 10 meters filter for spider polylines
  
  DateTime? lastDrivingTime;
  
  // Stop detection for notification
  DateTime? stopDetectedTime;
  bool notificationShownForCurrentStop = false;

  Future<DatabaseService> ensureDatabase() async {
    final existingService = dbService;
    if (existingService != null && pluginsInitialized) {
      return existingService;
    }

    final database = DatabaseService();
    await database.init(); // This calls Hive.initFlutter()
    dbService = database;
    
    // LogService depends on Hive being initialized
    await LogService.init();
    
    pluginsInitialized = true;
    LogService.log("Background Database & LogService initialized");
    return database;
  }

  Future<void> flushActiveLog() {
    if (activeLog == null || persistedVersion == changeVersion) {
      return Future.value();
    }

    if (activeFlush != null) {
      return activeFlush!;
    }

    activeFlush = () async {
      final db = await ensureDatabase();
      while (activeLog != null && persistedVersion != changeVersion) {
        final versionToPersist = changeVersion;
        await db.saveLog(activeLog!);
        persistedVersion = versionToPersist;
        pendingPointCount = 0;
        LogService.log("Log flushed to DB. Version: $persistedVersion");
      }
    }()
        .whenComplete(() {
      activeFlush = null;
    });

    return activeFlush!;
  }

  void showStopNotification() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'gps_tracker_channel_v3',
      'GPS Tracker Service',
      channelDescription: 'Select your current status',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showWhen: true,
      ongoing: true,
      silent: true,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'delivery', 
          'Delivery', 
          showsUserInterface: false,
          inputs: [
            AndroidNotificationActionInput(
              label: 'Add note (optional)',
            )
          ],
        ),
        AndroidNotificationAction('rest', 'Rest', showsUserInterface: false),
        AndroidNotificationAction('office', 'Office', showsUserInterface: false),
        AndroidNotificationAction('home', 'Home', showsUserInterface: false),
      ],
    );

    const platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      999,
      'Stop Detected',
      'Select status or add delivery note',
      platformChannelSpecifics,
    );
  }

  Timer? notificationTimer;

  String getFormattedDuration(DateTime start) {
    final diff = DateTime.now().difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  void updateLiveNotification() {
    if (activeLog != null) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '⚡ Live Tracking: ${activeLog!.totalDistance.toStringAsFixed(2)} km',
          content: 'Time: ${getFormattedDuration(activeLog!.startTime)} | Fare: ₹${activeLog!.totalFare.toStringAsFixed(2)}',
        );
      }
    } else {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'GPS Tracker',
          content: 'Monitoring for driving activity...',
        );
      }
    }
  }

  Future<void> handlePosition(Position position) async {
    final db = await ensureDatabase();
    final speed = position.speed;
    final accuracy = position.accuracy;

    // Skip low accuracy points to prevent jumps
    if (accuracy > 50) {
      LogService.log("Skipping low accuracy point: ${accuracy.toStringAsFixed(1)}m", level: 'DEBUG');
      return;
    }

    // Check for Home/Office to pause tracking
    final home = db.getWorkLocation('Home');
    final office = db.getWorkLocation('Office');
    
    bool atHome = false;
    bool atOffice = false;

    if (home != null) {
      final dist = DistanceCalculator.getDistanceBetween(
        Position(latitude: home.latitude, longitude: home.longitude, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0),
        position,
      );
      if (dist < home.radius / 1000) {
        atHome = true;
      }
    }

    if (office != null) {
      final dist = DistanceCalculator.getDistanceBetween(
        Position(latitude: office.latitude, longitude: office.longitude, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0),
        position,
      );
      if (dist < office.radius / 1000) {
        atOffice = true;
      }
    }

    // 1. AUTO-START / RESUME LOGIC
    if (activeLog == null) {
      // Automatic resume if moving and NOT at Home/Office
      if (speed > drivingStartThreshold && !atHome && !atOffice) {
        LogService.log("Auto-starting/resuming tracking. Speed: ${speed.toStringAsFixed(1)} m/s");
        
        final vehicles = db.getAllVehicles();
        Vehicle? vehicle;
        try {
          vehicle = vehicles.firstWhere((v) => v.isDefault);
        } catch (_) {
          if (vehicles.isNotEmpty) vehicle = vehicles.first;
        }

        if (vehicle != null) {
          // Check if there's a recent log from today to resume
          final todayLogs = await db.getLogsForDate(DateTime.now());
          GpsLog? resumeLog;
          
          if (todayLogs.isNotEmpty) {
             final lastLog = todayLogs.last;
             // If last log ended less than 30 mins ago, resume it
             if (lastLog.endTime != null && 
                 DateTime.now().difference(lastLog.endTime!).inMinutes < 30) {
               resumeLog = lastLog;
               LogService.log("Resuming recent log ID: ${resumeLog.id}");
             }
          }

          if (resumeLog != null) {
            activeLog = resumeLog;
            activeLog!.endTime = null; // Mark as active again
            currentLogId = activeLog!.id;
          } else {
            activeLog = GpsLog()
              ..startTime = DateTime.now()
              ..vehicleId = vehicle.id
              ..rateApplied = vehicle.ratePerKm
              ..points = []
              ..stays = [];
            currentLogId = await db.saveLog(activeLog!);
            LogService.log("Created new auto-log ID: $currentLogId");
          }

          lastPosition = null;
          stayStartTime = null;
          lastDrivingTime = DateTime.now();
          changeVersion = 0;
          persistedVersion = 0;
          pendingPointCount = 0;
          notificationShownForCurrentStop = false;

          flushTimer?.cancel();
          flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
            unawaited(flushActiveLog());
          });
          
          notificationTimer?.cancel();
          notificationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            updateLiveNotification();
          });
        }
      } else {
        service.invoke('update', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': speed,
          'distance': 0.0,
          'fare': 0.0,
          'status': atHome ? 'At Home' : (atOffice ? 'At Office' : 'Idle'),
        });
        return;
      }
    }

    // 2. DATA FILTERING & STOP DETECTION
    if (activeLog != null) {
      double distanceGained = 0;
      if (lastPosition != null) {
        distanceGained = DistanceCalculator.getDistanceBetween(
          lastPosition!,
          position,
        );
      }

      // Filter drift (Spider Polylines Fix)
      // Only add point if speed is significant OR distance from last point > threshold
      if (speed > drivingKeepThreshold || distanceGained > driftDistanceThreshold) {
        lastDrivingTime = DateTime.now();
        stopDetectedTime = null;
        notificationShownForCurrentStop = false;

        final newPoint = GpsPoint()
          ..latitude = position.latitude
          ..longitude = position.longitude
          ..timestamp = DateTime.now()
          ..speed = speed;

        activeLog!.points = [...activeLog!.points, newPoint];
        activeLog!.totalDistance += distanceGained;
        activeLog!.totalFare = activeLog!.totalDistance * activeLog!.rateApplied;
        changeVersion++;
        pendingPointCount++;

        if (pendingPointCount >= 20) {
          unawaited(flushActiveLog());
        }

        lastPosition = position;
        
        // Finalize any pending stay
        if (stayStartTime != null) {
          final stayDuration = DateTime.now().difference(stayStartTime!);
          if (stayDuration.inMinutes >= 1) {
             final stay = StayPoint()
              ..latitude = lastPosition?.latitude ?? position.latitude
              ..longitude = lastPosition?.longitude ?? position.longitude
              ..arrivalTime = stayStartTime
              ..departureTime = DateTime.now();
              
            activeLog!.stays = [...activeLog!.stays, stay];
            LogService.log("Stay recorded: ${stay.durationMinutes} mins");
            changeVersion++;
          }
          stayStartTime = null;
        }
      } else {
        // Detected Stop
        stayStartTime ??= DateTime.now();
        stopDetectedTime ??= DateTime.now();

        // Show notification after 1 minute of stop
        if (!notificationShownForCurrentStop && 
            DateTime.now().difference(stopDetectedTime!).inMinutes >= 1) {
          showStopNotification();
          notificationShownForCurrentStop = true;
          LogService.log("Stop notification shown");
        }

        // Auto-pause tracking if At Home/Office or if long idle
        bool shouldEnd = false;
        if (atHome || atOffice) {
          shouldEnd = true;
          LogService.log("Ending trip: At ${atHome ? 'Home' : 'Office'}");
        } else if (lastDrivingTime != null &&
            DateTime.now().difference(lastDrivingTime!).inMinutes >= 20) { // Increased to 20 mins
          shouldEnd = true;
          LogService.log("Ending trip: 20 mins inactivity");
        }

        if (shouldEnd) {
          activeLog!.endTime = DateTime.now();
          
          // Add final stay if needed
          if (stayStartTime != null) {
            final stay = StayPoint()
              ..latitude = position.latitude
              ..longitude = position.longitude
              ..arrivalTime = stayStartTime
              ..departureTime = DateTime.now()
              ..label = atHome ? 'Home' : (atOffice ? 'Office' : 'Rest');
            activeLog!.stays = [...activeLog!.stays, stay];
          }

          changeVersion++;
          await flushActiveLog();
          activeLog = null;
          currentLogId = null;
          flushTimer?.cancel();
          flushTimer = null;
          notificationTimer?.cancel();
          notificationTimer = null;

          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'GPS Tracker',
              content: atHome ? 'At Home - Paused' : (atOffice ? 'At Office - Paused' : 'Monitoring activity...'),
            );
          }
          return;
        }
      }

      updateLiveNotification();

      service.invoke('update', {
        'distance': activeLog?.totalDistance ?? 0.0,
        'fare': activeLog?.totalFare ?? 0.0,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': speed,
        'logId': currentLogId,
        'startTime': activeLog?.startTime.toIso8601String(),
      });
    }
  }

  Future<void> startPositionUpdates() async {
    await positionSubscription?.cancel();
    
    // Ensure database is ready before we start logging position events
    await ensureDatabase();

    final LocationSettings locationSettings;
    if (service is AndroidServiceInstance) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 5), // Reduced interval for better accuracy
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Tracking your route...",
          notificationTitle: "GPS Tracker Active",
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }

    LogService.log("Starting position stream");
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      unawaited(handlePosition(position));
    }, onError: (e) {
      LogService.log("Position stream error: $e", level: 'ERROR');
    });
  }

  // 3. START ACTIVITY RECOGNITION IN BACKGROUND
  void startActivityRecognition() {
    activitySubscription?.cancel();
    activitySubscription = ar.ActivityRecognition()
        .activityStream(runForegroundService: false)
        .listen((event) {
      currentActivityType = event.type.name;
      
      final bool isMoving = (event.type == ar.ActivityType.inVehicle ||
                             event.type == ar.ActivityType.onBicycle ||
                             event.type == ar.ActivityType.running ||
                             event.type == ar.ActivityType.walking);
      
      final bool wasMovingVehicular = isMovingVehicular;
      isMovingVehicular = (event.type == ar.ActivityType.inVehicle ||
                           event.type == ar.ActivityType.onBicycle);

      LogService.log("Activity Update: $currentActivityType (Moving: $isMoving)");

      // Wake up GPS if we started moving
      if (isMoving && activeLog == null && positionSubscription == null) {
        unawaited(startPositionUpdates());
      }

      // Notify UI
      service.invoke('activityUpdate', {
        'type': currentActivityType,
        'confidence': event.confidence.toString(),
      });
    }, onError: (e) {
      LogService.log("Activity Recognition Error: $e", level: 'ERROR');
    });
  }

  // Start immediately
  startActivityRecognition();

  service.on('setStayLabel').listen((event) async {
    final label = event?['label'] as String?;
    final note = event?['note'] as String?;
    final logId = (event?['logId'] as int?) ?? (activeLog?.id);
    
    LogService.log("Setting stay label: $label, note: $note for log: $logId");
    
    if (label != null && logId != null && logId != -1) {
      final db = await ensureDatabase();
      final log = (activeLog?.id == logId) ? activeLog : db.getLog(logId);
      
      if (log != null && log.stays.isNotEmpty) {
        for (var i = log.stays.length - 1; i >= 0; i--) {
          if (log.stays[i].label == null || log.stays[i].label == 'Rest' || log.stays[i].label == 'Delivery') {
            log.stays[i].label = label;
            log.stays[i].note = note; 
            break;
          }
        }
        
        await db.saveLog(log);
        LogService.log("Stay label updated successfully");
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Status Updated: $label',
            content: note != null ? 'Note: $note' : 'Resume driving to continue tracking.',
          );
        }
      }
    }
  });

  service.on('addQuickNote').listen((event) async {
    final note = event?['note'] as String?;
    LogService.log("Adding quick note: $note");
    
    if (note != null && activeLog != null) {
      // Add a 0-duration stay point as a "Note" event if no active stay
      if (stayStartTime == null) {
        final pos = await Geolocator.getCurrentPosition();
        final noteEvent = StayPoint()
          ..latitude = pos.latitude
          ..longitude = pos.longitude
          ..arrivalTime = DateTime.now()
          ..departureTime = DateTime.now()
          ..label = 'Note: $note';
        
        activeLog!.stays = [...activeLog!.stays, noteEvent];
        changeVersion++;
        await flushActiveLog();
      } else {
        // Attach to current stay
        for (var i = activeLog!.stays.length - 1; i >= 0; i--) {
           // This will be handled when stay is finalized or if we update active stays
        }
      }
    }
  });

  service.on('startTracking').listen((event) async {
    final rawLogId = event?['logId'];
    LogService.log("Manual tracking start requested. ID: $rawLogId");
    
    if (rawLogId is! int) return;

    final db = await ensureDatabase();
    currentLogId = rawLogId;
    activeLog = db.getLog(rawLogId);
    lastPosition = null;
    stayStartTime = null;
    lastDrivingTime = DateTime.now();
    changeVersion = 0;
    persistedVersion = 0;
    pendingPointCount = 0;
    notificationShownForCurrentStop = false;

    flushTimer?.cancel();
    flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(flushActiveLog());
    });

    notificationTimer?.cancel();
    notificationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      updateLiveNotification();
    });

    updateLiveNotification();
    unawaited(startPositionUpdates());
  });

  service.on('stopTracking').listen((event) async {
    LogService.log("Manual tracking stop requested");
    if (activeLog != null) {
      activeLog!.endTime = DateTime.now();
      changeVersion++;
      await flushActiveLog();
    }

    activeLog = null;
    currentLogId = null;
    flushTimer?.cancel();
    flushTimer = null;
    notificationTimer?.cancel();
    notificationTimer = null;

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'GPS Tracker',
        content: 'Monitoring for driving activity...',
      );
    }
  });

  // Start position updates immediately on startup
  unawaited(startPositionUpdates());
}

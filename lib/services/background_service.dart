import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:isar/isar.dart';
import 'database_service.dart';
import '../models/gps_log.dart';
import '../core/utils/distance_calculator.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'gps_tracker_channel',
    'GPS Tracker Service',
    description: 'This channel is used for GPS tracking features.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'gps_tracker_channel',
      initialNotificationTitle: 'GPS Tracker',
      initialNotificationContent: 'Ready to track your route',
      foregroundServiceNotificationId: 888,
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

  final dbService = DatabaseService();
  await dbService.init();

  int? currentLogId;
  Position? lastPosition;
  DateTime? stayStartTime;
  
  service.on('startTracking').listen((event) {
    currentLogId = event?['logId'];
  });

  service.on('stopTracking').listen((event) {
    service.stopSelf();
  });

  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  ).listen((Position position) async {
    if (currentLogId == null) return;

    final log = await dbService.isar.collection<GpsLog>().get(currentLogId!);
    if (log == null) return;

    // 1. Calculate Distance
    double distanceGained = 0;
    if (lastPosition != null) {
      distanceGained = DistanceCalculator.getDistanceBetween(lastPosition!, position);
    }

    // 2. Stay Detection Logic
    if (position.speed < 0.5) {
      stayStartTime ??= DateTime.now();
    } else {
      if (stayStartTime != null) {
        final stayDuration = DateTime.now().difference(stayStartTime!);
        if (stayDuration.inMinutes >= 2) {
          final stay = StayPoint()
            ..latitude = lastPosition?.latitude ?? position.latitude
            ..longitude = lastPosition?.longitude ?? position.longitude
            ..arrivalTime = stayStartTime
            ..departureTime = DateTime.now();
          
          log.stays = [...log.stays, stay];
        }
        stayStartTime = null;
      }
    }

    // 3. Update Log
    final newPoint = GpsPoint()
      ..latitude = position.latitude
      ..longitude = position.longitude
      ..timestamp = DateTime.now()
      ..speed = position.speed;

    log.points = [...log.points, newPoint];
    log.totalDistance += distanceGained;
    log.totalFare = log.totalDistance * log.rateApplied;

    await dbService.isar.writeTxn(() async {
      await dbService.isar.collection<GpsLog>().put(log);
    });

    lastPosition = position;

    // Update Notification
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "Tracking: ${log.totalDistance.toStringAsFixed(2)} km",
          content: "Fare: ₹${log.totalFare.toStringAsFixed(2)}",
        );
      }
    }

    // Send data to UI
    service.invoke('update', {
      "distance": log.totalDistance,
      "fare": log.totalFare,
    });
  });
}

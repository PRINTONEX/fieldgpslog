import 'package:hive_flutter/hive_flutter.dart';
import '../models/vehicle.dart';
import '../models/gps_log.dart';
import '../models/work_location.dart';
import '../models/expense_log.dart';
import '../models/activity_log.dart';

class DatabaseService {
  static const String vehicleBoxName = 'vehicles';
  static const String gpsLogBoxName = 'gps_logs';
  static const String workLocationBoxName = 'work_locations';
  static const String expenseBoxName = 'expenses';
  static const String activityLogBoxName = 'activity_logs';

  Box<Vehicle>? _vehicleBox;
  Box<GpsLog>? _gpsLogBox;
  Box<WorkLocation>? _workLocationBox;
  Box<ExpenseLog>? _expenseBox;
  Box<ActivityLog>? _activityLogBox;
  Box? _settingsBox;

  Future<void> init() async {
    // Check if already initialized in this isolate
    if (_gpsLogBox != null) return;
    await initHive();
    await openBoxes();
  }

  Future<void> initHive() async {
    await Hive.initFlutter();
    
    // ... (rest of the adapters)

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(VehicleAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(GpsLogAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(GpsPointAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(StayPointAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(ExpenseLogAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(ActivityLogAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(WorkLocationAdapter());
    }
  }

  Future<void> openBoxes() async {
    // Open settings box first as it might be needed for logic
    _settingsBox = await Hive.openBox('settings');

    // Open all other boxes in parallel for much faster startup
    final boxes = await Future.wait([
      Hive.openBox<Vehicle>(vehicleBoxName),
      Hive.openBox<GpsLog>(gpsLogBoxName),
      Hive.openBox<WorkLocation>(workLocationBoxName),
      Hive.openBox<ExpenseLog>(expenseBoxName),
      Hive.openBox<ActivityLog>(activityLogBoxName),
    ]);

    _vehicleBox = boxes[0] as Box<Vehicle>;
    _gpsLogBox = boxes[1] as Box<GpsLog>;
    _workLocationBox = boxes[2] as Box<WorkLocation>;
    _expenseBox = boxes[3] as Box<ExpenseLog>;
    _activityLogBox = boxes[4] as Box<ActivityLog>;
  }

  bool get hasShownDefaultMapPrompt => _settingsBox?.get('default_map_prompt', defaultValue: false) ?? false;
  Future<void> setShownDefaultMapPrompt(bool value) async => await _settingsBox?.put('default_map_prompt', value);

  Box<ActivityLog> get activityLogBox {
    final box = _activityLogBox;
    if (box == null || !box.isOpen) {
      throw StateError('Activity log box has not been opened.');
    }
    return box;
  }

  Future<void> logActivity(String event, {double? lat, double? lng, String? note}) async {
    final log = ActivityLog()
      ..timestamp = DateTime.now()
      ..event = event
      ..latitude = lat
      ..longitude = lng
      ..note = note;
    await activityLogBox.add(log);
  }

  List<ActivityLog> getActivityLogsForDate(DateTime date) {
    return activityLogBox.values.where((log) {
      return log.timestamp.year == date.year &&
          log.timestamp.month == date.month &&
          log.timestamp.day == date.day;
    }).toList();
  }

  Box<Vehicle> get vehicleBox {
    final box = _vehicleBox;
    if (box == null || !box.isOpen) {
      throw StateError('Vehicle box has not been opened.');
    }
    return box;
  }

  Box<GpsLog> get gpsLogBox {
    final box = _gpsLogBox;
    if (box == null || !box.isOpen) {
      throw StateError('GPS log box has not been opened.');
    }
    return box;
  }

  Box<WorkLocation> get workLocationBox {
    final box = _workLocationBox;
    if (box == null || !box.isOpen) {
      throw StateError('Work location box has not been opened.');
    }
    return box;
  }

  Box<ExpenseLog> get expenseBox {
    final box = _expenseBox;
    if (box == null || !box.isOpen) {
      throw StateError('Expense box has not been opened.');
    }
    return box;
  }

  List<Vehicle> getAllVehicles() => vehicleBox.values.toList();

  Vehicle? getVehicle(int key) => vehicleBox.get(key);

  Future<int> saveVehicle(Vehicle vehicle) async {
    if (vehicle.isInBox) {
      await vehicle.save();
      return vehicle.id;
    }

    return vehicleBox.add(vehicle);
  }

  Future<void> putVehicle(int key, Vehicle vehicle) async {
    await vehicleBox.put(key, vehicle);
  }

  Future<void> deleteVehicle(int key) async {
    await vehicleBox.delete(key);
  }

  List<GpsLog> getAllLogs() {
    final logs = gpsLogBox.values.toList();
    logs.sort((a, b) => b.startTime.compareTo(a.startTime));
    return logs;
  }

  GpsLog? getLog(int key) => gpsLogBox.get(key);

  Future<List<GpsLog>> getLogsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getLogsInRange(startOfDay, endOfDay);
  }

  Future<List<GpsLog>> getLogsInRange(DateTime start, DateTime end) async {
    final logs = gpsLogBox.values.where((log) {
      return !log.startTime.isBefore(start) && log.startTime.isBefore(end);
    }).toList();

    logs.sort((a, b) => a.startTime.compareTo(b.startTime));
    return logs;
  }

  Future<int> saveLog(GpsLog log) async {
    if (log.isInBox) {
      await log.save();
      return log.id;
    }

    return gpsLogBox.add(log);
  }

  Future<void> putLog(int key, GpsLog log) async {
    await gpsLogBox.put(key, log);
  }

  Future<void> deleteLog(int id) async {
    final box = await Hive.openBox<GpsLog>('gps_logs');
    await box.delete(id);
  }

  // Work Location Methods
  WorkLocation? getWorkLocation(String name) {
    for (var location in workLocationBox.values) {
      if (location.name == name) return location;
    }
    return null;
  }

  Future<void> saveWorkLocation(WorkLocation location) async {
    final existing = getWorkLocation(location.name);
    if (existing != null) {
      existing.latitude = location.latitude;
      existing.longitude = location.longitude;
      existing.radius = location.radius;
      await existing.save();
    } else {
      await workLocationBox.add(location);
    }
  }

  Future<void> close() async {
    await _gpsLogBox?.close();
    await _vehicleBox?.close();
    await _workLocationBox?.close();
    _gpsLogBox = null;
    _vehicleBox = null;
    _workLocationBox = null;
  }
}

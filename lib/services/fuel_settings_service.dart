import 'package:shared_preferences/shared_preferences.dart';

class FuelSettingsService {
  static const String _mileageKey = 'fuel_mileage_km_per_liter';
  static const String _priceKey = 'fuel_price_per_liter';

  static const double _defaultMileage = 40.0;
  static const double _defaultPrice = 100.0;

  /// Get saved mileage (km/liter)
  static Future<double> getMileage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_mileageKey) ?? _defaultMileage;
  }

  /// Get saved fuel price (per liter)
  static Future<double> getFuelPrice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_priceKey) ?? _defaultPrice;
  }

  /// Save mileage setting
  static Future<void> setMileage(double mileage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_mileageKey, mileage);
  }

  /// Save fuel price setting
  static Future<void> setFuelPrice(double price) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_priceKey, price);
  }

  /// Get both settings at once
  static Future<Map<String, double>> getAllSettings() async {
    return {
      'mileage': await getMileage(),
      'price': await getFuelPrice(),
    };
  }

  /// Reset to defaults
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_mileageKey, _defaultMileage);
    await prefs.setDouble(_priceKey, _defaultPrice);
  }
}

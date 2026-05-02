# Field GPS Log - Delivery Pro

A professional GPS tracking and distance logging application designed for delivery professionals. This app allows users to record their driving/walking distance, calculate fares based on vehicle-specific rates, and generate PDF reports.

## 📁 Project Structure

The project follows a **Feature-First Clean Architecture** approach:

```text
lib/
├── core/                # Global utilities, themes, and constants
│   ├── constants/       # App-wide constants (API keys, strings)
│   ├── theme/           # AppTheme (Dark/Light mode configurations)
│   └── utils/           # Formatters, calculations (Distance/Fare)
├── features/            # Feature-based modules
│   ├── dashboard/       # Main screen, Google Map integration
│   ├── tracking/        # GPS tracking logic and background service
│   ├── history/         # Date-wise logs and route visualization
│   ├── vehicles/        # Vehicle management (Activa, Bike, etc.)
│   ├── reports/         # PDF generation and export logic
│   └── settings/        # App configurations (API Keys, Theme)
├── models/              # Data models (Isar schemas)
├── services/            # Infrastructure layer (Database, Location, PDF)
└── main.dart            # Entry point
```

## 🚀 Features

- **Real-time Tracking**: Record GPS logs even while moving with sensor-based triggers.
- **Offline First**: All data is saved locally using Isar database; works without internet.
- **Dashboard**: Interactive Google Map showing today's route and live stats.
- **Vehicle Management**: Add multiple vehicles (e.g., Activa @ 2.5/km) with custom rates.
- **PDF Reports**: Export detailed driving logs filtered by date.
- **Dual Mode**: Support for Dark and Light themes.
- **Configurable**: Settable Google Maps API keys from settings.

## 🛠 Tech Stack

- **Framework**: Flutter
- **State Management**: Riverpod
- **Database**: Isar (High-performance NoSQL)
- **Maps**: Google Maps Flutter
- **Location**: Geolocator & Flutter Background Service
- **PDF**: PDF & Printing packages

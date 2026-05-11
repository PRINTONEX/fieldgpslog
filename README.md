# Field GPS Log - Professional Delivery Tracking & Analytics

Field GPS Log is a commercial-grade Flutter application designed for delivery professionals, riders, and fleet managers. It transforms your smartphone into a powerful tracking and productivity hub, similar to systems used by industry leaders like Blinkit, Zomato, and Uber Delivery.

## 🚀 Key Features

### 📦 Professional Delivery Workflow
- **Daily Journey Management**: Automated "Start Day" and "End Day" workflows with daily summary reports.
- **Smart Stop Classification**: Automatically detects and classifies stops as Deliveries, Office visits, Petrol pumps, or Rest periods based on duration and location.
- **Auto-Pause & Resume**: Reliable geofencing at Home/Office locations with automatic tracking resumption upon movement detection.

### 📸 Proof of Delivery (POD) System
- **Offline First**: Capture parcel photos and digital customer signatures even in areas with zero internet.
- **Verification**: OTP-based delivery confirmation and payment collection tracking.
- **Local Storage**: Securely stores all delivery media on device storage for later synchronization.

### 💰 Financial & Expense Hub
- **Earnings Engine**: Real-time calculation of total earnings based on per-KM rates and per-delivery incentives.
- **Expense Tracking**: Log fuel refills, tolls, parking, and food costs directly in the app.
- **Net Profit Dashboard**: Live visibility into your actual profit (`Earnings - Expenses`) for the day.

### 🎙️ Hands-Free Productivity
- **Voice Notes**: Dictate delivery updates while riding using integrated on-device Speech-to-Text.
- **Background Actions**: Perform quick actions (Rest, Delivery, Note) directly from notifications without opening the app.

### 🗺️ Advanced Map Analytics
- **Interactive Timeline**: Full-screen expandable map with route replay and event-marker synchronization.
- **Delivery Heatmap**: Visualize delivery density to identify high-frequency zones and optimize your routes.
- **Smart Polyline Smoothing**: Advanced GPS filtering to eliminate "drift" and "spider-web" artifacts while stationary.

## 🛠️ Technical Stack
- **Framework**: Flutter (Dart)
- **State Management**: GetX (Reactive architecture)
- **Database**: Hive (Ultra-fast, offline-first NoSQL storage)
- **Background Engine**: Flutter Background Service with High-Accuracy GPS
- **External Services**: Google Maps Platform, Speech-to-Text API, Android Activity Recognition

## 🏗️ Getting Started

### Prerequisites
- Flutter SDK (v3.0.0+)
- Android 10+ Device (Recommended)
- Google Maps API Key

### Setup
1. Clone the repository.
2. Run `flutter pub get` to install dependencies.
3. Configure your Google Maps API key in `android/app/src/main/AndroidManifest.xml`.
4. Run code generation for database adapters:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Launch the app: `flutter run`.
## 🛠 Tech Stack
Generate professional PDF reports of your daily journeys, including stop times, total distance, expenses, and profit summaries, ready for sharing or record-keeping.

---

*Transforming field operations through precision tracking and data-driven insights.*

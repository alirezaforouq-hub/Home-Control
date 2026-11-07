# Home Control (Flutter)

## Setup
1. Create the project shell (adds android/ios folders):
   flutter create --project-name home_control .
2. Replace pubspec.yaml and lib/ with the files from this folder, then:
   flutter pub get
3. Android: add to android/app/src/main/AndroidManifest.xml (inside <manifest>, before <application>):
   <uses-permission android:name="android.permission.INTERNET"/>
4. iOS: add to ios/Runner/Info.plist:
   <key>NSLocalNetworkUsageDescription</key>
   <string>Control your smart bulb on the local network.</string>
5. Run on a phone connected to the same Wi-Fi as the bulb:
   flutter run
6. On first launch enter the bulb IP (e.g. 192.168.1.50).

// Firebase configuration for project hp-bills
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '',
    appId: '1:398663582338:android:6fe9450e189c0948ecea9b',
    messagingSenderId: '398663582338',
    projectId: 'hp-bills',
    storageBucket: 'hp-bills.firebasestorage.app',
  );
}

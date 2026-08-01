// Generated from the Android app registered in the Firebase console
// (project touch-of-cure). Re-run this by hand if the Firebase project's
// Android config ever changes, or replace with `flutterfire configure`
// output once the Firebase CLI is available.
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase has not been configured for web. Register a web app in '
        'the Firebase console and add its options here.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Firebase has not been configured for iOS. Register an iOS app in '
          'the Firebase console and add its options here.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBnMmIr5AjBhlC8D7wxKtdZ0L7bV_EEUe0',
    appId: '1:29017856529:android:9c3d5f83912be03c2cefb0',
    messagingSenderId: '29017856529',
    projectId: 'touch-of-cure',
    storageBucket: 'touch-of-cure.firebasestorage.app',
  );
}

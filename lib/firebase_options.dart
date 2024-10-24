// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC-7y7yJ7fCtLfd_5nd81nK3nAooCKI0vg',
    appId: '1:538698773394:web:b197541d9e07cb5c1f474b',
    messagingSenderId: '538698773394',
    projectId: 'community-impact-tracker',
    authDomain: 'community-impact-tracker.firebaseapp.com',
    storageBucket: 'community-impact-tracker.appspot.com',
    measurementId: 'G-GCN6Q4WH0Y',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCVzDVQkmzgME40lXrHpMlVg0l_Ft3CvJU',
    appId: '1:538698773394:android:3ed9a3b131721fb61f474b',
    messagingSenderId: '538698773394',
    projectId: 'community-impact-tracker',
    storageBucket: 'community-impact-tracker.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD92zXmtG62z21prNOj0li4cDm61KZ9mgc',
    appId: '1:538698773394:ios:d543d59a2b9c57521f474b',
    messagingSenderId: '538698773394',
    projectId: 'community-impact-tracker',
    storageBucket: 'community-impact-tracker.appspot.com',
    iosBundleId: 'com.example.communityImpactTracker',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD92zXmtG62z21prNOj0li4cDm61KZ9mgc',
    appId: '1:538698773394:ios:d543d59a2b9c57521f474b',
    messagingSenderId: '538698773394',
    projectId: 'community-impact-tracker',
    storageBucket: 'community-impact-tracker.appspot.com',
    iosBundleId: 'com.example.communityImpactTracker',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC-7y7yJ7fCtLfd_5nd81nK3nAooCKI0vg',
    appId: '1:538698773394:web:8397a24c5442a6c71f474b',
    messagingSenderId: '538698773394',
    projectId: 'community-impact-tracker',
    authDomain: 'community-impact-tracker.firebaseapp.com',
    storageBucket: 'community-impact-tracker.appspot.com',
    measurementId: 'G-FD9P5FLJHL',
  );
}

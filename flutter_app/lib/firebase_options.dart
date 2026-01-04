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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyAVGDgu_dVMUU93FA7Vq5zz4dz22j0_1Yg',
    appId: '1:927491381202:web:8b38150daf041fef579a0b',
    messagingSenderId: '927491381202',
    projectId: 'student-app-36eec',
    authDomain: 'student-app-36eec.firebaseapp.com',
    storageBucket: 'student-app-36eec.firebasestorage.app',
    measurementId: 'G-SZJ2YDH9BB',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAVGDgu_dVMUU93FA7Vq5zz4dz22j0_1Yg',
    appId: '1:927491381202:android:YOUR_ANDROID_APP_ID',
    messagingSenderId: '927491381202',
    projectId: 'student-app-36eec',
    storageBucket: 'student-app-36eec.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVGDgu_dVMUU93FA7Vq5zz4dz22j0_1Yg',
    appId: '1:927491381202:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '927491381202',
    projectId: 'student-app-36eec',
    storageBucket: 'student-app-36eec.firebasestorage.app',
    iosBundleId: 'com.gdg.studentai',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAVGDgu_dVMUU93FA7Vq5zz4dz22j0_1Yg',
    appId: '1:927491381202:ios:YOUR_MACOS_APP_ID',
    messagingSenderId: '927491381202',
    projectId: 'student-app-36eec',
    storageBucket: 'student-app-36eec.firebasestorage.app',
    iosBundleId: 'com.gdg.studentai',
  );
}


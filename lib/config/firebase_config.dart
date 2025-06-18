import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseConfig {
  static FirebaseOptions get platformOptions {
    return const FirebaseOptions(
    apiKey: 'AIzaSyDuc1updwUAtRRUHXTdfD9231yQzaeCFCY',
    appId: '1:967307852599:android:23ec3ddcf7b8e922e338b2',
    messagingSenderId: '967307852599',
    projectId: 'balqees-restaurant',
    storageBucket: 'balqees-restaurant.firebasestorage.app',
    databaseURL: 'https://balqees-restaurant-default-rtdb.europe-west1.firebasedatabase.app',
    );
  }
}

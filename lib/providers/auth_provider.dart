import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:balqees/driver/driver_helper.dart'; // إضافة استيراد مساعد السائق

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String _userId = '';
  String _phone = '';
  String _name = '';
  String _address = '';
  String _role = 'user'; // Default role is user, can also be 'rider' or 'admin'

  bool get isLoggedIn => _isLoggedIn;
  String get userId => _userId;
  String get phone => _phone;
  String get name => _name;
  String get address => _address;
  String get role => _role;
  String get uuid => _userId;

  // Role checkers
  bool get isUser => _role == 'user';
  bool get isRider => _role == 'rider';
  bool get isAdmin => _role == 'admin';

  static final CollectionReference users =
      FirebaseFirestore.instance.collection('users');
  
  static final CollectionReference drivers =
      FirebaseFirestore.instance.collection('drivers');

  Future<void> registerUser({
    required String uuid,
    required String phone,
    required String password,
    required String address,
    required String name,
    required String fcmToken,
    Map<String, dynamic>? locationData,
    String role = 'user', // Default role is user
  }) async {
    // Create a base user data map
    final userData = {
      'uuid': uuid,
      'phone': phone,
      'password': password,
      'address': address,
      'name': name,
      'fcmToken': fcmToken,
      'role': role, // Adding role field
      'created_at': DateTime.now().toIso8601String(),
    };

    // If location data exists, add it properly structured


    // Save to Firestore
    await users.doc(uuid).set(userData);
    
    // If role is 'rider', also add to drivers collection
    if (role == 'rider') {
      await drivers.doc(uuid).set({
        'uuid': uuid,
        'phone': phone,
        'name': name,
        'address': address,
        'fcmToken': fcmToken,
        'isActive': true,
        'created_at': DateTime.now().toIso8601String(),
        'location': locationData != null ? {
          'latitude': locationData['latitude'],
          'longitude': locationData['longitude'],
          'lastUpdated': FieldValue.serverTimestamp(),
        } : null,
      });
    }
  }

  Future<bool> loginUser({
    required String phone,
    required String password,
  }) async {
    final snapshot = await users.where('phone', isEqualTo: phone).get();
    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      final user = doc.data() as Map<String, dynamic>;
      if (user['password'] == password) {
        _userId = doc.id;
        _phone = user['phone'] ?? '';
        _name = user['name'] ?? '';
        _address = user['address'] ?? '';
        _role = user['role'] ?? 'user'; // Get role with 'user' as default
        _isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uuid', user['uuid']);
        await prefs.setString('phone', _phone);
        await prefs.setString('name', _name);
        await prefs.setString('address', _address);
        await prefs.setString('role', _role);
        await prefs.setBool('isLoggedIn', true);

        // Update FCM token if available
        if (user['fcmToken'] != null && user['fcmToken'] != '') {
          // FCM token update logic here
        }

        // تهيئة مساعد السائق إذا كان المستخدم سائقاً
        if (_role == 'rider') {
          await DriverHelper().initialize(_userId);
        }

        notifyListeners();
        return true;
      }
    }
    return false;
  }

  Future<void> loginWithUUID(String uuid) async {
    try {
      final snapshot = await users.where('uuid', isEqualTo: uuid).limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        final userData = snapshot.docs.first.data() as Map<String, dynamic>;

        _userId = snapshot.docs.first.id;
        _phone = userData['phone'] ?? '';
        _name = userData['name'] ?? '';
        _address = userData['address'] ?? '';
        _role = userData['role'] ?? 'user'; // Get role with 'user' as default
        _isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('uuid', userData['uuid']);
        await prefs.setString('phone', _phone);
        await prefs.setString('name', _name);
        await prefs.setString('address', _address);
        await prefs.setString('role', _role);
        await prefs.setBool('isLoggedIn', true);

        // تهيئة مساعد السائق إذا كان المستخدم سائقاً
        if (_role == 'rider') {
          await DriverHelper().initialize(_userId);
        }

        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    // إذا كان المستخدم سائقاً، قم بإلغاء مساعد السائق
    if (_role == 'rider') {
      DriverHelper().dispose();
    }
    
    _isLoggedIn = false;
    _userId = '';
    _phone = '';
    _name = '';
    _address = '';
    _role = 'user'; // Reset role to default
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = prefs.getString('uuid');

    if (uuid == null || uuid.isEmpty) {
      _isLoggedIn = false;
      _role = 'user';
      notifyListeners();
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('uuid', isEqualTo: uuid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final user = snapshot.docs.first.data();
      _userId = snapshot.docs.first.id;
      _phone = user['phone'] ?? '';
      _name = user['name'] ?? '';
      _address = user['address'] ?? '';
      _role = user['role'] ?? 'user'; // ← يتم تحميل الدور مباشرة من Firestore
      _isLoggedIn = true;

      // تحديث SharedPreferences حسب الحاجة فقط (بدون الاعتماد عليه)
      await prefs.setString('uuid', user['uuid']);
      await prefs.setString('phone', _phone);
      await prefs.setString('name', _name);
      await prefs.setString('address', _address);
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('role', _role); // ← للمزامنة فقط

      // تهيئة مساعد السائق إذا كان المستخدم سائقاً
      if (_role == 'rider') {
        await DriverHelper().initialize(_userId);
      }
    } else {
      _isLoggedIn = false;
      _role = 'user';
    }

    notifyListeners();
  }


  // Method to update user location
  Future<void> updateLocation(Map<String, dynamic> locationData) async {
    if (!_isLoggedIn || _userId.isEmpty) return;

    final location = {
      'latitude': locationData['latitude'],
      'longitude': locationData['longitude'],
      'wazeLink': locationData['wazeLink'],
    };

    await users.doc(_userId).update({
      'location': location,
    });
    
    // Also update location in drivers collection if role is rider
    if (_role == 'rider') {
      await drivers.doc(_userId).update({
        'location': {
          'latitude': locationData['latitude'],
          'longitude': locationData['longitude'],
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      });
    }

    notifyListeners();
  }

  // Method to update FCM token
  Future<void> updateFCMToken(String token) async {
    if (!_isLoggedIn || _userId.isEmpty) return;

    await users.doc(_userId).update({
      'fcmToken': token,
    });
    
    // Also update FCM token in drivers collection if role is rider
    if (_role == 'rider') {
      await drivers.doc(_userId).update({
        'fcmToken': token,
      });
      
      // إعادة تهيئة DriverHelper مع الرمز الجديد
      await DriverHelper().initialize(_userId);
    }
  }
  
  // Method for riders to toggle active status
  Future<void> setRiderActiveStatus(bool isActive) async {
    if (!_isLoggedIn || _userId.isEmpty || _role != 'rider') return;
    
    await drivers.doc(_userId).update({
      'isActive': isActive,
    });
    
    notifyListeners();
  }
  
  // Method to check if a user can access rider features
  bool canAccessRiderFeatures() {
    return _isLoggedIn && (_role == 'rider' || _role == 'admin');
  }
}
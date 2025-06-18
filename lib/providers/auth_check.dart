import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthCheckProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String _role = 'user';
  String _userId = '';
  
  bool get isLoggedIn => _isLoggedIn;
  String get role => _role;
  String get userId => _userId;
  
  // Role checker getters
  bool get isUser => _role == 'user';
  bool get isRider => _role == 'rider';
  bool get isAdmin => _role == 'admin';

  Future<void> checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uuid = prefs.getString('uuid');

      if (uuid == null || uuid.isEmpty) {
        _isLoggedIn = false;
        _role = 'user';
        _userId = '';
      } else {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('uuid', isEqualTo: uuid)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          _isLoggedIn = true;
          _userId = snapshot.docs.first.id;
          
          // Get user role from Firestore
          final userData = snapshot.docs.first.data();
          _role = userData['role'] ?? 'user';
          
          // Update role in SharedPreferences to keep it in sync
          await prefs.setString('role', _role);
        } else {
          _isLoggedIn = false;
          _role = 'user';
          _userId = '';
        }
      }
    } catch (e) {
      _isLoggedIn = false;
      _role = 'user';
      _userId = '';
    }

    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isLoggedIn = false;
    _role = 'user';
    _userId = '';
    notifyListeners();
  }
  
  // Check if user can access driver features
  bool canAccessDriverFeatures() {
    return _isLoggedIn && (_role == 'rider' || _role == 'admin');
  }
}
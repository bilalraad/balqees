import 'package:balqees/screens/auth/login.dart';
import 'package:balqees/services/banned.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class BlacklistCheck extends StatefulWidget {
  final Widget child;

  const BlacklistCheck({super.key, required this.child});

  @override
  State<BlacklistCheck> createState() => _BlacklistCheckState();
}

class _BlacklistCheckState extends State<BlacklistCheck> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isBanned = false;
  bool _isLoggedIn = false;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    // استخدم Future.microtask لتأخير التحقق حتى يكتمل بناء الويدجيت
    Future.microtask(() {
      if (_isMounted) {
        _checkUserStatus();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    if (!_isMounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String? uuid = authProvider.uuid;
      
      // تحقق من تسجيل دخول المستخدم
      _isLoggedIn = authProvider.isLoggedIn;

      if (uuid == null || uuid.isEmpty) {
        _safeSetState(() {
          _isBanned = false; // ليس محظوراً، فقط غير مسجل الدخول
          _isLoading = false;
        });
        return;
      }

      // تحقق أولاً من وجود وثيقة القائمة السوداء
      final bannedDocsRef = _firestore.collection('blacklist').doc('banned_users');
      final docSnapshot = await bannedDocsRef.get();
      
      // إذا لم توجد الوثيقة، فالمستخدم ليس محظوراً
      if (!docSnapshot.exists) {
        _safeSetState(() {
          _isBanned = false;
          _isLoading = false;
        });
        return;
      }
      
      // تحقق مما إذا كان UUID محدد موجود في المصفوفة باستخدام استعلام
      final isUserBanned = await _firestore
          .collection('blacklist')
          .where(FieldPath.documentId, isEqualTo: 'banned_users')
          .where('uuids', arrayContains: uuid)
          .limit(1)
          .get();
      
      _safeSetState(() {
        // إذا حصلنا على أي نتائج، فإن المستخدم محظور
        _isBanned = isUserBanned.docs.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ أثناء التحقق من الحظر: $e');
      _safeSetState(() {
        _isBanned = false;
        _isLoading = false;
      });
    }
  }

  // دالة آمنة لاستدعاء setState فقط إذا كان الويدجيت لا يزال مثبتًا
  void _safeSetState(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // إذا كان المستخدم محظوراً وغير مسجل الدخول، قم بإعادة توجيهه إلى شاشة تسجيل الدخول
    if (_isBanned && !_isLoggedIn) {
      return const LoginPage();
    }
    
    // إذا كان المستخدم محظوراً ومسجلاً للدخول، أظهر صفحة الحظر
    if (_isBanned) {
      return const BannedPage();
    }

    // المستخدم ليس محظوراً، أظهر محتوى التطبيق العادي
    return widget.child;
  }
}
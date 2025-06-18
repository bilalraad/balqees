// utils/order_checker.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderChecker {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  late Timer _pollingTimer;
  String? _uuid;
  final Map<String, String> _lastStatuses = {}; // تتبع آخر الحالات
  bool _isFirstRun = true;

  Future<void> initialize() async {
    await _loadUuid();
    await _loadLastStatuses();
    await _setupLocalNotifications();
    _startPollingOrders();
  }

  Future<void> _loadUuid() async {
    final prefs = await SharedPreferences.getInstance();
    _uuid = prefs.getString('uuid');
    debugPrint('📱 تم تحميل معرف المستخدم: $_uuid');
  }

  Future<void> _loadLastStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStatuses = prefs.getString('last_statuses');
    if (savedStatuses != null) {
      _lastStatuses.addAll(Map<String, String>.from(jsonDecode(savedStatuses)));
    }
  }

  Future<void> _saveLastStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_statuses', jsonEncode(_lastStatuses));
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final orderId = response.payload;
        debugPrint('🔍 فتح تفاصيل الطلب: $orderId');
      },
    );
    debugPrint('🔔 تم تهيئة الإشعارات المحلية');
  }

  void _startPollingOrders() {
    if (_uuid == null) {
      debugPrint('⚠️ لم يتم العثور على معرف المستخدم، لا يمكن بدء مراقبة الطلبات');
      return;
    }

    debugPrint('🔄 بدء مراقبة الطلبات كل 3 ثوان');
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final snapshot = await _firestore
            .collection('orders')
            .where('uuid', isEqualTo: _uuid)
            .get();

        debugPrint('📦 تم العثور على ${snapshot.docs.length} طلب للمستخدم $_uuid');

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final orderId = doc.id;
          final status = data['status'] ?? '';
          final productName = data['name'] ?? 'الطلب';
          final total = data['total']?.toString() ?? '';

          final lastStatus = _lastStatuses[orderId];

          if (lastStatus == null) {
            if (!_isFirstRun) {
              debugPrint('📦 تم اكتشاف طلب جديد: $orderId بحالة $status');
              _showNewOrderNotification(status, orderId, productName, total);
            }
          } else if (lastStatus != status) {
            debugPrint('📦 تم تغيير حالة الطلب [$orderId] من $lastStatus إلى $status');
            _showLocalNotification(status, orderId, productName, total);
          }

          _lastStatuses[orderId] = status;
        }

        _isFirstRun = false;
        await _saveLastStatuses();
      } catch (e) {
        debugPrint('❌ خطأ أثناء التحقق من الطلبات: $e');
      }
    });
  }

  Future<void> _showNewOrderNotification(
    String status, 
    String orderId, 
    String productName, 
    String total
  ) async {
    final message = _getNewOrderMessage(productName, total);

    const androidDetails = AndroidNotificationDetails(
      'new_order_channel',
      'إشعارات الطلبات الجديدة',
      channelDescription: 'إشعارات تظهر عند إنشاء طلب جديد',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        (orderId + "_new").hashCode,
        '🛍️ طلب جديد!',
        message,
        notificationDetails,
        payload: orderId,
      );
      debugPrint('✅ تم إرسال إشعار لطلب جديد: $orderId');
    } catch (e) {
      debugPrint('❌ فشل في إرسال الإشعار للطلب الجديد $orderId: $e');
    }
  }

  String _getNewOrderMessage(String productName, String total) {
    if (productName.isNotEmpty && total.isNotEmpty) {
      return 'تم ارسال طلبك  بنجاح.\nالمنتج: $productName\nالإجمالي: $total';
    }
    return 'تم ارسال طلبك بنجاح.';
  }

  Future<void> _showLocalNotification(
    String status, 
    String orderId, 
    String productName, 
    String total
  ) async {
    final statusText = _getStatusMessage(status, productName, total);

    const androidDetails = AndroidNotificationDetails(
      'order_channel',
      'إشعارات الطلبات',
      channelDescription: 'إشعارات تظهر عند تحديث حالة الطلب',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        orderId.hashCode,
        '📦 حالة طلبك تغيرت',
        statusText,
        notificationDetails,
        payload: orderId,
      );
      debugPrint('✅ تم إرسال إشعار للحالة: $status (طلب: $orderId)');
    } catch (e) {
      debugPrint('❌ فشل في إرسال الإشعار للطلب $orderId: $e');
    }
  }

  String _getStatusMessage(String status, String productName, String total) {
    final baseMessage = switch (status) {
      'pending' => 'طلبك قيد الانتظار وسيتم مراجعته قريبًا.',
      'ready' => 'طلبك جاهز الآن ويمكن للسائق استلامه.',
      'accepted' => 'تم قبول طلبك وهو قيد التحضير.',
      'picked' => 'السائق استلم طلبك من المتجر.',
      'onway' => 'السائق في طريقه إليك الآن.',
      'delivered' => 'تم توصيل طلبك بنجاح.',
      'cancelled' => 'تم إلغاء الطلب من قبل الإدارة.',
      'failed' => 'لم يتم تسليم الطلب بسبب مشكلة.',
      _ => 'تم تحديث حالة طلبك إلى: $status',
    };

    if (productName.isNotEmpty && total.isNotEmpty) {
      return '$baseMessage\nالمنتج: $productName\nالإجمالي: $total';
    }
    return baseMessage;
  }

  void dispose() {
    debugPrint('🛑 إيقاف مراقبة الطلبات');
    if (_pollingTimer.isActive) {
      _pollingTimer.cancel();
    }
  }
}

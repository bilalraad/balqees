import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // للتعامل مع Int64List لنمط الاهتزاز

// هذا الصف يساعد في إشعارات الوقت الفعلي للسائقين
// يتعامل مع الإشعارات الخلفية حتى عندما يكون التطبيق مغلقًا
class DriverHelper {
  // نمط المفرد (Singleton)
  static final DriverHelper _instance = DriverHelper._internal();

  // مراجع Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // اشتراكات الدفق (Stream)
  StreamSubscription? _ordersSubscription;

  // معرف السائق
  String? _driverId;

  // بناء المصنع (Factory constructor)
  factory DriverHelper() {
    return _instance;
  }

  // البناء الخاص
  DriverHelper._internal();

  // تهيئة المساعد
  Future<void> initialize(String driverId) async {
    _driverId = driverId;

    // تكوين رسائل firebase للإشعارات الخلفية
    await _configureFirebaseMessaging();

    // تهيئة الإشعارات المحلية
    await _initializeLocalNotifications();

    // الاستماع للطلبات الجديدة
    _listenForNewOrders();
  }

  // تكوين Firebase Messaging
  Future<void> _configureFirebaseMessaging() async {
    // طلب إذن للإشعارات
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('حالة إذن إشعارات المستخدم: ${settings.authorizationStatus}');

    // الحصول على رمز FCM وتخزينه للسائق
    String? token = await _messaging.getToken();
    if (token != null && _driverId != null) {
      try {
        final driverRef = _firestore.collection('drivers').doc(_driverId);
        final driverDoc = await driverRef.get();

        if (driverDoc.exists) {
          await driverRef.update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint('رمز FCM: $token');
        } else {
          debugPrint(
              '⚠️ لم يتم العثور على وثيقة السائق عند تحديث FCM: $_driverId');
        }
      } catch (e) {
        debugPrint('خطأ في تحديث رمز FCM: $e');
      }
    }

    // تكوين معالجة الرسائل في المقدمة
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('وصلت رسالة أثناء تشغيل التطبيق في المقدمة!');
      debugPrint('بيانات الرسالة: ${message.data}');

      if (message.notification != null) {
        debugPrint(
            'الرسالة تحتوي أيضًا على إشعار: ${message.notification!.title}');
        _showLocalNotification(
          message.notification!.title ?? 'إشعار جديد',
          message.notification!.body ?? 'لديك إشعار جديد',
          message.data,
        );
      }
    });

    // معالجة عندما يتم فتح التطبيق من إشعار خلفي
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('تم نشر حدث onMessageOpenedApp جديد!');
      _handleNotificationClick(message.data);
    });

    // التحقق مما إذا تم فتح التطبيق من حالة متوقفة عبر الإشعار
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage.data);
    }
  }

  // تهيئة الإشعارات المحلية
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // معالجة النقر على الإشعار
        if (response.payload != null) {
          Map<String, dynamic> data = {};
          try {
            // تحليل الحمولة إلى خريطة
            final parts = response.payload!.split('&');
            for (var part in parts) {
              final keyValue = part.split('=');
              if (keyValue.length == 2) {
                data[keyValue[0]] = keyValue[1];
              }
            }
          } catch (e) {
            debugPrint('خطأ في تحليل حمولة الإشعار: $e');
          }
          _handleNotificationClick(data);
        }
      },
    );
  }

  // عرض إشعار محلي
  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    // تحويل خريطة البيانات إلى سلسلة حمولة
    String payload = data.entries.map((e) => '${e.key}=${e.value}').join('&');

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'driver_channel',
      'إشعارات السائق',
      channelDescription: 'إشعارات للسائقين حول الطلبات الجديدة',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(
          'notification_ringtone'), // استخدم الاسم فقط بدون امتداد
      enableLights: true,
      enableVibration: true,
      vibrationPattern:
          Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ongoing:
          false, // تم تغييره من true لأن ongoing يجعل الإشعار غير قابل للإزالة
      autoCancel:
          true, // تم تغييره من false لتمكين إلغاء الإشعار تلقائيًا عند النقر عليه
    );

    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_ringtone.wav', // تأكد من تضمين الامتداد .wav لـ iOS
      interruptionLevel: InterruptionLevel.critical,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // استخدام وقت UTC للحصول على معرّف فريد للإشعار
    int notificationId =
        DateTime.now().microsecondsSinceEpoch.remainder(100000);

    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // معالجة النقر على الإشعار
  void _handleNotificationClick(Map<String, dynamic> data) {
    if (data.containsKey('orderId')) {
      final orderId = data['orderId'];
      // الانتقال إلى شاشة تفاصيل الطلب
      // هذا يتطلب سياق التنقل، والذي سيتم تمريره عادةً من التطبيق الرئيسي
      debugPrint('يجب الانتقال إلى تفاصيل الطلب للطلب رقم: $orderId');

      // مثال على كيفية التنقل إذا كان مفتاح التنقل متاحًا:
      // Navigator.of(navigatorKey.currentContext!).pushNamed(
      //   '/order-details',
      //   arguments: {'orderId': orderId},
      // );
    }
  }

  // الاستماع للطلبات الجديدة في Firestore
  void _listenForNewOrders() {
    // إلغاء أي اشتراك موجود
    _ordersSubscription?.cancel();

    // الاشتراك في طلبات "جاهزة" جديدة
    _ordersSubscription = _firestore
        .collection('orders')
        .where('status', isEqualTo: 'ready')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // معالجة المستندات المضافة حديثًا فقط
        if (change.type == DocumentChangeType.added) {
          final orderData = change.doc.data() as Map<String, dynamic>;
          final orderId = change.doc.id;

          // التحقق مما إذا كان هذا طلبًا جديدًا (تم إنشاؤه في الدقيقة الماضية)
          final createdAt = orderData['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final now = DateTime.now();
            final orderTime = createdAt.toDate();
            final difference = now.difference(orderTime);

            // إذا تم إنشاء الطلب قبل أقل من دقيقة واحدة، قم بإشعار السائق
            if (difference.inMinutes < 1) {
              _showLocalNotification(
                'طلب جديد متاح',
                'لديك طلب جديد من ${orderData['storeName'] ?? 'متجر'}',
                {
                  'orderId': orderId,
                  'type': 'new_order',
                },
              );
            }
          }
        }
      }
    });
  }

  // الاستماع للطلبات المخصصة
  void listenForAssignedOrders() {
    if (_driverId == null) return;

    // الاستماع لتحديثات الطلبات المخصصة لهذا السائق
    _firestore
        .collection('orders')
        .where('driverId', isEqualTo: _driverId)
        .where('status', whereIn: ['accepted', 'picked', 'onway'])
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.modified) {
              final orderData = change.doc.data() as Map<String, dynamic>;
              final orderId = change.doc.id;

              // إذا كانت هناك رسالة جديدة من العميل أو المتجر
              if (orderData.containsKey('lastMessage') &&
                  orderData.containsKey('lastMessageTime')) {
                final lastMessageTime =
                    orderData['lastMessageTime'] as Timestamp?;
                if (lastMessageTime != null) {
                  final now = DateTime.now();
                  final messageTime = lastMessageTime.toDate();
                  final difference = now.difference(messageTime);

                  // إذا كانت الرسالة عمرها أقل من دقيقة واحدة
                  if (difference.inMinutes < 1) {
                    _showLocalNotification(
                      'رسالة جديدة',
                      orderData['lastMessage'] ?? 'لديك رسالة جديدة',
                      {
                        'orderId': orderId,
                        'type': 'message',
                      },
                    );
                  }
                }
              }
            }
          }
        });
  }

  // تحديث موقع السائق في الخلفية
  Future<void> updateDriverLocation(double latitude, double longitude) async {
    if (_driverId == null) return;

    try {
      // تحقق أولاً من وجود وثيقة السائق
      final driverRef = _firestore.collection('drivers').doc(_driverId);
      final driverDoc = await driverRef.get();

      if (driverDoc.exists) {
        // إذا كانت الوثيقة موجودة، قم بتحديث الموقع
        await driverRef.update({
          'location': {
            'latitude': latitude,
            'longitude': longitude,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        });
        debugPrint('✅ تم تحديث موقع السائق بنجاح');
      } else {
        // إذا لم تكن الوثيقة موجودة، قم بإنشائها
        debugPrint('⚠️ وثيقة السائق غير موجودة: $_driverId');

        // يمكن إنشاء وثيقة جديدة أو تسجيل خطأ حسب احتياجات التطبيق
        // أقترح إنشاء وثيقة جديدة بمعلومات أساسية
        await driverRef.set({
          'uuid': _driverId,
          'isActive': true,
          'created_at': FieldValue.serverTimestamp(),
          'location': {
            'latitude': latitude,
            'longitude': longitude,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));

        debugPrint('✅ تم إنشاء وثيقة جديدة للسائق وتحديث الموقع');
      }
    } catch (e) {
      debugPrint('❌ خطأ في تحديث موقع السائق: $e');
    }
  }

  // التوقف عن الاستماع للإشعارات والتحديثات
  void dispose() {
    _ordersSubscription?.cancel();
  }

  // التسجيل لمعالجة الرسائل الخلفية
  static Future<void> setupBackgroundMessaging() async {
    // إعداد معالج رسائل الخلفية
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}

// معالج رسائل الخلفية - يجب أن تكون دالة على المستوى الأعلى خارج الفئة
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // تحتاج إلى تهيئة Firebase هنا إذا كنت تستخدم خدمات Firebase أخرى
  debugPrint("معالجة رسالة خلفية: ${message.messageId}");

  // نظرًا لأن هذا معالج خلفي، لا يمكننا عرض واجهة مستخدم
  // ولكن يمكننا إنشاء إشعار

  // يجب أن يكون المعالج الخلفي عادةً الحد الأدنى
  // فقط ما يكفي لإظهار إشعار للمستخدم
}

// فئة لتسجيل المهام الخلفية لتحديثات الموقع
class BackgroundLocationService {
  static Future<void> registerBackgroundTask() async {
    // هذا سيستخدم واجهات برمجة تطبيقات المهام الخلفية الخاصة بالمنصة
    // بالنسبة لـ Android، قد تستخدم WorkManager
    // بالنسبة لـ iOS، قد تستخدم BGTaskScheduler

    // التنفيذ يعتمد على المتطلبات المحددة والمنصات
    if (Platform.isAndroid) {
      // تسجيل مهمة خلفية لنظام Android
    } else if (Platform.isIOS) {
      // تسجيل مهمة خلفية لنظام iOS
    }
  }
}

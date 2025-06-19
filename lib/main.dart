import 'dart:async';
import 'package:balqees/driver/driver_helper.dart';
import 'package:balqees/providers/auth_check.dart';
import 'package:balqees/providers/auth_provider.dart';
import 'package:balqees/services/blacklist.dart';
import 'package:balqees/utils/route.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'config/firebase_config.dart';
import 'providers/cart_provider.dart';
import 'providers/orders_provider.dart';
import 'utils/theme.dart';
import 'utils/order_checker.dart';
import 'utils/connectivity.dart'; // استيراد ملف فحص الاتصال

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ استقبال الإشعار في الخلفية
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseConfig.platformOptions,
      );
    }
  } catch (e) {
    debugPrint('Firebase بالفعل مهيأ في الخلفية');
  }

  debugPrint('🔔 إشعار في الخلفية: ${message.notification?.title}');
}

// إضافة متغير عام للوصول إلى OrderChecker
late OrderChecker orderChecker;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    // ✅ تهيئة الإشعارات
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();
    await DriverHelper.setupBackgroundMessaging();

    // ✅ إعداد قناة Android
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          debugPrint('تم الضغط على الإشعار: ${response.payload}');
          try {
            // محاولة تحليل البيانات المضمنة في الإشعار
            // ignore: unused_local_variable
            final data = jsonDecode(response.payload!);
            // يمكن استخدام هذه البيانات للتنقل إلى الشاشة المناسبة
            // لكن لا يمكننا استخدام context هنا مباشرة
          } catch (e) {
            debugPrint('خطأ في تحليل بيانات الإشعار: $e');
          }
        }
      },
    );

    // ✅ استقبال الإشعارات أثناء استخدام التطبيق
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'order_channel',
              'إشعارات الطلبات',
              channelDescription: 'إشعارات تظهر عند تحديث حالة الطلب',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
        );
      }
    });

    // ✅ تحميل بيانات تسجيل الدخول
    final authProvider = AuthProvider();
    await authProvider.checkLogin();

    // ✅ تهيئة OrderChecker بعد تهيئة Firebase
    orderChecker = OrderChecker();
    await orderChecker.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => authProvider),
          ChangeNotifierProvider(create: (_) => AuthCheckProvider()),
          ChangeNotifierProvider(create: (_) => OrdersProvider()),
          // إضافة مزود لحالة الاتصال
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ],
        child: const BalqeesApp(),
      ),
    );
  } catch (e, s) {
    debugPrint(e.toString());
    debugPrint(s.toString());
  }
}

class BalqeesApp extends StatefulWidget {
  const BalqeesApp({super.key});

  @override
  State<BalqeesApp> createState() => _BalqeesAppState();
}

class _BalqeesAppState extends State<BalqeesApp> {
  @override
  void dispose() {
    // إلغاء OrderChecker عند إغلاق التطبيق
    orderChecker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بلقيس',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/splash',
      onGenerateRoute: RouteManager.generateRoute,
      // تطبيق فاحص الاتصال قبل BlacklistCheck
      builder: (context, child) => ConnectivityChecker(
        child: BlacklistCheck(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
      ),
    );
  }
}

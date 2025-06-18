import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:math' as math;
import '../utils/colors.dart'; // استيراد ملف الألوان

// Provider لمراقبة حالة الاتصال
class ConnectivityProvider with ChangeNotifier {
  bool _isConnected = true;
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  
  bool get isConnected => _isConnected;
  
  ConnectivityProvider() {
    _initConnectivity();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen(_updateConnectionStatus);
  }
  
  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('خطأ في التحقق من الاتصال: $e');
      return;
    }
  }
  
  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    final bool wasConnected = _isConnected;
    // تحقق ما إذا كان هناك أي نوع من أنواع الاتصال متوفر
    final bool isConnected = results.contains(ConnectivityResult.wifi) || 
                             results.contains(ConnectivityResult.mobile) ||
                             results.contains(ConnectivityResult.ethernet);
    
    if (wasConnected != isConnected) {
      _isConnected = isConnected;
      notifyListeners();
    }
  }
  
  Future<bool> checkConnection() async {
    final results = await Connectivity().checkConnectivity();
    // تحقق ما إذا كان هناك أي نوع من أنواع الاتصال متوفر
    final bool isConnected = results.contains(ConnectivityResult.wifi) || 
                             results.contains(ConnectivityResult.mobile) ||
                             results.contains(ConnectivityResult.ethernet);
    
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      notifyListeners();
    }
    
    return _isConnected;
  }
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// كلاس للتحقق من الاتصال وعرض شاشة مناسبة
class ConnectivityChecker extends StatefulWidget {
  final Widget child;

  const ConnectivityChecker({
    super.key,
    required this.child,
  });

  @override
  State<ConnectivityChecker> createState() => _ConnectivityCheckerState();
}

class _ConnectivityCheckerState extends State<ConnectivityChecker>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isConnected = true;
  bool _isMounted = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // استخدم Future.microtask لتأخير التحقق حتى يكتمل بناء الويدجيت
    Future.microtask(() {
      if (_isMounted && mounted) {
        _checkInitialConnectivity();
        _setupConnectivityListener();
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    if (!mounted || !_isMounted) return;
    
    final results = await Connectivity().checkConnectivity();
    // تحقق من توفر أي نوع من أنواع الاتصال
    final isConnected = results.contains(ConnectivityResult.wifi) || 
                         results.contains(ConnectivityResult.mobile) ||
                         results.contains(ConnectivityResult.ethernet);
    
    _safeSetState(() {
      _isConnected = isConnected;
    });
    
    if (!_isConnected) {
      _animationController.repeat(reverse: true);
    }
  }

  void _setupConnectivityListener() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted || !_isMounted) return;
      
      final wasConnected = _isConnected;
      // تحقق من توفر أي نوع من أنواع الاتصال
      final isConnected = results.contains(ConnectivityResult.wifi) || 
                           results.contains(ConnectivityResult.mobile) ||
                           results.contains(ConnectivityResult.ethernet);
      
      _safeSetState(() {
        _isConnected = isConnected;
      });
      
      if (!wasConnected && isConnected) {
        // تم استعادة الاتصال
        _animationController.stop();
        
        // التأكد من وجود سياق صالح قبل إظهار رسالة
        if (mounted && _isMounted && context.mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              content: Text('تم استعادة الاتصال بالإنترنت'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (wasConnected && !isConnected) {
        // تم فقدان الاتصال
        _animationController.repeat(reverse: true);
      }
    });
  }

  // دالة آمنة لاستدعاء setState فقط إذا كان الويدجيت لا يزال مثبتًا
  void _safeSetState(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }

  Future<void> _retryConnection() async {
    if (!mounted || !_isMounted) return;
    
    _safeSetState(() {
      _isConnected = false; // إظهار حالة التحميل
    });
    
    final results = await Connectivity().checkConnectivity();
    if (!mounted || !_isMounted) return;
    
    // تحقق من توفر أي نوع من أنواع الاتصال
    final isConnected = results.contains(ConnectivityResult.wifi) || 
                         results.contains(ConnectivityResult.mobile) ||
                         results.contains(ConnectivityResult.ethernet);
    
    _safeSetState(() {
      _isConnected = isConnected;
    });
    
    if (_isConnected && mounted && _isMounted && context.mounted) {
      _animationController.stop();
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تم استعادة الاتصال بالإنترنت'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    _subscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return widget.child;
    }
    
    return AdvancedConnectivityScreen(
      onRetry: _retryConnection,
    );
  }
}

// شاشة الاتصال المتقدمة
class AdvancedConnectivityScreen extends StatefulWidget {
  final VoidCallback onRetry;
  
  const AdvancedConnectivityScreen({
    super.key, 
    required this.onRetry,
  });

  @override
  State<AdvancedConnectivityScreen> createState() => _AdvancedConnectivityScreenState();
}

class _AdvancedConnectivityScreenState extends State<AdvancedConnectivityScreen> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  bool _isRetrying = false;
  bool _isMounted = false;
  
  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _isMounted = false;
    _controller.dispose();
    super.dispose();
  }
  
  // دالة آمنة لاستدعاء setState فقط إذا كان الويدجيت لا يزال مثبتًا
  void _safeSetState(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }
  
  Future<void> _handleRetry() async {
    _safeSetState(() {
      _isRetrying = true;
    });
    
    // اعطاء وقت للتحقق من الاتصال
    await Future.delayed(const Duration(seconds: 2));
    
    widget.onRetry();
    
    // إذا لم يتم تغيير الشاشة (استمرار مشكلة الاتصال)
    _safeSetState(() {
      _isRetrying = false;
    });
  }
  
  void _showTroubleshootingDialog(BuildContext context) {
    // تأكد من وجود سياق صالح قبل إظهار الحوار
    if (!mounted || !_isMounted || !context.mounted) return;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اقتراحات إصلاح الاتصال'),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.burntBrown,
        ),
        backgroundColor: AppColors.cardBackground,
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• تحقق من تفعيل بيانات الهاتف أو الواي فاي'),
            SizedBox(height: 8),
            Text('• أعد تشغيل جهاز الراوتر'),
            SizedBox(height: 8),
            Text('• تحقق من وضع الطيران'),
            SizedBox(height: 8),
            Text('• تحقق من توفر رصيد للإنترنت'),
            SizedBox(height: 8),
            Text('• قم بتحديث تطبيق بلقيس'),
          ],
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.goldenOrange,
            ),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.lightBeige,
              AppColors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // أيقونة وصورة متحركة
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      0,
                      10 * math.sin(_controller.value * math.pi * 2),
                    ),
                    child: child,
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: size.width * 0.6,
                      height: size.width * 0.6,
                      decoration: BoxDecoration(
                        color: AppColors.goldenOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // استخدم أيقونة لتمثيل انقطاع الاتصال
                    Icon(
                      Icons.wifi_off_rounded,
                      size: size.width * 0.3,
                      color: AppColors.burntBrown,
                    ),
                    /* إذا كنت تريد استخدام ملفات Lottie، قم بإستيراد المكتبة وإلغاء التعليق عن هذا الكود
                    Lottie.asset(
                      'assets/animations/no_connection.json',
                      width: size.width * 0.5,
                      fit: BoxFit.contain,
                    ),
                    */
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // عنوان المشكلة
              Text(
                'لا يوجد اتصال بالإنترنت',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // وصف المشكلة
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'يرجى التحقق من اتصال الإنترنت الخاص بك والمحاولة مرة أخرى. قد تكون هناك مشكلة في شبكة الواي فاي أو بيانات الهاتف.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // زر إعادة المحاولة
              _isRetrying
                  ? const CircularProgressIndicator(
                      color: AppColors.goldenOrange,
                    )
                  : Container(
                      width: size.width * 0.7,
                      height: 56,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.goldenOrange.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _handleRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.goldenOrange,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'إعادة المحاولة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              
              const SizedBox(height: 24),
              
              // معلومات إضافية - حل مشكلة Navigator
              
            ],
          ),
        ),
      ),
    );
  }
}
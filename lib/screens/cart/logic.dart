import 'package:balqees/providers/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart'; // Add logger for better debugging

class CartCore {
  bool isLoading = false;
  String promoCode = '';
  double promoPercentage = 0.0; // Added for percentage-based coupons
  String deliveryMethod = 'توصيل';
  String paymentMethod = 'الدفع عند الاستلام';
  String? errorMessage; // Added for coupon error messages
  bool isValidatingCoupon = false; // Added for coupon validation state
  final logger = Logger(); // Added logger
  String notes = ''; // Added for order notes

  final TextEditingController promoController = TextEditingController();

  double get deliveryFee => deliveryMethod == 'توصيل' ? 0 : 0;

  // تحديث حساب المجموع الفرعي لاحتساب الخصومات الموجودة على المنتجات
  double calculateSubtotal(Map<String, int> cartItems, List<Map<String, dynamic>> products) {
    double total = 0;
    cartItems.forEach((productId, quantity) {
      final product = products.firstWhere(
        (p) => p['id'] == productId,
        orElse: () => {'price': 0},
      );
      
      // التحقق مما إذا كان المنتج به خصم
      // ignore: unused_local_variable
      bool hasDiscount = false;
      double finalPrice = 0.0;
      
      // استخدام نسبة الخصم من Firestore إذا كانت متوفرة
      if (product['discountPercentage'] != null) {
        hasDiscount = true;
        // استخراج نسبة الخصم - تأكد من تحويلها إلى double إذا كانت نصية
        double discountPercentage = double.tryParse(
            product['discountPercentage'].toString().replaceAll('%', '')
        ) ?? 0.0;
        double originalPrice = (product['price'] ?? 0).toDouble();
        finalPrice = originalPrice * (1 - (discountPercentage / 100));
      }
      // أو فحص وجود oldPrice للتوافق مع الكود السابق
      else if (product['oldPrice'] != null && 
               product['oldPrice'] > product['price']) {
        hasDiscount = true;
        finalPrice = (product['price'] ?? 0).toDouble();
      }
      else {
        // لا يوجد خصم، استخدم السعر العادي
        finalPrice = (product['price'] ?? 0).toDouble();
      }
      
      total += finalPrice * quantity;
    });
    return total;
  }

  // حساب الخصم من كود الخصم (تحديث ليستخدم النسبة المئوية الفعلية)
  double calculatePromoDiscount(double subtotal) {
    return promoCode.isNotEmpty ? subtotal * (promoPercentage / 100) : 0;
  }

  // حساب المجموع النهائي
  double calculateTotal(double subtotal, double deliveryFee, double discount) {
    return subtotal + deliveryFee - discount;
  }

  void triggerHapticFeedback() {
    HapticFeedback.lightImpact();
  }

  // تحديث لدعم التحقق من كوبونات الخصم من Firestore
  Future<void> validateAndApplyCoupon(BuildContext context, Function(String) updateState) async {
    final code = promoController.text.trim();
    if (code.isEmpty) {
      errorMessage = 'يرجى إدخال كود الكوبون';
      updateState('');
      return;
    }

    isValidatingCoupon = true;
    errorMessage = null;
    updateState('');

    try {
      // التحقق من كود الكوبون في Firestore
      final QuerySnapshot couponSnapshot = await FirebaseFirestore.instance
        .collection('discounts')
        .where('couponCode', isEqualTo: code)
        .get();
      
      // التحقق من وجود كوبون بهذا الكود
      if (couponSnapshot.docs.isEmpty) {
        errorMessage = 'كود الكوبون غير صالح';
        isValidatingCoupon = false;
        updateState('');
        return;
      }
      
      // الحصول على بيانات الكوبون
      final couponData = couponSnapshot.docs.first.data() as Map<String, dynamic>;
      
      // التحقق من أن الكوبون نشط
      if (couponData['isActive'] != true) {
        errorMessage = 'كود الكوبون غير نشط';
        isValidatingCoupon = false;
        updateState('');
        return;
      }
      
      // التحقق من تاريخ انتهاء الكوبون
      if (couponData.containsKey('expiryDate') && couponData['expiryDate'] != null) {
        final Timestamp expiryTimestamp = couponData['expiryDate'];
        final DateTime expiryDate = expiryTimestamp.toDate();
        
        if (expiryDate.isBefore(DateTime.now())) {
          errorMessage = 'انتهت صلاحية كود الكوبون';
          isValidatingCoupon = false;
          updateState('');
          return;
        }
      }
      
      // تطبيق الكوبون الصالح
      promoCode = code;
      promoPercentage = (couponData['percentage'] ?? 10).toDouble();
      
      // إذا كان الكوبون صالحًا، قم بتطبيقه أيضًا في CartProvider إذا كان متاحًا
      if (context.mounted) {
        try {
          final cartProvider = Provider.of<CartProvider>(context, listen: false);
          cartProvider.applyCoupon(
            code: code,
            discountPercentage: promoPercentage,
            name: couponData['name'] ?? 'كوبون خصم',
            expiryDate: couponData.containsKey('expiryDate') ? couponData['expiryDate'].toDate() : null,
          );
        } catch (e) {
          // قد يكون CartProvider غير متاح، فقط قم بتجاهل الخطأ
          logger.e('Error applying coupon to CartProvider: $e');
        }
      }

      // تحديث الواجهة
      updateState(code);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تطبيق كود الخصم بنجاح! (خصم ${promoPercentage.toStringAsFixed(0)}%)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      logger.e('Error validating coupon: $e');
      errorMessage = 'حدث خطأ أثناء التحقق من الكوبون';
      updateState('');
    } finally {
      isValidatingCoupon = false;
    }
  }

  // استخدام تنفيذ الكود القديم إذا لم يكن التحقق من Firebase متاحًا
  void applyPromoCode(BuildContext context, Function(String) updateState) {
    if (promoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال كود الخصم'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // محاولة التحقق من Firestore أولاً
    validateAndApplyCoupon(context, updateState);
  }

  void clearPromoCode(Function(String) updateState, BuildContext context) {
    promoCode = '';
    promoPercentage = 0.0;
    promoController.clear();
    
    // إلغاء الكوبون من CartProvider أيضًا إذا كان متاحًا
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.removeCoupon();
    } catch (e) {
      // قد يكون CartProvider غير متاح، فقط قم بتجاهل الخطأ
      logger.e('Error removing coupon from CartProvider: $e');
    }
    
    updateState('');
  }

  Map<String, dynamic> buildOrderData({
    required String orderId,
    required String uuid,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double deliveryFee,
    required double discount,
    required double total,
    required String deliveryMethod,
    required String paymentMethod,
    Map<String, dynamic>? couponDetails, // إضافة معلومات الكوبون
  }) {
    return {
      'orderId': orderId,
      'uuid': uuid,
      'items': items,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'discount': discount,
      'total': total,
      'deliveryMethod': deliveryMethod,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      // إضافة معلومات الكوبون إذا كان موجودًا
      'coupon': couponDetails,
    };
  }

  Future<void> checkout(
    BuildContext context,
    Function(bool) updateLoadingState, {
    required Map<String, int> cartItems,
    required List<Map<String, dynamic>> products,
    required double subtotal,
    required double deliveryFee,
    required double discount,
    required double total,
    Map<String, dynamic>? couponDetails, // إضافة معلومات الكوبون
  }) async {
    updateLoadingState(true);

    try {
      final firestore = FirebaseFirestore.instance;
      final prefs = await SharedPreferences.getInstance();

      final String? uuid = prefs.getString('uuid');

      if (uuid == null || uuid.isEmpty) {
        updateLoadingState(false);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على UUID. يرجى تسجيل الدخول مجددًا.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final String phone = prefs.getString('phone') ?? 'غير متوفر';
      final String orderId = firestore.collection('orders').doc().id;

      List<Map<String, dynamic>> orderItems = [];
      cartItems.forEach((productId, quantity) {
        final product = products.firstWhere(
          (p) => p['id'] == productId,
          orElse: () => {
            'id': productId,
            'name': 'المنتج غير متوفر',
            'price': 0,
          },
        );

        // حساب السعر النهائي مع الخصم إن وجد
        bool hasDiscount = false;
        double originalPrice = (product['price'] ?? 0).toDouble();
        double finalPrice = originalPrice;
        double discountPercentage = 0;

        // استخدام نسبة الخصم من Firestore إذا كانت متوفرة
        if (product['discountPercentage'] != null) {
          hasDiscount = true;
          discountPercentage = double.tryParse(
              product['discountPercentage'].toString().replaceAll('%', '')
          ) ?? 0.0;
          finalPrice = originalPrice * (1 - (discountPercentage / 100));
        }
        // أو فحص وجود oldPrice للتوافق مع الكود السابق
        else if (product['oldPrice'] != null && 
                product['oldPrice'] > product['price']) {
          hasDiscount = true;
          originalPrice = (product['oldPrice'] ?? 0).toDouble();
          finalPrice = (product['price'] ?? 0).toDouble();
          discountPercentage = ((originalPrice - finalPrice) / originalPrice) * 100;
        }

        orderItems.add({
          'productId': productId,
          'name': product['name'] ?? 'منتج غير معروف',
          'price': originalPrice,
          'finalPrice': finalPrice,
          'hasDiscount': hasDiscount,
          'discountPercentage': hasDiscount ? discountPercentage : null,
          'quantity': quantity,
          'total': finalPrice * quantity,
        });
      });

      // تحضير معلومات الكوبون للطلب
      Map<String, dynamic>? orderCouponDetails;
      if (promoCode.isNotEmpty) {
        orderCouponDetails = couponDetails ?? {
          'code': promoCode,
          'percentage': promoPercentage,
          'amount': calculatePromoDiscount(subtotal),
        };
      }

      final orderData = buildOrderData(
        orderId: orderId,
        uuid: uuid,
        items: orderItems,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        discount: discount,
        total: total,
        deliveryMethod: deliveryMethod,
        paymentMethod: paymentMethod,
        couponDetails: orderCouponDetails,
      );

      orderData['phone'] = phone; // ✅ إضافة رقم الهاتف من SharedPreferences

      await firestore.collection('orders').doc(orderId).set(orderData);

      updateLoadingState(false);
      
      if (context.mounted) {
        showOrderConfirmationDialog(context, orderId);
      }
    } catch (e) {
      logger.e('Error during checkout: $e');
      updateLoadingState(false);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إتمام الطلب: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void showOrderConfirmationDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تم تأكيد الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تم تأكيد طلبك بنجاح. سيصلك الطلب خلال 30-45 دقيقة.'),
            const SizedBox(height: 8),
            Text('رقم الطلب: $orderId', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (promoCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'تم تطبيق كوبون خصم: $promoCode (${promoPercentage.toStringAsFixed(0)}%)',
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<CartProvider>(context, listen: false).clearCart();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void dispose() {
    promoController.dispose();
  }
}
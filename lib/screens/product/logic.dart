import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:balqees/providers/cart_provider.dart';
import 'package:balqees/utils/colors.dart';

/// كلاس منطق صفحة تفاصيل المنتج
/// يحتوي على كافة الوظائف المنطقية وإدارة الحالة
class ProductDetailLogic extends ChangeNotifier {
  final Map<String, dynamic> product;
  int quantity = 1;
  bool showDetails = false;
  late Animation<Offset> slideAnimation;
  late Animation<double> fadeAnimation;
  
  // متغير لتخزين الخيار المحدد
  Map<String, dynamic>? _selectedOption;
  
  // متحكم الحركة
  late AnimationController _animationController;
  
  ProductDetailLogic(this.product, TickerProvider vsync) {
    // تهيئة متحكم الحركة
    _animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 800),
    );
    
    // حركة الظهور من أسفل الشاشة
    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // حركة التلاشي
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // تأخير قصير قبل بدء الحركة
    Future.delayed(const Duration(milliseconds: 200), () {
      _animationController.forward();
      showDetails = true;
      notifyListeners();
    });
    
    // تهيئة خيارات المنتج
    _initializeProductOptions();
  }
  
  // الحصول على الخيار المحدد
  Map<String, dynamic>? get selectedOption => _selectedOption;
  
  // تهيئة خيارات المنتج
  void _initializeProductOptions() {
    if (hasProductOptions()) {
      final options = getProductOptions();
      if (options.isNotEmpty) {
        _selectedOption = options.first;
      }
    }
  }
  
  // التحقق من وجود خيارات للمنتج
  bool hasProductOptions() {
    return product['hasOptions'] == true && 
           product['productOptions'] != null &&
           (product['productOptions'] as List).isNotEmpty;
  }
  
  // الحصول على قائمة خيارات المنتج
  List<Map<String, dynamic>> getProductOptions() {
    if (!hasProductOptions()) {
      return [];
    }
    
    List<dynamic> rawOptions = product['productOptions'];
    return rawOptions.map((option) => option as Map<String, dynamic>).toList();
  }
  
  // التحقق من وجود خصم واستخراج معلومات الخصم
  Map<String, dynamic> getDiscountInfo() {
    // السعر الأصلي
    double originalPrice = 0.0;
    // السعر بعد الخصم
    double finalPrice = 0.0;
    // هل يوجد خصم
    bool hasDiscount = false;
    // نسبة الخصم
    double discountPercentage = 0.0;
    
    // إذا كان هناك خيار محدد، استخدم سعره
    if (_selectedOption != null) {
      originalPrice = (_selectedOption!['price'] ?? 0).toDouble();
    } else {
      originalPrice = (product['price'] ?? 0).toDouble();
    }
    
    // التحقق من وجود discountPercentage في Firestore
    if (product['discountPercentage'] != null) {
      hasDiscount = true;
      // استخراج نسبة الخصم - تأكد من تحويلها إلى double إذا كانت نصية
      discountPercentage = double.tryParse(
        product['discountPercentage'].toString().replaceAll('%', '')
      ) ?? 0.0;
      
      // حساب السعر النهائي بعد الخصم
      finalPrice = originalPrice * (1 - (discountPercentage / 100));
    }
    // أو التحقق من وجود oldPrice
    else if (product['oldPrice'] != null && 
             (product['oldPrice'] > originalPrice)) {
      hasDiscount = true;
      // تعيين السعر الأصلي
      double oldPrice = (product['oldPrice'] ?? 0).toDouble();
      // تعيين السعر بعد الخصم
      finalPrice = originalPrice;
      // حساب نسبة الخصم
      discountPercentage = ((oldPrice - finalPrice) / oldPrice) * 100;
      // تحديث السعر الأصلي لعرضه
      originalPrice = oldPrice;
    }
    // إذا لم يكن هناك خصم
    else {
      // السعر الأصلي والنهائي متساويان
      finalPrice = originalPrice;
    }
    
    return {
      'hasDiscount': hasDiscount,
      'originalPrice': originalPrice,
      'finalPrice': finalPrice,
      'discountPercentage': discountPercentage,
    };
  }
  
  // استقطاع الكمية
  void decrementQuantity() {
    if (quantity > 1) {
      quantity--;
      HapticFeedback.lightImpact();
      notifyListeners();
    }
  }
  
  // زيادة الكمية
  void incrementQuantity() {
    quantity++;
    HapticFeedback.lightImpact();
    notifyListeners();
  }
  
  // تغيير الخيار المحدد
  void selectOption(Map<String, dynamic> option) {
    _selectedOption = option;
    HapticFeedback.lightImpact();
    notifyListeners();
  }
  
  // إضافة إلى السلة
  void addToCart(BuildContext context) {
    // تأثير اهتزاز
    HapticFeedback.mediumImpact();
    
    // الحصول على معلومات الخصم
    Map<String, dynamic> discountInfo = getDiscountInfo();
    bool hasDiscount = discountInfo['hasDiscount'];
    double originalPrice = discountInfo['originalPrice'];
    double finalPrice = discountInfo['finalPrice'];
    double discountPercentage = discountInfo['discountPercentage'];
    
    // إضافة معلومات الخيار المحدد
    String optionName = '';
    if (_selectedOption != null) {
      optionName = _selectedOption!['name'] ?? '';
    }
    
    // إضافة المنتج إلى السلة مع السعر النهائي بعد الخصم
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addItem(
      product['id'],
      product['name'] ?? '',
      originalPrice,  // السعر الأصلي
      product['imageUrl'],
      quantity,
      hasDiscount: hasDiscount,
      discountPercentage: hasDiscount ? discountPercentage : null,
      discountedPrice: hasDiscount ? finalPrice : null,  // السعر النهائي بعد الخصم
      optionName: optionName.isNotEmpty ? optionName : null,  // اسم الخيار إذا كان محددًا
    );

    // إظهار رسالة للمستخدم مع حركة فريدة
    _showAddedToCartAnimation(context, finalPrice, originalPrice, hasDiscount, optionName);
  }
  
  // حركة إضافة إلى السلة
  void _showAddedToCartAnimation(
    BuildContext context,
    double finalPrice,
    double originalPrice,
    bool hasDiscount,
    String optionName,
  ) {
    // إغلاق الصفحة بحركة
    Navigator.pop(context);
    
    // إظهار رسالة مع حركة تلاشي
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تمت الإضافة إلى السلة${optionName.isNotEmpty ? ' - $optionName' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasDiscount)
                    Text(
                      'السعر: ${finalPrice.toStringAsFixed(0)} د.ع بدلاً من ${originalPrice.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.burntBrown,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'السلة',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/cart');
          },
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
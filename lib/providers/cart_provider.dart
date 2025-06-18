import 'package:flutter/material.dart';
import '../models/cart_item.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  
  String? _fcmToken;
  String? _uuid;
  String? _phoneNumber;
  
  // بيانات كوبون الخصم
  String? _couponCode;
  double _couponDiscount = 0.0; // نسبة الخصم المطبقة من الكوبون (0-100)
  String? _couponName;
  DateTime? _couponExpiryDate;
  bool _isCouponValid = false;

  List<CartItem> get items => _items;
  
  // حساب المبلغ الإجمالي مع مراعاة الخصم إن وجد (خصم المنتج + خصم الكوبون)
  double get totalAmount {
    double itemsTotal = _items.fold(0.0, (sum, item) => sum + item.totalItemPrice);
    
    // تطبيق خصم الكوبون إذا كان صالحًا
    if (_isCouponValid && _couponDiscount > 0) {
      double couponDiscountAmount = (itemsTotal * _couponDiscount / 100);
      return itemsTotal - couponDiscountAmount;
    }
    
    return itemsTotal;
  }
  
  // حساب المبلغ الإجمالي قبل الخصم
  double get originalTotalAmount => _items.fold(0.0, (sum, item) => sum + item.originalTotalPrice);
  
  // حساب إجمالي قيمة الخصم على المنتجات (بدون خصم الكوبون)
  double get itemsDiscount => _items.fold(0.0, (sum, item) => sum + item.totalDiscount);
  
  // حساب قيمة خصم الكوبون
  double get couponDiscountAmount {
    if (_isCouponValid && _couponDiscount > 0) {
      // نحسب الخصم على المبلغ بعد تطبيق خصومات المنتجات
      double itemsTotal = _items.fold(0.0, (sum, item) => sum + item.totalItemPrice);
      return itemsTotal * _couponDiscount / 100;
    }
    return 0.0;
  }
  
  // إجمالي قيمة الخصم (خصم المنتجات + خصم الكوبون)
  double get totalDiscount => itemsDiscount + couponDiscountAmount;
  
  // معلومات الكوبون
  String? get couponCode => _couponCode;
  double get couponDiscount => _couponDiscount;
  String? get couponName => _couponName;
  bool get isCouponValid => _isCouponValid;
  DateTime? get couponExpiryDate => _couponExpiryDate;

  // ✅ Getters
  String? get fcmToken => _fcmToken;
  String? get uuid => _uuid;
  String? get phoneNumber => _phoneNumber;

  // ✅ Setter لتعيين بيانات المستخدم
  void setUserInfo({
    required String fcmToken,
    required String uuid,
    required String phoneNumber,
  }) {
    _fcmToken = fcmToken;
    _uuid = uuid;
    _phoneNumber = phoneNumber;
    notifyListeners();
  }
  
  // ✅ تطبيق كوبون خصم
  bool applyCoupon({
    required String code, 
    required double discountPercentage,
    required String name,
    DateTime? expiryDate,
  }) {
    // التحقق من صلاحية الكوبون (تاريخ الانتهاء)
    if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
      _isCouponValid = false;
      return false;
    }
    
    // تعيين بيانات الكوبون
    _couponCode = code;
    _couponDiscount = discountPercentage.clamp(0, 100); // التأكد من أن النسبة بين 0 و 100
    _couponName = name;
    _couponExpiryDate = expiryDate;
    _isCouponValid = true;
    
    notifyListeners();
    return true;
  }
  
  // ✅ إلغاء كوبون الخصم
  void removeCoupon() {
    _couponCode = null;
    _couponDiscount = 0.0;
    _couponName = null;
    _couponExpiryDate = null;
    _isCouponValid = false;
    
    notifyListeners();
  }

  // ✅ إضافة منتج مع دعم الخصم وخيارات المنتج والإضافات والأطباق الجانبية
  void addItem(
    String productId, 
    String name, 
    double price, 
    String? imageUrl, 
    int quantity, {
    bool hasDiscount = false,
    double? discountPercentage,
    double? discountedPrice,
    String? optionName, // خيار المنتج
    List<String>? selectedExtras, // الإضافات المحددة
    double extrasPrice = 0.0, // سعر الإضافات
    String? extras, // نص الإضافات
    List<String>? selectedSideDishes, // الأطباق الجانبية المحددة
    double sideDishesPrice = 0.0, // سعر الأطباق الجانبية
    String? sideDishes, // نص الأطباق الجانبية
    double? totalPrice, // السعر الإجمالي المحسوب مسبقًا
  }) {
    // البحث عن المنتج في السلة
    final index = _items.indexWhere((item) {
      bool sameProduct = item.productId == productId;
      bool sameOption = item.optionName == optionName;
      
      // مقارنة الإضافات
      bool sameExtras = true;
      if ((item.selectedExtras == null && selectedExtras != null) ||
          (item.selectedExtras != null && selectedExtras == null)) {
        sameExtras = false;
      } else if (item.selectedExtras != null && selectedExtras != null) {
        if (item.selectedExtras!.length != selectedExtras.length) {
          sameExtras = false;
        } else {
          sameExtras = item.selectedExtras!.toSet().containsAll(selectedExtras.toSet());
        }
      }
      
      // مقارنة الأطباق الجانبية
      bool sameSideDishes = true;
      if ((item.selectedSideDishes == null && selectedSideDishes != null) ||
          (item.selectedSideDishes != null && selectedSideDishes == null)) {
        sameSideDishes = false;
      } else if (item.selectedSideDishes != null && selectedSideDishes != null) {
        if (item.selectedSideDishes!.length != selectedSideDishes.length) {
          sameSideDishes = false;
        } else {
          sameSideDishes = item.selectedSideDishes!.toSet().containsAll(selectedSideDishes.toSet());
        }
      }
      
      return sameProduct && sameOption && sameExtras && sameSideDishes;
    });
    
    if (index >= 0) {
      // إذا كان المنتج موجود بالفعل بنفس الخيارات والإضافات، قم بتحديث الكمية فقط
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity + quantity
      );
    } else {
      // إضافة منتج جديد مع كل المعلومات
      _items.add(CartItem(
        productId: productId,
        name: name,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
        hasDiscount: hasDiscount,
        discountPercentage: discountPercentage,
        discountedPrice: discountedPrice,
        optionName: optionName,
        selectedExtras: selectedExtras,
        extrasPrice: extrasPrice,
        extras: extras,
        selectedSideDishes: selectedSideDishes,
        sideDishesPrice: sideDishesPrice,
        sideDishes: sideDishes,
        totalPrice: totalPrice,
      ));
    }

    notifyListeners();
  }

  void removeItem(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    // إلغاء الكوبون أيضًا عند مسح السلة
    removeCoupon();
    notifyListeners();
  }

  void removeItemById(
    String productId, {
    String? optionName,
    List<String>? selectedExtras,
    List<String>? selectedSideDishes,
  }) {
    // إزالة المنتج حسب المعرف والخيارات والإضافات
    _items.removeWhere((item) {
      // تحقق من تطابق المعرف والخيار
      bool sameIdOption = item.productId == productId && item.optionName == optionName;
      
      // إذا لم نحتاج للتحقق من الإضافات أو الأطباق الجانبية
      if (selectedExtras == null && selectedSideDishes == null) {
        return sameIdOption;
      }
      
      // تحقق من تطابق الإضافات إذا تم تحديدها
      bool extrasMatch = true;
      if (selectedExtras != null) {
        if (item.selectedExtras == null) {
          extrasMatch = false;
        } else {
          extrasMatch = item.selectedExtras!.toSet().containsAll(selectedExtras.toSet()) &&
                        item.selectedExtras!.length == selectedExtras.length;
        }
      }
      
      // تحقق من تطابق الأطباق الجانبية إذا تم تحديدها
      bool sideDishesMatch = true;
      if (selectedSideDishes != null) {
        if (item.selectedSideDishes == null) {
          sideDishesMatch = false;
        } else {
          sideDishesMatch = item.selectedSideDishes!.toSet().containsAll(selectedSideDishes.toSet()) &&
                            item.selectedSideDishes!.length == selectedSideDishes.length;
        }
      }
      
      return sameIdOption && extrasMatch && sideDishesMatch;
    });
    
    notifyListeners();
  }

  void updateItemQuantity(
    String productId, 
    int newQuantity, {
    String? optionName,
    List<String>? selectedExtras,
    List<String>? selectedSideDishes,
  }) {
    // تحديث كمية المنتج بناءً على جميع معايير التطابق
    final index = _items.indexWhere((item) {
      // تحقق من تطابق المعرف والخيار
      bool sameIdOption = item.productId == productId && item.optionName == optionName;
      
      // إذا لم نحتاج للتحقق من الإضافات أو الأطباق الجانبية
      if (selectedExtras == null && selectedSideDishes == null) {
        return sameIdOption;
      }
      
      // تحقق من تطابق الإضافات إذا تم تحديدها
      bool extrasMatch = true;
      if (selectedExtras != null) {
        if (item.selectedExtras == null) {
          extrasMatch = false;
        } else {
          extrasMatch = item.selectedExtras!.toSet().containsAll(selectedExtras.toSet()) &&
                        item.selectedExtras!.length == selectedExtras.length;
        }
      }
      
      // تحقق من تطابق الأطباق الجانبية إذا تم تحديدها
      bool sideDishesMatch = true;
      if (selectedSideDishes != null) {
        if (item.selectedSideDishes == null) {
          sideDishesMatch = false;
        } else {
          sideDishesMatch = item.selectedSideDishes!.toSet().containsAll(selectedSideDishes.toSet()) &&
                            item.selectedSideDishes!.length == selectedSideDishes.length;
        }
      }
      
      return sameIdOption && extrasMatch && sideDishesMatch;
    });
    
    if (index != -1) {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
      notifyListeners();
    }
  }
  
  // ✅ حفظ السلة في التخزين المحلي
  Map<String, dynamic> toJson() {
    return {
      'items': _items.map((item) => item.toJson()).toList(),
      'couponCode': _couponCode,
      'couponDiscount': _couponDiscount,
      'couponName': _couponName,
      'couponExpiryDate': _couponExpiryDate?.toIso8601String(),
      'isCouponValid': _isCouponValid,
    };
  }
  
  // ✅ استرجاع السلة من التخزين المحلي
  void fromJson(Map<String, dynamic> json) {
    // استرجاع المنتجات
    if (json.containsKey('items') && json['items'] is List) {
      _items.clear();
      (json['items'] as List).forEach((itemJson) {
        _items.add(CartItem.fromJson(itemJson));
      });
    }
    
    // استرجاع بيانات الكوبون
    _couponCode = json['couponCode'];
    _couponDiscount = (json['couponDiscount'] ?? 0.0).toDouble();
    _couponName = json['couponName'];
    _couponExpiryDate = json['couponExpiryDate'] != null 
        ? DateTime.parse(json['couponExpiryDate']) 
        : null;
    _isCouponValid = json['isCouponValid'] ?? false;
    
    notifyListeners();
  }
  
  // ✅ بيانات للتحقق من الطلب قبل إرساله
  Map<String, dynamic> getOrderSummary() {
    return {
      'items': _items.map((item) => item.toJson()).toList(),
      'itemsCount': _items.length,
      'totalQuantity': _items.fold(0, (sum, item) => sum + item.quantity),
      'originalTotal': originalTotalAmount,
      'itemsDiscount': itemsDiscount,
      'couponApplied': _isCouponValid,
      'couponCode': _couponCode,
      'couponDiscount': couponDiscountAmount,
      'totalDiscount': totalDiscount,
      'finalTotal': totalAmount,
      'userInfo': {
        'fcmToken': _fcmToken,
        'uuid': _uuid,
        'phoneNumber': _phoneNumber,
      }
    };
  }
}
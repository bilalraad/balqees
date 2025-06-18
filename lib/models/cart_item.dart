// lib/models/cart_item.dart
class CartItem {
  final String productId;
  final String name;
  final double price; // السعر الأصلي
  final int quantity;
  final String? imageUrl;
  
  // معلومات الخصم للمنتج
  final bool hasDiscount;
  final double? discountPercentage;
  final double? discountedPrice; // السعر بعد الخصم
  
  // معلومات خيارات المنتج
  final String? optionName;
  
  // معلومات الإضافات
  final List<String>? selectedExtras;
  final double extrasPrice;
  final String? extras; // نص الإضافات المحددة
  
  // معلومات الأطباق الجانبية
  final List<String>? selectedSideDishes;
  final double sideDishesPrice;
  final String? sideDishes; // نص الأطباق الجانبية
  
  // السعر الإجمالي المحسوب مسبقًا (للمنتج والإضافات والأطباق الجانبية)
  final double totalPrice;
  
  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.hasDiscount = false,
    this.discountPercentage,
    this.discountedPrice,
    this.optionName,
    this.selectedExtras,
    this.extrasPrice = 0.0,
    this.extras,
    this.selectedSideDishes,
    this.sideDishesPrice = 0.0,
    this.sideDishes,
    double? totalPrice,
  }) : this.totalPrice = totalPrice ?? 
       (((hasDiscount && discountedPrice != null) ? discountedPrice : price) + 
        extrasPrice + sideDishesPrice);
  
  // Clone this item with some properties changed
  CartItem copyWith({
    String? productId,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    bool? hasDiscount,
    double? discountPercentage,
    double? discountedPrice,
    String? optionName,
    List<String>? selectedExtras,
    double? extrasPrice,
    String? extras,
    List<String>? selectedSideDishes,
    double? sideDishesPrice,
    String? sideDishes,
    double? totalPrice,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      hasDiscount: hasDiscount ?? this.hasDiscount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      optionName: optionName ?? this.optionName,
      selectedExtras: selectedExtras ?? this.selectedExtras,
      extrasPrice: extrasPrice ?? this.extrasPrice,
      extras: extras ?? this.extras,
      selectedSideDishes: selectedSideDishes ?? this.selectedSideDishes,
      sideDishesPrice: sideDishesPrice ?? this.sideDishesPrice,
      sideDishes: sideDishes ?? this.sideDishes,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
  
  // حساب السعر النهائي للوحدة الواحدة مع مراعاة الخصم (بدون الإضافات والأطباق الجانبية)
  double get finalUnitPrice {
    if (hasDiscount && discountedPrice != null) {
      return discountedPrice!;
    } else if (hasDiscount && discountPercentage != null) {
      return price * (1 - discountPercentage! / 100);
    }
    return price;
  }
  
  // تصحيح: السعر النهائي بعد الخصم للوحدة الواحدة
  double get finalPrice => finalUnitPrice;
  
  // إجمالي سعر الوحدة مع الإضافات والأطباق الجانبية
  double get finalUnitPriceWithExtras {
    return finalUnitPrice + extrasPrice + sideDishesPrice;
  }
  
  // إجمالي سعر المنتج بعد الخصم والإضافات والأطباق الجانبية
  double get totalItemPrice {
    return totalPrice * quantity;
  }
  
  // إجمالي سعر المنتج قبل الخصم
  double get originalTotalPrice {
    return price * quantity;
  }
  
  // إجمالي قيمة الخصم للمنتج
  double get totalDiscount {
    if (hasDiscount) {
      return (price - finalUnitPrice) * quantity;
    }
    return 0.0;
  }
  
  // تحويل البيانات إلى Map لإرسالها إلى API
  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'hasDiscount': hasDiscount,
      'discountPercentage': discountPercentage,
      'discountedPrice': discountedPrice,
      'optionName': optionName,
      'selectedExtras': selectedExtras,
      'extrasPrice': extrasPrice,
      'extras': extras,
      'selectedSideDishes': selectedSideDishes,
      'sideDishesPrice': sideDishesPrice,
      'sideDishes': sideDishes,
      'totalPrice': totalPrice,
    };
  }
  
  // إنشاء CartItem من Map
  factory CartItem.fromJson(Map<String, dynamic> json) {
    List<String>? extrasList;
    if (json['selectedExtras'] != null) {
      extrasList = List<String>.from(json['selectedExtras']);
    }
    
    List<String>? sideDishList;
    if (json['selectedSideDishes'] != null) {
      sideDishList = List<String>.from(json['selectedSideDishes']);
    }
    
    return CartItem(
      productId: json['productId'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      imageUrl: json['imageUrl'] as String?,
      hasDiscount: json['hasDiscount'] as bool? ?? false,
      discountPercentage: json['discountPercentage'] != null 
          ? (json['discountPercentage'] as num).toDouble() 
          : null,
      discountedPrice: json['discountedPrice'] != null 
          ? (json['discountedPrice'] as num).toDouble() 
          : null,
      optionName: json['optionName'] as String?,
      selectedExtras: extrasList,
      extrasPrice: json['extrasPrice'] != null 
          ? (json['extrasPrice'] as num).toDouble() 
          : 0.0,
      extras: json['extras'] as String?,
      selectedSideDishes: sideDishList,
      sideDishesPrice: json['sideDishesPrice'] != null 
          ? (json['sideDishesPrice'] as num).toDouble() 
          : 0.0,
      sideDishes: json['sideDishes'] as String?,
      totalPrice: json['totalPrice'] != null 
          ? (json['totalPrice'] as num).toDouble() 
          : null,
    );
  }
}
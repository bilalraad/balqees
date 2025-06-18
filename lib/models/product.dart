class ProductOption {
  final String name;
  final double price;

  ProductOption({
    required this.name,
    required this.price,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) => ProductOption(
    name: json['name'] ?? '',
    price: json['price'] != null ? (json['price'] as num).toDouble() : 0.0,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
  };
}

class Product {
  final String id;
  final String name;
  final String description;
  final String image;
  final double price;
  final bool hasOptions;
  final List<ProductOption> productOptions;
  final double? discountPercentage;
  final double? itemRating;
  final bool isFeatured;
  final String? categoryId;
  final String? categoryName;
  final int preparationTime;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    this.hasOptions = false,
    this.productOptions = const [],
    this.discountPercentage,
    this.itemRating,
    this.isFeatured = false,
    this.categoryId,
    this.categoryName,
    this.preparationTime = 30,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // معالجة خيارات المنتج إذا وجدت
    List<ProductOption> options = [];
    if (json['hasOptions'] == true && json['productOptions'] != null) {
      options = (json['productOptions'] as List).map((option) => 
        ProductOption.fromJson(option as Map<String, dynamic>)
      ).toList();
    }

    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['imageUrl'] ?? json['image'] ?? '',
      price: json['price'] != null ? (json['price'] as num).toDouble() : 0.0,
      hasOptions: json['hasOptions'] ?? false,
      productOptions: options,
      discountPercentage: json['discountPercentage'] != null ? 
        (json['discountPercentage'] as num).toDouble() : null,
      itemRating: json['itemRating'] != null ? 
        (json['itemRating'] as num).toDouble() : null,
      isFeatured: json['isFeatured'] ?? false,
      categoryId: json['categoryId'],
      categoryName: json['categoryName'],
      preparationTime: json['preparationTime'] != null ? 
        (json['preparationTime'] as num).toInt() : 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': image,
      'price': price,
      'hasOptions': hasOptions,
      'productOptions': productOptions.map((option) => option.toJson()).toList(),
      if (discountPercentage != null) 'discountPercentage': discountPercentage,
      if (itemRating != null) 'itemRating': itemRating,
      'isFeatured': isFeatured,
      if (categoryId != null) 'categoryId': categoryId,
      if (categoryName != null) 'categoryName': categoryName,
      'preparationTime': preparationTime,
    };
  }

  // معرفة ما إذا كان المنتج له خصم
  bool get hasDiscount => discountPercentage != null && discountPercentage! > 0;

  // الحصول على السعر بعد الخصم
  double getDiscountedPrice({ProductOption? selectedOption}) {
    double basePrice = selectedOption != null ? selectedOption.price : price;
    
    if (hasDiscount) {
      return basePrice * (1 - (discountPercentage! / 100));
    }
    return basePrice;
  }

  // نسخة من المنتج مع تحديث البيانات
  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? image,
    double? price,
    bool? hasOptions,
    List<ProductOption>? productOptions,
    double? discountPercentage,
    double? itemRating,
    bool? isFeatured,
    String? categoryId,
    String? categoryName,
    int? preparationTime,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      price: price ?? this.price,
      hasOptions: hasOptions ?? this.hasOptions,
      productOptions: productOptions ?? this.productOptions,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      itemRating: itemRating ?? this.itemRating,
      isFeatured: isFeatured ?? this.isFeatured,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      preparationTime: preparationTime ?? this.preparationTime,
    );
  }
}
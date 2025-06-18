import 'package:balqees/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:balqees/providers/cart_provider.dart';
import 'package:flutter/services.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final String heroTag;

  const ProductDetailPage({
    super.key, 
    required this.product,
    required this.heroTag,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> with SingleTickerProviderStateMixin {
  int quantity = 1;
  bool _showDetails = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // إضافة متغير لتخزين الخيار المختار
  Map<String, dynamic>? _selectedOption;
  
  // إضافة متغيرات للإضافات
  final List<Map<String, dynamic>> _selectedExtras = [];
  
  // إضافة متغيرات للأطباق الجانبية
  final List<Map<String, dynamic>> _selectedSideDishes = [];
  
  @override
  void initState() {
    super.initState();
    // تعريف متحكم الحركات
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // حركة الظهور من أسفل الشاشة
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // حركة التلاشي
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // تأخير قصير قبل بدء الحركة
    Future.delayed(const Duration(milliseconds: 200), () {
      _animationController.forward();
      setState(() {
        _showDetails = true;
      });
    });
    
    // تعيين الخيار الافتراضي إذا كان المنتج يحتوي على خيارات
    _initializeProductOptions();
    
    // تهيئة الإضافات إذا كان المنتج يحتوي على إضافات
    _initializeProductExtras();
    
    // تهيئة الأطباق الجانبية إذا كان المنتج يحتوي على أطباق جانبية
    _initializeProductSideDishes();
  }
  
  // تهيئة خيارات المنتج
  void _initializeProductOptions() {
    if (_hasProductOptions()) {
      // تحقق من وجود خيارات للمنتج واختر الخيار الأول كافتراضي
      final options = _getProductOptions();
      if (options.isNotEmpty) {
        setState(() {
          _selectedOption = options.first;
        });
      }
    }
  }
  
  // تهيئة إضافات المنتج
  void _initializeProductExtras() {
    if (_hasProductExtras()) {
      // تهيئة الإضافات المحددة (فارغة بشكل افتراضي، المستخدم يختار لاحقًا)
      _selectedExtras.clear();
      // يمكن تعبئة بعض الإضافات الافتراضية إذا لزم الأمر
    }
  }
  
  // تهيئة الأطباق الجانبية للمنتج
  void _initializeProductSideDishes() {
    if (_hasProductSideDishes()) {
      // تحقق من وجود أطباق جانبية واضف الأطباق الإلزامية تلقائيًا
      final sideDishes = _getProductSideDishes();
      
      // إضافة الأطباق الإلزامية فقط تلقائيًا
      for (var dish in sideDishes) {
        if (dish['isRequired'] == true) {
          _selectedSideDishes.add(dish);
        }
      }
    }
  }
  
  // التحقق من وجود خيارات للمنتج
  bool _hasProductOptions() {
    return widget.product['hasOptions'] == true && 
           widget.product['productOptions'] != null &&
           (widget.product['productOptions'] as List).isNotEmpty;
  }
  
  // التحقق من وجود إضافات للمنتج
  bool _hasProductExtras() {
    return widget.product['hasExtras'] == true && 
           widget.product['productExtras'] != null &&
           (widget.product['productExtras'] as List).isNotEmpty;
  }
  
  // التحقق من وجود أطباق جانبية للمنتج
  bool _hasProductSideDishes() {
    return widget.product['hasSideDishes'] == true && 
           widget.product['productSideDishes'] != null &&
           (widget.product['productSideDishes'] as List).isNotEmpty;
  }
  
  // الحصول على قائمة خيارات المنتج
  List<Map<String, dynamic>> _getProductOptions() {
    if (!_hasProductOptions()) {
      return [];
    }
    
    // تحويل البيانات من Firestore إلى قائمة من الخرائط
    List<dynamic> rawOptions = widget.product['productOptions'];
    return rawOptions.map((option) => option as Map<String, dynamic>).toList();
  }
  
  // الحصول على قائمة إضافات المنتج
  List<Map<String, dynamic>> _getProductExtras() {
    if (!_hasProductExtras()) {
      return [];
    }
    
    // تحويل البيانات من Firestore إلى قائمة من الخرائط
    List<dynamic> rawExtras = widget.product['productExtras'];
    return rawExtras.map((extra) => extra as Map<String, dynamic>).toList();
  }
  
  // الحصول على قائمة الأطباق الجانبية للمنتج
  List<Map<String, dynamic>> _getProductSideDishes() {
    if (!_hasProductSideDishes()) {
      return [];
    }
    
    // تحويل البيانات من Firestore إلى قائمة من الخرائط
    List<dynamic> rawSideDishes = widget.product['productSideDishes'];
    return rawSideDishes.map((dish) => dish as Map<String, dynamic>).toList();
  }
  
  // الحصول على معلومات المكونات
  List<String> _getIngredients() {
    if (widget.product['ingredients'] == null) {
      return [];
    }
    
    List<dynamic> rawIngredients = widget.product['ingredients'];
    return rawIngredients.map((ingredient) => ingredient.toString()).toList();
  }
  
  // الحصول على وقت التحضير
  String _getPreparationTime() {
    if (widget.product['preparationTime'] == null) {
      return "غير محدد";
    }
    
    int minutes = widget.product['preparationTime'];
    if (minutes < 60) {
      return "$minutes دقيقة";
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return "$hours ساعة";
      } else {
        return "$hours ساعة و $remainingMinutes دقيقة";
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // التحقق من وجود خصم واستخراج معلومات الخصم
  Map<String, dynamic> _getDiscountInfo() {
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
      originalPrice = (widget.product['price'] ?? 0).toDouble();
    }
    
    // التحقق من وجود discountPercentage في Firestore
    if (widget.product['discountPercentage'] != null) {
      hasDiscount = true;
      // استخراج نسبة الخصم - تأكد من تحويلها إلى double إذا كانت نصية
      discountPercentage = double.tryParse(
        widget.product['discountPercentage'].toString().replaceAll('%', '')
      ) ?? 0.0;
      
      // حساب السعر النهائي بعد الخصم
      finalPrice = originalPrice * (1 - (discountPercentage / 100));
    }
    // أو التحقق من وجود oldPrice
    else if (widget.product['oldPrice'] != null && 
             (widget.product['oldPrice'] > originalPrice)) {
      hasDiscount = true;
      // تعيين السعر الأصلي
      double oldPrice = (widget.product['oldPrice'] ?? 0).toDouble();
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
  
  // حساب سعر الإضافات المختارة
  double _calculateExtrasPrice() {
    double extrasPrice = 0.0;
    
    for (var extra in _selectedExtras) {
      double extraPrice = (extra['price'] ?? 0).toDouble();
      extrasPrice += extraPrice;
    }
    
    return extrasPrice;
  }
  
  // حساب سعر الأطباق الجانبية المختارة
  double _calculateSideDishesPrice() {
    double sideDishesPrice = 0.0;
    
    for (var dish in _selectedSideDishes) {
      double dishPrice = (dish['price'] ?? 0).toDouble();
      sideDishesPrice += dishPrice;
    }
    
    return sideDishesPrice;
  }
  
  // حساب السعر الإجمالي
  double _calculateTotalPrice() {
    // الحصول على معلومات الخصم
    Map<String, dynamic> discountInfo = _getDiscountInfo();
    double finalProductPrice = discountInfo['finalPrice']; // السعر بعد الخصم
    
    // إضافة سعر الإضافات والأطباق الجانبية
    double extrasPrice = _calculateExtrasPrice();
    double sideDishesPrice = _calculateSideDishesPrice();
    
    // حساب السعر الإجمالي: سعر المنتج الأساسي + الإضافات + الأطباق الجانبية
    double totalPrice = finalProductPrice + extrasPrice + sideDishesPrice;
    
    // ضرب الإجمالي بالكمية
    return totalPrice * quantity;
  }
  
  // استقطاع الكمية
  void _decrementQuantity() {
    if (quantity > 1) {
      setState(() {
        quantity--;
      });
      HapticFeedback.lightImpact();
    }
  }
  
  // زيادة الكمية
  void _incrementQuantity() {
    setState(() {
      quantity++;
    });
    HapticFeedback.lightImpact();
  }
  
  // تغيير الخيار المحدد
  void _selectOption(Map<String, dynamic> option) {
    setState(() {
      _selectedOption = option;
    });
    HapticFeedback.lightImpact();
  }
  
  // إضافة أو إزالة إضافة من القائمة
  void _toggleExtra(Map<String, dynamic> extra) {
    setState(() {
      // البحث عن الإضافة في القائمة
      final index = _selectedExtras.indexWhere((e) => e['name'] == extra['name']);
      
      // إذا كانت موجودة، قم بإزالتها. وإلا، أضفها
      if (index >= 0) {
        _selectedExtras.removeAt(index);
      } else {
        _selectedExtras.add(extra);
      }
    });
    HapticFeedback.lightImpact();
  }
  
  // التحقق مما إذا كانت الإضافة محددة
  bool _isExtraSelected(String extraName) {
    return _selectedExtras.any((e) => e['name'] == extraName);
  }
  
  // إضافة أو إزالة طبق جانبي من القائمة
  
  
  // التحقق مما إذا كان الطبق الجانبي محددًا
  bool _isSideDishSelected(String productId) {
    return _selectedSideDishes.any((d) => d['productId'] == productId);
  }
  
  // إضافة إلى السلة مع تأثيرات
  void _addToCart() {
    // تأثير اهتزاز
    HapticFeedback.mediumImpact();
    
    // الحصول على معلومات الخصم
    Map<String, dynamic> discountInfo = _getDiscountInfo();
    bool hasDiscount = discountInfo['hasDiscount'];
    double originalPrice = discountInfo['originalPrice'];
    double finalPrice = discountInfo['finalPrice'];
    double discountPercentage = discountInfo['discountPercentage'];
    
    // إضافة معلومات الخيار المحدد
    String optionName = '';
    if (_selectedOption != null) {
      optionName = _selectedOption!['name'] ?? '';
    }
    
    // قائمة الإضافات المحددة كنص
    List<String> extrasNames = _selectedExtras.map((e) => e['name']?.toString() ?? '').toList();
    String extrasString = extrasNames.isEmpty ? '' : extrasNames.join('، ');
    
    // قائمة الأطباق الجانبية المحددة
    List<String> sideDishNames = _selectedSideDishes.map((d) => d['name']?.toString() ?? '').toList();
    String sideDishString = sideDishNames.isEmpty ? '' : sideDishNames.join('، ');
    
    // حساب السعر الإجمالي
    double totalItemPrice = _calculateTotalPrice() / quantity; // سعر القطعة الواحدة
    
    // إضافة المنتج إلى السلة مع السعر النهائي بعد الخصم
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addItem(
      widget.product['id'],
      widget.product['name'] ?? '',
      originalPrice,  // السعر الأصلي
      widget.product['imageUrl'],
      quantity,
      hasDiscount: hasDiscount,
      discountPercentage: hasDiscount ? discountPercentage : null,
      discountedPrice: hasDiscount ? finalPrice : null,  // السعر النهائي بعد الخصم
      optionName: optionName.isNotEmpty ? optionName : null,  // اسم الخيار إذا كان محددًا
      extras: extrasString.isNotEmpty ? extrasString : null,  // الإضافات المحددة
      sideDishes: sideDishString.isNotEmpty ? sideDishString : null,  // الأطباق الجانبية المحددة
      totalPrice: totalItemPrice, // السعر الإجمالي للقطعة مع الإضافات
    );

    // إظهار رسالة للمستخدم مع حركة فريدة
    _showAddedToCartAnimation(totalItemPrice, originalPrice, hasDiscount, optionName);
  }
  
  // حركة إضافة إلى السلة
  void _showAddedToCartAnimation(double finalPrice, double originalPrice, bool hasDiscount, String optionName) {
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
                  if (_selectedExtras.isNotEmpty)
                    Text(
                      'مع إضافات: ${_selectedExtras.map((e) => e['name']).join('، ')}',
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
  
  // إنشاء قسم عرض الإضافات
  Widget _buildExtrasSection() {
    final productExtras = _getProductExtras();
    
    if (productExtras.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const Text(
                'الإضافات:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: productExtras.map((extra) {
            final isSelected = _isExtraSelected(extra['name']);
            final hasPrice = extra['price'] != null && extra['price'] > 0;
            
            return GestureDetector(
              onTap: () => _toggleExtra(extra),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.burntBrown.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.burntBrown : Colors.grey[300]!,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(2),
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          color: AppColors.burntBrown,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    Text(
                      extra['name'] ?? '',
                      style: TextStyle(
                        color: isSelected ? AppColors.burntBrown : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (hasPrice) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(+${extra['price'].toStringAsFixed(0)} د.ع)',
                        style: TextStyle(
                          color: isSelected ? AppColors.burntBrown : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  // إنشاء قسم عرض الأطباق الجانبية
  
  // عرض قسم المكونات
  Widget _buildIngredientsSection() {
    final ingredients = _getIngredients();
    
    if (ingredients.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Row(
            children: [
              const Text(
                'المكونات',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: ingredients.map((ingredient) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.burntBrown,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ingredient,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  // عرض قسم وقت التحضير والتقييم
  Widget _buildPreparationAndRatingSection() {
    final preparationTime = _getPreparationTime();
    final rating = widget.product['itemRating'] ?? 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          // وقت التحضير
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: AppColors.burntBrown,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'وقت التحضير',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        preparationTime,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 10),
          
          // التقييم
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD700),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'التقييم',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            ' / 5',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // حساب أبعاد الشاشة
    final screenSize = MediaQuery.of(context).size;
    
    // الحصول على معلومات الخصم
    Map<String, dynamic> discountInfo = _getDiscountInfo();
    bool hasDiscount = discountInfo['hasDiscount'];
    double originalPrice = discountInfo['originalPrice'];
    double finalPrice = discountInfo['finalPrice'];
    double discountPercentage = discountInfo['discountPercentage'];
    
    // الحصول على خيارات المنتج
    final productOptions = _getProductOptions();
    final hasOptions = _hasProductOptions();
    
    // الحصول على إضافات المنتج
    final hasExtras = _hasProductExtras();
    
    // الحصول على الأطباق الجانبية
    
    // حساب السعر الإجمالي
    final totalPrice = _calculateTotalPrice();
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar 
          SliverAppBar(
            expandedHeight: screenSize.height * 0.45,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: AnimatedOpacity(
              opacity: _showDetails ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              if (_showDetails)
                AnimatedOpacity(
                  opacity: _showDetails ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // صورة المنتج
                  Hero(
                    tag: widget.heroTag,
                    child: widget.product['imageUrl'] != null
                      ? CachedNetworkImage(
                          imageUrl: widget.product['imageUrl'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(color: AppColors.burntBrown),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image, size: 50, color: Colors.grey),
                          ),
                        ),
                  ),
                  // تدرج لتحسين مظهر النص
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // شارة الخصم
                  if (hasDiscount)
                    Positioned(
                      top: 50,
                      right: 20,
                      child: AnimatedOpacity(
                        opacity: _showDetails ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 800),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.discount_outlined, 
                                color: Colors.white, 
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'خصم ${discountPercentage.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // شارة المميز
                  if (widget.product['isFeatured'] == true)
                    Positioned(
                      top: 50,
                      left: 20,
                      child: AnimatedOpacity(
                        opacity: _showDetails ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 800),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.burntBrown,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.burntBrown.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star, 
                                color: Colors.white, 
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'مميز',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // محتوى المنتج مع تأثيرات
          SliverToBoxAdapter(
            child: AnimatedSlide(
              offset: _showDetails ? Offset.zero : const Offset(0, 0.2),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showDetails ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // فئة المنتج
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.burntBrown.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          widget.product['categoryName'] ?? '',
                          style: const TextStyle(
                            color: AppColors.burntBrown,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      
                      // اسم المنتج
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          widget.product['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      // عرض وقت التحضير والتقييم
                      _buildPreparationAndRatingSection(),
                      
                      // قسم خيارات المنتج (مثل حجم الدجاجة: كاملة، نصف، ربع)
                      if (hasOptions) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    const Text(
                                      'الخيارات المتاحة:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.grey[300],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: productOptions.map((option) {
                                    final isSelected = _selectedOption != null && 
                                                      _selectedOption!['name'] == option['name'];
                                    return GestureDetector(
                                      onTap: () => _selectOption(option),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.only(right: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.burntBrown : Colors.white,
                                          borderRadius: BorderRadius.circular(15),
                                          border: Border.all(
                                            color: isSelected ? AppColors.burntBrown : Colors.grey[300]!,
                                            width: 1.5,
                                          ),
                                          boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.burntBrown.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : [],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              option['name'] ?? '',
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.black,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${(option['price'] ?? 0).toStringAsFixed(0)} د.ع',
                                              style: TextStyle(
                                                color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey[700],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // قسم الإضافات
                      if (hasExtras)
                        _buildExtrasSection(),
                      
                      // قسم الأطباق الجانبية
                      
                      // قسم السعر مع تأثيرات - استخدام finalPrice (السعر بعد الخصم)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasDiscount ? 'السعر بعد الخصم:' : 'السعر:',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      '${finalPrice.toStringAsFixed(0)} د.ع', // السعر بعد الخصم
                                      style: TextStyle(
                                        color: hasDiscount ? Colors.red : AppColors.burntBrown,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (hasDiscount) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '${originalPrice.toStringAsFixed(0)} د.ع',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (_selectedOption != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    'الخيار المحدد: ${_selectedOption!['name']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const Spacer(),
                            if (hasDiscount)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  'توفير ${((originalPrice - finalPrice) * quantity).toStringAsFixed(0)} د.ع',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // محدد الكمية
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          children: [
                            const Text(
                              'الكمية:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.burntBrown.withOpacity(0.1),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // زر النقصان
                                  InkWell(
                                    onTap: _decrementQuantity,
                                    borderRadius: BorderRadius.circular(15),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: quantity > 1 ? AppColors.burntBrown : Colors.grey[300],
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(15)),
                                      ),
                                      child: const Icon(
                                        Icons.remove,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  
                                  // عرض الكمية
                                  Container(
                                    width: 50,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return ScaleTransition(scale: animation, child: child);
                                      },
                                      child: Text(
                                        quantity.toString(),
                                        key: ValueKey<int>(quantity),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // زر الزيادة
                                  InkWell(
                                    onTap: _incrementQuantity,
                                    borderRadius: BorderRadius.circular(15),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        color: AppColors.burntBrown,
                                        borderRadius: BorderRadius.horizontal(left: Radius.circular(15)),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // السعر الإجمالي - استخدام finalPrice (السعر بعد الخصم)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.burntBrown.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'المجموع:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.5),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: Text(
                                '${totalPrice.toStringAsFixed(0)} د.ع', // السعر الإجمالي بعد إضافة كل المكونات
                                key: ValueKey<int>(quantity),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: hasDiscount ? Colors.red : AppColors.burntBrown,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // قسم المكونات
                      _buildIngredientsSection(),
                      
                      // وصف المنتج
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 10),
                        child: Row(
                          children: [
                            const Text(
                              'الوصف',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.grey[300],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.product['description'] ?? 'لا يوجد وصف متوفر لهذا المنتج.',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 100), // مساحة للزر السفلي
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      
      // زر إضافة إلى السلة
      bottomNavigationBar: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burntBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 3,
                  shadowColor: AppColors.burntBrown.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart),
                    const SizedBox(width: 10),
                    // نص الزر يعرض السعر النهائي بعد الخصم والخيار المحدد
                    Text(
                      _selectedOption != null
                        ? 'أضف ${_selectedOption!['name']} للسلة - ${totalPrice.toStringAsFixed(0)} د.ع'
                        : 'أضف للسلة - ${totalPrice.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
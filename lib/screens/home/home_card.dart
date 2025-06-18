import 'package:balqees/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:balqees/screens/product/main.dart';
import 'home_core.dart';

class HomeCard {
  // Widget لتحميل الصور المخزنة مؤقتًا مع تحسينات anti-aliasing
  static Widget buildCachedImage(
    String? imageUrl, {
    double? height,
    double? width,
    BoxFit fit = BoxFit.cover,
    Widget? alternativeIcon,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10), // تدوير حواف الحاوية
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9), // قليلاً أصغر من border الخارجي
        child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              height: height,
              width: width,
              fit: fit,
              filterQuality: FilterQuality.medium, // تحسين anti-aliasing
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: AppColors.burntBrown, strokeWidth: 2),
              ),
              errorWidget: (context, url, error) => alternativeIcon ??
                Container(
                  height: height,
                  width: width,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
            )
          : Container(
              height: height,
              width: width,
              color: Colors.grey[200],
              child: alternativeIcon ?? const Center(child: Icon(Icons.image, color: Colors.grey)),
            ),
      ),
    );
  }

  static Widget buildProductCard(
    BuildContext context,
    Map<String, dynamic> item,
    HomeCore core, {
    bool isFeatured = false,
    int index = -1,
    required VoidCallback onAddToCart,
  }) {
    // التأكد من وجود معرف للمنتج
    if (item['id'] == null || item['id'].toString().isEmpty) {
      print('Warning: Product with no ID at index $index');
      item['id'] = 'product_$index';
    }
    
    // التعامل مع الخصم - استخدام discountPercentage الجديد إذا كان موجودًا
    bool hasDiscount = item['discountPercentage'] != null && item['discountPercentage'] > 0;
    int originalPrice = (item['price'] ?? 0) as int;
    int? discountPercentage = item['discountPercentage'] as int?;
    
    // حساب السعر القديم (قبل الخصم) والسعر الحالي (بعد الخصم)
    int oldPrice = 0;
    int currentPrice = originalPrice;
    
    if (hasDiscount && discountPercentage != null && discountPercentage > 0) {
      oldPrice = originalPrice;
      currentPrice = (originalPrice * (100 - discountPercentage) / 100).round();
    } else {
      currentPrice = originalPrice;
      if (item['oldPrice'] != null) {
        oldPrice = (item['oldPrice'] ?? 0) as int;
        hasDiscount = true;
      }
    }
    
    // ignore: unused_local_variable
    bool isInCart = core.cartItems.containsKey(item['id']);
    
    // الحصول على تقييم المنتج
    double itemRating = 0;
    if (item['itemRating'] != null) {
      itemRating = (item['itemRating'] is int) 
          ? (item['itemRating'] as int).toDouble() 
          : (item['itemRating'] as double);
    }
    
    String heroTag = 'product_${item['id']}';
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // الحصول على العرض والتكيف مع حجم الشاشة
        final cardWidth = constraints.maxWidth;
        
        // استخدام MediaQuery للتحقق من حجم الشاشة
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 600;
        
        // تعديل المقاييس بناءً على حجم الشاشة
        final double baseIconSize = isSmallScreen ? 0.07 : 0.05;
        final double baseFontSize = isSmallScreen ? 0.06 : 0.045;
        final double titleFontSize = isSmallScreen ? 0.07 : 0.055;
        final double priceFontSize = isSmallScreen ? 0.07 : 0.055;
        final double buttonTextSize = isSmallScreen ? 0.07 : 0.055;
        
        // حساب نسبة الارتفاع للصورة
        // ignore: unused_local_variable
        final double imageRatio = 1.0; // نسبة ارتفاع الصورة إلى عرضها (مربع)
        
        // حساب الحشوات بناءً على حجم الشاشة
        final horizontalPadding = cardWidth * (isSmallScreen ? 0.04 : 0.03);
        final verticalPadding = cardWidth * (isSmallScreen ? 0.03 : 0.02);
        
        // لا نعتمد على ارتفاعات ثابتة للأقسام، بل نترك المحتوى يحدد الارتفاع
        return Hero(
          tag: heroTag,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (_, __, ___) => ProductDetailPage(
                      product: item,
                      heroTag: heroTag,
                    ),
                    transitionsBuilder: (_, animation, __, child) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: cardWidth,
                // استخدام IntrinsicHeight لضمان أن ارتفاع البطاقة يتكيف تلقائيًا مع المحتوى
                child: AspectRatio(
                  aspectRatio: isSmallScreen ? 0.6 : 0.7, // نسبة ارتفاع إلى عرض البطاقة بالكامل (أطول على الأجهزة الصغيرة)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // قسم الصورة مع البادجات - يأخذ مساحة نسبية من البطاقة
                      Expanded(
                        flex: 5, // نسبة الصورة من البطاقة
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            color: Colors.grey[200],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // صورة المنتج
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: item['imageUrl'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: item['imageUrl'],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      filterQuality: FilterQuality.medium,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.burntBrown,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                                    ),
                              ),

                              // البادجات (خصم / مميز)
                              Positioned(
                                bottom: 6,
                                left: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasDiscount)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 3),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: cardWidth * 0.02,
                                          vertical: cardWidth * 0.005,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.burntBrown,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          discountPercentage != null ? 'خصم $discountPercentage%' : 'خصم',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: cardWidth * baseFontSize,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (isFeatured)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: cardWidth * 0.02,
                                          vertical: cardWidth * 0.005,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'مميز',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: cardWidth * baseFontSize,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // التقييم
                              if (itemRating > 0)
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: cardWidth * 0.02,
                                      vertical: cardWidth * 0.005,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: cardWidth * baseIconSize,
                                        ),
                                        SizedBox(width: cardWidth * 0.01),
                                        Text(
                                          itemRating.toStringAsFixed(1),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: cardWidth * baseFontSize,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // قسم معلومات المنتج (الاسم والسعر)
                      Expanded(
                        flex: 3, // نسبة معلومات المنتج من البطاقة
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: verticalPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // اسم المنتج
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    item['name'] ?? '',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: cardWidth * titleFontSize,
                                      height: 1.1,
                                    ),
                                    textAlign: TextAlign.right,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              
                              // قسم السعر - تكييف مع حجم الشاشة
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          hasDiscount
                                              ? '$currentPrice د.ع'
                                              : '$originalPrice د.ع',
                                          style: TextStyle(
                                            color: Color.fromARGB(255, 0, 0, 0),
                                            fontSize: cardWidth * priceFontSize,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (hasDiscount) ...[
                                          SizedBox(width: cardWidth * 0.01),
                                          Text(
                                            '$oldPrice د.ع',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: cardWidth * (priceFontSize - 0.01),
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // زر الإضافة للسلة - استخدام Expanded مع flex للتحكم في النسبة
                      Expanded(
                        flex: 2, // نسبة زر الإضافة للسلة من البطاقة
                        child: Container(
                          decoration: const BoxDecoration(
                            color: AppColors.burntBrown,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                core.addToCart(context, item, (fn) {});
                                onAddToCart();
                              },
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_shopping_cart_outlined,
                                        color: Colors.white,
                                        size: cardWidth * baseIconSize * 1.3,
                                      ),
                                      SizedBox(width: cardWidth * 0.02),
                                      Text(
                                        'أضف للسلة',
                                        style: TextStyle(
                                          fontSize: cardWidth * buttonTextSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}
import 'package:balqees/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:balqees/utils/colors.dart';
import 'logic.dart'; // استيراد ملف المنطق

class ProductDetailPageUI extends StatelessWidget {
  final Map<String, dynamic> product;
  final String heroTag;

  const ProductDetailPageUI({
    super.key,
    required this.product,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    // الحصول على نموذج المنطق من Provider
    final logic = Provider.of<ProductDetailLogic>(context);
    final screenSize = MediaQuery.of(context).size;

    // استخراج معلومات الخصم
    final discountInfo = logic.getDiscountInfo();
    final hasDiscount = discountInfo['hasDiscount'];
    final originalPrice = discountInfo['originalPrice'];
    final finalPrice = discountInfo['finalPrice'];
    final discountPercentage = discountInfo['discountPercentage'];

    // التحقق من وجود خيارات المنتج
    final hasOptions = logic.hasProductOptions();
    final productOptions = logic.getProductOptions();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          _buildAppBar(
              context, screenSize, logic, hasDiscount, discountPercentage),

          // محتوى المنتج
          _buildProductContent(context, logic, hasOptions, productOptions,
              hasDiscount, originalPrice, finalPrice, discountPercentage),
        ],
      ),

      // زر إضافة إلى السلة
      bottomNavigationBar: _buildAddToCartButton(context, logic, finalPrice),
    );
  }

  // بناء شريط التطبيق مع صورة المنتج
  Widget _buildAppBar(
    BuildContext context,
    Size screenSize,
    ProductDetailLogic logic,
    bool hasDiscount,
    double discountPercentage,
  ) {
    return SliverAppBar(
      expandedHeight: screenSize.height * 0.45,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: AnimatedOpacity(
        opacity: logic.showDetails ? 1.0 : 0.0,
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
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // صورة المنتج
            Hero(
              tag: heroTag,
              child: product['imageUrl'] != null
                  ? CachedNetworkImage(
                      imageUrl: product['imageUrl'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.burntBrown,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.grey,
                        ),
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
                  opacity: logic.showDetails ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
          ],
        ),
      ),
    );
  }

  // بناء محتوى المنتج
  Widget _buildProductContent(
    BuildContext context,
    ProductDetailLogic logic,
    bool hasOptions,
    List<Map<String, dynamic>> productOptions,
    bool hasDiscount,
    double originalPrice,
    double finalPrice,
    double discountPercentage,
  ) {
    return SliverToBoxAdapter(
      child: AnimatedSlide(
        offset: logic.showDetails ? Offset.zero : const Offset(0, 0.2),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: logic.showDetails ? 1.0 : 0.0,
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
                _buildCategoryBadge(),

                // اسم المنتج
                _buildProductName(),

                // خيارات المنتج
                if (hasOptions) _buildProductOptions(logic, productOptions),

                // قسم السعر
                _buildPriceSection(
                  logic,
                  hasDiscount,
                  originalPrice,
                  finalPrice,
                ),

                // محدد الكمية
                _buildQuantitySelector(logic),

                // إجمالي السعر
                _buildTotalPrice(
                  logic,
                  hasDiscount,
                  finalPrice,
                ),

                // وصف المنتج
                _buildProductDescription(),

                const SizedBox(height: 100), // مساحة للزر السفلي
              ],
            ),
          ),
        ),
      ),
    );
  }

  // شارة فئة المنتج
  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.burntBrown.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        product['categoryName'] ?? '',
        style: const TextStyle(
          color: AppColors.burntBrown,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  // اسم المنتج
  Widget _buildProductName() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        product['name'] ?? '',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // خيارات المنتج
  Widget _buildProductOptions(
    ProductDetailLogic logic,
    List<Map<String, dynamic>> productOptions,
  ) {
    return Padding(
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
                final isSelected = logic.selectedOption != null &&
                    logic.selectedOption!['name'] == option['name'];
                return GestureDetector(
                  onTap: () => logic.selectOption(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.burntBrown : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.burntBrown
                            : Colors.grey[300]!,
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
                            color: isSelected
                                ? Colors.white.withOpacity(0.9)
                                : Colors.grey[700],
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
    );
  }

  // قسم السعر
  Widget _buildPriceSection(
    ProductDetailLogic logic,
    bool hasDiscount,
    double originalPrice,
    double finalPrice,
  ) {
    return Container(
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
                    '${finalPrice.toStringAsFixed(0)} د.ع',
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
              if (logic.selectedOption != null) ...[
                const SizedBox(height: 5),
                Text(
                  'الخيار المحدد: ${logic.selectedOption!['name']}',
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
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'توفير ${((originalPrice - finalPrice) * logic.quantity).toStringAsFixed(0)} د.ع',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // محدد الكمية
  Widget _buildQuantitySelector(ProductDetailLogic logic) {
    return Padding(
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
                  onTap: logic.decrementQuantity,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: logic.quantity > 1
                          ? AppColors.burntBrown
                          : Colors.grey[300],
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(15),
                      ),
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
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Text(
                      logic.quantity.toString(),
                      key: ValueKey<int>(logic.quantity),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // زر الزيادة
                InkWell(
                  onTap: logic.incrementQuantity,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.burntBrown,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(15),
                      ),
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
    );
  }

  // إجمالي السعر
  Widget _buildTotalPrice(
    ProductDetailLogic logic,
    bool hasDiscount,
    double finalPrice,
  ) {
    return Container(
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
              '${(finalPrice * logic.quantity).toStringAsFixed(0)} د.ع',
              key: ValueKey<int>(logic.quantity),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: hasDiscount ? Colors.red : AppColors.burntBrown,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // وصف المنتج
  Widget _buildProductDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            product['description'] ?? 'لا يوجد وصف متوفر لهذا المنتج.',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // زر إضافة إلى السلة
  Widget _buildAddToCartButton(
    BuildContext context,
    ProductDetailLogic logic,
    double finalPrice,
  ) {
    return SlideTransition(
      position: logic.slideAnimation,
      child: FadeTransition(
        opacity: logic.fadeAnimation,
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
              onPressed: () {
                if (!context.read<AuthProvider>().isLoggedIn) {
                  Navigator.pushNamed(context, '/login');
                  return;
                }
                logic.addToCart(context);
              },
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
                  Text(
                    logic.selectedOption != null
                        ? 'أضف ${logic.selectedOption!['name']} للسلة - ${(finalPrice * logic.quantity).toStringAsFixed(0)} د.ع'
                        : 'أضف للسلة - ${(finalPrice * logic.quantity).toStringAsFixed(0)} د.ع',
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
    );
  }
}

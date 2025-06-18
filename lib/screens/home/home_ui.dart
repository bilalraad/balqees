import 'package:balqees/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/bottom.dart';
import '../../providers/cart_provider.dart';
import 'home_core.dart';
import 'home_card.dart';
import 'home_cart.dart';

class HomeUI extends StatefulWidget {
  final HomeCore core;
  const HomeUI({super.key, required this.core});

  @override
  State<HomeUI> createState() => _HomeUIState();
}

class _HomeUIState extends State<HomeUI> with SingleTickerProviderStateMixin {
  late AnimationController _cartAnimationController;
  late Animation<double> _cartAnimation;
  final GlobalKey _cartIconKey = GlobalKey();
  HomeCore get _core => widget.core;

  // Keeps track of filtered products by category
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isFilteringProducts = false;

  @override
  void initState() {
    super.initState();
    _core.fetchData((fn) {
      if (mounted) setState(fn);
      // Initialize filtered products to show all products initially
      _filteredProducts = _core.products;
    });
    
    _cartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _cartAnimation = CurvedAnimation(
      parent: _cartAnimationController,
      curve: Curves.easeInOut,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _core.getCartIconPosition(_cartIconKey);
      _core.setupBannerTimer((fn) {
        if (mounted) setState(fn);
      });
      _core.fetchBanners((fn) {
        if (mounted) setState(fn);
      });
    });
  }

  @override
  void dispose() {
    _cartAnimationController.dispose();
    super.dispose();
  }

  // Improved filtering function for products by category
  void _filterProductsByCategory(String categoryName) {
    setState(() {
      _isFilteringProducts = true;
    });

    // Update the selected category in core
    _core.selectedCategory = categoryName;

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        if (categoryName == 'الكل') {
          // Show all products when "All" is selected
          _filteredProducts = _core.products;
        } else {
          // Filter products by the selected category
          _filteredProducts = _core.products
              .where((product) => 
                  product['category'] == categoryName || 
                  product['categoryId'] == getCategoryIdByName(categoryName))
              .toList();
        }
        _isFilteringProducts = false;
      });
    });
  }

  // Helper method to get category ID by name
  String getCategoryIdByName(String categoryName) {
    for (var category in _core.categories) {
      if (category['name'] == categoryName) {
        return category['id'] ?? '';
      }
    }
    return '';
  }

  // Category card with improved transitions
  Widget _buildCategoryCard(Map<String, dynamic> category, int index, bool isAllCategory) {
  final String categoryName = isAllCategory ? 'الكل' : (category['name'] ?? '');
  final bool isSelected = _core.selectedCategory == categoryName;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    width: 70, // Reduced from 80
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), // Slightly smaller margin
    child: GestureDetector(
      onTap: () {
        _filterProductsByCategory(categoryName);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(1), // Reduced padding
            decoration: BoxDecoration(
              color: isSelected ? AppColors.burntBrown : Colors.white,
              borderRadius: BorderRadius.circular(12), // Slightly tighter corners
              boxShadow: [
                BoxShadow(
                  color: isSelected 
                      ? AppColors.burntBrown.withOpacity(0.3)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                  spreadRadius: isSelected ? 1.5 : 0,
                ),
              ],
            ),
            child: isAllCategory
                ? Icon(
                    Icons.apps,
                    color: isSelected ? Colors.white : Colors.grey,
                    size: 60, // Smaller icon
                  )
                : (category['imageUrl'] != null 
                    ? Hero(
                        tag: 'category_${category['id'] ?? 'cat_$index'}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: category['imageUrl'],
                            height: 60, // Smaller image
                            width: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.burntBrown,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.category,
                              color: isSelected ? Colors.white : Colors.grey,
                              size: 24,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.category,
                        color: isSelected ? Colors.white : Colors.grey,
                        size: 24,
                      )),
          ),
          const SizedBox(height: 6), // Slightly smaller spacing
          Text(
            categoryName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.burntBrown : Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}


  // Loading indicator widget
  Widget _buildLoadingIndicator(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.burntBrown),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Product grid with transition effects
  Widget _buildProductsGrid() {
    if (_isFilteringProducts) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200, 
          child: _buildLoadingIndicator('جاري تحميل منتجات ${_core.selectedCategory}...'),
        ),
      );
    }
    
    if (_filteredProducts.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'لا توجد منتجات في ${_core.selectedCategory}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.70,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _filteredProducts.length) {
            return const SizedBox.shrink();
          }
          final product = _filteredProducts[index];
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 500),
            opacity: 1.0,
            child: HomeCard.buildProductCard(
              context, 
              product, 
              _core,
              index: index,
              onAddToCart: () {
                final String productId = product['id'];
                final String name = product['name'] ?? '';
                final double price = (product['price'] ?? 0.0) is double 
                    ? product['price'] 
                    : double.tryParse(product['price'].toString()) ?? 0.0;
                final String imageUrl = product['imageUrl'] ?? '';
                const int quantity = 1;
                
                final cartProvider = Provider.of<CartProvider>(context, listen: false);
                cartProvider.addItem(productId, name, price, imageUrl, quantity);
                
                _cartAnimationController.reset();
                _cartAnimationController.forward();
              },
            ),
          );
        },
        childCount: _filteredProducts.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Show a dialog asking if the user wants to exit the app
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('تأكيد الخروج'),
                content: const Text('هل تريد الخروج من التطبيق؟'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                      SystemNavigator.pop(); // Exit the app
                    },
                    child: const Text('خروج'),
                  ),
                ],
              );
            },
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          title: SvgPicture.asset(
            'assets/images/pattern.svg',
            height: 30,
            fit: BoxFit.contain,
            color: AppColors.burntBrown
          ),
          centerTitle: false,
          actions: [
            Stack(
              children: [
                IconButton(
                  key: _cartIconKey,
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black54),
                  onPressed: () {
                    Navigator.pushNamed(context, '/cart').then((_) => setState(() {}));
                  },
                ),
                if (cartProvider.items.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: AppColors.goldenOrange, shape: BoxShape.circle),
                      child: Text(
                        '${cartProvider.items.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        body: _core.isLoading
            ? _buildLoadingIndicator('جاري تحميل ${_core.selectedCategory == 'الكل' ? 'المنتجات' : 'منتجات ${_core.selectedCategory}'}...')
            : Stack(
                children: [
                  RefreshIndicator(
                    color: AppColors.burntBrown,
                    onRefresh: () async {
                      await _core.fetchData((fn) {
                        if (mounted) setState(fn);
                      });
                      _filterProductsByCategory(_core.selectedCategory);
                      return;
                    },
                    child: CustomScrollView(
                      controller: _core.scrollController,
                      slivers: [
                        // Search bar with improved design
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: TextField(
                              controller: _core.searchController,
                              decoration: InputDecoration(
                                hintText: 'ابحث عن منتجات...',
                                prefixIcon: const Icon(Icons.search, color: AppColors.burntBrown),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: AppColors.burntBrown, width: 1.5),
                                ),
                                suffixIcon: _core.searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: Colors.grey),
                                        onPressed: () {
                                          _core.searchController.clear();
                                          setState(() {
                                            // Reset filtered products to show all products in the selected category
                                            _filterProductsByCategory(_core.selectedCategory);
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  // Filter products based on search text and category
                                  if (value.isEmpty) {
                                    // If search is empty, show all products from the selected category
                                    _filterProductsByCategory(_core.selectedCategory);
                                  } else {
                                    // Filter products by search text within the selected category
                                    if (_core.selectedCategory == 'الكل') {
                                      _filteredProducts = _core.products.where((product) {
                                        final String name = product['name']?.toString().toLowerCase() ?? '';
                                        final String description = product['description']?.toString().toLowerCase() ?? '';
                                        return name.contains(value.toLowerCase()) || 
                                               description.contains(value.toLowerCase());
                                      }).toList();
                                    } else {
                                      _filteredProducts = _core.products.where((product) {
                                        final String name = product['name']?.toString().toLowerCase() ?? '';
                                        final String description = product['description']?.toString().toLowerCase() ?? '';
                                        final String category = product['category']?.toString() ?? '';
                                        final String categoryId = product['categoryId']?.toString() ?? '';
                                        
                                        return (name.contains(value.toLowerCase()) || 
                                                description.contains(value.toLowerCase())) && 
                                               (category == _core.selectedCategory || 
                                                categoryId == getCategoryIdByName(_core.selectedCategory));
                                      }).toList();
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        
                        // Banner Slider with improved design
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            height: screenSize.height * 0.2,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: PageView.builder(
                                controller: _core.bannerController,
                                onPageChanged: (index) {
                                  setState(() {
                                    _core.currentBannerIndex = index;
                                  });
                                },
                                itemCount: _core.bannerData.length,
                                itemBuilder: (context, index) {
                                  final banner = _core.bannerData[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CachedNetworkImage(
                                          imageUrl: banner['imageUrl'] ?? '',
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.burntBrown,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey[300],
                                            child: const Center(
                                              child: Icon(Icons.image_not_supported, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                        // Optional overlay for text readability
                                        if (banner['title'] != null)
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    Colors.black.withOpacity(0.7),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                              child: Text(
                                                banner['title'] ?? '',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                textAlign: TextAlign.start,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        
                        // Banner indicator with improved design
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10, bottom: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _core.bannerData.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  height: 8,
                                  width: _core.currentBannerIndex == index ? 24 : 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: _core.currentBannerIndex == index
                                        ? AppColors.burntBrown
                                        : Colors.grey[300],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        // Categories header with indicator showing selected category
                        SliverToBoxAdapter(
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.burntBrown,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.category_outlined,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'الأقسام',
                                          style: TextStyle(
                                            fontSize: 18, 
                                            fontWeight: FontWeight.bold
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (_core.selectedCategory != 'الكل')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.burntBrown.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppColors.burntBrown.withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              _core.selectedCategory,
                                              style: const TextStyle(
                                                color: AppColors.burntBrown,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Categories List with improved design and transitions
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 120,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              scrollDirection: Axis.horizontal,
                              itemCount: _core.categories.length + 1, // +1 for "All" category
                              itemBuilder: (context, index) {
                                // Add "All" category at the beginning
                                if (index == 0) {
                                  return _buildCategoryCard({}, index, true);
                                }
                                
                                final actualIndex = index - 1;
                                if (actualIndex >= _core.categories.length) {
                                  return const SizedBox.shrink();
                                }
                                
                                final category = _core.categories[actualIndex];
                                return _buildCategoryCard(category, actualIndex, false);
                              },
                            ),
                          ),
                        ),
                        
                        // Featured Products section (only visible when in "All" category or if there are featured products in this category)
                        SliverToBoxAdapter(
                          child: _core.featured.isEmpty || 
                                (_core.selectedCategory != 'الكل' && 
                                 !_core.featured.any((product) => 
                                     product['category'] == _core.selectedCategory || 
                                     product['categoryId'] == getCategoryIdByName(_core.selectedCategory)))
                              ? const SizedBox.shrink()
                              : Stack(
                                  children: [
                                    // Wave decoration
                                    ClipPath(
                                      clipper: WaveClipper(flip: true),
                                      child: Container(
                                        height: 40,
                                        color: Colors.amber.withOpacity(0.1),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber,
                                                      borderRadius: BorderRadius.circular(8),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.amber.withOpacity(0.3),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(Icons.star, color: Colors.white, size: 16),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'العناصر المميزة',
                                                    style: TextStyle(
                                                      fontSize: 18, 
                                                      fontWeight: FontWeight.bold
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              TextButton(
                                                onPressed: () {},
                                                child: const Text(
                                                  'عرض الكل',
                                                  style: TextStyle(
                                                    color: AppColors.burntBrown,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Featured Products Slider with category filtering
                                        SizedBox(
                                          height: 270,
                                          child: ListView.builder(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            scrollDirection: Axis.horizontal,
                                            itemCount: _core.selectedCategory == 'الكل' 
                                                ? _core.featured.length 
                                                : _core.featured.where((product) => 
                                                    product['category'] == _core.selectedCategory || 
                                                    product['categoryId'] == getCategoryIdByName(_core.selectedCategory)).length,
                                            itemBuilder: (context, index) {
                                              final filteredFeatured = _core.selectedCategory == 'الكل' 
                                                  ? _core.featured 
                                                  : _core.featured.where((product) => 
                                                      product['category'] == _core.selectedCategory || 
                                                      product['categoryId'] == getCategoryIdByName(_core.selectedCategory)).toList();
                                              
                                              if (index >= filteredFeatured.length) {
                                                return const SizedBox.shrink();
                                              }
                                              
                                              final item = filteredFeatured[index];
                                              return Container(
                                                width: 180,
                                                margin: const EdgeInsets.only(right: 12),
                                                child: HomeCard.buildProductCard(
                                                  context, 
                                                  item, 
                                                  _core,
                                                  isFeatured: true, 
                                                  index: index,
                                                  onAddToCart: () {
                                                    final String productId = item['id'];
                                                    final String name = item['name'] ?? '';
                                                    final double price = (item['price'] ?? 0.0) is double 
                                                        ? item['price'] 
                                                        : double.tryParse(item['price'].toString()) ?? 0.0;
                                                    final String imageUrl = item['imageUrl'] ?? '';
                                                    const int quantity = 1;
                                                    
                                                    final cartProvider = Provider.of<CartProvider>(context, listen: false);
                                                    cartProvider.addItem(productId, name, price, imageUrl, quantity);
                                                    
                                                    _cartAnimationController.reset();
                                                    _cartAnimationController.forward();
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),

                        // Category title display 
                        SliverToBoxAdapter(
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(255, 119, 51, 2),
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.brown.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.shopping_bag, color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _core.selectedCategory == 'الكل' 
                                          ? 'جميع المنتجات' 
                                          : 'منتجات ${_core.selectedCategory}',
                                      style: const TextStyle(
                                        fontSize: 18, 
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_filteredProducts.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_filteredProducts.length}',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Products Grid with category filtering
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: _buildProductsGrid(),
                        ),
                        
                        // Bottom padding
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 20),
                        ),
                      ],
                    ),
                  ),
                  
                  // Flying cart animation
                  HomeCart.buildFlyingCartAnimation(
                    _core.cartIconPosition, 
                    _cartAnimation, 
                    _cartAnimationController
                  ),
                ],
              ),
        bottomNavigationBar: AppNavigationBar(
          currentIndex: 0,
          onTap: (index) {
            // Handle navigation
          },
        ),
        floatingActionButton: cartProvider.items.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.pushNamed(context, '/cart'),
                backgroundColor: AppColors.goldenOrange,
                icon: const Icon(
                  Icons.shopping_cart,
                  color: AppColors.lightBeige,
                ),
                label: Text(
                  '${cartProvider.items.length} عناصر',
                  style: const TextStyle(color: Colors.white),
                ),
              )
            : null,
      ),
    );
  }
}

// Custom clipper for wave effect
class WaveClipper extends CustomClipper<Path> {
  final bool flip;
  
  WaveClipper({this.flip = false});
  
  @override
  Path getClip(Size size) {
    final path = Path();
    if (flip) {
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
      
      final firstControlPoint = Offset(size.width * 0.75, size.height * 0.5);
      final firstEndPoint = Offset(size.width * 0.5, 0);
      path.quadraticBezierTo(
        firstControlPoint.dx, 
        firstControlPoint.dy, 
        firstEndPoint.dx, 
        firstEndPoint.dy
      );
      
      final secondControlPoint = Offset(size.width * 0.25, -size.height * 0.4);
      final secondEndPoint = Offset(0, 0);
      path.quadraticBezierTo(
        secondControlPoint.dx, 
        secondControlPoint.dy, 
        secondEndPoint.dx, 
        secondEndPoint.dy
      );
    } else {
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      
      final firstControlPoint = Offset(size.width * 0.75, size.height * 0.5);
      final firstEndPoint = Offset(size.width * 0.5, size.height);
      path.quadraticBezierTo(
        firstControlPoint.dx, 
        firstControlPoint.dy, 
        firstEndPoint.dx, 
        firstEndPoint.dy
      );
      
      final secondControlPoint = Offset(size.width * 0.25, size.height * 1.4);
      final secondEndPoint = Offset(0, size.height);
      path.quadraticBezierTo(
        secondControlPoint.dx, 
        secondControlPoint.dy, 
        secondEndPoint.dx, 
        secondEndPoint.dy
      );
    }
    
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
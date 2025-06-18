import 'package:balqees/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class HomeCore {
  // متغيرات الحالة التي سيتم الوصول إليها من واجهة المستخدم
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> featured = [];
  List<Map<String, dynamic>> allProducts = []; // قائمة كاملة بجميع المنتجات
  List<Map<String, dynamic>> bannerData = []; // بيانات البنر من Firestore
  Map<String, int> cartItems = {};
  
  String selectedCategory = 'الكل';
  bool isLoading = true;
  int currentBannerIndex = 0;
  bool isCartUpdating = false;
  bool isBannerInitialized = false;
  bool isBannersLoading = true; // إضافة متغير لتتبع حالة تحميل البنرات
  
  // وحدات التحكم
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final PageController bannerController = PageController();
  Timer? bannerTimer;
  
  // متغيرات متعلقة بالرسوم المتحركة
  Offset? cartIconPosition;

  get favoriteItems => null;
  
  // طرق لجلب البيانات ومعالجتها
  Future<void> fetchData(Function setState) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final catsSnap = await firestore.collection('categories').get();
      final prodSnap = await firestore.collection('products').get();
      final featuredSnap = await firestore.collection('products')
          .where('featured', isEqualTo: true)
          .limit(10)
          .get();

      setState(() {
        categories = catsSnap.docs.map((e) => {...e.data(), 'id': e.id}).toList();
        products = prodSnap.docs.map((e) => {...e.data(), 'id': e.id}).toList();
        featured = featuredSnap.docs.map((e) => {...e.data(), 'id': e.id}).toList();
        
        // تخزين جميع المنتجات لاستخدام السلة
        allProducts = prodSnap.docs.map((e) => {...e.data(), 'id': e.id}).toList();
        isLoading = false;
      });
      
      // للتشخيص
      print("تم جلب ${allProducts.length} منتج");
      print("المنتجات بالمعرفات: ${allProducts.map((p) => p['id']).toList()}");
      print("تحتوي السلة على ${cartItems.length} عنصر: $cartItems");
      
    } catch (e) {
      print('خطأ في جلب البيانات: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // طريقة محدثة لجلب البنرات من Firestore (تتوافق مع لوحة التحكم)
  Future<void> fetchBanners(Function setState) async {
    try {
      setState(() {
        isBannersLoading = true;
      });
      
      final firestore = FirebaseFirestore.instance;
      
      // استعلام البيانات بنفس الطريقة التي تم تعريفها في لوحة التحكم
      final bannersSnap = await firestore.collection('banners')
          .where('isActive', isEqualTo: true)  // يجلب البنرات النشطة فقط
          .get();
      
      if (bannersSnap.docs.isNotEmpty) {
        setState(() {
          bannerData = bannersSnap.docs.map((doc) => {
            'id': doc.id,
            'imageUrl': doc.data()['imageUrl'] ?? '',    // رابط الصورة
            'title': doc.data()['title'] ?? '',          // عنوان البنر
            'linkUrl': doc.data()['linkUrl'] ?? '',      // رابط البنر للنقر
          }).toList();
          
          isBannersLoading = false;
        });
        
        print("تم جلب ${bannerData.length} بنر من فايرستور");
      } else {
        setState(() {
          bannerData = [];
          isBannersLoading = false;
        });
        print("لا توجد بنرات نشطة في فايرستور");
      }
    } catch (e) {
      print('خطأ في جلب البنرات: $e');
      setState(() {
        bannerData = [];
        isBannersLoading = false;
      });
    }
  }
  
  Future<void> filterProductsByCategory(String categoryName, Function setState) async {
    setState(() {
      isLoading = true;
      selectedCategory = categoryName;
    });
    
    try {
      final firestore = FirebaseFirestore.instance;
      
      if (categoryName == 'الكل') {
        final prodSnap = await firestore.collection('products').get();
        setState(() {
          products = prodSnap.docs.map((e) => {...e.data(), 'id': e.id}).toList();
          isLoading = false;
        });
      } else {
        final prodSnap = await firestore.collection('products')
          .where('categoryName', isEqualTo: categoryName)
          .get();
        
        setState(() {
          products = prodSnap.docs.map((e) => {...e.data(), 'id': e.id}).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('خطأ في تصفية المنتجات: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  void addToCart(BuildContext context, Map<String, dynamic> product, Function setState, {bool showAnimation = true}) {
    // تأكد من أن المنتج له معرف
    String productId = product['id'] ?? '';
    if (productId.isEmpty) {
      print('تحذير: معرف المنتج فارغ!');
      return;
    }
    
    // تأكد من وجود المنتج في قائمة المنتجات الكاملة
    if (!allProducts.any((p) => p['id'] == productId)) {
      // أضف المنتج إلى القائمة الكاملة إذا لم يكن موجودًا
      allProducts.add(product);
      print('تمت إضافة المنتج إلى allProducts: $productId');
    }
    
    // ردود الفعل اللمسية
    HapticFeedback.mediumImpact();
    
    setState(() {
      if (cartItems.containsKey(productId)) {
        cartItems[productId] = (cartItems[productId] ?? 0) + 1;
      } else {
        cartItems[productId] = 1;
      }
      
      isCartUpdating = true;
    });
    
    // للتشخيص
    print('تمت الإضافة إلى السلة: $productId');
    print('تحتوي السلة الآن على: $cartItems');
    
    // عرض مؤشر مؤقت على أيقونة السلة
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        isCartUpdating = false;
      });
    });
    
    // عرض رسالة نجاح
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة ${product['name']} إلى السلة'),
        backgroundColor: AppColors.burntBrown,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'عرض السلة',
          textColor: Colors.white,
          onPressed: () {
            // الانتقال إلى صفحة السلة
            Navigator.pushNamed(context, '/cart');
          },
        ),
      ),
    );
  }
  
  // تحديث كمية العنصر في السلة
  void updateCartItemQuantity(String productId, int quantity) {
    if (productId.isEmpty) {
      print('تحذير: لا يمكن تحديث الكمية لمعرف منتج فارغ');
      return;
    }
    
    if (quantity <= 0) {
      cartItems.remove(productId);
      print('تمت إزالة المنتج من السلة: $productId');
    } else {
      cartItems[productId] = quantity;
      print('تم تحديث الكمية لـ $productId إلى $quantity');
    }
    
    // للتشخيص
    print('السلة بعد التحديث: $cartItems');
  }
  
  // إزالة المنتج من السلة
  void removeFromCart(String productId) {
    if (productId.isEmpty) {
      print('تحذير: لا يمكن إزالة معرف منتج فارغ');
      return;
    }
    
    cartItems.remove(productId);
    print('تمت الإزالة من السلة: $productId');
    print('تحتوي السلة الآن على: $cartItems');
  }
  
  // الحصول على المنتج بواسطة المعرف
  Map<String, dynamic> getProductById(String productId) {
    try {
      return allProducts.firstWhere(
        (product) => product['id'] == productId,
        orElse: () => {
          'id': productId,
          'name': 'منتج غير معروف',
          'price': 0,
          'imageUrl': null,
        },
      );
    } catch (e) {
      print('خطأ في الحصول على المنتج حسب المعرف: $e');
      return {
        'id': productId,
        'name': 'منتج غير معروف',
        'price': 0,
        'imageUrl': null,
      };
    }
  }
  
  // طرق معالجة البنر
  void startBannerTimer(Function setState) {
    bannerTimer?.cancel(); // إلغاء أي مؤقت موجود لتجنب التكرار
    
    // لا تبدأ المؤقت إذا لم يكن لدينا بنرات
    if (bannerData.isEmpty) return;
    
    bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // تحقق مما إذا كان وحدة التحكم متصلة
      if (bannerController.hasClients) {
        try {
          final int bannerLength = bannerData.length;
          if (bannerLength <= 1) {
            // لا تقم بالرسوم المتحركة إذا كان لدينا 0 أو 1 بنر فقط
            timer.cancel();
            return;
          }
          
          if (currentBannerIndex < bannerLength - 1) {
            bannerController.animateToPage(
              currentBannerIndex + 1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          } else {
            bannerController.animateToPage(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        } catch (e) {
          // إذا واجهنا خطأ، قم بإلغاء المؤقت
          timer.cancel();
          print('خطأ في حركة البنر: $e');
        }
      } else {
        // إذا لم تكن وحدة التحكم متصلة، قم بإلغاء المؤقت
        timer.cancel();
      }
    });
  }
  
  void getCartIconPosition(GlobalKey cartIconKey) {
    final RenderBox? renderBox = cartIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      cartIconPosition = position;
    }
  }
  
  void setupBannerTimer(Function setState) {
    // قم بإعداد المؤقت فقط عندما نتأكد من أن PageView تم بناؤه وجاهز
    if (!isBannerInitialized) {
      setState(() {
        isBannerInitialized = true;
      });
      
      // ابدأ المؤقت مع تأخير للتأكد من تهيئة PageView بالكامل
      Future.delayed(const Duration(seconds: 1), () {
        startBannerTimer(setState);
      });
    }
  }
  
  // وظائف البحث
  List<Map<String, dynamic>> getFilteredProducts() {
    final String searchQuery = searchController.text.toLowerCase().trim();
    if (searchQuery.isEmpty) {
      return products;
    }
    
    return products.where((product) {
      final String name = (product['name'] ?? '').toLowerCase();
      final String description = (product['description'] ?? '').toLowerCase();
      return name.contains(searchQuery) || description.contains(searchQuery);
    }).toList();
  }
  
  // تنظيف
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    bannerController.dispose();
    bannerTimer?.cancel();
  }
  
  void clearCartItems() {
    cartItems.clear();
  }
  
  // دالة مساعدة لمعالجة النقر على البنر
  void handleBannerClick(BuildContext context, int index) {
    if (index < 0 || index >= bannerData.length) return;
    
    final String? linkUrl = bannerData[index]['linkUrl'];
    if (linkUrl != null && linkUrl.isNotEmpty) {
      print('تم النقر على البنر برابط: $linkUrl');
      
      // يمكنك تنفيذ منطق معالجة مختلف بناءً على نوع الرابط
      // مثال: إذا كان الرابط لمنتج معين
      if (linkUrl.startsWith('/product/')) {
        final String productId = linkUrl.replaceFirst('/product/', '');
        Navigator.pushNamed(
          context,
          '/product-details',
          arguments: {'productId': productId}
        );
      }
      // مثال: إذا كان الرابط لقسم معين
      else if (linkUrl.startsWith('/category/')) {
        final String categoryName = linkUrl.replaceFirst('/category/', '');
        Navigator.pushNamed(
          context, 
          '/category',
          arguments: {'categoryName': categoryName}
        );
      }
      // يمكنك إضافة المزيد من الحالات حسب الحاجة
    }
  }
  
  // إنشاء واجهة البنر مع حالة التحميل
  Widget buildBannerWidget(BuildContext context) {
    if (isBannersLoading) {
      // حالة التحميل
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (bannerData.isEmpty) {
      // حالة عدم وجود بنرات
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('لا توجد عروض متاحة حالياً'),
        ),
      );
    }
    
    // إذا وجدت بنرات، قم بعرضها
    return Container(
      height: 180,
      child: PageView.builder(
        controller: bannerController,
        onPageChanged: (index) {
          currentBannerIndex = index;
        },
        itemCount: bannerData.length,
        itemBuilder: (context, index) {
          final banner = bannerData[index];
          return GestureDetector(
            onTap: () => handleBannerClick(context, index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // صورة البنر
                    Image.network(
                      banner['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / 
                                    loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // عرض العنوان إذا كان موجوداً
                    if (banner['title'] != null && banner['title'].toString().isNotEmpty)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          color: Colors.black.withOpacity(0.5),
                          child: Text(
                            banner['title'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  toggleFavorite(item) {}
}
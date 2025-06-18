import 'package:balqees/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart';
import 'logic.dart';
import 'package:balqees/providers/auth_provider.dart';
import 'package:balqees/providers/cart_provider.dart';
import 'package:balqees/models/cart_item.dart';
import 'package:balqees/services/coupon_service.dart';

class CartPage extends StatefulWidget {
  final Map<String, int> cartItems;
  final List<Map<String, dynamic>> products;
  final Function(String, int) onUpdateQuantity;
  final Function(String) onRemoveItem;
  final VoidCallback onAddToCart;

  const CartPage({
    super.key,
    required this.cartItems,
    required this.products,
    required this.onUpdateQuantity,
    required this.onRemoveItem,
    required this.onAddToCart,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartCore _core = CartCore();
  List<Map<String, dynamic>> savedAddresses = [];
  bool isLoadingAddresses = true;
  String? selectedDeliveryAddress;
  String selectedPaymentMethod = 'cashOnDelivery';
  
  // Map related variables
  LatLng? selectedLocation;
  final fmap.MapController mapController = fmap.MapController();
  String? wazeLink;
  bool isDragging = false;
  double? dragStartLat;
  double? dragStartLng;
  final TextEditingController addressController = TextEditingController();
  bool isSaving = false;
  
  @override
  void initState() {
    super.initState();
    selectedLocation = const LatLng(32.6027147, 44.0196987);
    loadSavedAddresses();
  }
  
  @override
  void dispose() {
    _core.dispose();
    addressController.dispose();
    super.dispose();
  }

  double get _subtotal => _core.calculateSubtotal(widget.cartItems, widget.products);
  double get _deliveryFee => _core.deliveryFee;
  double get _promoDiscount => _core.calculatePromoDiscount(_subtotal);
  double get _total => _core.calculateTotal(_subtotal, _deliveryFee, _promoDiscount);

  Future<void> loadSavedAddresses() async {
    setState(() => isLoadingAddresses = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uuid)
          .collection('addresses')
          .get();

      final addresses = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'address': data['address'] ?? '',
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
          'wazeLink': data['wazeLink'] ?? '',
          'isDefault': data['isDefault'] ?? false,
        };
      }).toList();

      setState(() {
        savedAddresses = addresses;
        isLoadingAddresses = false;

        final defaultAddress = addresses.firstWhere(
          (addr) => addr['isDefault'] == true,
          orElse: () => {},
        );
        selectedDeliveryAddress = defaultAddress.isNotEmpty ? defaultAddress['id'] : null;
      });
    } catch (e) {
      setState(() => isLoadingAddresses = false);
      _showAnimatedSnackBar(
        context,
        'حدث خطأ أثناء تحميل العناوين: $e',
        isError: true,
      );
    }
  }

  void _showAnimatedSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            _showAnimatedSnackBar(context, 'يرجى تفعيل خدمة الموقع');
          }
          return;
        }
      }

      loc.PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus == loc.PermissionStatus.denied) {
        permissionStatus = await location.requestPermission();
        if (permissionStatus != loc.PermissionStatus.granted) {
          if (mounted) {
            _showAnimatedSnackBar(context, 'لم يتم السماح بالوصول إلى الموقع');
          }
          return;
        }
      }

      loc.LocationData locationData = await location.getLocation();
      if (mounted) {
        setState(() {
          selectedLocation = LatLng(locationData.latitude!, locationData.longitude!);
          _getLocationName();
        });

        mapController.move(selectedLocation!, 15.0);
      }
    } catch (e) {
      if (mounted) {
        _showAnimatedSnackBar(context, 'حدث خطأ أثناء تحديد الموقع: $e', isError: true);
      }
    }
  }

  Future<void> _getLocationName() async {
    if (selectedLocation != null) {
      final lat = selectedLocation!.latitude;
      final lng = selectedLocation!.longitude;
      wazeLink = 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
      
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          final locationName = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((item) => item != null && item.isNotEmpty).join(', ');
          
          if (mounted) {
            setState(() {
              addressController.text = locationName.isNotEmpty ? locationName : 'الموقع المحدد';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              addressController.text = 'الموقع المحدد';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            addressController.text = 'الموقع المحدد';
          });
        }
      }
    }
  }

  Future<void> _saveNewAddress() async {
    if (selectedLocation == null || addressController.text.isEmpty) {
      _showAnimatedSnackBar(
        context,
        'الرجاء تحديد موقع وعنوان',
        isError: true,
      );
      return;
    }

    setState(() => isSaving = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      bool isDefault = savedAddresses.isEmpty;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uuid)
          .collection('addresses')
          .add({
        'address': addressController.text.trim(),
        'latitude': selectedLocation!.latitude,
        'longitude': selectedLocation!.longitude,
        'wazeLink': wazeLink,
        'isDefault': isDefault,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (isDefault) {
        await FirebaseFirestore.instance.collection('users').doc(auth.uuid).update({
          'address': addressController.text.trim(),
        });
        await auth.checkLogin();
      }
      
      await loadSavedAddresses();
      
      _showAnimatedSnackBar(
        context,
        'تم إضافة العنوان بنجاح! 🎉',
        isError: false,
      );
    } catch (e) {
      _showAnimatedSnackBar(
        context,
        'حدث خطأ أثناء حفظ العنوان: $e',
        isError: true,
      );
    }
    
    setState(() => isSaving = false);
  }

  void _showMapBottomSheet() {
    final currentContext = context;
    showModalBottomSheet(
      context: currentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.95,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'حدد موقعك',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: () {
                          _getCurrentLocation();
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      fmap.FlutterMap(
                        mapController: mapController,
                        options: fmap.MapOptions(
                          initialCenter: selectedLocation!,
                          initialZoom: 15.0,
                          maxZoom: 18.0,
                          minZoom: 5.0,
                          onTap: (tapPosition, latLng) {
                            setModalState(() {
                              selectedLocation = latLng;
                              _getLocationName();
                            });
                            setState(() {});
                          },
                        ),
                        children: [
                          fmap.TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.balqees.app',
                          ),
                        ],
                      ),
                      
                      GestureDetector(
                        onPanStart: (details) {
                          setModalState(() {
                            isDragging = true;
                            dragStartLat = selectedLocation!.latitude;
                            dragStartLng = selectedLocation!.longitude;
                          });
                        },
                        onPanUpdate: (details) {
                          if (isDragging) {
                            final zoomFactor = 0.0002 * (20 - mapController.camera.zoom);
                            
                            final newLat = selectedLocation!.latitude - details.delta.dy * zoomFactor;
                            final newLng = selectedLocation!.longitude + details.delta.dx * zoomFactor;
                            final newLatLng = LatLng(newLat, newLng);
                            
                            setModalState(() {
                              selectedLocation = newLatLng;
                            });
                            mapController.move(newLatLng, mapController.camera.zoom);
                          }
                        },
                        onPanEnd: (details) {
                          if (isDragging) {
                            setModalState(() {
                              isDragging = false;
                              _getLocationName();
                            });
                            setState(() {});
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: isDragging ? 70 : 60,
                          transform: isDragging 
                            ? Matrix4.translationValues(0, -10, 0) 
                            : Matrix4.identity(),
                          child: const Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Icon(
                                Icons.location_pin,
                                color: AppColors.burntBrown,
                                size: 50,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              Positioned(
                                bottom: 12,
                                child: CircleAvatar(
                                  radius: 4,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (addressController.text.isNotEmpty)
                        Positioned(
                          bottom: 80,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  addressController.text,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'اسحب الدبوس لتحديد الموقع بدقة',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                      if (isDragging && selectedLocation != null)
                        Positioned(
                          top: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${selectedLocation!.latitude.toStringAsFixed(6)}, ${selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'وصف العنوان (مثل: المنزل، العمل)',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _saveNewAddress();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burntBrown,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'حفظ العنوان',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _setDefaultAddress(String addressId, String addressText) async {
    setState(() => isSaving = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      final batch = FirebaseFirestore.instance.batch();
      
      final addressesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uuid)
          .collection('addresses')
          .get();
      
      for (var doc in addressesSnapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }
      
      batch.update(
        FirebaseFirestore.instance
            .collection('users')
            .doc(auth.uuid)
            .collection('addresses')
            .doc(addressId),
        {'isDefault': true}
      );
      
      batch.update(
        FirebaseFirestore.instance
            .collection('users')
            .doc(auth.uuid),
        {'address': addressText}
      );
      
      await batch.commit();
      await auth.checkLogin();
      
      await loadSavedAddresses();
      
      _showAnimatedSnackBar(
        context,
        'تم تعيين العنوان الافتراضي بنجاح!',
        isError: false,
      );
    } catch (e) {
      _showAnimatedSnackBar(
        context,
        'حدث خطأ أثناء تعيين العنوان الافتراضي: $e',
        isError: true,
      );
    }
    
    setState(() => isSaving = false);
  }

  Future<void> _deleteAddress(String addressId, bool isDefault) async {
    setState(() => isSaving = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uuid)
          .collection('addresses')
          .doc(addressId)
          .delete();
      
      if (isDefault && savedAddresses.length > 1) {
        final newDefaultAddress = savedAddresses.firstWhere((addr) => addr['id'] != addressId);
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(auth.uuid)
            .collection('addresses')
            .doc(newDefaultAddress['id'])
            .update({'isDefault': true});
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(auth.uuid)
            .update({'address': newDefaultAddress['address']});
        
        await auth.checkLogin();
      } else if (savedAddresses.length <= 1) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(auth.uuid)
            .update({'address': ''});
        
        await auth.checkLogin();
      }
      
      await loadSavedAddresses();
      
      _showAnimatedSnackBar(
        context,
        'تم حذف العنوان بنجاح',
        isError: false,
      );
    } catch (e) {
      _showAnimatedSnackBar(
        context,
        'حدث خطأ أثناء حذف العنوان: $e',
        isError: true,
      );
    }
    
    setState(() => isSaving = false);
  }

  // Add this helper method to format dates
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  // Add this method to validate and apply coupon codes
  Future<void> _validateAndApplyCoupon() async {
    final couponCode = _core.promoController.text.trim();
    if (couponCode.isEmpty) {
      setState(() {
        _core.errorMessage = 'يرجى إدخال كود الكوبون';
      });
      return;
    }

    setState(() {
      _core.isValidatingCoupon = true;
      _core.errorMessage = null;
    });

    try {
      // Use our new coupon service to validate the coupon
      final CouponService couponService = CouponService();
      final couponData = await couponService.validateCoupon(couponCode);
      
      if (couponData == null) {
        setState(() {
          _core.errorMessage = 'كود الكوبون غير صالح أو منتهي الصلاحية';
          _core.isValidatingCoupon = false;
        });
        return;
      }

      // Apply the valid coupon to the cart provider
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final bool applied = cartProvider.applyCoupon(
        code: couponData['code'],
        discountPercentage: (couponData['percentage'] as num).toDouble(),
        name: couponData['name'],
        expiryDate: couponData['expiryDate'],
      );

      if (applied) {
        // Set promo code in the core for backward compatibility 
        // with existing code that might still use this
        _core.promoCode = couponData['code'];
        _core.promoPercentage = (couponData['percentage'] as num).toDouble();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تطبيق كوبون ${couponData['name']} بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _core.errorMessage = 'فشل في تطبيق الكوبون';
        });
      }
    } catch (e) {
      setState(() {
        _core.errorMessage = 'حدث خطأ أثناء التحقق من الكوبون';
      });
      print('Error validating coupon: $e');
    } finally {
      setState(() {
        _core.isValidatingCoupon = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final List<CartItem> cartItemsList = cartProvider.items;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('سلة التسوق'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: cartItemsList.isEmpty
          ? _buildEmptyCart()
          : CustomScrollView(
              slivers: [
                // Cart Items
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cartItem = cartItemsList[index];
                      return _buildCartItem(cartItem, context);
                    },
                    childCount: cartItemsList.length,
                  ),
                ),
                
                // Promo Code
                SliverToBoxAdapter(
                  child: _buildPromoCodeSection(),
                ),
                
                // Delivery Options
                SliverToBoxAdapter(
                  child: _buildDeliveryOptionsSection(),
                ),
                
                // Payment Methods
                SliverToBoxAdapter(
                  child: _buildPaymentMethodsSection(),
                ),
                
                // Order Summary
                SliverToBoxAdapter(
                  child: _buildOrderSummarySection(),
                ),
                
                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
      bottomNavigationBar: cartItemsList.isEmpty
          ? null
          : _buildCheckoutButton(),
    );
  }
  
  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'سلة التسوق فارغة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أضف بعض المنتجات للمتابعة',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burntBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('العودة للتسوق'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildCartItem(CartItem cartItem, BuildContext context) {
  final cartProvider = Provider.of<CartProvider>(context, listen: false);
  final screenWidth = MediaQuery.of(context).size.width;
  
  // Adaptive horizontal padding based on screen size
  final horizontalPadding = screenWidth < 360 ? 8.0 : 16.0;
  
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Dismissible(
        key: Key(cartItem.optionName != null 
            ? '${cartItem.productId}-${cartItem.optionName}' 
            : cartItem.productId),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: AppColors.burntBrown,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 30,
          ),
        ),
        onDismissed: (direction) {
          cartProvider.removeItemById(cartItem.productId, optionName: cartItem.optionName);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // تعديل الصورة لتكون داخل panel مع إضافة anti-aliasing
            Padding(
              padding: const EdgeInsets.all(8.0), // إضافة هامش داخلي
              child: Container(
                width: screenWidth < 360 ? 80 : 100,
                height: screenWidth < 360 ? 80 : 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10), // تدوير الحواف للحاوية
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                  // إضافة border للحاوية
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10), // تدوير الحواف للصورة نفسها
                  child: cartItem.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: cartItem.imageUrl!,
                          fit: BoxFit.cover,
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
                          // إضافة filterQuality لتحسين جودة الصورة (anti-aliasing)
                          filterQuality: FilterQuality.medium,
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                ),
              ),
            ),
            
            Expanded(
              child: Padding(
                // Adaptive inner padding based on screen size
                padding: EdgeInsets.all(screenWidth < 360 ? 8 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cartItem.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // إضافة عرض خيار المنتج (كاملة، نصف، ربع)
                    if (cartItem.optionName != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.burntBrown.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          cartItem.optionName!,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 4),
                    
                    // عرض السعر
                    if (cartItem.hasDiscount) ...[
                      Wrap(
                        spacing: 4,
                        children: [
                          Text(
                            '${cartItem.finalPrice.toStringAsFixed(0)} د.ع',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${cartItem.price.toStringAsFixed(0)} د.ع',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${cartItem.discountPercentage?.toStringAsFixed(0) ?? "0"}%',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        '${cartItem.price.toStringAsFixed(0)} د.ع',
                        style: const TextStyle(
                          color: AppColors.burntBrown,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            if (cartItem.quantity > 1) {
                              cartProvider.updateItemQuantity(
                                cartItem.productId, 
                                cartItem.quantity - 1,
                                optionName: cartItem.optionName,
                              );
                            } else {
                              cartProvider.removeItemById(
                                cartItem.productId,
                                optionName: cartItem.optionName,
                              );
                            }
                            _core.triggerHapticFeedback();
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.remove, color: AppColors.burntBrown, size: 16),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 8 : 12),
                          child: Text(
                            '${cartItem.quantity}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            cartProvider.updateItemQuantity(
                              cartItem.productId, 
                              cartItem.quantity + 1,
                              optionName: cartItem.optionName,
                            );
                            _core.triggerHapticFeedback();
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.burntBrown,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Use Padding with appropriate constraints for the total price
            Container(
              padding: EdgeInsets.all(screenWidth < 360 ? 8 : 12),
              constraints: BoxConstraints(minWidth: screenWidth < 360 ? 60 : 80),
              child: Text(
                '${cartItem.totalPrice.toStringAsFixed(0)} د.ع',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    ),
  );

}
  
  Widget _buildPromoCodeSection() {
    final cartProvider = Provider.of<CartProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'كود الخصم',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _core.promoController,
                    decoration: InputDecoration(
                      hintText: 'أدخل كود الكوبون',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _validateAndApplyCoupon(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burntBrown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('تطبيق'),
                ),
              ],
            ),
            if (cartProvider.isCouponValid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تم تطبيق كوبون: ${cartProvider.couponName ?? ""}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'خصم ${cartProvider.couponDiscount.toStringAsFixed(0)}% على إجمالي الطلب',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontSize: 12,
                            ),
                          ),
                          if (cartProvider.couponExpiryDate != null)
                            Text(
                              'ينتهي في: ${_formatDate(cartProvider.couponExpiryDate!)}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    InkWell(
  onTap: () {
    _core.clearPromoCode((code) {
      setState(() {});
    }, context);  // Pass context here
  },
  child: const Icon(Icons.close, color: Colors.green, size: 16),
),
                  ],
                ),
              ),
            ],
            if (_core.errorMessage != null && _core.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _core.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _core.errorMessage = null;
                        });
                      },
                      child: const Icon(Icons.close, color: Colors.red, size: 16),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDeliveryOptionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'خيارات التوصيل',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            
            // Saved addresses
            if (isLoadingAddresses)
              const Center(
                child: CircularProgressIndicator(
                  color: AppColors.burntBrown,
                  strokeWidth: 2,
                ),
              )
            else if (savedAddresses.isEmpty)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'لا توجد عناوين محفوظة. يرجى إضافة عنوان توصيل.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showMapBottomSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burntBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('إضافة عنوان جديد'),
                  ),
                ],
              )
            else
              Column(
                children: [
                  ...savedAddresses.map((address) {
                    final String addressId = address['id'] ?? '';
                    final bool isSelected = selectedDeliveryAddress == addressId;
                    final bool isDefault = address['isDefault'] ?? false;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.burntBrown.withOpacity(0.1) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.burntBrown : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: Text(
                              address['address'] ?? '',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: isDefault
                                ? const Text(
                                    'العنوان الافتراضي',
                                    style: TextStyle(
                                      color: AppColors.burntBrown,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            value: addressId,
                            groupValue: selectedDeliveryAddress,
                            activeColor: AppColors.burntBrown,
                            onChanged: (value) {
                              setState(() {
                                selectedDeliveryAddress = value;
                              });
                            },
                          ),
                          
                          // Address action buttons
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(right: 16, left: 16, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!isDefault)
                                    TextButton.icon(
                                      onPressed: () => _setDefaultAddress(
                                        addressId,
                                        address['address'],
                                      ),
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        size: 16,
                                        color: AppColors.burntBrown,
                                      ),
                                      label: const Text(
                                        'تعيين كافتراضي',
                                        style: TextStyle(
                                          color: AppColors.burntBrown,
                                          fontSize: 14,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ),
                                  TextButton.icon(
                                    onPressed: () => _deleteAddress(
                                      addressId,
                                      isDefault,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'حذف',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  
                  // Add new address button
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showMapBottomSheet,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.burntBrown,
                      side: const BorderSide(color: AppColors.burntBrown),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('إضافة عنوان جديد'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethodsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'طرق الدفع',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              decoration: BoxDecoration(
                color: selectedPaymentMethod == 'cashOnDelivery'
                    ? AppColors.burntBrown.withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selectedPaymentMethod == 'cashOnDelivery'
                      ? AppColors.burntBrown
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: RadioListTile<String>(
                title: const Text('الدفع عند الاستلام'),
                subtitle: const Text('ادفع نقداً عند استلام طلبك'),
                secondary: const Icon(Icons.payments_outlined),
                value: 'cashOnDelivery',
                groupValue: selectedPaymentMethod,
                activeColor: AppColors.burntBrown,
                onChanged: (value) {
                  setState(() {
                    selectedPaymentMethod = value!;
                    _core.paymentMethod = 'الدفع عند الاستلام';
                  });
                },
              ),
            ),
            
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: selectedPaymentMethod == 'onlinePayment'
                    ? AppColors.burntBrown.withOpacity(0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selectedPaymentMethod == 'onlinePayment'
                      ? AppColors.burntBrown
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: RadioListTile<String>(
                title: const Text('الدفع الإلكتروني'),
                subtitle: const Text('قريباً - سيتم إضافة هذه الخدمة لاحقاً'),
                secondary: const Icon(Icons.credit_card_outlined),
                value: 'onlinePayment',
                groupValue: selectedPaymentMethod,
                activeColor: AppColors.burntBrown,
                onChanged: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOrderSummarySection() {
    final cartProvider = Provider.of<CartProvider>(context);
    
    // Calculate total with delivery fee
    final totalWithDelivery = cartProvider.totalAmount + _deliveryFee;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص الطلب',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المجموع الفرعي'),
                Text('${cartProvider.originalTotalAmount.toStringAsFixed(0)} د.ع'),
              ],
            ),
            if (cartProvider.itemsDiscount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('خصم المنتجات'),
                  Text(
                    '- ${cartProvider.itemsDiscount.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('رسوم التوصيل'),
                Text('${_deliveryFee.toStringAsFixed(0)} د.ع'),
              ],
            ),
            if (cartProvider.couponDiscountAmount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('خصم الكوبون (${cartProvider.couponDiscount.toStringAsFixed(0)}%)'),
                  Text(
                    '- ${cartProvider.couponDiscountAmount.toStringAsFixed(0)} د.ع',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المجموع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  '${totalWithDelivery.toStringAsFixed(0)} د.ع',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.burntBrown,
                  ),
                ),
              ],
            ),
            if (cartProvider.totalDiscount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.savings, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'وفرت ${cartProvider.totalDiscount.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildCheckoutButton() {
    final cartProvider = Provider.of<CartProvider>(context);
    final totalWithDelivery = cartProvider.totalAmount + _deliveryFee;
    bool canCheckout = selectedDeliveryAddress != null && cartProvider.items.isNotEmpty;
    
    return Container(
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
          onPressed: _core.isLoading || !canCheckout
              ? null
              : () => _core.checkout(
                    context,
                    (isLoading) {
                      setState(() {
                        _core.isLoading = isLoading;
                      });
                    },
                    cartItems: widget.cartItems,
                    products: widget.products,
                    subtotal: cartProvider.originalTotalAmount,
                    deliveryFee: _deliveryFee,
                    discount: cartProvider.totalDiscount,
                    total: totalWithDelivery,
                    couponDetails: cartProvider.isCouponValid ? {
                      'code': cartProvider.couponCode,
                      'name': cartProvider.couponName,
                      'percentage': cartProvider.couponDiscount,
                      'amount': cartProvider.couponDiscountAmount,
                    } : null,
                  ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.burntBrown,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: _core.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'إتمام الطلب',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${totalWithDelivery.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
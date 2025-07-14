import 'package:balqees/screens/orders/main.dart';
import 'package:balqees/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:balqees/providers/auth_provider.dart';
import 'package:balqees/widgets/bottom.dart';
import 'dart:ui' as ui;
import 'dart:math' show Random;
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  bool isSaving = false;

  // Map related variables
  LatLng? selectedLocation;
  final fmap.MapController mapController = fmap.MapController();
  String? wazeLink;
  bool isDragging = false;
  double? dragStartLat;
  double? dragStartLng;
  List<Map<String, dynamic>> savedAddresses = [];
  bool isLoadingAddresses = true;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    nameController.text = auth.name;
    phoneController.text = auth.phone;
    addressController.text = auth.address;

    // Initialize selected location with default values
    // You can modify these to match your region
    selectedLocation = const LatLng(32.6027147, 44.0196987);

    // Load saved addresses from Firestore
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    setState(() {
      isLoadingAddresses = true;
    });

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
      });
    } catch (e) {
      setState(() {
        isLoadingAddresses = false;
      });
      _showAnimatedSnackBar(
        context,
        'حدث خطأ أثناء تحميل العناوين: $e',
        isError: true,
      );
    }
  }

  Future<void> _renameAddress(String addressId, String currentName) async {
    // Create a text controller initialized with the current name
    final TextEditingController renameController =
        TextEditingController(text: currentName);

    // Show dialog to get the new name
    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl, // For Arabic
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'تعديل اسم العنوان',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: Container(
            decoration: BoxDecoration(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inputBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: renameController,
              decoration: const InputDecoration(
                hintText: 'أدخل اسم العنوان الجديد',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              autofocus: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = renameController.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(context, newName);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    ).then((newName) async {
      if (newName != null && newName is String && newName.isNotEmpty) {
        setState(() => isSaving = true);

        try {
          final auth = Provider.of<AuthProvider>(context, listen: false);

          // Update address name in Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(auth.uuid)
              .collection('addresses')
              .doc(addressId)
              .update({'address': newName});

          // If it's the default address, update the user's main address too
          final isDefault = savedAddresses.firstWhere(
            (addr) => addr['id'] == addressId,
            orElse: () => {'isDefault': false},
          )['isDefault'];

          if (isDefault) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(auth.uuid)
                .update({'address': newName});

            await auth.checkLogin();
          }

          // Refresh addresses list
          await _loadSavedAddresses();

          _showAnimatedSnackBar(
            context,
            'تم تعديل اسم العنوان بنجاح! 🎉',
            isError: false,
          );
        } catch (e) {
          _showAnimatedSnackBar(
            context,
            'حدث خطأ أثناء تعديل اسم العنوان: $e',
            isError: true,
          );
        }

        setState(() => isSaving = false);
      }
    });
  }

  Future<void> saveChanges() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uuid)
          .update({
        'name': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
      });
      await auth.checkLogin();

      // Enhanced success message
      _showAnimatedSnackBar(
        // ignore: use_build_context_synchronously
        context,
        'تم تحديث البيانات بنجاح! 🎉',
        isError: false,
      );
    } catch (e) {
      _showAnimatedSnackBar(
        // ignore: use_build_context_synchronously
        context,
        'حدث خطأ أثناء الحفظ: $e',
        isError: true,
      );
    }
    setState(() => isSaving = false);
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

      // Check if this is the first address (make it default)
      bool isDefault = savedAddresses.isEmpty;

      // Create new address document in Firestore
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

      // If it's default address, also update user's main address
      if (isDefault) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(auth.uuid)
            .update({
          'address': addressController.text.trim(),
        });
        await auth.checkLogin();
      }

      // Refresh addresses list
      await _loadSavedAddresses();

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

  Future<void> _setDefaultAddress(String addressId, String addressText) async {
    setState(() => isSaving = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // First, remove default status from all addresses
      final batch = FirebaseFirestore.instance.batch();

      final addressesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uuid)
          .collection('addresses')
          .get();

      for (var doc in addressesSnapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }

      // Set the selected address as default
      batch.update(
          FirebaseFirestore.instance
              .collection('users')
              .doc(auth.uuid)
              .collection('addresses')
              .doc(addressId),
          {'isDefault': true});

      // Update user's main address
      batch.update(
          FirebaseFirestore.instance.collection('users').doc(auth.uuid),
          {'address': addressText});

      await batch.commit();
      await auth.checkLogin();

      // Refresh addresses list
      await _loadSavedAddresses();

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

      // Delete the address
      await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uuid)
          .collection('addresses')
          .doc(addressId)
          .delete();

      // If it was the default address, set a new default
      if (isDefault && savedAddresses.length > 1) {
        // Find another address to set as default
        final newDefaultAddress =
            savedAddresses.firstWhere((addr) => addr['id'] != addressId);

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
        // If it was the last address, clear default address
        await FirebaseFirestore.instance
            .collection('users')
            .doc(auth.uuid)
            .update({'address': ''});

        await auth.checkLogin();
      }

      // Refresh addresses list
      await _loadSavedAddresses();

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

  void _showAnimatedSnackBar(BuildContext context, String message,
      {bool isError = false}) {
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
          selectedLocation =
              LatLng(locationData.latitude!, locationData.longitude!);
          _getLocationName();
        });

        mapController.move(selectedLocation!, 15.0);
      }
    } catch (e) {
      if (mounted) {
        _showAnimatedSnackBar(context, 'حدث خطأ أثناء تحديد الموقع: $e',
            isError: true);
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
              addressController.text =
                  locationName.isNotEmpty ? locationName : 'الموقع المحدد';
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
        // حالة فشل الحصول على اسم الموقع
        if (mounted) {
          setState(() {
            addressController.text = 'الموقع المحدد';
          });
        }
      }
    }
  }

  void _showMapBottomSheet() {
    final currentContext = context;
    showModalBottomSheet(
      context: currentContext,
      isScrollControlled: true, // السماح بالشاشة الكاملة
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height:
                MediaQuery.of(context).size.height * 0.95, // شاشة كاملة تقريبا
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // الرأس
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
                          setModalState(() {}); // تحديث الخريطة
                        },
                      ),
                    ],
                  ),
                ),

                // الخريطة
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // الخريطة الأساسية
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
                            setState(() {}); // تحديث الحالة الأساسية
                          },
                        ),
                        children: [
                          fmap.TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.balqees.app',
                          ),
                        ],
                      ),

                      // دبوس الموقع القابل للسحب
                      GestureDetector(
                        onPanStart: (details) {
                          setModalState(() {
                            isDragging = true;
                            // حفظ إحداثيات بداية السحب
                            dragStartLat = selectedLocation!.latitude;
                            dragStartLng = selectedLocation!.longitude;
                          });
                        },
                        onPanUpdate: (details) {
                          if (isDragging) {
                            // إنشاء معامل تحسس يعتمد على مستوى التكبير
                            final zoomFactor =
                                0.0002 * (20 - mapController.camera.zoom);

                            // تحديث الموقع الجديد بناءً على حركة السحب
                            final newLat = selectedLocation!.latitude -
                                details.delta.dy * zoomFactor;
                            final newLng = selectedLocation!.longitude +
                                details.delta.dx * zoomFactor;
                            final newLatLng = LatLng(newLat, newLng);

                            // تحديث الموقع المحدد وحركة الخريطة
                            setModalState(() {
                              selectedLocation = newLatLng;
                            });
                            mapController.move(
                                newLatLng, mapController.camera.zoom);
                          }
                        },
                        onPanEnd: (details) {
                          if (isDragging) {
                            setModalState(() {
                              isDragging = false;
                              _getLocationName();
                            });
                            setState(() {}); // تحديث الحالة الأساسية
                          }
                        },
                        // الدبوس نفسه مع تصميم جذاب
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
                                color: AppColors.goldenOrange,
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

                      // صندوق معلومات الموقع
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

                      // مؤشر الإحداثيات أثناء السحب
                      if (isDragging && selectedLocation != null)
                        Positioned(
                          top: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
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

                // التسمية والحفظ
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                              color: AppColors.inputBorder, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'وصف العنوان (مثل: المنزل، العمل)',
                              hintStyle: TextStyle(color: AppColors.textLight),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ),

                      // زر التأكيد
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            // إرجاع الإحداثيات والعنوان
                            Navigator.pop(context);
                            _saveNewAddress(); // حفظ العنوان الجديد
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldenOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'حفظ العنوان',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Directionality(
      textDirection: TextDirection.rtl, // For Arabic language support
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Background with pattern
            Positioned.fill(
              child: _buildBackgroundPattern(),
            ),

            // Main content
            CustomScrollView(
              slivers: [
                // Custom App Bar
                SliverAppBar(
                  expandedHeight: 250.0,
                  floating: false,
                  pinned: false,
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Flat color background for appbar
                        Container(
                          color: const Color.fromARGB(255, 146, 65, 14),
                        ),
                        // Decorative food icons pattern
                        // Food icon overlay
                        Center(
                          child: Opacity(
                            opacity: 1, // ← هنا تتحكم بنسبة الشفافية من 0 إلى 1
                            child: SvgPicture.asset(
                              'assets/icons/logo.svg', // ← المسار الصحيح لشعارك
                              height: 900,
                              width: 1000,
                              fit: BoxFit.contain,
                              colorFilter: const ColorFilter.mode(
                                Color.fromARGB(255, 255, 254,
                                    254), // ← أو تتحكم بالشفافية هنا إذا تحب
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: AppColors.textOnPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // Profile Avatar Section
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppColors.white,
                                  child: Text(
                                    auth.name.isNotEmpty
                                        ? auth.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: AppColors.textOnSecondary,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              auth.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Profile Info Section
                        _buildSectionHeader(
                            'معلومات شخصية', Icons.person, AppColors.primary),

                        const SizedBox(height: 16),

                        // Name field with enhanced design
                        _buildAnimatedProfileField(
                          icon: Icons.person,
                          label: 'الاسم',
                          controller: nameController,
                          color: AppColors.primary,
                        ),

                        const SizedBox(height: 16),

                        // Phone field with enhanced design
                        _buildAnimatedProfileField(
                          icon: Icons.phone,
                          label: 'رقم الهاتف',
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          color: AppColors.primary,
                        ),

                        const SizedBox(height: 16),

                        // Current address field (not editable)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                                color: AppColors.inputBorder, width: 1),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on,
                                      color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    auth.address.isEmpty
                                        ? 'لم يتم تحديد عنوان بعد'
                                        : auth.address,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Flat Save Button
                        _buildFlatButton(
                          onPressed: isSaving ? null : saveChanges,
                          child: isSaving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: AppColors.textOnPrimary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save,
                                        color: AppColors.textOnPrimary),
                                    SizedBox(width: 8),
                                    Text(
                                      'حفظ التعديلات',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textOnPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 30),

                        // Addresses Section
                        _buildSectionHeader('العناوين المحفوظة',
                            Icons.location_on, AppColors.secondary),

                        const SizedBox(height: 16),

                        // Add new address button
                        InkWell(
                          onTap: _showMapBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.secondary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_location_alt,
                                    color: AppColors.secondary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'إضافة عنوان جديد',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // List of saved addresses
                        if (isLoadingAddresses)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        else if (savedAddresses.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 48,
                                    color: AppColors.grey.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'لا توجد عناوين محفوظة',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Column(
                            children: savedAddresses.map((address) {
                              final bool isDefault =
                                  address['isDefault'] ?? false;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDefault
                                      ? AppColors.secondary.withOpacity(0.1)
                                      : AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDefault
                                        ? AppColors.secondary
                                        : AppColors.inputBorder,
                                    width: isDefault ? 2 : 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: AppColors.shadow,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: (isDefault
                                                      ? AppColors.secondary
                                                      : AppColors.primary)
                                                  .withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.location_on,
                                              color: isDefault
                                                  ? AppColors.secondary
                                                  : AppColors.primary,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              address['address'] ?? '',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: isDefault
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (isDefault)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondary,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'افتراضي',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          // زر تعديل الاسم
                                          TextButton.icon(
                                            onPressed: () => _renameAddress(
                                              address['id'],
                                              address['address'],
                                            ),
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                            label: const Text(
                                              'تعديل الاسم',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 14,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                            ),
                                          ),
                                          // زر تعيين كافتراضي
                                          if (!isDefault)
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _setDefaultAddress(
                                                address['id'],
                                                address['address'],
                                              ),
                                              icon: const Icon(
                                                Icons.check_circle_outline,
                                                size: 16,
                                                color: AppColors.goldenOrange,
                                              ),
                                              label: const Text(
                                                'تعيين كافتراضي',
                                                style: TextStyle(
                                                  color: AppColors.goldenOrange,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                              ),
                                            ),
                                          // زر الحذف
                                          TextButton.icon(
                                            onPressed: () => _deleteAddress(
                                              address['id'],
                                              isDefault,
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: AppColors.error,
                                            ),
                                            label: const Text(
                                              'حذف',
                                              style: TextStyle(
                                                color: AppColors.error,
                                                fontSize: 14,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 30),

                        // Additional options
                        _buildOptionTile(
                          title: 'الطلبات السابقة',
                          icon: Icons.history,
                          color: AppColors.primary,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => OrdersPage()),
                            );
                          },
                        ),

                        _buildOptionTile(
                          title: 'حذف الحساب',
                          icon: Icons.delete,
                          color: AppColors.error,
                          onTap: () {
                            launchUrl(
                              Uri.parse(
                                  'https://balqees-delete-account.vercel.app/'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),

                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: const AppNavigationBar(currentIndex: 4),
      ),
    );
  }

  Widget _buildBackgroundPattern() {
    final size = MediaQuery.of(context).size;
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return ui.Gradient.linear(
          const Offset(0, 0),
          Offset(1, bounds.height),
          [Colors.white.withOpacity(0.1), Colors.white],
          [0.1, 0.3],
        );
      },
      blendMode: BlendMode.dstIn,
      child: Container(
        color: AppColors.background,
        width: size.width,
        height: size.height,
        child: Stack(
          children: List.generate(
            10, // Generate 10 patterns for a dense look
            (index) {
              // Use fixed seed for consistent but varied pattern
              final random = Random(index * 7);

              // Calculate position for each pattern
              final double left = random.nextDouble() * size.width;
              final double top = random.nextDouble() * size.height;

              // Vary sizes between 15 and 35
              final double patternSize = 10.0 + random.nextDouble() * 20;

              // Vary opacity slightly
              final double opacity = 0.7 + (random.nextDouble() * 0.3);

              return Positioned(
                left: left,
                top: top,
                child: Opacity(
                  opacity: opacity,
                  child: SvgPicture.asset(
                    'assets/images/pattern.svg',
                    fit: BoxFit.contain,
                    height: patternSize,
                    width: patternSize,
                    colorFilter: const ColorFilter.mode(
                      Colors.brown,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedProfileField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required Color color,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.inputBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Focus the text field when container is tapped
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: label,
                      hintStyle: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 15,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlatButton({
    required VoidCallback? onPressed,
    required Widget child,
  }) {
    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: onPressed == null ? AppColors.grey : AppColors.primary,
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textLight,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

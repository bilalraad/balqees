import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import 'package:geocoding/geocoding.dart';

import '../../providers/auth_provider.dart';
import '../../utils/colors.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final addressController = TextEditingController();
  final nameController = TextEditingController();

  // إضافة متغيرات للتحكم في حالة التركيز لكل حقل
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  
  // متغيرات لتتبع حالة التركيز والنص في كل حقل
  bool _isNameFocused = false;
  bool _isPhoneFocused = false;
  bool _isPasswordFocused = false;
  bool _isAddressFocused = false;
  
  bool _hasNameText = false;
  bool _hasPhoneText = false;
  bool _hasPasswordText = false;
  bool _hasAddressText = false;

  // متغير لإظهار/إخفاء كلمة المرور
  bool _isPasswordVisible = false;

  LatLng? selectedLocation;
  final fmap.MapController mapController = fmap.MapController();
  bool isLoading = false;
  String errorMessage = '';
  String? wazeLink;
  bool isDragging = false;
  double? dragStartLat;
  double? dragStartLng;

  @override
  void initState() {
    super.initState();
    // تعيين الموقع الافتراضي
    selectedLocation = const LatLng(32.6027147, 44.0196987);
    
    // إضافة مستمعين للتحكم في التركيز لكل حقل
    _nameFocus.addListener(_onNameFocusChange);
    _phoneFocus.addListener(_onPhoneFocusChange);
    _passwordFocus.addListener(_onPasswordFocusChange);
    _addressFocus.addListener(_onAddressFocusChange);
    
    // إضافة مستمعين للنص لتتبع ما إذا كان هناك نص في الحقل
    nameController.addListener(_onNameTextChange);
    phoneController.addListener(_onPhoneTextChange);
    passwordController.addListener(_onPasswordTextChange);
    addressController.addListener(_onAddressTextChange);
    
    // الحصول على اسم الموقع بعد التهيئة
    Future.microtask(() => _getLocationName());
  }

  // وظائف معالجة تغيير التركيز
  void _onNameFocusChange() {
    setState(() {
      _isNameFocused = _nameFocus.hasFocus;
    });
  }

  void _onPhoneFocusChange() {
    setState(() {
      _isPhoneFocused = _phoneFocus.hasFocus;
    });
  }

  void _onPasswordFocusChange() {
    setState(() {
      _isPasswordFocused = _passwordFocus.hasFocus;
    });
  }

  void _onAddressFocusChange() {
    setState(() {
      _isAddressFocused = _addressFocus.hasFocus;
    });
  }

  // وظائف معالجة تغيير النص
  void _onNameTextChange() {
    setState(() {
      _hasNameText = nameController.text.isNotEmpty;
    });
  }

  void _onPhoneTextChange() {
    setState(() {
      _hasPhoneText = phoneController.text.isNotEmpty;
    });
  }

  void _onPasswordTextChange() {
    setState(() {
      _hasPasswordText = passwordController.text.isNotEmpty;
    });
  }

  void _onAddressTextChange() {
    setState(() {
      _hasAddressText = addressController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    // إلغاء تسجيل المستمعين
    _nameFocus.removeListener(_onNameFocusChange);
    _phoneFocus.removeListener(_onPhoneFocusChange);
    _passwordFocus.removeListener(_onPasswordFocusChange);
    _addressFocus.removeListener(_onAddressFocusChange);
    
    nameController.removeListener(_onNameTextChange);
    phoneController.removeListener(_onPhoneTextChange);
    passwordController.removeListener(_onPasswordTextChange);
    addressController.removeListener(_onAddressTextChange);
    
    // التخلص من الكائنات
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _addressFocus.dispose();
    
    phoneController.dispose();
    passwordController.dispose();
    addressController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown-ios';
    } else {
      return 'unknown-device';
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoading = true;
    });

    try {
      final location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) {
            _showSnackBar('يرجى تفعيل خدمة الموقع');
          }
          return;
        }
      }

      loc.PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus == loc.PermissionStatus.denied) {
        permissionStatus = await location.requestPermission();
        if (permissionStatus != loc.PermissionStatus.granted) {
          if (mounted) {
            _showSnackBar('لم يتم السماح بالوصول إلى الموقع');
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
        _showSnackBar('حدث خطأ أثناء تحديد الموقع: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
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
              addressController.text = locationName.isNotEmpty ? locationName : '';
              _hasAddressText = addressController.text.isNotEmpty;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              addressController.text = '';
              _hasAddressText = false;
            });
          }
        }
      } catch (e) {
        // حالة فشل الحصول على اسم الموقع
        if (mounted) {
          setState(() {
            addressController.text = '';
            _hasAddressText = false;
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
            height: MediaQuery.of(context).size.height * 0.95, // شاشة كاملة تقريبا
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
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                            final zoomFactor = 0.0002 * (20 - mapController.camera.zoom);
                            
                            // تحديث الموقع الجديد بناءً على حركة السحب
                            final newLat = selectedLocation!.latitude - details.delta.dy * zoomFactor;
                            final newLng = selectedLocation!.longitude + details.delta.dx * zoomFactor;
                            final newLatLng = LatLng(newLat, newLng);
                            
                            // تحديث الموقع المحدد وحركة الخريطة
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
                            setState(() {});  // تحديث الحالة الأساسية
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
                
                // زر التأكيد
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
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
                        'تأكيد الموقع',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.burntBrown,
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final uuid = await getDeviceId();
      final fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
      final locationData = selectedLocation != null
          ? {
              'latitude': selectedLocation!.latitude,
              'longitude': selectedLocation!.longitude,
              'wazeLink': wazeLink,
            }
          : null;

      // الحصول على مثيل AuthProvider قبل العمليات غير المتزامنة
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // استخدام تنفيذ AuthProvider الموجود
      await authProvider.registerUser(
        uuid: uuid,
        phone: phoneController.text.trim(),
        password: passwordController.text.trim(),
        address: addressController.text.trim(),
        name: nameController.text.trim(),
        fcmToken: fcmToken,
        locationData: locationData,
        role: 'user', // تعيين الدور الافتراضي إلى 'user'
      );

      // محاولة تسجيل الدخول مباشرة بعد التسجيل
      await authProvider.loginWithUUID(uuid);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'حدث خطأ أثناء إنشاء الحساب: $e';
        });
      }
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // ضمان تخطيط RTL للعربية
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.lightBeige,
                Colors.white,
              ],
            ),
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // شعار التطبيق مع SVG
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: SizedBox(
                            height: 120,
                            width: 120,
                            child: SvgPicture.asset(
                              'assets/icons/logo.svg',
                              fit: BoxFit.contain,
                              colorFilter: const ColorFilter.mode(
                                AppColors.burntBrown,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // العنوان
                      const Padding(
                        padding: EdgeInsets.only(bottom: 30),
                        child: Text(
                          'إنشاء حساب جديد',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.burntBrown,
                          ),
                        ),
                      ),
                      
                      // حقل الاسم - محسن
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: nameController,
                          focusNode: _nameFocus,
                          decoration: InputDecoration(
                            labelText: _isNameFocused || _hasNameText ? 'الاسم الكامل' : null,
                            hintText: _isNameFocused ? null : 'أدخل اسمك الكامل',
                            labelStyle: const TextStyle(color: AppColors.textSecondary),
                            prefixIcon: const Icon(Icons.person, color: AppColors.goldenOrange),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.goldenOrange, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال الاسم';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      // حقل الهاتف - محسن
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: phoneController,
                          focusNode: _phoneFocus,
                          decoration: InputDecoration(
                            labelText: _isPhoneFocused || _hasPhoneText ? 'رقم الهاتف' : null,
                            hintText: _isPhoneFocused ? null : 'أدخل رقم هاتفك',
                            labelStyle: const TextStyle(color: AppColors.textSecondary),
                            prefixIcon: const Icon(Icons.phone, color: AppColors.goldenOrange),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.goldenOrange, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال رقم الهاتف';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      // حقل كلمة المرور - محسن مع إضافة زر العين
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: passwordController,
                          focusNode: _passwordFocus,
                          obscureText: !_isPasswordVisible, // تبديل حالة الإخفاء
                          decoration: InputDecoration(
                            labelText: _isPasswordFocused || _hasPasswordText ? 'كلمة المرور' : null,
                            hintText: _isPasswordFocused ? null : 'أدخل كلمة المرور',
                            labelStyle: const TextStyle(color: AppColors.textSecondary),
                            prefixIcon: const Icon(Icons.lock, color: AppColors.goldenOrange),
                            // إضافة زر العين للتبديل بين إظهار وإخفاء كلمة المرور
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible 
                                  ? Icons.visibility 
                                  : Icons.visibility_off,
                                color: AppColors.goldenOrange,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: AppColors.goldenOrange, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال كلمة المرور';
                            }
                            if (value.length < 6) {
                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      // حقل العنوان مع محدد الموقع - محسن
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: AppColors.inputBackground,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: _showMapBottomSheet,
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: addressController,
                              focusNode: _addressFocus,
                              decoration: InputDecoration(
                                labelText: _isAddressFocused || _hasAddressText ? 'العنوان' : null,
                                hintText: _isAddressFocused ? null : 'اضغط هنا لتحديد موقعك',
                                labelStyle: const TextStyle(color: AppColors.textSecondary),
                                prefixIcon: const Icon(Icons.location_on, color: AppColors.goldenOrange),
                                suffixIcon: const Icon(Icons.map_outlined, color: AppColors.goldenOrange),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.inputBorder, width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.goldenOrange, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                              ),
                              maxLines: 2,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'الرجاء تحديد موقعك';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                      
                      // رسالة الخطأ
                      if (errorMessage.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // زر التسجيل
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldenOrange,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.goldenOrange.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                              shadowColor: AppColors.goldenOrange.withOpacity(0.5),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 25,
                                    width: 25,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'إنشاء الحساب',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: AppColors.white,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      
                      // رابط تسجيل الدخول
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'لديك حساب بالفعل؟',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.burntBrown,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                color: AppColors.burntBrown,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
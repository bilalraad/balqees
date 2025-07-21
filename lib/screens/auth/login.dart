import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/auth_provider.dart';
import '../../utils/colors.dart';

class LoginPage extends StatefulWidget {
  final bool isFromSplash;
  const LoginPage({super.key, this.isFromSplash = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // إضافة متغيرات للتحكم في حالة التركيز لكل حقل
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  // متغيرات لتتبع حالة التركيز والنص في كل حقل
  bool _isPhoneFocused = false;
  bool _isPasswordFocused = false;

  bool _hasPhoneText = false;
  bool _hasPasswordText = false;

  bool isLoading = false;
  bool _isPasswordVisible = false; // تسمية متسقة مع RegisterPage
  String errorMessage = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuint,
      ),
    );

    // إضافة مستمعين للتحكم في التركيز لكل حقل
    _phoneFocus.addListener(_onPhoneFocusChange);
    _passwordFocus.addListener(_onPasswordFocusChange);

    // إضافة مستمعين للنص لتتبع ما إذا كان هناك نص في الحقل
    phoneController.addListener(_onPhoneTextChange);
    passwordController.addListener(_onPasswordTextChange);

    _animationController.forward();
  }

  // وظائف معالجة تغيير التركيز
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

  // وظائف معالجة تغيير النص
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

  @override
  void dispose() {
    // إلغاء تسجيل المستمعين
    _phoneFocus.removeListener(_onPhoneFocusChange);
    _passwordFocus.removeListener(_onPasswordFocusChange);

    phoneController.removeListener(_onPhoneTextChange);
    passwordController.removeListener(_onPasswordTextChange);

    // التخلص من الكائنات
    _phoneFocus.dispose();
    _passwordFocus.dispose();

    _animationController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Validate form
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneController.text.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final user = snapshot.docs.first.data();
        if (user['password'] == passwordController.text.trim()) {
          // Success animation and haptic feedback
          HapticFeedback.mediumImpact();

          final uuid = user['uuid'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('uuid', uuid);

          await Provider.of<AuthProvider>(context, listen: false)
              .loginWithUUID(uuid);

          Navigator.pushReplacementNamed(context, '/');
        } else {
          HapticFeedback.vibrate();
          setState(() {
            errorMessage = 'كلمة المرور غير صحيحة';
          });
        }
      } else {
        HapticFeedback.vibrate();
        setState(() {
          errorMessage = 'رقم الهاتف غير مسجل';
        });
      }
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() {
        errorMessage = 'حدث خطأ أثناء تسجيل الدخول: ${e.toString()}';
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // استخدام PopScope لمنع الخروج من الصفحة والتحكم في سلوك زر العودة
    return Directionality(
      textDirection: TextDirection.rtl, // Ensure RTL layout for Arabic
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل الدخول',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              )),
          centerTitle: true,
          backgroundColor: AppColors.burntBrown,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
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
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: size.width > 600 ? 500 : size.width * 0.9,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromARGB(26, 161, 14, 14),
                              spreadRadius: 2,
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Food delivery logo SVG
                            SizedBox(
                              height: 150,
                              child: SvgPicture.asset(
                                'assets/icons/logo.svg',
                                fit: BoxFit.contain,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.burntBrown,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Animated welcome text
                            const Text(
                              'مرحباً بك في مطبخ بلقيس',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.burntBrown,
                              ),
                            ),

                            const SizedBox(height: 12),
                            const Text(
                              'أشهى الأكلات توصل لباب بيتك',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Login form
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Phone field - محسن ومتسق مع RegisterPage
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
                                      keyboardType: TextInputType.phone,
                                      textDirection: TextDirection.ltr,
                                      maxLength: 15,
                                      buildCounter: (context,
                                              {required currentLength,
                                              required isFocused,
                                              maxLength}) =>
                                          null,
                                      style: const TextStyle(
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      decoration: InputDecoration(
                                        labelText:
                                            _isPhoneFocused || _hasPhoneText
                                                ? 'رقم الهاتف'
                                                : null,
                                        hintText: _isPhoneFocused
                                            ? null
                                            : 'أدخل رقم هاتفك',
                                        labelStyle: const TextStyle(
                                            color: AppColors.textSecondary),
                                        prefixIcon: const Icon(Icons.phone,
                                            color: AppColors.goldenOrange),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                              color: AppColors.inputBorder,
                                              width: 1),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                              color: AppColors.goldenOrange,
                                              width: 2),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 15, horizontal: 20),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'يرجى إدخال رقم الهاتف';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  // Password field - محسن ومتسق مع RegisterPage
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
                                      obscureText: !_isPasswordVisible,
                                      decoration: InputDecoration(
                                        labelText: _isPasswordFocused ||
                                                _hasPasswordText
                                            ? 'كلمة المرور'
                                            : null,
                                        hintText: _isPasswordFocused
                                            ? null
                                            : 'أدخل كلمة المرور',
                                        labelStyle: const TextStyle(
                                            color: AppColors.textSecondary),
                                        prefixIcon: const Icon(Icons.lock,
                                            color: AppColors.goldenOrange),
                                        // زر العين مع نفس التصميم المستخدم في RegisterPage
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: AppColors.goldenOrange,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordVisible =
                                                  !_isPasswordVisible;
                                            });
                                          },
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                              color: AppColors.inputBorder,
                                              width: 1),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                              color: AppColors.goldenOrange,
                                              width: 2),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 15, horizontal: 20),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'يرجى إدخال كلمة المرور';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Error message
                                  if (errorMessage.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 20),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppColors.error
                                                .withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: AppColors.error),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              errorMessage,
                                              style: const TextStyle(
                                                  color: AppColors.error),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Login button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: AppColors.goldenOrange,
                                        disabledBackgroundColor: AppColors
                                            .goldenOrange
                                            .withOpacity(0.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        elevation: 3,
                                        shadowColor: AppColors.goldenOrange
                                            .withOpacity(0.5),
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'تسجيل الدخول',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Register link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'ليس لديك حساب؟',
                                  style:
                                      TextStyle(color: AppColors.textSecondary),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pushNamed(context, '/register'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.burntBrown,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                  child: const Text(
                                    'إنشاء حساب جديد',
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
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLoginButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.divider,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 32,
        ),
      ),
    );
  }
}

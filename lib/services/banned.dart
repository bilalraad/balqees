import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';

class BannedPage extends StatefulWidget {
  final String currentDateTime;
  final String userLogin;
  
  const BannedPage({
    super.key, 
    this.currentDateTime = '2025-05-02 22:03:48',
    this.userLogin = 'RAY-40EX',
  });

  @override
  State<BannedPage> createState() => _BannedPageState();
}

class _BannedPageState extends State<BannedPage> with WidgetsBindingObserver {
  String? username;
  String? userEmail;
  String? userPhoneNumber;
  String? userPhotoUrl;
  bool isLoading = true;
  String? deviceId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUserData();
    
    // Prevent back navigation by setting system UI overlay
    SystemChannels.navigation.invokeMethod('systemNavigator.setSystemUIOverlayStyle', {
      'systemNavigationBarColor': '#FFFFFF', // Use hex string instead of Color
      'systemNavigationBarIconBrightness': 'dark',
    });
    
    // Lock device in portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Reset orientation settings
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
  
  @override
  Future<bool> didPopRoute() async {
    // Prevent back navigation
    return true; // Return true to indicate we've handled the pop
  }

  // Function to get device model/build number
  Future<String?> _getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // or other properties like androidInfo.model
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      debugPrint('Error getting device ID: $e');
    }
    
    return null;
  }

  Future<void> _fetchUserData() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        await currentUser.reload();
        currentUser = FirebaseAuth.instance.currentUser; // Get refreshed user
        
        setState(() {
          username = currentUser?.displayName;
          userEmail = currentUser?.email;
          userPhoneNumber = currentUser?.phoneNumber;
          userPhotoUrl = currentUser?.photoURL;
          deviceId = currentUser?.uid;
          isLoading = false;
        });
      } else {
        deviceId = await _getDeviceId();
        setState(() {
          username = null;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      setState(() {
        username = 'Error Loading User';
        isLoading = false;
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        debugPrint('Could not launch $phoneUri');
      }
    } catch (e) {
      debugPrint('Error making phone call: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = username ?? widget.userLogin;
    
    return WillPopScope(
      onWillPop: () async => false, 
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'UTC: ${widget.currentDateTime}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.grey[700],
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (userPhotoUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundImage: NetworkImage(userPhotoUrl!),
                                    ),
                                  ),
                                Text(
                                  'Banned: $displayName',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
                if (userEmail != null && userEmail!.isNotEmpty) 
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'البريد الإلكتروني: $userEmail',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0x1AF44336), // Use hexadecimal color instead of Colors.red.withOpacity(0.1)
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block,
                    color: Colors.red,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 36),
                // Main heading
                const Text(
                  'سلملي تم حظر هذا الجهاز',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'عذراً، لا يمكنك استخدام التطبيق حالياً. إذا كنت تعتقد أن هذا خطأ، يرجى التواصل مع الدعم.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                if (deviceId != null) 
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ID: $deviceId',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFEF9A9A)), // Replace Colors.red.shade300
                    borderRadius: BorderRadius.circular(12),
                    color: Color(0xFFFFEBEE), // Replace Colors.red.shade50
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'الدعم الفني',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '07709114499',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _makePhoneCall('07709114499'),
                        icon: const Icon(Icons.phone),
                        label: const Text(
                          'اتصل الآن',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Spacer(),
                Text(
                  'رمز الحظر: BAN-${displayName.substring(0, min(displayName.length, 2))}-${DateTime.now().microsecondsSinceEpoch % 10000}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper function to avoid errors when getting substring
  int min(int a, int b) {
    return a < b ? a : b;
  }
}
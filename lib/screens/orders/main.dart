import 'package:balqees/screens/orders/ratings/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/bottom.dart';
import 'package:balqees/providers/auth_provider.dart' as auth_provider;
// استيراد ملف التقييمات
// ignore: unused_import

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  bool _isRefreshing = false;
  String? currentUuid;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isTimeout = false;
  late AnimationController _animationController;
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUser();
    });
    _setupTimeout();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupTimeout() {
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() {
          _isTimeout = true;
          _isLoading = false;
          _errorMessage = 'تعذر تحميل البيانات، يرجى التحقق من اتصالك بالإنترنت';
        });
      }
    });
  }

  Future<void> _initializeUser() async {
    try {
      final auth = Provider.of<auth_provider.AuthProvider>(context, listen: false);
      if (!auth.isLoggedIn || auth.uuid.isEmpty) {
        setState(() {
          _errorMessage = 'يرجى تسجيل الدخول لعرض طلباتك';
          _isLoading = false;
        });
        return;
      }
      await _fetchOrdersDirectly(auth.uuid);
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل تحميل بيانات المستخدم: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchOrdersDirectly(String uid) async {
    try {
      final ordersQuery = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      if (ordersQuery.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            currentUuid = uid;
            _isLoading = false;
          });
        }
        return;
      }
      await fetchCurrentUuid(uid);
    } catch (e) {
      await fetchCurrentUuid(uid);
    }
  }

  Future<void> fetchCurrentUuid(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;
      final userData = snapshot.data();

      if (userData != null) {
        final possibleUuidFields = ['uuid', 'UUID', 'id', 'userId', 'user_id', 'uid'];
        String? foundUuid;
        for (final field in possibleUuidFields) {
          if (userData.containsKey(field) && userData[field] != null && userData[field].toString().isNotEmpty) {
            foundUuid = userData[field].toString();
            break;
          }
        }
        setState(() {
          currentUuid = foundUuid ?? userData['phone']?.toString() ?? uid;
          _isLoading = false;
        });
      } else {
        setState(() {
          currentUuid = uid;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentUuid = uid;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
      _isTimeout = false;
    });
    try {
      final auth = Provider.of<auth_provider.AuthProvider>(context, listen: false);
      if (!auth.isLoggedIn) throw Exception('المستخدم غير مسجل الدخول');
      await _fetchOrdersDirectly(auth.uuid);
      await Future.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل التحديث: $e';
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Widget _buildOrdersList() {
    if (currentUuid == null) {
      return _ErrorWidget(
        onRetry: _refreshData,
        errorMessage: 'معرّف المستخدم غير متاح',
        icon: Icons.person_off_outlined,
      );
    }
    
    Query ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('uuid', isEqualTo: currentUuid)
        .orderBy('createdAt', descending: true);
    
    // Apply filters if selected
    if (_selectedFilter != null) {
      switch (_selectedFilter) {
        case 'قيد التنفيذ':
          ordersQuery = ordersQuery.where('status', whereIn: ['قيد التنفيذ', 'قيد المعالجة', 'قيد التوصيل']);
          break;
        case 'تم التسليم':
          ordersQuery = ordersQuery.where('status', whereIn: ['تم التسليم', 'مكتمل']);
          break;
        case 'ملغية':
          ordersQuery = ordersQuery.where('status', isEqualTo: 'ملغي');
          break;
      }
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: ordersQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isRefreshing) {
          return _buildLoadingWidget();
        }
        if (snapshot.hasError) {
          return _buildAlternativeOrderList();
        }
        final orders = snapshot.data?.docs ?? [];
        if (orders.isEmpty) {
          return _buildAlternativeOrderList();
        }
        return _buildOrdersListView(orders);
      },
    );
  }

  Widget _buildOrdersListView(List<QueryDocumentSnapshot> orders) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index].data() as Map<String, dynamic>;
          final orderId = orders[index].id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            // استخدام RatableOrderCard من ملف ratings.dart
            child: RatableOrderCard(orderId: orderId, order: order),
          );
        },
      ),
    );
  }

  Widget _buildAlternativeOrderList() {
    final uuid = Provider.of<auth_provider.AuthProvider>(context, listen: false).uuid;
    
    Query ordersQuery = FirebaseFirestore.instance
        .collection('orders')
        .where('uuid', isEqualTo: uuid)
        .orderBy('createdAt', descending: true);
    
    // Apply filters for alternative query too
    if (_selectedFilter != null) {
      switch (_selectedFilter) {
        case 'قيد التنفيذ':
          ordersQuery = ordersQuery.where('status', whereIn: ['قيد التنفيذ', 'قيد المعالجة', 'قيد التوصيل']);
          break;
        case 'تم التسليم':
          ordersQuery = ordersQuery.where('status', whereIn: ['تم التسليم', 'مكتمل']);
          break;
        case 'ملغية':
          ordersQuery = ordersQuery.where('status', isEqualTo: 'ملغي');
          break;
      }
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: ordersQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }
        if (snapshot.hasError) {
          return _ErrorWidget(
            onRetry: _refreshData,
            errorMessage: 'حدث خطأ أثناء جلب الطلبات',
            icon: Icons.error_outline,
          );
        }
        final orders = snapshot.data?.docs ?? [];
        if (orders.isEmpty) {
          return const _EmptyOrdersWidget();
        }
        return _buildOrdersListView(orders);
      },
    );
  }

  Widget _buildLoadingWidget() {
    return _isRefreshing 
      ? const _SkeletonLoadingList() 
      : const _LoadingWidget();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isTimeout) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: _ErrorWidget(
          onRetry: _refreshData,
          errorMessage: 'انقطع الاتصال. حاول مرة أخرى.',
          icon: Icons.wifi_off_outlined,
        ),
        bottomNavigationBar: const AppNavigationBar(currentIndex: 2),
      );
    }
    
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const _LoadingWidget(),
        bottomNavigationBar: const AppNavigationBar(currentIndex: 2),
      );
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: _ErrorWidget(
          onRetry: _refreshData,
          errorMessage: _errorMessage!,
          icon: Icons.error_outline,
        ),
        bottomNavigationBar: const AppNavigationBar(currentIndex: 2),
      );
    }
    
    return Scaffold(
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: theme.primaryColor,
        backgroundColor: theme.cardColor,
        child: _buildOrdersList(),
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 2),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'طلباتي',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal', // Use an Arabic-friendly font
        ),
      ),
      centerTitle: true,
      elevation: 0.5,
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () {
            _showFilterOptions(context);
          },
          tooltip: 'فلترة الطلبات',
        ),
      ],
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'فلترة الطلبات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
                const Divider(),
                _FilterOption(
                  title: 'جميع الطلبات',
                  icon: Icons.list_alt,
                  isSelected: _selectedFilter == null,
                  onTap: () {
                    setState(() {
                      _selectedFilter = null;
                    });
                    Navigator.pop(context);
                  },
                ),
                _FilterOption(
                  title: 'قيد التنفيذ',
                  icon: Icons.timelapse,
                  isSelected: _selectedFilter == 'قيد التنفيذ',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'قيد التنفيذ';
                    });
                    Navigator.pop(context);
                  },
                ),
                _FilterOption(
                  title: 'تم التسليم',
                  icon: Icons.check_circle_outline,
                  isSelected: _selectedFilter == 'تم التسليم',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'تم التسليم';
                    });
                    Navigator.pop(context);
                  },
                ),
                _FilterOption(
                  title: 'ملغية',
                  icon: Icons.cancel_outlined,
                  isSelected: _selectedFilter == 'ملغية',
                  onTap: () {
                    setState(() {
                      _selectedFilter = 'ملغية';
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const _FilterOption({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.colorScheme.primary : null,
        ),
      ),
      onTap: onTap,
      tileColor: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جاري تحميل الطلبات...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontFamily: 'Tajawal',
              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLoadingList extends StatelessWidget {
  const _SkeletonLoadingList();
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SkeletonCard(),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSkeletonLine(width: 120),
              _buildSkeletonLine(width: 80),
            ],
          ),
          const SizedBox(height: 12),
          _buildSkeletonLine(width: double.infinity, height: 12),
          const SizedBox(height: 8),
          _buildSkeletonLine(width: double.infinity, height: 12),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildSkeletonLine(width: 100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLine({required double width, double height = 16}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String errorMessage;
  final IconData icon;

  const _ErrorWidget({
    this.onRetry, 
    required this.errorMessage,
    this.icon = Icons.error_outline,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.error.withOpacity(0.8),
            ),
            const SizedBox(height: 24),
            Text(
              errorMessage,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'Tajawal',
                color: theme.textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Tajawal'),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrdersWidget extends StatelessWidget {
  const _EmptyOrdersWidget();
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد طلبات حالياً',
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'لم تقم بإجراء أي طلبات بعد. تصفح المنتجات وأضف ما تريده إلى سلة المشتريات.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Tajawal',
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to shopping screen
                Navigator.of(context).pushReplacementNamed('/shop');
              },
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text(
                'تسوق الآن',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
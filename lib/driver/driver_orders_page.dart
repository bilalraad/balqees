import 'package:balqees/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'driver_orders_controller.dart';
import 'driver_orders_ui_components.dart';

class DriverOrdersPage extends StatefulWidget {
  const DriverOrdersPage({super.key});

  @override
  State<DriverOrdersPage> createState() => _DriverOrdersPageState();
}

class _DriverOrdersPageState extends State<DriverOrdersPage> with SingleTickerProviderStateMixin {
  // UI state
  bool isLoading = true;
  bool _isRefreshing = false;
  bool isSearching = false;
  
  // Controllers
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late DriverOrdersController _ordersController;
  
  // Order lists
  List<DocumentSnapshot> availableOrders = [];
  List<DocumentSnapshot> myOrders = [];
  List<DocumentSnapshot> filteredAvailableOrders = [];
  List<DocumentSnapshot> filteredMyOrders = [];

  @override
  void initState() {
    super.initState();
    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    
    // Setup search controller
    _searchController.addListener(_filterOrders);
    
    // Initialize the controller
    _ordersController = DriverOrdersController(
      onOrdersLoaded: _updateOrdersLists,
      onError: _showSnackBar,
      onLoadingChanged: (isLoading) {
        if (mounted) {
          setState(() {
            this.isLoading = isLoading;
            _isRefreshing = isLoading;
          });
        }
      }
    );
    
    // Check if user is logged in and has rider role
    _checkAuth();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Update orders lists
  void _updateOrdersLists(List<DocumentSnapshot> newAvailableOrders, List<DocumentSnapshot> newMyOrders) {
    if (mounted) {
      setState(() {
        availableOrders = newAvailableOrders;
        myOrders = newMyOrders;
        filteredAvailableOrders = newAvailableOrders;
        filteredMyOrders = newMyOrders;
        isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  // Filter orders based on search text
  void _filterOrders() {
    final String searchText = _searchController.text.toLowerCase();
    
    setState(() {
      isSearching = searchText.isNotEmpty;
      
      if (searchText.isEmpty) {
        filteredAvailableOrders = availableOrders;
        filteredMyOrders = myOrders;
        return;
      }
      
      // Filter available orders
      filteredAvailableOrders = availableOrders.where((order) {
        final data = order.data() as Map<String, dynamic>;
        final orderId = order.id.toLowerCase();
        final storeName = (data['storeName'] ?? '').toString().toLowerCase();
        final customerName = (data['name'] ?? '').toString().toLowerCase();
        
        return orderId.contains(searchText) || 
               storeName.contains(searchText) || 
               customerName.contains(searchText);
      }).toList();
      
      // Filter my orders
      filteredMyOrders = myOrders.where((order) {
        final data = order.data() as Map<String, dynamic>;
        final orderId = order.id.toLowerCase();
        final storeName = (data['storeName'] ?? '').toString().toLowerCase();
        final customerName = (data['name'] ?? '').toString().toLowerCase();
        
        return orderId.contains(searchText) || 
               storeName.contains(searchText) || 
               customerName.contains(searchText);
      }).toList();
    });
  }

  // Check if user is authenticated and has rider privileges
  Future<void> _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isLoggedIn) {
      // Navigate to login page if not logged in
      _showErrorAndNavigate('يجب تسجيل الدخول لاستخدام صفحة السائق', '/login');
      return;
    }
    
    if (authProvider.role != 'rider') {
      // Navigate to home page if not a rider
      _showErrorAndNavigate('لا تملك صلاحيات كافية للوصول إلى صفحة السائق', '/');
      return;
    }
    
    // If authentication checks passed, initialize the controller
    _ordersController.initialize(context);
  }

  void _showErrorAndNavigate(String message, String route) {
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
        ),
      );
      Navigator.pushReplacementNamed(context, route);
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        backgroundColor: AppColors.burntBrown.withOpacity(0.9),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'إغلاق',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبات التوصيل'),
          centerTitle: true,
          backgroundColor: AppColors.burntBrown,
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isRefreshing ? null : () => _ordersController.loadOrders(),
            ),
          ],
        ),
        body: isLoading && !_isRefreshing ? 
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.burntBrown),
            ),
          ) : 
          Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث عن طلب...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty ? 
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ) : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.burntBrown),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              
              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.burntBrown,
                  labelColor: AppColors.burntBrown,
                  unselectedLabelColor: Colors.grey.shade600,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delivery_dining),
                          const SizedBox(width: 8),
                          const Text('الطلبات المتاحة'),
                          const SizedBox(width: 5),
                          if (filteredAvailableOrders.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.burntBrown,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${filteredAvailableOrders.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.motorcycle),
                          const SizedBox(width: 8),
                          const Text('طلباتي'),
                          const SizedBox(width: 5),
                          if (filteredMyOrders.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.burntBrown,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${filteredMyOrders.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tab contents
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Available orders tab
                    _buildAvailableOrdersList(),
                    
                    // My orders tab
                    _buildMyOrdersList(),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }
  
  // Build available orders list
  Widget _buildAvailableOrdersList() {
    if (_isRefreshing) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.burntBrown),
        ),
      );
    }
    
    if (filteredAvailableOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'لا توجد نتائج للبحث' : 'لا توجد طلبات متاحة حالياً',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _ordersController.loadOrders(),
      color: AppColors.burntBrown,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredAvailableOrders.length,
        itemBuilder: (context, index) {
          final order = filteredAvailableOrders[index];
          return DriverOrderCard(
            order: order,
            isMyOrder: false,
            controller: _ordersController,
            onTap: () => showOrderDetailsBottomSheet(
              context: context,
              order: order,
              ordersController: _ordersController,
            ),
          );
        },
      ),
    );
  }
  
  // Build my orders list
  Widget _buildMyOrdersList() {
    if (_isRefreshing) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.burntBrown),
        ),
      );
    }
    
    if (filteredMyOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delivery_dining, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'لا توجد نتائج للبحث' : 'لا توجد طلبات مقبولة حالياً',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _ordersController.loadOrders(),
      color: AppColors.burntBrown,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredMyOrders.length,
        itemBuilder: (context, index) {
          final order = filteredMyOrders[index];
          return DriverOrderCard(
            order: order,
            isMyOrder: true,
            controller: _ordersController,
            onTap: () => showOrderDetailsBottomSheet(
              context: context,
              order: order,
              ordersController: _ordersController,
            ),
          );
        },
      ),
    );
  }
}
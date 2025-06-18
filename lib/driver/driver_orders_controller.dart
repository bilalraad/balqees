import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';

class DriverOrdersController {
  // Callbacks
  final Function(List<DocumentSnapshot>, List<DocumentSnapshot>) onOrdersLoaded;
  final Function(String) onError;
  final Function(bool) onLoadingChanged;
  
  // Firestore references
  final CollectionReference ordersRef = FirebaseFirestore.instance.collection('orders');
  final CollectionReference usersRef = FirebaseFirestore.instance.collection('users');
  
  // State
  late BuildContext _context;
  Map<String, DocumentSnapshot> customerCache = {};
  
  DriverOrdersController({
    required this.onOrdersLoaded,
    required this.onError,
    required this.onLoadingChanged,
  });
  
  // Initialize the controller
  void initialize(BuildContext context) {
    _context = context;
    loadOrders();
  }
  
  // Load available and assigned orders
  Future<void> loadOrders() async {
    try {
      onLoadingChanged(true);
      
      final authProvider = Provider.of<AuthProvider>(_context, listen: false);
      
      // Load available orders (status = 'ready')
      final availableOrdersQuery = await ordersRef
          .where('status', isEqualTo: 'ready')
          .orderBy('createdAt', descending: true)
          .get();
      
      // Load my orders (assigned to this driver)
      final myOrdersQuery = await ordersRef
          .where('driverId', isEqualTo: authProvider.userId)
          .where('status', whereIn: ['accepted', 'picked', 'onway'])
          .orderBy('updatedAt', descending: true)
          .get();
      
      // Initialize lists
      final List<DocumentSnapshot> newAvailableOrders = availableOrdersQuery.docs;
      final List<DocumentSnapshot> newMyOrders = myOrdersQuery.docs;
      
      // Load customer data for all orders
      final Set<String> customerIds = {};
      
      // Collect all unique customer IDs from orders
      for (var doc in [...newAvailableOrders, ...newMyOrders]) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('customerId') && data['customerId'] != null) {
          customerIds.add(data['customerId'].toString());
        }
      }
      
      // Fetch all customers in batches
      if (customerIds.isNotEmpty) {
        await _fetchCustomerData(customerIds.toList());
      }
      
      // Update state with new orders through callback
      onOrdersLoaded(newAvailableOrders, newMyOrders);
      onLoadingChanged(false);
      
    } catch (e) {
      onLoadingChanged(false);
      onError('حدث خطأ أثناء تحميل الطلبات: ${e.toString()}');
    }
  }

  // Fetch customer data from Firestore
  Future<void> _fetchCustomerData(List<String> customerIds) async {
    if (customerIds.isEmpty) return;
    
    try {
      // Split into chunks of 10 for batched queries (Firestore limitation)
      for (var i = 0; i < customerIds.length; i += 10) {
        final end = (i + 10 < customerIds.length) ? i + 10 : customerIds.length;
        final batch = customerIds.sublist(i, end);
        
        // Query for this batch of customers
        final QuerySnapshot customersQuery = await usersRef
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        // Add to cache
        for (var doc in customersQuery.docs) {
          customerCache[doc.id] = doc;
        }
      }
    } catch (e) {
      print('Error fetching customer data: ${e.toString()}');
    }
  }

  // Get customer information from cache or Firestore
  Future<Map<String, dynamic>?> getCustomerInfo(String customerId) async {
    try {
      // Check cache first
      if (customerCache.containsKey(customerId)) {
        return customerCache[customerId]!.data() as Map<String, dynamic>;
      }
      
      // If not in cache, fetch from Firestore
      final userDoc = await usersRef.doc(customerId).get();
      if (userDoc.exists) {
        customerCache[customerId] = userDoc;
        return userDoc.data() as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      print('Error fetching customer info: ${e.toString()}');
      return null;
    }
  }

  // Accept an order
  Future<void> acceptOrder(String orderId) async {
    try {
      onLoadingChanged(true);

      final authProvider = Provider.of<AuthProvider>(_context, listen: false);

      // Update order status in Firestore
      await ordersRef.doc(orderId).update({
        'status': 'accepted',
        'driverId': authProvider.userId,
        'driverName': authProvider.name,
        'driverPhone': authProvider.phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get updated order data
      DocumentSnapshot orderDoc = await ordersRef.doc(orderId).get();
      Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;

      // Send notification to customer
      if (orderData.containsKey('customerId')) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': orderData['customerId'],
          'title': 'تحديث الطلب',
          'body': 'قبل السائق طلبك وحاليا متوجه الى المطعم',
          'orderId': orderId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Show Waze dialog after acceptance
      _showWazeDialog();

      // Reload orders
      await loadOrders();
      onError('تم قبول الطلب بنجاح');
    } catch (e) {
      onError('حدث خطأ أثناء قبول الطلب: ${e.toString()}');
      onLoadingChanged(false);
    }
  }

  // Show Waze dialog
  // Show Waze dialog
void _showWazeDialog() {
  showDialog(
    context: _context,
    builder: (context) => AlertDialog(
      title: const Text('فتح تطبيق Waze'),
      content: const Text('هل تريد الانتقال إلى موقع المتجر عبر تطبيق Waze؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final Uri wazeUri = Uri.parse('waze://?ll=32.5955993,44.0135201&navigate=yes');
            final Uri webUri = Uri.parse('https://waze.com/ul?ll=32.5955993,44.0135201&navigate=yes');

            if (await canLaunchUrl(wazeUri)) {
              await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
            } else if (await canLaunchUrl(webUri)) {
              await launchUrl(webUri, mode: LaunchMode.externalApplication);
            } else {
              onError('تعذر فتح تطبيق Waze أو الموقع.');
            }
          },
          child: const Text('فتح Waze'),
        ),
      ],
    ),
  );
}


  // Update order status to "picked"
  Future<void> pickUpOrder(String orderId) async {
    try {
      onLoadingChanged(true);
      
      // Update status in Firestore
      await ordersRef.doc(orderId).update({
        'status': 'picked',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to customer
      DocumentSnapshot orderDoc = await ordersRef.doc(orderId).get();
      Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;
      
      if (orderData.containsKey('customerId')) {
        // Add notification to user's notifications
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': orderData['customerId'],
          'title': 'تحديث الطلب',
          'body': 'تم استلام طلبك والسائق متوجه اليك',
          'orderId': orderId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Refresh orders
      await loadOrders();
      
      onError('تم استلام الطلب من المتجر');
    } catch (e) {
      onError('حدث خطأ أثناء تحديث حالة الطلب: ${e.toString()}');
      onLoadingChanged(false);
    }
  }

  // Mark order as delivered
  Future<void> deliverOrder(String orderId) async {
    try {
      onLoadingChanged(true);
      
      // Update status in Firestore
      await ordersRef.doc(orderId).update({
        'status': 'delivered',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Send notification to customer
      DocumentSnapshot orderDoc = await ordersRef.doc(orderId).get();
      Map<String, dynamic> orderData = orderDoc.data() as Map<String, dynamic>;
      
      if (orderData.containsKey('customerId')) {
        // Add notification to user's notifications
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': orderData['customerId'],
          'title': 'تحديث الطلب',
          'body': 'تم توصيل طلبك بنجاح',
          'orderId': orderId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Refresh orders
      await loadOrders();
      
      onError('تم توصيل الطلب بنجاح');
    } catch (e) {
      onError('حدث خطأ أثناء تحديث حالة الطلب: ${e.toString()}');
      onLoadingChanged(false);
    }
  }

  // Contact the restaurant to cancel order
  Future<void> contactRestaurantForCancellation(String orderId, String storePhone) async {
    try {
      final Uri phoneUri = Uri.parse('tel:$storePhone');
if (await canLaunchUrl(phoneUri)) {
  await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
} else {
  onError('لا يمكن الاتصال بالمطعم');
}

    } catch (e) {
      onError('حدث خطأ أثناء محاولة الاتصال: ${e.toString()}');
    }
  }

  // Call customer
  Future<void> callCustomer(String phoneNumber) async {
    try {
      if (phoneNumber.isEmpty) {
        onError('رقم الهاتف غير متوفر');
        return;
      }
      
      final Uri phoneUri = Uri.parse('tel:$phoneNumber');
if (await canLaunchUrl(phoneUri)) {
  await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
} else {
  onError('لا يمكن الاتصال بالزبون');
}

    } catch (e) {
      onError('حدث خطأ أثناء محاولة الاتصال: ${e.toString()}');
    }
  }
}
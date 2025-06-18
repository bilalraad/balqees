import 'package:balqees/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_orders_controller.dart';
import 'driver_orders_models.dart';

/// Order card widget for list display
class DriverOrderCard extends StatelessWidget {
  final DocumentSnapshot order;
  final bool isMyOrder;
  final VoidCallback onTap;
  final DriverOrdersController controller;
  
  const DriverOrderCard({
    Key? key,
    required this.order,
    required this.isMyOrder,
    required this.onTap,
    required this.controller,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final data = order.data() as Map<String, dynamic>;
    final orderId = order.id;
    final status = data['status'] as String;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header with ID and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلب #${orderId.substring(0, 6)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      getStatusText(status),
                      style: TextStyle(
                        color: getStatusColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Divider
              Divider(color: Colors.grey.shade200),
              
              const SizedBox(height: 8),
              
              // Store info
              Row(
                children: [
                  Icon(Icons.store_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['storeName'] ?? 'مطبخ بلقيس',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Customer info
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['name'] ?? 'غير محدد',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Order amount and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.attach_money, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        '${formatPrice(data['total'])} دينار عراقي',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.burntBrown,
                        ),
                      ),
                    ],
                  ),
                  
                  Text(
                    formatDate(data['createdAt']),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              
              // Action buttons based on status
              if (!isMyOrder && status == 'ready')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: buildActionButton(
                    text: 'قبول الطلب',
                    icon: Icons.check_circle_outline,
                    color: AppColors.burntBrown,
                    onPressed: () => controller.acceptOrder(orderId),
                  ),
                )
              else if (isMyOrder && status == 'accepted')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: buildActionButton(
                    text: 'تم استلام الطلب من المتجر',
                    icon: Icons.delivery_dining,
                    color: Colors.blue.shade600,
                    onPressed: () => controller.pickUpOrder(orderId),
                  ),
                )
              else if (isMyOrder && status == 'picked')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: buildActionButton(
                    text: 'تم توصيل الطلب',
                    icon: Icons.check_circle,
                    color: Colors.green.shade600,
                    onPressed: () => controller.deliverOrder(orderId),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Build action button
  Widget buildActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Order details bottom sheet
void showOrderDetailsBottomSheet({
  required BuildContext context,
  required DocumentSnapshot order,
  required DriverOrdersController ordersController,
}) {
  final data = order.data() as Map<String, dynamic>;
  final orderId = order.id;
  final status = data['status'] as String;
  final customerId = data['uuid'];
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: FutureBuilder(
          future: ordersController.getCustomerInfo(customerId),
          builder: (context, snapshot) {
            // Default customer info
            String name = data['name'] ?? 'غير محدد';
            String phone = data['phone'] ?? '';
            String address = data['Address'] ?? 'غير محدد';
            
            // If we have customer data from users collection, use it
            if (snapshot.hasData && snapshot.data != null) {
              final customerData = snapshot.data as Map<String, dynamic>;
              name = customerData['name'] ?? name;
              phone = customerData['phone'] ?? phone;
              address = customerData['address'] ?? address;
            }
            
            return Column(
              children: [
                // Handle and close button
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      height: 5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    
                    // Header with status badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFFEEEEEE),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: getStatusColor(status).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  getStatusIcon(status),
                                  color: getStatusColor(status),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'طلب #${orderId.substring(0, 6)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(status).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      getStatusText(status),
                                      style: TextStyle(
                                        color: getStatusColor(status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          // Close button
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.black54,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Order details content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        
                        // Customer Info Card
                        buildInfoCard(
                          title: 'معلومات العميل',
                          iconData: Icons.person_rounded,
                          iconColor: Colors.blue,
                          children: [
                            buildInfoItem(Icons.person_outline_rounded, 'الاسم:', name),
                            buildInfoItem(Icons.phone_outlined, 'رقم الهاتف:', phone),
                            buildInfoItem(Icons.location_on_outlined, 'العنوان:', address),
                            
                            // Call button and Waze navigation button
                            Row(
                              children: [
                                if (phone.isNotEmpty)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10, right: 5),
                                      child: InkWell(
                                        onTap: () => ordersController.callCustomer(phone),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.green.shade200),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.call_outlined, color: Colors.green.shade700, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                'اتصال بالعميل',
                                                style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Waze navigation button if address contains coordinates
                                if (containsCoordinates(address))
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10, left: 5),
                                      child: InkWell(
                                        onTap: () => openWazeNavigation(address),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.directions, color: Colors.blue.shade700, size: 18),
                                              const SizedBox(width: 8),
                                              Text(
                                                'الملاحة عبر Waze',
                                                style: TextStyle(
                                                  color: Colors.blue.shade700,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Store Info Card
                        buildInfoCard(
                          title: 'معلومات المتجر',
                          iconData: Icons.store_rounded,
                          iconColor: Colors.orange.shade700,
                          children: [
                            buildInfoItem(Icons.storefront_outlined, 'اسم المتجر:', data['storeName'] ?? 'مطبخ بلقيس'),
                            buildInfoItem(Icons.location_on_outlined, 'عنوان المتجر:', data['storeAddress'] ?? 'العراق محافظة كربلاء المقدسة '),
                            buildInfoItem(Icons.phone_outlined, 'رقم الهاتف:', data['storePhone'] ?? '07809114499'),
                            
                            // Call store button
                            if (data['storePhone'] != null && data['storePhone'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: InkWell(
                                  onTap: () => ordersController.callCustomer(data['storePhone'].toString()),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.call_outlined, color: Colors.orange.shade700, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'اتصال بالمتجر',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Order Info Card
                        buildInfoCard(
                          title: 'معلومات الطلب',
                          iconData: Icons.receipt_long_rounded,
                          iconColor: AppColors.burntBrown,
                          children: [
                            buildInfoItem(Icons.numbers_outlined, 'رقم الطلب:', orderId),
                            buildInfoItem(Icons.category_outlined, 'حالة الطلب:', getStatusText(status)),
                            buildInfoItem(Icons.payment_outlined, 'طريقة الدفع:', data['paymentMethod'] ?? 'غير محدد'),
                            buildInfoItem(Icons.attach_money_outlined, 'المبلغ الإجمالي:', '${formatPrice(data['total'])} دينار عراقي'),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Order Items Card
                        if (data['items'] != null && (data['items'] as List).isNotEmpty)
                          buildInfoCard(
                            title: 'العناصر المطلوبة',
                            iconData: Icons.shopping_bag_rounded,
                            iconColor: Colors.purple.shade600,
                            children: [
                              ...List.generate((data['items'] as List).length, (index) {
                                final item = data['items'][index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['name'] ?? 'منتج',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${item['quantity'] ?? 1} × ${formatPrice(item['price'])} دينار عراقي',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              
                              // Total
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'المجموع:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${formatPrice(data['total'])} دينار عراقي',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.burntBrown,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        
                        // Notes if available
                        if (data['notes'] != null && data['notes'].toString().isNotEmpty) 
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 15),
                              buildInfoCard(
                                title: 'ملاحظات',
                                iconData: Icons.note_alt_rounded,
                                iconColor: Colors.teal.shade600,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      data['notes'].toString(),
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        
                        const SizedBox(height: 100), // Space for buttons
                      ],
                    ),
                  ),
                ),
                
                // Action buttons
                if (status != 'delivered')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'ready')
                          buildBottomSheetActionButton(
                            text: 'قبول الطلب',
                            icon: Icons.check_circle_outline_rounded,
                            color: AppColors.burntBrown,
                            onPressed: () {
                              Navigator.pop(context);
                              ordersController.acceptOrder(orderId);
                            },
                          )
                        else if (status == 'accepted')
                          GestureDetector(
                            onLongPress: () {
                              Navigator.pop(context);
                              ordersController.pickUpOrder(orderId);
                            },
                            child: buildBottomSheetActionButton(
                              text: 'تم استلام الطلب من المتجر',
                              icon: Icons.delivery_dining_rounded,
                              color: Colors.blue.shade600,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('اضغط مطولاً للتأكيد على استلام الطلب من المتجر'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    margin: const EdgeInsets.all(10),
                                  ),
                                );
                              },
                            ),
                          )
                        else if (status == 'picked' || status == 'onway')
                          GestureDetector(
                            onLongPress: () {
                              Navigator.pop(context);
                              ordersController.deliverOrder(orderId);
                            },
                            child: buildBottomSheetActionButton(
                              icon: Icons.check_circle_rounded,
                              color: Colors.green.shade600,
                              text: 'تم توصيل الطلب',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('اضغط مطولاً للتأكيد على تسليم الطلب'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    margin: const EdgeInsets.all(10),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                        // Cancel button (for all statuses except delivered)
                        if (status != 'delivered')
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: GestureDetector(
                              onLongPress: () {
                                Navigator.pop(context);
                                ordersController.contactRestaurantForCancellation(orderId, data['storePhone'] ?? '');
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cancel_outlined,
                                      color: Colors.red.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'إلغاء الطلب',
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      );
    },
  );
}

// Helper method to build action buttons in bottom sheet
Widget buildBottomSheetActionButton({
  required String text,
  required IconData icon,
  required Color color,
  required VoidCallback onPressed,
}) {
  return Container(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
}

// Build info card widget
Widget buildInfoCard({
  required String title,
  required IconData iconData,
  required Color iconColor,
  required List<Widget> children,
}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card header
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        
        // Divider
        Divider(
          color: Colors.grey.shade200,
          thickness: 1,
          height: 1,
        ),
        
        // Card content
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    ),
  );
}

// Build info item widget
Widget buildInfoItem(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}

// Helper method to format price by removing decimal zeros
String formatPrice(dynamic price) {
  if (price == null) return '0';
  
  // Convert to string if it's not already
  String priceStr = price.toString();
  
  // If the price has a decimal part with only zeros, remove it
  if (priceStr.contains('.')) {
    // Split by decimal point
    List<String> parts = priceStr.split('.');
    
    // Check if the decimal part is only zeros
    if (parts[1] == '0' || parts[1] == '00') {
      return parts[0]; // Return only the integer part
    }
  }
  
  return priceStr;
}

// Helper method to check if a string contains coordinates
bool containsCoordinates(String text) {
  // Regular expression to match common coordinate formats
  // This pattern will match formats like:
  // 32.1234, 45.6789
  // 32.1234,45.6789
  // 32.1234 45.6789
  final RegExp coordPattern = RegExp(
    r'[-+]?([1-8]?\d(\.\d+)?|90(\.0+)?),\s*[-+]?(180(\.0+)?|((1[0-7]\d)|([1-9]?\d))(\.\d+)?)',
    caseSensitive: false,
  );
  
  return coordPattern.hasMatch(text);
}
// Helper method to open Waze with the given coordinates
Future<void> openWazeNavigation(String address) async {
  try {
    final RegExp coordPattern = RegExp(
      r'([-+]?[0-9]*\.?[0-9]+),\s*([-+]?[0-9]*\.?[0-9]+)',
      caseSensitive: false,
    );

    final match = coordPattern.firstMatch(address);
    if (match != null && match.groupCount >= 2) {
      final lat = match.group(1);
      final lng = match.group(2);

      final Uri wazeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      final Uri webUri = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');

      if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        print('تعذر فتح Waze أو الموقع.');
      }
    } else {
      print('العنوان لا يحتوي على إحداثيات صحيحة.');
    }
  } catch (e) {
    print('خطأ أثناء محاولة فتح Waze: $e');
  }
}

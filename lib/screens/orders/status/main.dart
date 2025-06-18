import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';

class OrderStatusPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic>? initialOrderData;

  const OrderStatusPage({
    super.key, 
    required this.orderId,
    this.initialOrderData,
  });

  // Define our theme colors
  static const Color primaryColor = Color(0xFFF7931E); // Orange
  static const Color secondaryColor = Color(0xFF994C1F); // Brown
  static const Color tertiaryColor = Color(0xFFFCE5B1); // Light Beige
  static const Color textDarkColor = Color(0xFF333333);
  static const Color textLightColor = Color(0xFFFFFBF5);

  @override
  Widget build(BuildContext context) {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    return Scaffold(
      backgroundColor: tertiaryColor.withOpacity(0.3),
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: textLightColor,
        title: const Text('تتبع حالة الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, size: 28),
            tooltip: 'اتصل بنا للمساعدة',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('اتصل بخدمة العملاء', textAlign: TextAlign.center),
                  content: const Text('هل تواجه مشكلة في طلبك؟ يمكنك التواصل معنا مباشرة.'),
                  actions: [
                    TextButton(
                      child: const Text('إغلاق'),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.phone),
                      label: const Text('اتصل الآن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: textLightColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        // TODO: تنفيذ الاتصال برقم خدمة العملاء
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: initialOrderData != null
          ? _buildOrderDetails(context, initialOrderData!)
          : StreamBuilder<DocumentSnapshot>(
              stream: orderRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: secondaryColor,
                          backgroundColor: tertiaryColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'جاري تحميل تفاصيل الطلب...',
                          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }
                
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
                          const SizedBox(height: 24),
                          const Text('لم يتم العثور على الطلب', 
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          const Text('تأكد من صحة رقم الطلب المدخل', 
                            style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('العودة للرئيسية', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: textLightColor,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 2,
                            ),
                            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final order = snapshot.data!.data() as Map<String, dynamic>;
                return _buildOrderDetails(context, order);
              },
            ),
    );
  }

  // بناء تفاصيل الطلب
  Widget _buildOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final items = List.from(order['items'] ?? []);
    final date = (order['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final deliveryAddress = order['address'] as Map<String, dynamic>?;
    final total = order['total'] ?? 0;
    
    // تنسيق التاريخ
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm', 'ar').format(date);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // بطاقة معلومات الطلب الرئيسية
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: tertiaryColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: tertiaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_long, color: secondaryColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طلب #${orderId.substring(orderId.length - 6)}',
                              style: const TextStyle(
                                fontSize: 20, 
                                fontWeight: FontWeight.bold,
                                color: secondaryColor,
                              ),
                            ),
                            Text(
                              formattedDate, 
                              style: TextStyle(color: Colors.grey[600], fontSize: 13)
                            ),
                          ],
                        ),
                      ],
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إجمالي المبلغ:', 
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w500,
                          color: secondaryColor
                        )
                      ),
                      Text(
                        '$total د.ع', 
                        style: const TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: secondaryColor
                        )
                      ),
                    ],
                  ),
                ),
                
                // إضافة زر تقييم الطلب إذا كان مكتملاً
                if (status == 'تم التسليم') ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.star_border, color: primaryColor),
                    label: const Text(
                      'تقييم الطلب', 
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      )
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                      side: const BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      // العودة إلى صفحة الطلبات والطلب من المستخدم التقييم
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يمكنك تقييم الطلب من صفحة الطلبات',
                            style: TextStyle(fontFamily: 'Tajawal'),
                          ),
                          backgroundColor: secondaryColor,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          ),
          
          // المؤقت الزمني لحالة الطلب
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: tertiaryColor, width: 1),
            ),
            child: _buildStatusTimeline(status),
          ),
          
          // قائمة المنتجات
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: tertiaryColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shopping_bag, color: secondaryColor),
                      SizedBox(width: 10),
                      Text(
                        'المنتجات', 
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: secondaryColor,
                        )
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1, 
                    color: Colors.grey.withOpacity(0.2),
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: Container(
                        width: 55,
                        height: 55,
                        decoration: BoxDecoration(
                          color: tertiaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${item['quantity']}x', 
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: secondaryColor,
                            )
                          ),
                        ),
                      ),
                      title: Text(
                        item['name'] ?? 'منتج',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: item['notes'] != null && item['notes'].toString().isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                'ملاحظات: ${item['notes']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : null,
                      trailing: Text(
                        '${(item['price'] ?? 0) * (item['quantity'] ?? 1)} د.ع',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryColor,
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Divider(color: Colors.grey.withOpacity(0.3), thickness: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي:', 
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: secondaryColor,
                            )
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: primaryColor.withOpacity(0.5), width: 1),
                            ),
                            child: Text(
                              '$total د.ع', 
                              style: const TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold, 
                                color: primaryColor,
                              )
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // معلومات التوصيل
          if (deliveryAddress != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: secondaryColor.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: tertiaryColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.location_on, color: primaryColor),
                        SizedBox(width: 10),
                        Text(
                          'عنوان التوصيل', 
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: secondaryColor,
                          )
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAddressRow(Icons.location_city, 'المدينة:', '${deliveryAddress['city'] ?? ''}'),
                        const SizedBox(height: 10),
                        _buildAddressRow(Icons.map, 'الشارع:', '${deliveryAddress['street'] ?? ''}'),
                        if (deliveryAddress['building'] != null) ...[
                          const SizedBox(height: 10),
                          _buildAddressRow(Icons.home, 'المبنى:', '${deliveryAddress['building']}'),
                        ],
                        if (deliveryAddress['floor'] != null) ...[
                          const SizedBox(height: 10),
                          _buildAddressRow(Icons.stairs, 'الطابق:', '${deliveryAddress['floor']}'),
                        ],
                        if (deliveryAddress['apartment'] != null) ...[
                          const SizedBox(height: 10),
                          _buildAddressRow(Icons.door_front_door, 'الشقة:', '${deliveryAddress['apartment']}'),
                        ],
                        if (deliveryAddress['notes'] != null) ...[
                          const SizedBox(height: 10),
                          _buildAddressRow(Icons.note, 'ملاحظات:', '${deliveryAddress['notes']}'),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('عرض الموقع على الخريطة', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: secondaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: () {
                            // TODO: فتح الخريطة لعرض الموقع
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // أزرار الإجراءات
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: tertiaryColor, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إجراءات سريعة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة الطلب', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                    ),
                    onPressed: () {
                      // TODO: تنفيذ عملية إعادة الطلب
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('إعادة الطلب', textAlign: TextAlign.center),
                          content: const Text('هل ترغب في إعادة طلب نفس المنتجات؟'),
                          actions: [
                            TextButton(
                              child: const Text('إلغاء'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            ElevatedButton(
                              child: const Text('نعم، إعادة الطلب'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                // TODO: تنفيذ إعادة الطلب
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('تمت إضافة المنتجات إلى السلة'),
                                    backgroundColor: secondaryColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.headset_mic, color: secondaryColor),
                    label: const Text(
                      'التواصل مع خدمة العملاء', 
                      style: TextStyle(
                        fontSize: 16,
                        color: secondaryColor,
                      )
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      side: const BorderSide(color: secondaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      // TODO: تنفيذ الاتصال بخدمة العملاء
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // صف عنوان التوصيل
  Widget _buildAddressRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tertiaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: secondaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // بناء الشريط الزمني لحالة الطلب
  Widget _buildStatusTimeline(String currentStatus) {
    final statuses = [
      {'status': 'pending', 'label': 'قيد المعالجة', 'icon': Icons.receipt_long},
      {'status': 'preparing', 'label': 'قيد التحضير', 'icon': Icons.restaurant},
      {'status': 'ready', 'label': 'جاهز للتسليم', 'icon': Icons.delivery_dining},
      {'status': 'delivered', 'label': 'تم التسليم', 'icon': Icons.check_circle},
    ];
    
    int currentStep = 0;
    
    switch (currentStatus) {
      case 'pending':
        currentStep = 0;
        break;
      case 'preparing':
        currentStep = 1;
        break;
      case 'ready':
        currentStep = 2;
        break;
      case 'delivered':
      case 'تم التسليم':
        currentStep = 3;
        break;
      case 'cancelled':
        return _buildCancelledStatus();
      default:
        currentStep = 0;
    }
    
    return Column(
      children: [
        for (int i = 0; i < statuses.length; i++)
          TimelineTile(
            alignment: TimelineAlign.manual,
            lineXY: 0.1,
            isFirst: i == 0,
            isLast: i == statuses.length - 1,
            indicatorStyle: IndicatorStyle(
              width: 40,
              height: 40,
              indicator: _buildIndicator(i <= currentStep, statuses[i]['icon'] as IconData),
              drawGap: true,
            ),
            beforeLineStyle: LineStyle(
              color: i <= currentStep ? primaryColor : Colors.grey.shade300,
              thickness: 3,
            ),
            afterLineStyle: LineStyle(
              color: i < currentStep ? primaryColor : Colors.grey.shade300,
              thickness: 3,
            ),
            endChild: Container(
              constraints: const BoxConstraints(minHeight: 80),
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: i <= currentStep 
                  ? i == currentStep 
                    ? primaryColor.withOpacity(0.1) 
                    : tertiaryColor.withOpacity(0.7)
                  : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: i == currentStep
                  ? Border.all(color: primaryColor.withOpacity(0.5), width: 1.5)
                  : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statuses[i]['label'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: i <= currentStep 
                        ? i == currentStep ? primaryColor : secondaryColor
                        : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStatusDescription(statuses[i]['status'] as String),
                    style: TextStyle(
                      color: i <= currentStep ? textDarkColor : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  if (i == currentStep) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'الحالة الحالية',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  // بناء حالة إلغاء الطلب
  Widget _buildCancelledStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.cancel, color: Colors.red, size: 64),
          const SizedBox(height: 20),
          const Text(
            'تم إلغاء الطلب',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 12),
          const Text(
            'لمزيد من المعلومات، يرجى التواصل مع خدمة العملاء',
            style: TextStyle(color: Colors.black87, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.support_agent),
            label: const Text('التواصل مع خدمة العملاء', style: TextStyle(fontSize: 16)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.red, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
              // TODO: تنفيذ الاتصال بخدمة العملاء
            },
          ),
        ],
      ),
    );
  }
  
  // بناء مؤشر للشريط الزمني
  Widget _buildIndicator(bool isActive, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? primaryColor : Colors.grey.shade400,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: isActive ? [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
  
  // الحصول على وصف حالة الطلب
  String _getStatusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'تم استلام طلبك وهو قيد المراجعة.';
      case 'preparing':
        return 'يتم الآن تحضير وجبتك بكل عناية.';
      case 'ready':
        return 'طلبك جاهز وفي طريقه إليك، ترقب وصوله قريباً.';
      case 'delivered':
        return 'تم توصيل طلبك بنجاح! نتمنى لك وجبة شهية.';
      default:
        return '';
    }
  }
  
  // بناء رقاقة الحالة
  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    IconData icon;
    
    switch (status) {
      case 'pending':
        color = const Color(0xFFFF9800); // Orange
        label = 'قيد المعالجة';
        icon = Icons.hourglass_empty;
        break;
      case 'preparing':
        color = const Color(0xFF2196F3); // Blue
        label = 'قيد التحضير';
        icon = Icons.restaurant;
        break;
      case 'ready':
        color = const Color(0xFF673AB7); // Purple
        label = 'جاهز للتسليم';
        icon = Icons.delivery_dining;
        break;
      case 'delivered':
      case 'تم التسليم':
        color = const Color(0xFF4CAF50); // Green
        label = 'تم التسليم';
        icon = Icons.check_circle;
        break;
      case 'cancelled':
      case 'ملغي':
        color = const Color(0xFFF44336); // Red
        label = 'ملغي';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
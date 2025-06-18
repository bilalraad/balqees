import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // لـ Timestamp
import 'package:intl/intl.dart';

class OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> order;

  const OrderCard({
    super.key,
    required this.orderId,
    required this.order,
  });

  String formatDateFromTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final dayName = DateFormat('EEEE', 'ar').format(date); // يوم الاثنين
    final dateText = DateFormat('d MMMM', 'ar').format(date); // 15 أبريل
    return 'طلب بتاريخ $dateText - $dayName';
  }

  String formatTotal(num total) {
    return total % 1 == 0 ? total.toInt().toString() : total.toString();
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'قيد المعالجة';
    final total = order['total'] ?? 0;
    final itemCount = (order['items'] as List?)?.length ?? 0;
    final createdAt = order['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null
        ? formatDateFromTimestamp(createdAt)
        : 'طلب بدون تاريخ';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const Icon(Icons.receipt_long, color: Colors.blue),
        title: Text(
          formattedDate,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('الحالة: $status'),
            Text('عدد العناصر: $itemCount'),
            Text('المجموع: ${formatTotal(total)} د.ع'),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.pushNamed(context, '/order-status/$orderId');
        },
      ),
    );
  }
}

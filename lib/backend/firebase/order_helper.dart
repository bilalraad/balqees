import 'package:cloud_firestore/cloud_firestore.dart';

class OrderHelper {
  static final CollectionReference ordersRef =
      FirebaseFirestore.instance.collection('orders');

  static Future<String> createOrder({
    required String uuid,
    required List<Map<String, dynamic>> items,
    required double total,
    required String address,
  }) async {
    final order = {
      'uuid': uuid,
      'items': items,
      'total': total,
      'status': 'قيد التحضير',
      'address': address,
      'created_at': DateTime.now().toIso8601String(),
    };

    final doc = await ordersRef.add(order);
    return doc.id;
  }

  static Stream<DocumentSnapshot> trackOrder(String orderId) {
    return ordersRef.doc(orderId).snapshots();
  }

  static Future<void> updateOrderStatus(String orderId, String status) async {
    await ordersRef.doc(orderId).update({'status': status});
  }
}

// lib/services/coupon_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class CouponService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // التحقق من صلاحية كوبون الخصم
  Future<Map<String, dynamic>?> validateCoupon(String code) async {
    try {
      // البحث عن الكوبون في Firestore
      final QuerySnapshot couponSnapshot = await _firestore
        .collection('discounts')
        .where('couponCode', isEqualTo: code)
        .get();
      
      // التحقق من وجود كوبون بهذا الكود
      if (couponSnapshot.docs.isEmpty) {
        return null; // الكوبون غير موجود
      }
      
      // الحصول على بيانات الكوبون
      final couponDoc = couponSnapshot.docs.first;
      final couponData = couponDoc.data() as Map<String, dynamic>;
      
      // التحقق من أن الكوبون نشط
      if (couponData['isActive'] != true) {
        return null; // الكوبون غير نشط
      }
      
      // التحقق من تاريخ انتهاء الكوبون
      if (couponData.containsKey('expiryDate') && couponData['expiryDate'] != null) {
        final Timestamp expiryTimestamp = couponData['expiryDate'];
        final DateTime expiryDate = expiryTimestamp.toDate();
        
        if (expiryDate.isBefore(DateTime.now())) {
          return null; // الكوبون منتهي الصلاحية
        }
      }
      
      // إعادة بيانات الكوبون الصالح
      return {
        'id': couponDoc.id,
        'code': couponData['couponCode'],
        'name': couponData['name'] ?? 'كوبون خصم',
        'percentage': couponData['percentage'] ?? 0.0,
        'expiryDate': couponData.containsKey('expiryDate') && couponData['expiryDate'] != null
                     ? couponData['expiryDate'].toDate() 
                     : null,
        'description': couponData['description'] ?? '',
      };
    } catch (e) {
      print('Error validating coupon: $e');
      return null;
    }
  }
}
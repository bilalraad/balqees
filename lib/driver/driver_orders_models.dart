import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper functions for order status handling and formatting

// Get status color
Color getStatusColor(String status) {
  switch (status) {
    case 'ready':
      return Colors.blue;
    case 'accepted':
      return Colors.orange;
    case 'picked':
      return Colors.purple;
    case 'onway':
      return Colors.indigo;
    case 'delivered':
      return Colors.green;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

// Get status icon
IconData getStatusIcon(String status) {
  switch (status) {
    case 'ready':
      return Icons.inventory_2_outlined;
    case 'accepted':
      return Icons.directions_bike_outlined;
    case 'picked':
      return Icons.delivery_dining_outlined;
    case 'onway':
      return Icons.local_shipping_outlined;
    case 'delivered':
      return Icons.check_circle_outline;
    case 'cancelled':
      return Icons.cancel_outlined;
    default:
      return Icons.help_outline;
  }
}

// Get status text
String getStatusText(String status) {
  switch (status) {
    case 'ready':
      return 'جاهز للتوصيل';
    case 'accepted':
      return 'تم قبول الطلب';
    case 'picked':
      return 'تم استلام الطلب من المتجر';
    case 'onway':
      return 'جاري التوصيل';
    case 'delivered':
      return 'تم التوصيل';
    case 'cancelled':
      return 'ملغي';
    default:
      return 'غير معروف';
  }
}

// Format date
String formatDate(dynamic timestamp) {
  if (timestamp == null) return 'غير محدد';
  
  DateTime dateTime;
  if (timestamp is Timestamp) {
    dateTime = timestamp.toDate();
  } else {
    return 'غير محدد';
  }
  
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}
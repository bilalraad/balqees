import 'package:flutter/material.dart';

enum OrderStatus {
  pending,
  preparing,
  accepted,
  picked,
  ready,
  delivered,
  cancelled,
}

class OrderModel {
  final String id;
  final OrderStatus status;
  final DateTime updatedAt;

  OrderModel({
    required this.id,
    required this.status,
    required this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['orderId'] ?? '',
      status: _parseStatus(json['status']),
      updatedAt: DateTime.now(),
    );
  }

  static OrderStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'preparing':
        return OrderStatus.preparing;
      case 'accepted':
        return OrderStatus.accepted;
      case 'picked':
        return OrderStatus.picked;
      case 'ready':
        return OrderStatus.ready;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

class OrdersProvider with ChangeNotifier {
  List<OrderModel> _orders = [];

  List<OrderModel> get orders => _orders;

  void updateOrder(OrderModel order) {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      _orders[index] = order;
    } else {
      _orders.add(order);
    }
    notifyListeners();
  }

  OrderModel? getOrderById(String id) {
    try {
      return _orders.firstWhere((order) => order.id == id);
    } catch (_) {
      return null;
    }
  }
}

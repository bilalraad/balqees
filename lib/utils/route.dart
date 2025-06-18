import 'package:balqees/driver/driver_orders_page.dart';
import 'package:balqees/screens/auth/login.dart';
import 'package:balqees/screens/auth/register.dart';
import 'package:balqees/screens/cart/interface.dart';
import 'package:balqees/screens/home/home_core.dart';
import 'package:balqees/screens/home/home_ui.dart';
import 'package:balqees/screens/orders/main.dart';
import 'package:balqees/screens/orders/status/main.dart';
import 'package:balqees/screens/profile/main.dart';
import 'package:balqees/widgets/splash_loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:balqees/providers/cart_provider.dart';

class RouteManager {
  static final HomeCore _homeCore = HomeCore();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final routeName = settings.name;
    final args = settings.arguments;

    if (routeName != null && routeName.startsWith('/order-status/')) {
      final orderId = routeName.substring('/order-status/'.length);
      return MaterialPageRoute(
        builder: (_) => OrderStatusPage(orderId: orderId),
      );
    }

    switch (settings.name) {
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case '/register':
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      case '/':
        return MaterialPageRoute(builder: (_) => HomeUI(core: _homeCore));

      case '/orders':
        return MaterialPageRoute(builder: (_) => const OrdersPage());

      case '/order_status_page':
        // هنا نضيف المسار لصفحة حالة الطلب
        if (args is Map<String, dynamic>) {
          final orderId = args['orderId'] as String;
          final order = args['order'] as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (_) => OrderStatusPage(
              orderId: orderId,
              initialOrderData: order,
            ),
          );
        }
        // في حالة عدم وجود معرف للطلب، نعود للصفحة الرئيسية
        return MaterialPageRoute(builder: (_) => HomeUI(core: _homeCore));

      case '/driver':
        return MaterialPageRoute(builder: (_) => const DriverOrdersPage());

      case '/profile':
        return MaterialPageRoute(builder: (_) => const ProfilePage());

      case '/cart':
        return MaterialPageRoute(
          builder: (context) {
            final cartProvider = Provider.of<CartProvider>(context);
            return CartPage(
              cartItems: {
                for (var item in cartProvider.items)
                  item.productId: item.quantity,
              },
              products: _homeCore.allProducts.isEmpty
                  ? _homeCore.products
                  : _homeCore.allProducts,
              onUpdateQuantity: (productId, quantity) {
                if (quantity <= 0) {
                  cartProvider.removeItemById(productId);
                } else {
                  cartProvider.updateItemQuantity(productId, quantity);
                }
              },
              onRemoveItem: (productId) {
                cartProvider.removeItemById(productId);
              },
              onAddToCart: () {
                Navigator.pop(context);
              },
            );
          },
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('صفحة غير موجودة')),
          ),
        );
    }
  }
}

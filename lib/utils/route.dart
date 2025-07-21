import 'package:balqees/driver/driver_orders_page.dart';
import 'package:balqees/providers/auth_provider.dart';
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

  static Route<dynamic> generateRoute(
      RouteSettings settings, BuildContext context) {
    final routeName = settings.name;
    final args = settings.arguments;

    if (routeName != null && routeName.startsWith('/order-status/')) {
      final orderId = routeName.substring('/order-status/'.length);
      return MaterialPageRoute(
        builder: (_) => OrderStatusPage(orderId: orderId),
      );
    }

    final isLoggedIn =
        Provider.of<AuthProvider>(context, listen: false).isLoggedIn;

    MaterialPageRoute checkLoginStatus(Widget page) {
      if (isLoggedIn) {
        return MaterialPageRoute(builder: (_) => page);
      } else {
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
        );
      }
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
        return checkLoginStatus(OrdersPage());

      case '/order_status_page':
        // هنا نضيف المسار لصفحة حالة الطلب
        if (args is Map<String, dynamic>) {
          final orderId = args['orderId'] as String;
          final order = args['order'] as Map<String, dynamic>?;
          return checkLoginStatus(
            OrderStatusPage(
              orderId: orderId,
              initialOrderData: order,
            ),
          );
        }
        // في حالة عدم وجود معرف للطلب، نعود للصفحة الرئيسية
        return MaterialPageRoute(builder: (_) => HomeUI(core: _homeCore));

      case '/driver':
        return checkLoginStatus(const DriverOrdersPage());

      case '/profile':
        return checkLoginStatus(const ProfilePage());

      case '/cart':
        return checkLoginStatus(CartPage(
          cartItems: {
            for (var item
                in Provider.of<CartProvider>(context, listen: false).items)
              item.productId: item.quantity,
          },
          products: _homeCore.allProducts.isEmpty
              ? _homeCore.products
              : _homeCore.allProducts,
          onUpdateQuantity: (productId, quantity) {
            if (quantity <= 0) {
              Provider.of<CartProvider>(context, listen: false)
                  .removeItemById(productId);
            } else {
              Provider.of<CartProvider>(context, listen: false)
                  .updateItemQuantity(productId, quantity);
            }
          },
          onRemoveItem: (productId) {
            Provider.of<CartProvider>(context, listen: false)
                .removeItemById(productId);
          },
          onAddToCart: () {
            Navigator.pop(context);
          },
        ));

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('صفحة غير موجودة')),
          ),
        );
    }
  }
}

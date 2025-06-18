import 'package:flutter/material.dart';

class AppColors {
  // Main Brand Colors
  static const Color goldenOrange = Color(0xFFF59E0B); // اللون الأول - Primary brand color
  static const Color burntBrown = Color(0xFF92400E);   // اللون الثاني - Secondary brand color
  static const Color lightBeige = Color(0xFFFDEBCB);   // اللون الثالث - Background color
  
  // Alias for standard usage (to match previous code)
  static const Color primary = goldenOrange;
  static const Color secondary = burntBrown;
  static const Color background = lightBeige;
  
  // Extended UI Colors
  static const Color white = Colors.white;
  static const Color black = Colors.black87;
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color darkGrey = Color(0xFF616161);
  
  // Semantic Colors
  static const Color success = Color(0xFF22C55E);      // Green for success states
  static const Color error = Color(0xFFEF4444);        // Red for errors
  static const Color warning = Color(0xFFF97316);      // Orange for warnings
  static const Color info = Color(0xFF3B82F6);         // Blue for information
  
  // Status Colors (for orders)
  static const Color processing = Color(0xFFFCD34D);   // Yellow for processing
  static const Color confirmed = Color(0xFF22C55E);    // Green for confirmed
  static const Color shipping = Color(0xFF60A5FA);     // Blue for shipping
  static const Color delivered = Color(0xFF10B981);    // Teal for delivered
  static const Color cancelled = Color(0xFFF87171);    // Light red for cancelled
  
  // Additional UI Colors
  static const Color cardBackground = Colors.white;
  static const Color divider = Color(0xFFE5E7EB);
  static const Color inputBackground = Color(0xFFF9FAFB);
  static const Color inputBorder = Color(0xFFD1D5DB);
  static const Color shadow = Color(0x1A000000);       // 10% opacity black for shadows
  
  // Text Colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;
  static const Color textOnSecondary = Colors.white;
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [goldenOrange, Color(0xFFDB7C06)], // Darker variation
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [burntBrown, Color(0xFF6B3000)], // Darker variation
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Helper method to create opacity variations
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
  
  // Helper method for status colors based on order status string
  static Color getOrderStatusColor(String status) {
    switch (status) {
      case 'قيد المعالجة':
        return processing;
      case 'تم التأكيد':
        return confirmed;
      case 'قيد التوصيل':
        return shipping;
      case 'تم التسليم':
        return delivered;
      case 'ملغي':
        return cancelled;
      default:
        return grey;
    }
  }
  
  // Helper method for status background colors (lighter versions)
  static Color getOrderStatusBackgroundColor(String status) {
    switch (status) {
      case 'قيد المعالجة':
        return processing.withOpacity(0.1);
      case 'تم التأكيد':
        return confirmed.withOpacity(0.1);
      case 'قيد التوصيل':
        return shipping.withOpacity(0.1);
      case 'تم التسليم':
        return delivered.withOpacity(0.1);
      case 'ملغي':
        return cancelled.withOpacity(0.1);
      default:
        return grey.withOpacity(0.1);
    }
  }
  
  // Generate a Material color swatch from a single color
  static MaterialColor createMaterialColor(Color color) {
    List<double> strengths = <double>[.05, .1, .2, .3, .4, .5, .6, .7, .8, .9];
    Map<int, Color> swatch = {};
    
    final int r = color.red, g = color.green, b = color.blue;
    
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    
    return MaterialColor(color.value, swatch);
  }
  
  // Primary Swatch for MaterialApp theme
  static final MaterialColor primarySwatch = createMaterialColor(goldenOrange);
}
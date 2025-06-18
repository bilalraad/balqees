import 'package:flutter/material.dart';

class HomeCart {
  // Improved flying cart animation
  static Widget buildFlyingCartAnimation(
    Offset? cartIconPosition,
    Animation<double> animation,
    AnimationController controller
  ) {
    if (cartIconPosition == null) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (animation.value == 0.0 || animation.value == 1.0) {
          return const SizedBox.shrink();
        }
        
        // Get the current tap position from the Overlay
        final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        final Size overlaySize = overlay.size;
        
        // Calculate path for a curved animation
        // Starting point (a bit up from wherever the product was tapped)
        final double startX = overlaySize.width / 2;
        final double startY = overlaySize.height * 0.6;
        
        // Control point for the quadratic bezier curve (higher to create an arc)
        final double controlX = (startX + cartIconPosition.dx) / 2;
        final double controlY = startY - 100; // Higher point for the arc
        
        // End point (cart icon position)
        final double endX = cartIconPosition.dx;
        final double endY = cartIconPosition.dy;
        
        // Calculate the current position using a quadratic bezier curve
        final double t = animation.value;
        final double currentX = _calculateBezierPoint(t, startX, controlX, endX);
        final double currentY = _calculateBezierPoint(t, startY, controlY, endY);
        
        // Make the animation more interesting
        // Scale down as it approaches the cart
        final double scale = 1.0 - animation.value * 0.7;
        // Fade out slightly as it approaches the cart
        final double opacity = animation.value < 0.8 ? 1.0 : 5.0 * (1.0 - animation.value);
        
        return Positioned(
          left: currentX - 15 * scale, // Center the icon
          top: currentY - 15 * scale,  // Center the icon
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shopping_cart,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Helper function to calculate a point on a quadratic bezier curve
  static double _calculateBezierPoint(double t, double start, double control, double end) {
    return (1 - t) * (1 - t) * start + 2 * (1 - t) * t * control + t * t * end;
  }
}
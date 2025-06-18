import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:balqees/providers/auth_provider.dart' as auth_provider;
import 'package:intl/intl.dart'; // For better date formatting

/// بطاقة الطلب التي تدعم التقييم - واجهة محسنة
class RatableOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> order;

  const RatableOrderCard({
    Key? key,
    required this.orderId,
    required this.order,
  }) : super(key: key);

  @override
  State<RatableOrderCard> createState() => _RatableOrderCardState();
}

class _RatableOrderCardState extends State<RatableOrderCard> {
  bool _isRated = false;
  int? _userRating;
  String? _userComment;
  bool _isLoading = true;
  final GlobalKey _cardKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _checkExistingRating();
  }

  /// فحص إذا كان المستخدم قد قيّم الطلب مسبقاً
  Future<void> _checkExistingRating() async {
    try {
      final ratingDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .collection('ratings')
          .doc('userRating')
          .get();

      if (mounted) {
        setState(() {
          _isRated = ratingDoc.exists;
          if (ratingDoc.exists) {
            final data = ratingDoc.data();
            _userRating = data?['rating'];
            _userComment = data?['comment'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// إرسال تقييم المستخدم للطلب
  Future<void> _submitRating(int rating, String comment) async {
    final auth = Provider.of<auth_provider.AuthProvider>(context, listen: false);
    if (!auth.isLoggedIn) {
      _showLoginPrompt();
      return;
    }

    try {
      setState(() => _isLoading = true);
      
      // الحصول على معلومات المستخدم
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(auth.uuid)
          .get();
      
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? userData['displayName'] ?? 'مستخدم';
      final userPhone = userData['phone'] ?? '';
      final userEmail = userData['email'] ?? '';
      
      // إنشاء بيانات التقييم
      final ratingData = {
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': auth.uuid,
        'orderId': widget.orderId,
        'userInfo': {
          'name': userName,
          'phone': userPhone,
          'email': userEmail,
        },
        'orderTotal': widget.order['total'],
        'orderItems': widget.order['items'],
        'orderStatus': widget.order['status'],
      };

      // حفظ البيانات في Firestore - داخل وثيقة الطلب
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .collection('ratings')
          .doc('userRating')
          .set(ratingData);
      
      // حفظ نسخة في مجموعة مركزية للتقييمات لسهولة الاستعلام
      await FirebaseFirestore.instance
          .collection('ratings')
          .doc(widget.orderId)
          .set(ratingData);

      // تحديث وثيقة الطلب بمعلومات التقييم
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'hasRating': true,
        'ratingValue': rating,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isRated = true;
          _userRating = rating;
          _userComment = comment;
          _isLoading = false;
        });
        
        Navigator.of(context).pop();
        
        // تجربة مستخدم أفضل - تحريك الشاشة إلى البطاقة التي تم تقييمها
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Scrollable.ensureVisible(
            _cardKey.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
        
        // عرض رسالة نجاح محسنة
        _showSuccessMessage();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        
        // عرض رسالة خطأ محسنة
        _showErrorMessage(e.toString());
      }
    }
  }

  /// عرض نافذة التقييم المحسنة
  void _showRatingDialog() {
    final status = widget.order['status'] ?? 'قيد المعالجة';
    final isDelivered = status == 'delivered';
    
    // فتح نافذة التقييم فقط إذا كان الطلب تم تسليمه
    if (isDelivered) {
      showDialog(
        context: context,
        builder: (context) => OrderRatingDialog(
          orderId: widget.orderId,
          order: widget.order,
          onSubmit: _submitRating,
          hasRated: _isRated,
          existingRating: _userRating,
          existingComment: _userComment,
        ),
      );
    } else {
      // إظهار رسالة إذا حاول المستخدم تقييم طلب لم يتم تسليمه بعد
      _showNotDeliveredMessage();
    }
  }

  /// عرض رسالة نجاح محسنة
  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم إرسال تقييمك بنجاح! شكراً لمساهمتك',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'إغلاق',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// عرض رسالة خطأ محسنة
  void _showErrorMessage(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'فشل إرسال التقييم، حاول لاحقاً',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'إغلاق',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// عرض رسالة تنبيه للطلبات غير المسلمة
  void _showNotDeliveredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'يمكنك تقييم الطلب فقط بعد أن يتم تسليمه',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
    );
  }

  /// عرض رسالة تنبيه لتسجيل الدخول
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تسجيل الدخول مطلوب',
          style: TextStyle(fontFamily: 'Tajawal'),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'يرجى تسجيل الدخول لتتمكن من تقييم الطلب',
          style: TextStyle(fontFamily: 'Tajawal'),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = widget.order;
    final status = order['status'] ?? 'قيد المعالجة';
    final isDelivered = status == 'delivered';
    final total = order['total'] ?? 0;
    final date = order['createdAt'] != null 
        ? (order['createdAt'] as Timestamp).toDate()
        : DateTime.now();
    
    // تنسيق التاريخ بشكل أفضل باستخدام intl
    final DateFormat formatter = DateFormat('dd/MM/yyyy', 'ar');
    final formattedDate = formatter.format(date);
    
    final orderItems = order['items'] as List<dynamic>? ?? [];
    
    return Card(
      key: _cardKey,
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDelivered ? theme.colorScheme.primary.withOpacity(0.2) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس البطاقة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      size: 20,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'طلب #${widget.orderId.substring(0, 6)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            
            // معلومات الطلب
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // التاريخ والمجموع
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formattedDate,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'Tajawal',
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$total د.ع',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  
                  // عنوان قسم المنتجات
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'المنتجات (${orderItems.length})',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // قائمة المنتجات
                 if (orderItems.isNotEmpty)
                 
  SizedBox(
    
    height: orderItems.length > 2 ? 70 : 35 * (orderItems.length > 0 ? orderItems.length : 1).toDouble(),
    child: ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: orderItems.length > 3 ? 3 : orderItems.length,
      itemBuilder: (context, index) {
        final item = orderItems[index] as Map<String, dynamic>? ?? {};
        final productName = item['name'] ?? 'منتج';
        final quantity = item['quantity'] ?? 1;
        final price = item['price'] ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  productName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'Tajawal',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${quantity}x',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${price * quantity} د.ع',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    ),
  ),

                  
                  // عرض عدد المنتجات الإضافية
                  if (orderItems.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(
                            '/order_status_page',
                            arguments: {'orderId': widget.orderId, 'order': widget.order},
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '... و ${orderItems.length - 3} منتجات أخرى',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'Tajawal',
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // قسم التقييم
            if (isDelivered)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isRated 
                      ? Colors.amber.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isRated ? Icons.star : Icons.star_border,
                                  color: _isRated ? Colors.amber : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isRated ? 'تقييمك' : 'تقييم الطلب',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    color: _isRated ? Colors.amber.shade800 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            if (_isRated)
                              Row(
                                children: List.generate(
                                  5,
                                  (index) => Icon(
                                    index < (_userRating ?? 0)
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        // عرض التعليق إذا كان موجوداً
                        if (_isRated && _userComment != null && _userComment!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Text(
                                _userComment!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'Tajawal',
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          
                        if (!_isRated)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'شاركنا رأيك في هذا الطلب لتحسين خدماتنا',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          
                        // زر التقييم
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _showRatingDialog,
                            icon: Icon(
                              _isRated ? Icons.edit : Icons.star_border,
                              size: 16,
                              color: _isRated ? Colors.amber.shade800 : theme.colorScheme.primary,
                            ),
                            label: Text(
                              _isRated ? 'تعديل التقييم' : 'إضافة تقييم',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                color: _isRated ? Colors.amber.shade800 : theme.colorScheme.primary,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: _isRated ? Colors.amber.shade300 : theme.colorScheme.primary.withOpacity(0.3),
                                ),
                              ),
                              backgroundColor: _isRated ? Colors.amber.withOpacity(0.1) : theme.colorScheme.primary.withOpacity(0.1),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            
            // أزرار الإجراءات
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      // الانتقال إلى صفحة تفاصيل الطلب
                      Navigator.of(context).pushNamed(
                        '/order_status_page',
                        arguments: {'orderId': widget.orderId, 'order': widget.order},
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text(
                      'عرض التفاصيل',
                      style: TextStyle(fontFamily: 'Tajawal'),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// إنشاء رقاقة حالة الطلب (Status Chip) محسّنة
  Widget _buildStatusChip(String status) {
    // تحديد الألوان والأيقونات بناءً على حالة الطلب
    Color chipColor;
    IconData chipIcon;
    String displayStatus;
    
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'تم التسليم':
      case 'مكتمل':
        chipColor = Colors.green;
        chipIcon = Icons.check_circle;
        displayStatus = 'تم التسليم';
        break;
      case 'processing':
      case 'قيد التنفيذ':
      case 'قيد المعالجة':
        chipColor = Colors.blue;
        chipIcon = Icons.autorenew;
        displayStatus = 'قيد المعالجة';
        break;
      case 'shipping':
      case 'قيد التوصيل':
        chipColor = Colors.orange;
        chipIcon = Icons.local_shipping;
        displayStatus = 'قيد التوصيل';
        break;
      case 'cancelled':
      case 'ملغي':
        chipColor = Colors.red;
        chipIcon = Icons.cancel;
        displayStatus = 'ملغي';
        break;
      default:
        chipColor = Colors.blue;
        chipIcon = Icons.info;
        displayStatus = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            chipIcon,
            size: 16,
            color: chipColor,
          ),
          const SizedBox(width: 6),
          Text(
            displayStatus,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }
}

/// نافذة تقييم الطلب محسنة
class OrderRatingDialog extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> order;
  final Function(int rating, String comment) onSubmit;
  final bool hasRated;
  final int? existingRating;
  final String? existingComment;

  const OrderRatingDialog({
    Key? key,
    required this.orderId, 
    required this.order,
    required this.onSubmit,
    this.hasRated = false,
    this.existingRating,
    this.existingComment,
  }) : super(key: key);

  @override
  State<OrderRatingDialog> createState() => _OrderRatingDialogState();
}

class _OrderRatingDialogState extends State<OrderRatingDialog> {
  int _selectedRating = 0;
  late TextEditingController _commentController;
  bool _isSubmitting = false;
  String _ratingText = '';
  
  @override
  void initState() {
    super.initState();
    _selectedRating = widget.existingRating ?? 0;
    _commentController = TextEditingController(text: widget.existingComment ?? '');
    _updateRatingText();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // تحديث نص تعليق على التقييم بناءً على عدد النجوم
  void _updateRatingText() {
    switch (_selectedRating) {
      case 1:
        _ratingText = 'سيئ جداً';
        break;
      case 2:
        _ratingText = 'سيئ';
        break;
      case 3:
        _ratingText = 'متوسط';
        break;
      case 4:
        _ratingText = 'جيد';
        break;
      case 5:
        _ratingText = 'ممتاز';
        break;
      default:
        _ratingText = '';
    }
  }
Widget _buildStarRating(int starValue) {
  return IconButton(
    icon: Icon(
      starValue <= _selectedRating ? Icons.star : Icons.star_border,
      color: Colors.amber,
      size: 32,
    ),
    onPressed: () {
      setState(() {
        _selectedRating = starValue;
        _updateRatingText();
      });    },
  );
}

@override
Widget build(BuildContext context) {

  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Text(
      'تقييم الطلب',
      style: TextStyle(
        fontFamily: 'Tajawal',
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) => _buildStarRating(index + 1)),
        ),
        if (_ratingText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _ratingText,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'اكتب تعليقك هنا...',
            hintStyle: const TextStyle(fontFamily: 'Tajawal'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        child: const Text(
          'إلغاء',
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
      ),
      ElevatedButton(
        onPressed: _isSubmitting || _selectedRating == 0
            ? null
            : () async {
                setState(() => _isSubmitting = true);
                await widget.onSubmit(_selectedRating, _commentController.text.trim());
                setState(() => _isSubmitting = false);
              },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
color: Color(0xFFFFCC80), // بصلي متوسط
                ),
              )
            : const Text(
                'إرسال',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
      ),
    ],
  );
}
}

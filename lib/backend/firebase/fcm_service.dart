import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:balqees/config/keys.dart';

class FCMService {
  static Future<void> sendNotificationToUser({
    required String uuid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uuid)
          .get();

      if (!snapshot.exists) return;

      final userData = snapshot.data();
      final token = userData?['fcmToken'];

      if (token == null || token.isEmpty) return;

      final message = {
        "to": token,
        "notification": {
          "title": title,
          "body": body,
        },
        "data": {
          ...?data,
          "click_action": "FLUTTER_NOTIFICATION_CLICK",
        }
      };

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Authorization': 'key=${FirebaseKeys.fcmServerKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode != 200) {
        throw Exception('فشل إرسال الإشعار: ${response.body}');
      }
    } catch (e) {
      print('FCM Error: $e');
    }
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class PushNotificationSender {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> sendPush({
    required String receiverId,
    required String title,
    required String body,
  }) async {
    try {
      // 1. Get Access Token via Service Account
      final serviceAccountJson = await rootBundle.loadString('assets/service_account.json');
      final serviceAccountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      
      // Parse project_id manually as it might not be exposed on credentials object
      final jsonMap = jsonDecode(serviceAccountJson) as Map<String, dynamic>;
      final projectId = jsonMap['project_id'] as String?;
      
      if (projectId == null) {
         debugPrint('Error: project_id not found in service_account.json');
         return;
      }
      
      final client = await clientViaServiceAccount(serviceAccountCredentials, _scopes);

      // 2. Get Receiver's FCM Tokens
      final response = await _client
          .from('fcm_tokens')
          .select('token')
          .eq('user_id', receiverId);
      
      final tokens = (response as List).map((e) => e['token'] as String).toList();

      if (tokens.isEmpty) {
        client.close();
        return;
      }

      // 3. Send to each token using HTTP v1 API
      for (final token in tokens) {
        await _sendToTokenV1(client, projectId!, token, title, body);
      }
      
      client.close();
      
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }

  Future<void> _sendToTokenV1(
    AutoRefreshingAuthClient client, 
    String projectId, 
    String token, 
    String title, 
    String body
  ) async {
    try {
      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      
      final response = await client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'id': '1',
              'status': 'done',
              'type': 'chat_message',
            },
            'android': {
              'priority': 'HIGH',
              'notification': {
                  'sound': 'default'
              }
            },
            'apns': {
              'payload': {
                'aps': {
                  'sound': 'default',
                  'content-available': 1
                }
              }
            }
          }
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('FCM V1 Send Error: ${response.body}');
      }
    } catch (e) {
      debugPrint('FCM V1 HTTP Error: $e');
    }
  }
}

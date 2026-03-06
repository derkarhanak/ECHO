import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EchoApiService {
  // Singleton pattern
  EchoApiService._privateConstructor();
  static final EchoApiService instance = EchoApiService._privateConstructor();
  factory EchoApiService() => instance;

  static const String baseUrl = 'https://api.derkarhanak.space';
  static const int maxRetries = 3;
  static const Duration timeoutDuration = Duration(seconds: 8);

  String? _jwtToken;
  String? _userId;

  String? get userId => _userId;

  Future<void> authenticate() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString('jwt_token');
    _userId = prefs.getString('user_id');

    // If missing identity, request one from backend auth endpoint
    if (_jwtToken == null || _userId == null) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/auth'))
            .timeout(timeoutDuration);
            
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _jwtToken = data['token'];
          _userId = data['userId'];
          await prefs.setString('jwt_token', _jwtToken!);
          await prefs.setString('user_id', _userId!);
        } else {
          debugPrint('Auth failed with status: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Auth network error: $e');
      }
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
      };

  Future<List<dynamic>> fetchInbox() async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/inbox'), headers: _headers)
            .timeout(timeoutDuration);
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } on SocketException catch (_) {
        debugPrint('Inbox poll failed: No network connection (Attempt ${i + 1})');
      } catch (e) {
        debugPrint('Inbox poll failed: $e (Attempt ${i + 1})');
      }
      if (i < maxRetries - 1) await Future.delayed(Duration(seconds: i + 1));
    }
    return [];
  }

  Future<bool> sendEcho({required String content}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/exhale'),
              headers: _headers,
              body: jsonEncode({'content': content}),
            )
            .timeout(timeoutDuration);
        return response.statusCode == 200 || response.statusCode == 201;
      } on SocketException catch (_) {
        debugPrint('Network error: No network connection (Attempt ${i + 1})');
      } catch (e) {
        debugPrint('Network error: $e (Attempt ${i + 1})');
      }
      if (i < maxRetries - 1) await Future.delayed(Duration(seconds: i + 1));
    }
    return false;
  }

  Future<Map<String, dynamic>?> fetchRandomEcho() async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/catch'), headers: _headers)
            .timeout(timeoutDuration);
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else if (response.statusCode == 404) {
          return null; // The void is empty gracefully
        }
      } on SocketException catch (_) {
        debugPrint('Catch failed: No network connection (Attempt ${i + 1})');
        throw Exception("Connection lost.");
      } catch (e) {
        debugPrint('Catch failed: $e (Attempt ${i + 1})');
      }
      if (i < maxRetries - 1) await Future.delayed(Duration(seconds: i + 1));
    }
    throw Exception("Connection lost.");
  }

  Future<bool> sendReply({
    required String echoId,
    required String content,
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/reply'),
              headers: _headers,
              body: jsonEncode({
                'echoId': echoId,
                'content': content,
              }),
            )
            .timeout(timeoutDuration);
        return response.statusCode == 200 || response.statusCode == 201;
      } on SocketException catch (_) {
        debugPrint('Reply failed: No network connection (Attempt ${i + 1})');
      } catch (e) {
        debugPrint('Reply failed: $e (Attempt ${i + 1})');
      }
      if (i < maxRetries - 1) await Future.delayed(Duration(seconds: i + 1));
    }
    return false;
  }
}


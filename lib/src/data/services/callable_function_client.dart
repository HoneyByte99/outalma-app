import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const _projectId = 'outalmaservice-d1e59';
const _region = 'us-central1';

/// Invokes a Firebase HTTPS callable Cloud Function via plain Dart HTTP,
/// bypassing the Firebase Functions iOS SDK (works around the Swift concurrency
/// fatalError in asyncLet_finish_after_task_completion observed with
/// FirebaseFunctions ~11.15 on iOS).
///
/// Wire protocol (Firebase callable v1):
///   Request:  POST {"data": <payload>}   Content-Type: application/json
///   Success:  {"result": <value>}
///   Error:    {"error": {"status": "PERMISSION_DENIED", "message": "…"}}
///
/// Throws [FirebaseFunctionsException] with the same kebab-case codes the
/// native SDK uses, so existing catch-blocks need no changes.
class CallableFunctionClient {
  const CallableFunctionClient();

  static Uri _uri(String name) =>
      Uri.parse('https://$_region-$_projectId.cloudfunctions.net/$name');

  Future<Map<String, dynamic>> call(
    String name, {
    Map<String, dynamic> data = const {},
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.post(
      _uri(name),
      headers: headers,
      body: jsonEncode({'data': data}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body.containsKey('error')) {
      final err = body['error'] as Map<String, dynamic>;
      final code = (err['status'] as String? ?? 'UNKNOWN')
          .toLowerCase()
          .replaceAll('_', '-');
      throw FirebaseFunctionsException(
        code: code,
        message: err['message'] as String? ?? 'Cloud Function error',
      );
    }

    return (body['result'] as Map<String, dynamic>?) ?? {};
  }
}

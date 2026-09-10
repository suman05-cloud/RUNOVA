import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:runova/features/run/data/run_sync.dart';

class IdleSync extends RunSync {
  @override
  SyncState build() => const SyncState();
  @override
  Future<void> sync() async {}
}

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.reply);
  final (int, Object) Function(RequestOptions) reply;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = reply(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const testProfile = <String, dynamic>{
  'id': 'user-one',
  'email': 'runner@example.com',
  'username': 'runner',
  'display_name': 'Runner One',
  'city': 'Kolkata',
  'country_code': 'IN',
  'profile_is_public': false,
};

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'device_snapshot.dart';

class DeviceException implements Exception {
  DeviceException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class AidClient {
  Future<DeviceSnapshot> fetchData(String host);
  Future<Map<String, dynamic>> postAction(
    String host,
    String action, {
    String? value,
  });
  Future<void> postSettings(String host, Map<String, String> fields);
}

class HttpAidClient implements AidClient {
  HttpAidClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<DeviceSnapshot> fetchData(String host) {
    return _guard(host, () async {
      final res = await _client
          .get(_uri(host, '/api/data'))
          .timeout(AppConfig.requestTimeout);
      return DeviceSnapshot.fromJson(_decode(res));
    });
  }

  @override
  Future<Map<String, dynamic>> postAction(
    String host,
    String action, {
    String? value,
  }) {
    return _guard(host, () async {
      final body = <String, String>{'action': action};
      if (value != null) body['value'] = value;
      final res = await _client
          .post(_uri(host, '/api/action'), body: body)
          .timeout(AppConfig.requestTimeout);
      return _decode(res);
    });
  }

  @override
  Future<void> postSettings(String host, Map<String, String> fields) {
    return _guard(host, () async {
      final res = await _client
          .post(_uri(host, '/api/settings'), body: fields)
          .timeout(AppConfig.requestTimeout);
      _decode(res);
    });
  }

  Future<T> _guard<T>(String host, Future<T> Function() run) async {
    try {
      return await run();
    } on DeviceException {
      rethrow;
    } on TimeoutException {
      throw DeviceException(
        'Máy $host không phản hồi. Kiểm tra Wi-Fi ${AppConfig.wifiName}.',
      );
    } catch (_) {
      throw DeviceException(
        'Không kết nối được $host. Bật thiết bị và vào Wi-Fi ${AppConfig.wifiName}.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json = {};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      } else if (decoded is Map) {
        json = decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      throw DeviceException('Máy trả về dữ liệu không đọc được.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = json['message']?.toString();
      throw DeviceException(
        message == null || message.isEmpty
            ? 'Máy trả về mã ${res.statusCode}'
            : message,
      );
    }
    return json;
  }

  Uri _uri(String host, String path) {
    var cleaned = host.trim().replaceFirst(RegExp(r'^https?://'), '');
    cleaned = cleaned.replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty) cleaned = AppConfig.defaultHost;
    return Uri.parse('http://$cleaned$path');
  }
}

enum ConnectMode { local, mqtt }

abstract class HostStore {
  Future<String?> readHost();
  Future<void> writeHost(String host);
  Future<String?> readChip();
  Future<void> writeChip(String chip);
  Future<ConnectMode> readMode();
  Future<void> writeMode(ConnectMode mode);
}

class PrefsHostStore implements HostStore {
  @override
  Future<String?> readHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.hostPrefKey);
  }

  @override
  Future<void> writeHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.hostPrefKey, host);
  }

  @override
  Future<String?> readChip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.chipPrefKey);
  }

  @override
  Future<void> writeChip(String chip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.chipPrefKey, chip);
  }

  @override
  Future<ConnectMode> readMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConfig.modePrefKey);
    return raw == 'mqtt' ? ConnectMode.mqtt : ConnectMode.local;
  }

  @override
  Future<void> writeMode(ConnectMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConfig.modePrefKey,
      mode == ConnectMode.mqtt ? 'mqtt' : 'local',
    );
  }
}

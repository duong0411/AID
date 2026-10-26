import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'aid_models.dart';

class AidController extends ChangeNotifier {
  AidController({this.autoConnect = true});

  static const brokerUrl = 'wss://mqtt.duynguyen.io.vn/mqtt';

  final bool autoConnect;
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage?>>>? _sub;
  bool _connecting = false;
  bool connected = false;
  String lastError = '';
  String chipId = '';
  String? deviceOnline;
  AidSnapshot? snapshot;
  final discovered = <String>{};
  final hrTrace = <double>[];
  final forceTrace = <double>[];
  final spo2Trace = <double>[];
  final piezoTrace = <double>[];

  Future<void> start() async {
    await _loadChip();
    if (autoConnect) {
      await connect();
    }
  }

  Future<void> _loadChip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('aid_chip') ?? '';
      if (saved.isNotEmpty) {
        chipId = saved.toUpperCase();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setChip(String value) async {
    chipId = value.trim().toUpperCase();
    snapshot = null;
    deviceOnline = null;
    _clearTraces();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('aid_chip', chipId);
    } catch (_) {}
  }

  Future<bool> connect() async {
    if (_connecting) return false;
    if (connected) return true;
    _connecting = true;
    lastError = '';
    notifyListeners();

    await _drop();
    final uri = Uri.parse(brokerUrl);
    final clientId = 'aid_app_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient.withPort(
      '${uri.scheme}://${uri.host}${uri.path}',
      clientId,
      uri.port == 0 ? 443 : uri.port,
    );
    _client = client;
    client.useWebSocket = true;
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    client.logging(on: false);
    client.setProtocolV311();
    client.keepAlivePeriod = 30;
    client.connectTimeoutPeriod = 12000;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.onConnected = () {
      connected = true;
      _subscribe();
    };
    client.onDisconnected = () {
      connected = false;
      notifyListeners();
    };
    client.onAutoReconnected = () {
      connected = true;
      _listen();
      _subscribe();
      notifyListeners();
    };
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();

    try {
      await client.connect().timeout(const Duration(seconds: 15));
    } catch (e) {
      lastError = 'Khong ket noi MQTT';
      connected = false;
      _connecting = false;
      await _drop();
      notifyListeners();
      return false;
    }

    connected = client.connectionStatus?.state == MqttConnectionState.connected;
    _connecting = false;
    if (!connected) {
      lastError = 'Broker tu choi ket noi';
      await _drop();
      notifyListeners();
      return false;
    }
    _listen();
    _subscribe();
    notifyListeners();
    return true;
  }

  void _subscribe() {
    final client = _client;
    if (client == null) return;
    for (final topic in ['tele/+/oled', 'tele/+/status']) {
      try {
        client.subscribe(topic, MqttQos.atLeastOnce);
      } catch (_) {}
    }
  }

  void _listen() {
    _sub?.cancel();
    final updates = _client?.updates;
    if (updates == null) return;
    _sub = updates.listen((events) {
      for (final event in events) {
        final rec = event.payload as MqttPublishMessage;
        final payload =
            MqttPublishPayload.bytesToStringAsString(rec.payload.message);
        _onMessage(event.topic, payload);
      }
    });
  }

  void _onMessage(String topic, String payload) {
    final parts = topic.split('/');
    if (parts.length < 3 || parts.first != 'tele') return;
    final id = parts[1].toUpperCase();
    if (id.isEmpty) return;
    discovered.add(id);

    if (topic.endsWith('/status')) {
      if (chipId.isEmpty || chipId == id) {
        if (chipId.isEmpty) chipId = id;
        deviceOnline = payload.trim().toLowerCase();
      }
      notifyListeners();
      return;
    }

    if (!topic.endsWith('/oled')) return;
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) json = decoded;
      if (decoded is Map) json = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    if (json == null) return;
    final next = AidSnapshot.fromJson(json);
    if (next == null) return;
    if (chipId.isNotEmpty && next.id != chipId) return;
    if (chipId.isEmpty) chipId = next.id;
    snapshot = next;
    deviceOnline = 'online';
    _pushTrace(hrTrace, next.hr.toDouble());
    _pushTrace(forceTrace, next.force);
    _pushTrace(spo2Trace, next.spo2);
    _pushTrace(piezoTrace, next.piezo);
    notifyListeners();
  }

  void _pushTrace(List<double> trace, double value) {
    trace.add(value);
    if (trace.length > 64) trace.removeAt(0);
  }

  void _clearTraces() {
    hrTrace.clear();
    forceTrace.clear();
    spo2Trace.clear();
    piezoTrace.clear();
  }

  void sendButton(String name) {
    final id = (snapshot?.id ?? chipId).trim();
    if (id.isEmpty) return;
    _publish('cmnd/$id/BTN', name);
  }

  void sendScreen(int screen) {
    final id = (snapshot?.id ?? chipId).trim();
    if (id.isEmpty) return;
    _publish('cmnd/$id/SCREEN', '$screen');
  }

  void _publish(String topic, String message) {
    final client = _client;
    if (client == null || !connected) return;
    final builder = MqttClientPayloadBuilder()..addString(message);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> _drop() async {
    _sub?.cancel();
    _sub = null;
    connected = false;
    final client = _client;
    _client = null;
    if (client == null) return;
    try {
      client.autoReconnect = false;
      client.disconnect();
    } catch (_) {}
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }
}

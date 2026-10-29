import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'device_api.dart';
import 'device_snapshot.dart';
import 'mqtt_service.dart';
import 'practice_session.dart';

class MonitorProvider extends ChangeNotifier {
  MonitorProvider({
    AidClient? api,
    HostStore? hosts,
    MqttService? mqtt,
    PracticeStore? practiceStore,
  })  : _api = api ?? HttpAidClient(),
        _hosts = hosts ?? PrefsHostStore(),
        _mqtt = mqtt ?? MqttService(),
        _practiceStore = practiceStore ?? PracticeStore();

  final AidClient _api;
  final HostStore _hosts;
  final MqttService _mqtt;
  final PracticeStore _practiceStore;

  Timer? _timer;
  StreamSubscription? _mqttSub;
  bool _wasAlarm = false;

  bool connecting = false;
  bool entered = false;
  bool live = false;
  ConnectMode mode = ConnectMode.mqtt;
  String host = AppConfig.defaultHost;
  String chipId = AppConfig.defaultChipId;
  String status = 'Chưa kết nối thiết bị';
  DeviceSnapshot? data;
  final List<SamplePoint> history = [];

  bool practiceRunning = false;
  PracticeAccumulator? _practiceAcc;
  final List<PracticeSession> practiceSessions = [];

  bool get canEnterSystem => entered && data != null;
  bool get isMqtt => mode == ConnectMode.mqtt;

  String get _practiceModeLabel =>
      isMqtt ? 'Từ xa · chip $chipId' : 'Gần máy · $host';

  Future<void> loadSavedHost() async {
    mode = await _hosts.readMode();
    final savedHost = await _hosts.readHost();
    final savedChip = await _hosts.readChip();
    if (savedHost != null && savedHost.trim().isNotEmpty) {
      host = savedHost.trim();
    }
    if (savedChip != null && savedChip.trim().isNotEmpty) {
      chipId = savedChip.trim();
      AppConfig.setChipId(chipId);
    }
    practiceSessions
      ..clear()
      ..addAll(await _practiceStore.load());
    notifyListeners();
  }

  void startPractice() {
    if (practiceRunning || data == null) return;
    practiceRunning = true;
    _practiceAcc = PracticeAccumulator()..startedAt = DateTime.now();
    _practiceAcc!.add(data!);
    notifyListeners();
  }

  Future<PracticeSession?> stopPractice() async {
    if (!practiceRunning || _practiceAcc == null) return null;
    final session = _practiceAcc!.finish(_practiceModeLabel);
    practiceRunning = false;
    _practiceAcc = null;
    practiceSessions.insert(0, session);
    while (practiceSessions.length > AppConfig.maxPracticeSessions) {
      practiceSessions.removeLast();
    }
    await _practiceStore.save(practiceSessions);
    notifyListeners();
    return session;
  }

  Future<void> clearPracticeHistory() async {
    if (practiceRunning) await stopPractice();
    practiceSessions.clear();
    await _practiceStore.save(practiceSessions);
    notifyListeners();
  }

  Future<bool> connectLocal(String rawHost) async {
    final next = rawHost.trim().isEmpty ? AppConfig.defaultHost : rawHost.trim();
    connecting = true;
    mode = ConnectMode.local;
    status = 'Đang vào máy $next...';
    notifyListeners();

    await _mqtt.disconnect();
    _mqttSub?.cancel();
    _mqttSub = null;

    try {
      final snap = await _api.fetchData(next);
      host = next;
      await _hosts.writeHost(next);
      await _hosts.writeMode(ConnectMode.local);
      _apply(snap, resetHistory: true);
      entered = true;
      live = true;
      status = 'Gần máy · $next';
      _startPoll();
      return true;
    } on DeviceException catch (e) {
      entered = false;
      live = false;
      status = e.message;
      return false;
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<bool> connectMqtt(String rawChip) async {
    final id = rawChip.trim().isEmpty ? AppConfig.defaultChipId : rawChip.trim();
    connecting = true;
    mode = ConnectMode.mqtt;
    AppConfig.setChipId(id);
    chipId = AppConfig.chipId;
    status = 'Đang vào MQTT chip $chipId...';
    data = null;
    history.clear();
    notifyListeners();

    _timer?.cancel();
    _timer = null;

    final ok = await _mqtt.connect(force: true);
    if (!ok) {
      connecting = false;
      entered = false;
      live = false;
      status = 'Không vào được broker. Kiểm tra Internet.';
      notifyListeners();
      return false;
    }

    await _hosts.writeChip(chipId);
    await _hosts.writeMode(ConnectMode.mqtt);
    _mqttSub?.cancel();
    _mqttSub = _mqtt.messages.listen(_onMqtt);
    connecting = false;
    entered = true;
    live = false;
    status = 'MQTT OK · chờ chip $chipId online...';
    notifyListeners();
    return true;
  }

  /// Giữ API cũ cho test / gọi nhanh.
  Future<bool> connect(String rawHost) => connectLocal(rawHost);

  void disconnect() {
    if (practiceRunning) {
      unawaited(stopPractice());
    }
    _timer?.cancel();
    _timer = null;
    _mqttSub?.cancel();
    _mqttSub = null;
    unawaited(_mqtt.disconnect());
    entered = false;
    live = false;
    data = null;
    history.clear();
    _wasAlarm = false;
    status = isMqtt
        ? 'Đã ngắt MQTT. Nhập Chip ID để theo dõi từ xa.'
        : 'Đã ngắt. Vào lại Wi-Fi ${AppConfig.wifiName} để theo dõi gần.';
    notifyListeners();
  }

  Future<void> refresh() async {
    if (isMqtt) {
      status = live ? 'MQTT · chip $chipId' : 'Đang chờ chip $chipId...';
      notifyListeners();
      return;
    }
    await _poll();
  }

  Future<void> toggleMute() async {
    if (isMqtt) {
      _mqtt.toggleMute();
      return;
    }
    await _run(() => _api.postAction(host, 'mute'));
  }

  Future<void> testAlarm() async {
    if (isMqtt) {
      _mqtt.testAlarm();
      return;
    }
    await _run(() => _api.postAction(host, 'test_alarm'));
  }

  Future<void> saveSettings({
    required int forceThresh,
    required int pulseMin,
    required int pulseMax,
    required int spo2Min,
    required int piezoThresh,
    required bool buzzerEnabled,
  }) async {
    if (isMqtt) {
      _mqtt.publishSettings({
        'forceThresh': forceThresh,
        'pulseMin': pulseMin,
        'pulseMax': pulseMax,
        'spo2Min': spo2Min,
        'piezoThresh': piezoThresh,
        'buzzerEn': buzzerEnabled,
      });
      return;
    }
    await _run(
      () => _api.postSettings(host, {
        'forceThresh': '$forceThresh',
        'pulseMin': '$pulseMin',
        'pulseMax': '$pulseMax',
        'spo2Min': '$spo2Min',
        'piezoThresh': '$piezoThresh',
        'buzzerEn': buzzerEnabled ? '1' : '0',
      }),
    );
  }

  void _onMqtt(Map<String, dynamic> msg) {
    final topic = msg['topic'] as String? ?? '';
    final value = msg['value'];
    final raw = msg['raw']?.toString() ?? '';

    if (topic == AppConfig.topicOnline) {
      final online = value.toString().toLowerCase() == 'online';
      live = online || data != null;
      status = online
          ? 'Từ xa · chip $chipId online'
          : 'Chip $chipId offline';
      notifyListeners();
      return;
    }

    if (topic == AppConfig.topicVitals) {
      try {
        final map = value is Map<String, dynamic>
            ? value
            : value is Map
                ? value.map((k, v) => MapEntry(k.toString(), v))
                : jsonDecode(raw) as Map<String, dynamic>;
        final snap = DeviceSnapshot.fromJson(map);
        _apply(snap, resetHistory: false);
        live = true;
        status = 'Từ xa · chip $chipId';
        notifyListeners();
      } catch (e) {
        if (kDebugMode) print('vitals parse: $e');
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _poll();
    } on DeviceException catch (e) {
      status = e.message;
      live = false;
      notifyListeners();
      rethrow;
    }
  }

  void _startPoll() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (!entered || isMqtt) return;
    try {
      final snap = await _api.fetchData(host);
      _apply(snap, resetHistory: false);
      live = true;
      status = 'Gần máy · $host';
    } on DeviceException catch (e) {
      live = false;
      status = e.message;
    }
    notifyListeners();
  }

  void _apply(DeviceSnapshot snap, {required bool resetHistory}) {
    data = snap;
    if (resetHistory) history.clear();
    history.add(
      SamplePoint(
        pulseBpm: snap.pulseBpm.toDouble(),
        spo2: snap.spo2,
        forcePct: snap.forcePct,
        piezoPct: snap.piezoPct,
      ),
    );
    if (history.length > AppConfig.maxHistory) {
      history.removeRange(0, history.length - AppConfig.maxHistory);
    }
    if (practiceRunning && _practiceAcc != null) {
      _practiceAcc!.add(snap);
    }
    if (snap.alarmActive && !_wasAlarm) {
      HapticFeedback.heavyImpact();
    }
    _wasAlarm = snap.alarmActive;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mqttSub?.cancel();
    unawaited(_mqtt.dispose());
    super.dispose();
  }
}

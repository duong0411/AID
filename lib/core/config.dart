/// Local SoftAP hoặc MQTT từ xa (cùng broker LenMen).
class AppConfig {
  static const String defaultHost = '192.168.4.1';
  static const String wifiName = 'Smart-First-AID';
  static const String wifiPassword = '12345678';
  static const String deviceName = 'Smart First AID';

  static const String brokerUrl = 'wss://mqtt.duynguyen.io.vn/mqtt';
  static const String defaultChipId = '777';

  static const String hostPrefKey = 'device_host';
  static const String chipPrefKey = 'device_chip';
  static const String modePrefKey = 'connect_mode';
  static const String practicePrefKey = 'practice_sessions';

  static const Duration pollInterval = Duration(milliseconds: 800);
  static const Duration requestTimeout = Duration(seconds: 4);
  static const int maxHistory = 90;
  static const int maxPracticeSessions = 40;

  static String chipId = defaultChipId;

  static void setChipId(String id) {
    final cleaned = id.trim();
    chipId = cleaned.isEmpty ? defaultChipId : cleaned;
  }

  static String get topicOnline => 'tele/$chipId/status';
  static String get topicVitals => 'tele/${chipId}_vitals/status';
  static String get cmndMute => 'cmnd/${chipId}_mute/POWER';
  static String get cmndTest => 'cmnd/${chipId}_test/POWER';
  static String get cmndSettings => 'cmnd/${chipId}_settings/VALUE';

  static List<String> get subscribeTopics => [topicOnline, topicVitals];
}

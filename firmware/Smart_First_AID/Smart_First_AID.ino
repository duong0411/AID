/**
 * ==============================================================================
 * DỰ ÁN: SMART FIRST AID (THIẾT BỊ SƠ CẤP CỨU THÔNG MINH)
 * PHẦN CỨNG: ESP32-WROOM-32E (4MB)
 * SƠ ĐỒ NGUYÊN LÝ: Smart First AID.pdf
 * ==============================================================================
 * 
 * SƠ ĐỒ CHÂN (PINOUT):
 * 1. OLED Display (DM-OLED096-636 - SSD1306 128x64 I2C):
 *    - SDA_OLED -> GPIO 21
 *    - SCL_OLED -> GPIO 22
 * 
 * 2. Cảm biến SpO2 & Nhịp tim (MAX30100 / MAX30102 - I2C riêng biệt):
 *    - SDA_MAX  -> GPIO 26
 *    - SCL_MAX  -> GPIO 25
 * 
 * 3. Cảm biến Analog:
 *    - OUT_PUL  -> GPIO 33 (Pulse Sensor - Cảm biến quang nhịp tim)
 *    - OUT_FOR  -> GPIO 32 (Force Sensor - Cảm biến lực/áp suất FSR)
 *    - OUT_PIE  -> GPIO 35 (Piezoelectric - Điện thế sinh học / Rung chấn)
 * 
 * 4. Nút bấm (Buttons - Tích hợp trở kéo lên RN1 330R, nhấn tích cực mức LOW):
 *    - MENU     -> GPIO 18 (SW3 - Chuyển đổi màn hình chức năng)
 *    - UP       -> GPIO 5  (SW4 - Lên / Tăng giá trị ngưỡng)
 *    - DOWN     -> GPIO 17 (SW5 - Xuống / Giảm giá trị ngưỡng)
 *    - ENTER    -> GPIO 16 (SW7 - Chọn / Bật-Tắt còi báo / Lưu cài đặt)
 * 
 * 5. Còi báo & Đèn báo (Buzzer & LED):
 *    - BZ       -> GPIO 4 (Kích transistor MOSFET AO3400 lái còi chip LS1 & LED1)
 *    - LED      -> GPIO 2 (Đèn LED2 onboard báo trạng thái)
 * ==============================================================================
 */

#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <WebSocketsClient.h>
#include <MQTTPubSubClient.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Preferences.h>
#include "MAX3010x_Driver.h"

// ------------------------------------------------------------------------------
// ĐỊNH NGHĨA CHÂN PHẦN CỨNG THEO SCHEMATIC
// ------------------------------------------------------------------------------
#define PIN_OLED_SDA   21
#define PIN_OLED_SCL   22

#define PIN_MAX_SDA    26
#define PIN_MAX_SCL    25

#define PIN_OUT_PUL    33  // Pulse Sensor
#define PIN_OUT_FOR    32  // Force Sensor
#define PIN_OUT_PIE    35  // Piezoelectric Sensor

#define PIN_BTN_MENU   18
#define PIN_BTN_UP     5
#define PIN_BTN_DOWN   17
#define PIN_BTN_ENTER  16

#define PIN_BUZZER     4   // BZ
#define PIN_LED        2   // LED báo trạng thái

// ------------------------------------------------------------------------------
// CẤU HÌNH MÀN HÌNH OLED
// ------------------------------------------------------------------------------
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
#define OLED_I2C_ADDR 0x3C
#define OLED_ROTATION 2  // 0: Mặc định (0 độ), 2: Lật ngược 180 độ, 1: Xoay dọc 90 độ, 3: Xoay dọc 270 độ

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// ------------------------------------------------------------------------------
// ĐỐI TƯỢNG NGOẠI VI & LƯU TRỮ
// ------------------------------------------------------------------------------
TwoWire WireMax = TwoWire(1);
MAX3010x_Driver maxSensor;
Preferences prefs;

// ------------------------------------------------------------------------------
// CÁC CHẾ ĐỘ MÀN HÌNH (SCREENS)
// ------------------------------------------------------------------------------
enum ScreenMode {
  SCREEN_DASHBOARD = 0,   // Màn hình 0: Tổng quan 4 cảm biến
  SCREEN_PULSE     = 1,   // Màn hình 1: Nhịp tim (Pulse Sensor)
  SCREEN_FORCE     = 2,   // Màn hình 2: Lực / Áp suất (Force Sensor)
  SCREEN_SPO2      = 3,   // Màn hình 3: Nồng độ Oxy máu (SpO2 MAX3010x)
  SCREEN_PIEZO     = 4,   // Màn hình 4: Điện thế sinh học / Rung (Piezo)
  SCREEN_SETTINGS  = 5    // Màn hình 5: Cài đặt ngưỡng cảnh báo
};

ScreenMode currentScreen = SCREEN_DASHBOARD;
const int TOTAL_SCREENS = 6;

// ------------------------------------------------------------------------------
// NGƯỠNG CẢNH BÁO (THRESHOLDS)
// ------------------------------------------------------------------------------
struct Settings {
  int forceThreshold;     // Ngưỡng lực tối đa (%) (Mặc định: 60%)
  int pulseMinBpm;        // Ngưỡng nhịp tim tối thiểu (BPM) (Mặc định: 50)
  int pulseMaxBpm;        // Ngưỡng nhịp tim tối đa (BPM) (Mặc định: 120)
  int spo2Min;            // Ngưỡng SpO2 tối thiểu (%) (Mặc định: 92%)
  int piezoThreshold;     // Ngưỡng rung/điện thế (%) (Mặc định: 50%)
  bool buzzerEnabled;     // Cho phép bật còi báo
} configSettings;

// ------------------------------------------------------------------------------
// BIẾN ĐO LƯỜNG CỦA CẢM BIẾN
// ------------------------------------------------------------------------------
// 1. Nhịp tim quang học (Pulse Sensor - GPIO 33)
int   rawPulseADC = 0;
float pulseFiltered = 0;
int   pulseBPM = 0;
bool  pulseBeatDetected = false;
uint32_t lastPulseBeatTime = 0;

#define GRAPH_WIDTH 128
uint8_t pulseWaveBuffer[GRAPH_WIDTH];  // Đồ thị sóng nhịp tim ECG
uint8_t forceWaveBuffer[GRAPH_WIDTH];  // Đồ thị diễn biến lực FSR
uint8_t spo2WaveBuffer[GRAPH_WIDTH];   // Đồ thị sóng mạch quang học PPG MAX3010x
uint8_t piezoWaveBuffer[GRAPH_WIDTH];  // Đồ thị dao động xung điện thế / rung Piezo


// 2. Cảm biến lực (Force Sensor - GPIO 32)
int   rawForceADC = 0;
float forcePercent = 0.0f;
float forceGrams = 0.0f;

// 3. Cảm biến SpO2 (MAX3010x - GPIO 26/25)
float maxSpo2 = 0.0f;
float maxBpm = 0.0f;
bool  maxFinger = false;
bool  maxOnline = false;

// 4. Cảm biến Piezoelectric (GPIO 35)
int   rawPiezoADC = 0;
float piezoPercent = 0.0f;
float piezoVoltage = 0.0f;
float piezoPeak = 0.0f;

// ------------------------------------------------------------------------------
// TRẠNG THÁI CẢNH BÁO (ALARM STATE)
// ------------------------------------------------------------------------------
bool alarmActive = false;
bool alarmPulse = false;
bool alarmForce = false;
bool alarmSpo2 = false;
bool alarmPiezo = false;
String alarmReason = "";
bool buzzerMuted = false;

// ------------------------------------------------------------------------------
// WIFI + MQTT (mqtt.duynguyen.io.vn) THEO CHIP ID
// ------------------------------------------------------------------------------
char chipId[8] = "000000";
char apSsid[16] = "AID_000000";
char wifiSsid[32] = "";
char wifiPass[64] = "";
char remoteBtn = 0;
bool portalActive = false;
bool mqttOnline = false;
bool mqttStackReady = false;
uint32_t lastMqttTry = 0;
uint32_t lastTele = 0;
uint32_t lastWifiTry = 0;
bool wifiBeginPending = false;

WebServer webServer(80);
DNSServer dnsServer;
WebSocketsClient wsClient;
arduino::mqtt::PubSubClient<1024> mqttClient;

// ------------------------------------------------------------------------------
// QUẢN LÝ NÚT NHẤN (DEBOUNCING & EVENTS)
// ------------------------------------------------------------------------------
struct Button {
  uint8_t pin;
  bool lastState;
  bool currentState;
  uint32_t lastDebounceTime;
  bool pressedEvent;
};

Button btnMenu  = { PIN_BTN_MENU,  HIGH, HIGH, 0, false };
Button btnUp    = { PIN_BTN_UP,    HIGH, HIGH, 0, false };
Button btnDown  = { PIN_BTN_DOWN,  HIGH, HIGH, 0, false };
Button btnEnter = { PIN_BTN_ENTER, HIGH, HIGH, 0, false };

const uint32_t DEBOUNCE_DELAY = 45; // ms

// Chế độ chỉnh sửa trong Settings
int  settingCursor = 0;
bool settingEditMode = false;

// ------------------------------------------------------------------------------
// KHAI BÁO NGUYÊN MẪU HÀM
// ------------------------------------------------------------------------------
void updateButtons();
bool isButtonPressed(Button &b);
void readSensors();
void checkAlarms();
void updateAlarmOutputs();
void updateUI();
void drawHeader(const char* title);
void drawDashboardScreen();
void drawPulseScreen();
void drawForceScreen();
void drawSpo2Screen();
void drawPiezoScreen();
void drawSettingsScreen();
void loadSettings();
void saveSettings();
void pushWave(uint8_t buffer[], uint8_t newVal);
void initChipId();
void netSetup();
void netLoop();
void consumeRemoteButton();

// ==============================================================================
// KHỞI ĐỘNG HỆ THỐNG (SETUP)
// ==============================================================================
void setup() {
  Serial.begin(115200);
  delay(100);
  initChipId();
  Serial.println("\n==========================================");
  Serial.println("  SMART FIRST AID FIRMWARE - ESP32-WROOM  ");
  Serial.printf("  Chip ID: %s\n", chipId);
  Serial.println("  MQTT: mqtt.duynguyen.io.vn:443/mqtt");
  Serial.println("==========================================");

  // 1. Cấu hình chân I/O
  pinMode(PIN_BTN_MENU, INPUT_PULLUP);
  pinMode(PIN_BTN_UP, INPUT_PULLUP);
  pinMode(PIN_BTN_DOWN, INPUT_PULLUP);
  pinMode(PIN_BTN_ENTER, INPUT_PULLUP);

  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);
  digitalWrite(PIN_LED, LOW);

  // Cấu hình chân ADC
  pinMode(PIN_OUT_PUL, INPUT);
  pinMode(PIN_OUT_FOR, INPUT);
  pinMode(PIN_OUT_PIE, INPUT);
  analogReadResolution(12); // ESP32 12-bit ADC (0 - 4095)

  // Khởi tạo các bộ đệm đồ thị sóng cảm biến
  for (int i = 0; i < GRAPH_WIDTH; i++) {
    pulseWaveBuffer[i] = 49;
    forceWaveBuffer[i] = 62;
    spo2WaveBuffer[i]  = 49;
    piezoWaveBuffer[i] = 62;
  }

  // 2. Tải cài đặt từ bộ nhớ Flash NVS (Preferences)
  loadSettings();

  // 3. Khởi tạo màn hình OLED (I2C Wire: SDA=21, SCL=22)
  Wire.begin(PIN_OLED_SDA, PIN_OLED_SCL, 400000);
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR)) {
    Serial.println("[ERR] Khong tim thay OLED SSD1306! Kiem tra dia chi 0x3C.");
  } else {
    display.setRotation(OLED_ROTATION); // Cấu hình hướng màn hình (0: Chuẩn, 2: Lật ngược 180 độ)
    Serial.println("[OK] OLED 128x64 khoi tao thanh cong.");
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(16, 4);
    display.println("SMART FIRST AID");
    display.setCursor(22, 18);
    display.printf("Chip %s", chipId);
    display.setCursor(4, 32);
    display.println("mqtt.duynguyen.io.vn");
    display.setCursor(16, 48);
    display.printf("AP %s", apSsid);
    display.display();
    
    // Bíp nhẹ 1 tiếng báo khởi động
    digitalWrite(PIN_BUZZER, HIGH);
    digitalWrite(PIN_LED, HIGH);
    delay(100);
    digitalWrite(PIN_BUZZER, LOW);
    digitalWrite(PIN_LED, LOW);
    delay(600);
  }

  // 4. Khởi tạo cảm biến MAX3010x (I2C Wire1: SDA=26, SCL=25)
  Serial.println("[INFO] Dang ket noi MAX3010x tren SDA:26, SCL:25...");
  if (maxSensor.begin(&WireMax, PIN_MAX_SDA, PIN_MAX_SCL, 100000)) {
    maxOnline = true;
    Serial.println("[OK] Cảm biến MAX3010x đã sẵn sàng.");
  } else {
    maxOnline = false;
    Serial.println("[CANH BAO] Khong tim thay MAX3010x (chua gan cam bien).");
  }

  netSetup();
  Serial.println("[OK] Khoi dong hoan tat. Chuyen vao vong lap chinh.");
}

// ==============================================================================
// VÒNG LẶP CHÍNH (LOOP)
// ==============================================================================
void loop() {
  netLoop();

  // 1. Quét nút nhấn và xử lý sự kiện
  updateButtons();

  // 2. Đọc và lọc tín hiệu từ các cảm biến
  readSensors();

  // 3. Kiểm tra ngưỡng và cảnh báo
  checkAlarms();

  // 4. Điều khiển Còi & LED
  updateAlarmOutputs();

  // 5. Cập nhật giao diện người dùng trên OLED (~20-25 FPS)
  static uint32_t lastUiUpdate = 0;
  if (millis() - lastUiUpdate >= 45) {
    lastUiUpdate = millis();
    updateUI();
  }

  // 6. In định kỳ qua Serial Monitor để gỡ lỗi
  static uint32_t lastSerialLog = 0;
  if (millis() - lastSerialLog >= 1000) {
    lastSerialLog = millis();
    Serial.printf("[SENSOR] Pulse: %d BPM (ADC:%d) | Force: %.1f%% (~%.0fg) | SpO2: %.0f%% (HR:%.0f) | Piezo: %.1f%% (%.2fV)\n",
                  pulseBPM, rawPulseADC, forcePercent, forceGrams, maxSpo2, maxBpm, piezoPercent, piezoVoltage);
    if (alarmActive) {
      Serial.printf("  >>> [CANH BAO!] %s <<<\n", alarmReason.c_str());
    }
  }
}

// ==============================================================================
// XỬ LÝ NÚT BẤM (BUTTON HANDLING)
// ==============================================================================
void updateButtons() {
  consumeRemoteButton();
  Button* buttons[] = { &btnMenu, &btnUp, &btnDown, &btnEnter };

  for (int i = 0; i < 4; i++) {
    Button* b = buttons[i];
    bool reading = digitalRead(b->pin);

    if (reading != b->lastState) {
      b->lastDebounceTime = millis();
    }

    if ((millis() - b->lastDebounceTime) > DEBOUNCE_DELAY) {
      if (reading != b->currentState) {
        b->currentState = reading;
        // Nút nhấn tích cực mức LOW
        if (b->currentState == LOW) {
          b->pressedEvent = true;
        }
      }
    }
    b->lastState = reading;
  }

  // --- Nút MENU: Chuyển đổi màn hình chức năng ---
  if (isButtonPressed(btnMenu)) {
    if (currentScreen == SCREEN_SETTINGS && settingEditMode) {
      // Thoát chế độ edit nếu đang chỉnh sửa
      settingEditMode = false;
      saveSettings();
    } else {
      int next = (int)currentScreen + 1;
      if (next >= TOTAL_SCREENS) next = 0;
      currentScreen = (ScreenMode)next;
    }
    Serial.printf("[UI] Chuyen man hinh: %d\n", currentScreen);
  }

  // --- Nút UP ---
  if (isButtonPressed(btnUp)) {
    if (currentScreen == SCREEN_SETTINGS) {
      if (settingEditMode) {
        // Tăng giá trị tham số
        switch (settingCursor) {
          case 0: configSettings.forceThreshold = min(100, configSettings.forceThreshold + 5); break;
          case 1: configSettings.pulseMinBpm = min(configSettings.pulseMaxBpm - 5, configSettings.pulseMinBpm + 5); break;
          case 2: configSettings.pulseMaxBpm = min(220, configSettings.pulseMaxBpm + 5); break;
          case 3: configSettings.spo2Min = min(99, configSettings.spo2Min + 1); break;
          case 4: configSettings.piezoThreshold = min(100, configSettings.piezoThreshold + 5); break;
          case 5: configSettings.buzzerEnabled = !configSettings.buzzerEnabled; break;
        }
      } else {
        // Di chuyển con trỏ lên
        settingCursor--;
        if (settingCursor < 0) settingCursor = 5;
      }
    } else {
      // Ở chế độ thường: lùi màn hình
      int prev = (int)currentScreen - 1;
      if (prev < 0) prev = TOTAL_SCREENS - 1;
      currentScreen = (ScreenMode)prev;
    }
  }

  // --- Nút DOWN ---
  if (isButtonPressed(btnDown)) {
    if (currentScreen == SCREEN_SETTINGS) {
      if (settingEditMode) {
        // Giảm giá trị tham số
        switch (settingCursor) {
          case 0: configSettings.forceThreshold = max(10, configSettings.forceThreshold - 5); break;
          case 1: configSettings.pulseMinBpm = max(30, configSettings.pulseMinBpm - 5); break;
          case 2: configSettings.pulseMaxBpm = max(configSettings.pulseMinBpm + 5, configSettings.pulseMaxBpm - 5); break;
          case 3: configSettings.spo2Min = max(75, configSettings.spo2Min - 1); break;
          case 4: configSettings.piezoThreshold = max(10, configSettings.piezoThreshold - 5); break;
          case 5: configSettings.buzzerEnabled = !configSettings.buzzerEnabled; break;
        }
      } else {
        // Di chuyển con trỏ xuống
        settingCursor++;
        if (settingCursor > 5) settingCursor = 0;
      }
    } else {
      // Ở chế độ thường: tiến màn hình
      int next = (int)currentScreen + 1;
      if (next >= TOTAL_SCREENS) next = 0;
      currentScreen = (ScreenMode)next;
    }
  }

  // --- Nút ENTER ---
  if (isButtonPressed(btnEnter)) {
    if (currentScreen == SCREEN_SETTINGS) {
      settingEditMode = !settingEditMode;
      if (!settingEditMode) {
        saveSettings();
      }
    } else {
      // Ở màn hình cảm biến: bấm ENTER để Bật/Tắt tắt tiếng còi tạm thời (Mute toggle)
      buzzerMuted = !buzzerMuted;
      Serial.printf("[ALARM] Còi báo %s\n", buzzerMuted ? "DA TAT TIENG (MUTED)" : "BAT TIENG (UNMUTED)");
    }
  }
}

bool isButtonPressed(Button &b) {
  if (b.pressedEvent) {
    b.pressedEvent = false;
    return true;
  }
  return false;
}

// ==============================================================================
// ĐẨY MẪU MỚI VÀO BỘ ĐỆM ĐỒ THỊ SÓNG (128 PIXEL)
// ==============================================================================
void pushWave(uint8_t buffer[], uint8_t newVal) {
  memmove(buffer, buffer + 1, GRAPH_WIDTH - 1);
  buffer[GRAPH_WIDTH - 1] = newVal;
}

// ==============================================================================
// ĐỌC VÀ LỌC TÍN HIỆU CẢM BIẾN (SENSOR SAMPLING)
// ==============================================================================
void readSensors() {
  uint32_t now = millis();

  // 1. ĐỌC CẢM BIẾN NHỊP TIM QUANG HỌC (PULSE SENSOR - GPIO 33)
  static uint32_t lastPulseSample = 0;
  if (now - lastPulseSample >= 10) { // Lấy mẫu 100Hz
    lastPulseSample = now;
    rawPulseADC = analogRead(PIN_OUT_PUL);

    // Lọc thông dải / EMA lọc tín hiệu
    pulseFiltered = 0.85f * pulseFiltered + 0.15f * (float)rawPulseADC;

    // Cập nhật bộ đệm đồ thị sóng nhịp tim (128 điểm ảnh - ~40Hz)
    static uint32_t lastPulseWave = 0;
    if (now - lastPulseWave >= 25) {
      lastPulseWave = now;
      static float pulseDC = 2048;
      pulseDC = 0.96f * pulseDC + 0.04f * pulseFiltered;
      float ac = pulseFiltered - pulseDC;

      static float pulseAmp = 120.0f;
      if (abs(ac) > pulseAmp) pulseAmp = 0.9f * pulseAmp + 0.1f * abs(ac);
      else pulseAmp *= 0.996f;
      if (pulseAmp < 35.0f) pulseAmp = 35.0f;

      int y = 49 - (int)((ac / pulseAmp) * 11.0f);
      y = constrain(y, 36, 62);
      pushWave(pulseWaveBuffer, (uint8_t)y);
    }

    // Thuật toán phát hiện đỉnh nhịp tim (Peak Detection)
    static float pulseThreshold = 2048;
    static bool wasAbove = false;
    pulseThreshold = 0.98f * pulseThreshold + 0.02f * pulseFiltered;

    if (pulseFiltered > (pulseThreshold + 120)) {
      if (!wasAbove && (now - lastPulseBeatTime > 320)) { // Giới hạn nhịp tối đa 190 BPM
        uint32_t interval = now - lastPulseBeatTime;
        lastPulseBeatTime = now;
        wasAbove = true;
        pulseBeatDetected = true;

        if (interval > 320 && interval < 1500) { // 40 - 187 BPM
          int instantBPM = 60000 / interval;
          if (pulseBPM == 0) pulseBPM = instantBPM;
          else pulseBPM = (int)(0.65f * pulseBPM + 0.35f * instantBPM);
        }
      }
    } else if (pulseFiltered < (pulseThreshold - 50)) {
      wasAbove = false;
    }

    // Nếu quá 2.5 giây không có nhịp thì reset BPM về 0
    if (now - lastPulseBeatTime > 2500) {
      pulseBPM = 0;
    }
  }

  // 2. ĐỌC CẢM BIẾN LỰC / ÁP SUẤT (FORCE SENSOR FSR - GPIO 32)
  static uint32_t lastForceSample = 0;
  if (now - lastForceSample >= 25) { // 40Hz
    lastForceSample = now;
    rawForceADC = analogRead(PIN_OUT_FOR);

    // Lọc mượt
    static float smoothedForce = 0;
    smoothedForce = 0.8f * smoothedForce + 0.2f * (float)rawForceADC;

    // Tính phần trăm lực ép (0 - 100%)
    forcePercent = (smoothedForce / 4095.0f) * 100.0f;
    forcePercent = constrain(forcePercent, 0.0f, 100.0f);

    // Ước tính tải trọng theo đường đặc tính FSR (áp dụng cho FSR-402 / RFP-602)
    // 0 -> 2000g (2kg)
    if (smoothedForce < 100) {
      forceGrams = 0;
    } else {
      forceGrams = (smoothedForce - 100) * (2000.0f / 3995.0f);
    }

    // Cập nhật bộ đệm đồ thị diễn biến lực (128 điểm ảnh)
    static uint32_t lastForceWave = 0;
    if (now - lastForceWave >= 30) {
      lastForceWave = now;
      int y = 62 - (int)((forcePercent / 100.0f) * 24.0f);
      y = constrain(y, 37, 62);
      pushWave(forceWaveBuffer, (uint8_t)y);
    }
  }

  // 3. ĐỌC CẢM BIẾN SPO2 & NHỊP TIM MAX3010x (GPIO 26/25)
  if (maxOnline) {
    maxSensor.update();
    maxFinger = maxSensor.isFingerDetected();
    maxSpo2   = maxSensor.getSpO2();
    maxBpm    = maxSensor.getHeartRate();
  }

  // Cập nhật bộ đệm đồ thị sóng mạch quang học PPG từ MAX3010x
  static uint32_t lastSpo2Wave = 0;
  if (now - lastSpo2Wave >= 25) {
    lastSpo2Wave = now;
    int y = 49;
    if (maxOnline && maxFinger) {
      float acIr = maxSensor.getACWave();
      static float spo2Amp = 120.0f;
      if (abs(acIr) > spo2Amp) spo2Amp = 0.9f * spo2Amp + 0.1f * abs(acIr);
      else spo2Amp *= 0.996f;
      if (spo2Amp < 30.0f) spo2Amp = 30.0f;

      y = 49 - (int)((acIr / spo2Amp) * 11.0f);
      y = constrain(y, 36, 62);
    }
    pushWave(spo2WaveBuffer, (uint8_t)y);
  }

  // 4. ĐỌC CẢM BIẾN ĐIỆN THẾ SINH HỌC / RUNG (PIEZO - GPIO 35)
  static uint32_t lastPiezoSample = 0;
  if (now - lastPiezoSample >= 15) {
    lastPiezoSample = now;
    rawPiezoADC = analogRead(PIN_OUT_PIE);

    // Tính điện áp thực tế (0 - 3.3V)
    piezoVoltage = (rawPiezoADC * 3.3f) / 4095.0f;

    // Lấy đỉnh xung (Peak detector với decay)
    static float currentPeak = 0;
    if (rawPiezoADC > currentPeak) {
      currentPeak = rawPiezoADC;
    } else {
      currentPeak *= 0.94f; // Suy hao tự nhiên
    }
    piezoPeak = currentPeak;
    piezoPercent = constrain((piezoPeak / 4095.0f) * 100.0f, 0.0f, 100.0f);

    // Cập nhật bộ đệm đồ thị dao động sóng xung điện thế / rung
    static uint32_t lastPiezoWave = 0;
    if (now - lastPiezoWave >= 25) {
      lastPiezoWave = now;
      int y = 62 - (int)((piezoPercent / 100.0f) * 24.0f);
      y = constrain(y, 37, 62);
      pushWave(piezoWaveBuffer, (uint8_t)y);
    }
  }
}


// ==============================================================================
// KIỂM TRA NGƯỠNG CẢNH BÁO (ALARM LOGIC)
// ==============================================================================
void checkAlarms() {
  alarmPulse = false;
  alarmForce = false;
  alarmSpo2  = false;
  alarmPiezo = false;
  alarmReason = "";

  // 1. Kiểm tra cảm biến Lực (Force Sensor)
  if (forcePercent > configSettings.forceThreshold) {
    alarmForce = true;
    alarmReason = "LUC VUOT NGUONG!";
  }

  // 2. Kiểm tra cảm biến Nhịp tim (Pulse Sensor)
  // Chỉ cảnh báo khi đang có tín hiệu nhịp tim hợp lệ (BPM > 0)
  if (pulseBPM > 0) {
    if (pulseBPM > configSettings.pulseMaxBpm) {
      alarmPulse = true;
      alarmReason = "NHIP TIM QUA CAO!";
    } else if (pulseBPM < configSettings.pulseMinBpm) {
      alarmPulse = true;
      alarmReason = "NHIP TIM QUA THAP!";
    }
  }

  // 3. Kiểm tra cảm biến SpO2 (Oxy máu)
  // Chỉ cảnh báo khi có ngón tay và giá trị SpO2 hợp lệ
  if (maxOnline && maxFinger && maxSpo2 > 50) {
    if (maxSpo2 < configSettings.spo2Min) {
      alarmSpo2 = true;
      alarmReason = "THIEU OXY (SPO2 THAP)!";
    }
  }

  // 4. Kiểm tra cảm biến Điện thế sinh học / Rung (Piezo)
  if (piezoPercent > configSettings.piezoThreshold) {
    alarmPiezo = true;
    alarmReason = "RUNG/XUNG QUA NGUONG!";
  }

  // Tổng hợp trạng thái báo động
  alarmActive = (alarmForce || alarmPulse || alarmSpo2 || alarmPiezo);
}

// ==============================================================================
// ĐIỀU KHIỂN CÒI BÁO VÀ ĐÈN LED (BUZZER & LED CONTROL)
// ==============================================================================
void updateAlarmOutputs() {
  uint32_t now = millis();

  if (alarmActive) {
    // Nếu có cảnh báo: còi kêu theo nhịp dồn dập (100ms ON / 100ms OFF)
    bool beepState = ((now / 120) % 2 == 0);

    // Bật còi nếu được phép và không bị tắt tiếng (Mute)
    if (configSettings.buzzerEnabled && !buzzerMuted) {
      digitalWrite(PIN_BUZZER, beepState ? HIGH : LOW);
    } else {
      digitalWrite(PIN_BUZZER, LOW);
    }

    // Đèn LED chớp theo nhịp còi báo
    digitalWrite(PIN_LED, beepState ? HIGH : LOW);

  } else {
    // Trạng thái bình thường
    digitalWrite(PIN_BUZZER, LOW);

    // Đèn LED nháy nhẹ theo nhịp tim khi có phát hiện nhịp
    if (pulseBeatDetected) {
      pulseBeatDetected = false;
      digitalWrite(PIN_LED, HIGH);
    } else if (now - lastPulseBeatTime > 60) {
      digitalWrite(PIN_LED, LOW);
    }
  }
}

// ==============================================================================
// GIAO DIỆN HIỂN THỊ TRÊN MÀN HÌNH OLED (UI RENDERER)
// ==============================================================================
void updateUI() {
  display.clearDisplay();

  switch (currentScreen) {
    case SCREEN_DASHBOARD:
      drawDashboardScreen();
      break;
    case SCREEN_PULSE:
      drawPulseScreen();
      break;
    case SCREEN_FORCE:
      drawForceScreen();
      break;
    case SCREEN_SPO2:
      drawSpo2Screen();
      break;
    case SCREEN_PIEZO:
      drawPiezoScreen();
      break;
    case SCREEN_SETTINGS:
      drawSettingsScreen();
      break;
  }

  display.display();
}

// ------------------------------------------------------------------------------
// Vẽ thanh tiêu đề trên cùng (Header)
// ------------------------------------------------------------------------------
void drawHeader(const char* title) {
  // Nếu đang có cảnh báo: nhấp nháy đảo màu tiêu đề
  bool blink = (millis() / 250) % 2;

  if (alarmActive && blink) {
    display.fillRect(0, 0, 128, 11, SSD1306_WHITE);
    display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
    display.setCursor(2, 2);
    display.print("! CANH BAO !");
  } else {
    display.setTextColor(SSD1306_WHITE, SSD1306_BLACK);
    display.setCursor(2, 2);
    display.print(title);
  }

  // Biểu tượng loa / còi báo ở góc trên bên phải
  display.setCursor(102, 2);
  if (!configSettings.buzzerEnabled) {
    display.print("[OFF]");
  } else if (buzzerMuted) {
    display.print("[M]");
  } else if (alarmActive) {
    display.print("[!]");
  } else if (!mqttOnline) {
    display.print("NET");
  } else {
    display.print("[OK]");
  }

  // Đường kẻ phân cách
  display.drawLine(0, 11, 127, 11, SSD1306_WHITE);
  display.setTextColor(SSD1306_WHITE, SSD1306_BLACK);
}

// ------------------------------------------------------------------------------
// Màn hình 0: Tổng quan cả 4 cảm biến (Dashboard)
// ------------------------------------------------------------------------------
void drawDashboardScreen() {
  char title[20];
  snprintf(title, sizeof(title), "1. %s", chipId);
  drawHeader(title);

  // Dòng 1: Nhịp tim
  display.setCursor(2, 14);
  display.print("N.Tim: ");
  if (pulseBPM > 0) {
    display.printf("%3d bpm", pulseBPM);
    if (alarmPulse) display.print(" !");
  } else {
    display.print("--- bpm");
  }

  // Dòng 2: Áp lực / Lực
  display.setCursor(2, 26);
  display.print("Luc  : ");
  display.printf("%3.0f%% (%4.0fg)", forcePercent, forceGrams);
  if (alarmForce) display.print(" !");

  // Dòng 3: SpO2 Nồng độ oxy
  display.setCursor(2, 38);
  display.print("SpO2 : ");
  if (maxOnline && maxFinger && maxSpo2 > 0) {
    display.printf("%3.0f%%", maxSpo2);
    if (alarmSpo2) display.print(" !");
  } else if (!maxOnline) {
    display.print("K.co IC");
  } else {
    display.print("Chua dat");
  }

  // Dòng 4: Điện thế sinh học / Piezo
  display.setCursor(2, 50);
  display.print("Piezo: ");
  display.printf("%3.0f%% (%1.2fV)", piezoPercent, piezoVoltage);
  if (alarmPiezo) display.print(" !");

  // Dải trạng thái dưới cùng
  if (alarmActive) {
    display.fillRect(0, 54, 128, 10, SSD1306_WHITE);
    display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
    display.setCursor(2, 55);
    display.print(alarmReason);
    display.setTextColor(SSD1306_WHITE, SSD1306_BLACK);
  }
}

// ------------------------------------------------------------------------------
// Màn hình 1: Cảm biến nhịp tim (Pulse Sensor)
// ------------------------------------------------------------------------------
void drawPulseScreen() {
  drawHeader("2. NHIP TIM (PULSE)");

  // Hiển thị BPM kích thước lớn
  display.setTextSize(2);
  display.setCursor(2, 13);
  if (pulseBPM > 0) {
    display.printf("%3d", pulseBPM);
  } else {
    display.print("---");
  }
  display.setTextSize(1);
  display.setCursor(42, 13);
  display.print("BPM");

  // Biểu tượng trái tim nhấp nháy khi có nhịp
  bool heartOn = (millis() - lastPulseBeatTime) < 180;
  display.setCursor(72, 13);
  if (heartOn) display.print("<3 BEAT");
  else display.print("   BEAT");

  // Hiển thị thông số ngưỡng & cảnh báo
  display.setCursor(2, 25);
  display.printf("Nguong:%d-%dBPM", configSettings.pulseMinBpm, configSettings.pulseMaxBpm);
  if (alarmPulse) {
    display.setCursor(96, 25);
    display.print("[!]");
  } else if (pulseBPM > 0) {
    display.setCursor(96, 25);
    display.print("[OK]");
  }

  // Khung vẽ đồ thị sóng ECG nhịp tim thời gian thực (128x29 px)
  display.drawRect(0, 35, 128, 29, SSD1306_WHITE);
  // Đường chuẩn ngang nét đứt ở giữa (y = 49)
  for (int x = 2; x < 126; x += 4) {
    display.drawPixel(x, 49, SSD1306_WHITE);
  }
  // Vẽ đồ thị sóng liên tục
  for (int x = 0; x < 127; x++) {
    display.drawLine(x, pulseWaveBuffer[x], x + 1, pulseWaveBuffer[x + 1], SSD1306_WHITE);
  }
  display.setCursor(106, 37);
  display.print("ECG");
}

// ------------------------------------------------------------------------------
// Màn hình 2: Cảm biến lực / Áp suất (Force Sensor)
// ------------------------------------------------------------------------------
void drawForceScreen() {
  drawHeader("3. CAM BIEN LUC");

  // Hiển thị lực phần trăm lớn
  display.setTextSize(2);
  display.setCursor(2, 13);
  display.printf("%3.0f%%", forcePercent);
  display.setTextSize(1);
  display.setCursor(52, 13);
  display.printf("~%.0fg", forceGrams);

  // Hiển thị ngưỡng & trạng thái
  display.setCursor(2, 25);
  display.printf("Nguong: >%d%%", configSettings.forceThreshold);
  if (alarmForce) {
    display.setCursor(80, 25);
    display.print("[ALARM!]");
  } else {
    display.setCursor(96, 25);
    display.print("[OK]");
  }

  // Khung vẽ biểu đồ biến thiên lực theo thời gian (128x29 px)
  display.drawRect(0, 35, 128, 29, SSD1306_WHITE);
  // Vạch ngưỡng nét đứt
  int threshY = 62 - (int)((configSettings.forceThreshold / 100.0f) * 24.0f);
  for (int x = 2; x < 126; x += 4) {
    display.drawPixel(x, threshY, SSD1306_WHITE);
  }
  // Đường cong biểu diễn lực
  for (int x = 0; x < 127; x++) {
    display.drawLine(x, forceWaveBuffer[x], x + 1, forceWaveBuffer[x + 1], SSD1306_WHITE);
  }
  display.setCursor(106, 37);
  display.print("FSR");
}

// ------------------------------------------------------------------------------
// Màn hình 3: Cảm biến SpO2 Oxy máu (MAX3010x)
// ------------------------------------------------------------------------------
void drawSpo2Screen() {
  drawHeader("4. OXY MAU (SPO2)");

  if (!maxOnline) {
    display.setCursor(4, 20);
    display.print("CHUA KET NOI IC (I2C1)");
    display.setCursor(4, 34);
    display.print("Kiem tra day SDA/SCL:");
    display.setCursor(4, 48);
    display.print("Pin 26 (SDA), 25 (SCL)");
    return;
  }

  // Hiển thị SpO2 lớn
  display.setTextSize(2);
  display.setCursor(2, 13);
  if (maxFinger && maxSpo2 > 0) {
    display.printf("%2.0f%%", maxSpo2);
  } else {
    display.print("--%");
  }
  display.setTextSize(1);
  display.setCursor(42, 13);
  display.print("SpO2");

  display.setCursor(76, 13);
  if (maxFinger && maxBpm > 0) {
    display.printf("%2.0fbpm", maxBpm);
  } else {
    display.print("--bpm");
  }

  display.setCursor(2, 25);
  display.printf("Nguong: <%d%%", configSettings.spo2Min);
  if (alarmSpo2) {
    display.setCursor(80, 25);
    display.print("[ALARM!]");
  } else if (maxFinger) {
    display.setCursor(96, 25);
    display.print("[OK]");
  }

  // Khung vẽ đồ thị sóng mạch quang học PPG từ MAX3010x (128x29 px)
  display.drawRect(0, 35, 128, 29, SSD1306_WHITE);
  if (!maxFinger) {
    for (int x = 2; x < 126; x += 4) {
      display.drawPixel(x, 49, SSD1306_WHITE);
    }
    display.setCursor(10, 46);
    display.print("DAT TAY LEN CAM BIEN");
  } else {
    for (int x = 2; x < 126; x += 4) {
      display.drawPixel(x, 49, SSD1306_WHITE);
    }
    for (int x = 0; x < 127; x++) {
      display.drawLine(x, spo2WaveBuffer[x], x + 1, spo2WaveBuffer[x + 1], SSD1306_WHITE);
    }
    display.setCursor(106, 37);
    display.print("PPG");
  }
}

// ------------------------------------------------------------------------------
// Màn hình 4: Cảm biến Điện thế sinh học / Rung (Piezoelectric)
// ------------------------------------------------------------------------------
void drawPiezoScreen() {
  drawHeader("5. DIEN THE (PIEZO)");

  // Hiển thị phần trăm và điện áp
  display.setTextSize(2);
  display.setCursor(2, 13);
  display.printf("%3.0f%%", piezoPercent);
  display.setTextSize(1);
  display.setCursor(52, 13);
  display.printf("%.2fV", piezoVoltage);

  // Hiển thị ngưỡng & trạng thái
  display.setCursor(2, 25);
  display.printf("Nguong: >%d%%", configSettings.piezoThreshold);
  if (alarmPiezo) {
    display.setCursor(80, 25);
    display.print("[ALARM!]");
  } else {
    display.setCursor(96, 25);
    display.print("[OK]");
  }

  // Khung vẽ biểu đồ dao động sóng cơ / điện thế sinh học (128x29 px)
  display.drawRect(0, 35, 128, 29, SSD1306_WHITE);
  int threshY = 62 - (int)((configSettings.piezoThreshold / 100.0f) * 24.0f);
  for (int x = 2; x < 126; x += 4) {
    display.drawPixel(x, threshY, SSD1306_WHITE);
  }
  for (int x = 0; x < 127; x++) {
    display.drawLine(x, piezoWaveBuffer[x], x + 1, piezoWaveBuffer[x + 1], SSD1306_WHITE);
  }
  display.setCursor(106, 37);
  display.print("VIB");
}


// ------------------------------------------------------------------------------
// Màn hình 5: Cài đặt ngưỡng cảnh báo (Settings Menu)
// ------------------------------------------------------------------------------
void drawSettingsScreen() {
  drawHeader("6. CAI DAT NGUONG");

  const char* labels[] = {
    "1.Luc Max (%): ",
    "2.Nhip tim Min: ",
    "3.Nhip tim Max: ",
    "4.SpO2 Min (%): ",
    "5.Piezo Max(%): ",
    "6.Coi bao (BZ): "
  };

  // Hiển thị 4 mục một lúc có cuộn theo con trỏ
  int startIdx = 0;
  if (settingCursor >= 3) {
    startIdx = settingCursor - 2;
    if (startIdx > 2) startIdx = 2;
  }

  for (int i = 0; i < 4; i++) {
    int idx = startIdx + i;
    int y = 14 + i * 11;

    // Dấu con trỏ chọn
    if (idx == settingCursor) {
      if (settingEditMode) {
        // Nhấp nháy khi đang chế độ sửa giá trị
        if ((millis() / 200) % 2 == 0) {
          display.setCursor(0, y);
          display.print("*");
        }
      } else {
        display.setCursor(0, y);
        display.print(">");
      }
    }

    display.setCursor(8, y);
    display.print(labels[idx]);

    // Giá trị tương ứng
    switch (idx) {
      case 0: display.printf("%3d%%", configSettings.forceThreshold); break;
      case 1: display.printf("%3d", configSettings.pulseMinBpm); break;
      case 2: display.printf("%3d", configSettings.pulseMaxBpm); break;
      case 3: display.printf("%3d%%", configSettings.spo2Min); break;
      case 4: display.printf("%3d%%", configSettings.piezoThreshold); break;
      case 5: display.print(configSettings.buzzerEnabled ? "BAT" : "TAT"); break;
    }
  }

  // Hướng dẫn thao tác dưới chân màn hình
  display.setCursor(2, 57);
  if (settingEditMode) {
    display.print("UP/DOWN:Doi | ENT:Luu");
  } else {
    display.print("UP/DN:Chon | ENT:Sua");
  }
}

// ==============================================================================
// LƯU TRỮ VÀ KHÔI PHỤC CÀI ĐẶT TỪ FLASH NVS (PREFERENCES)
// ==============================================================================
void loadSettings() {
  prefs.begin("firstaid", false);
  configSettings.forceThreshold = prefs.getInt("forceThresh", 60);
  configSettings.pulseMinBpm    = prefs.getInt("pulseMin", 50);
  configSettings.pulseMaxBpm    = prefs.getInt("pulseMax", 120);
  configSettings.spo2Min        = prefs.getInt("spo2Min", 92);
  configSettings.piezoThreshold = prefs.getInt("piezoThresh", 50);
  configSettings.buzzerEnabled  = prefs.getBool("buzzerEn", true);
  prefs.end();

  Serial.println("[CONFIG] Da doc cai dat tu Flash NVS:");
  Serial.printf("  - Force Max:  %d%%\n", configSettings.forceThreshold);
  Serial.printf("  - Pulse Min:  %d BPM\n", configSettings.pulseMinBpm);
  Serial.printf("  - Pulse Max:  %d BPM\n", configSettings.pulseMaxBpm);
  Serial.printf("  - SpO2 Min:   %d%%\n", configSettings.spo2Min);
  Serial.printf("  - Piezo Max:  %d%%\n", configSettings.piezoThreshold);
  Serial.printf("  - Buzzer:     %s\n", configSettings.buzzerEnabled ? "BAT" : "TAT");
}

void saveSettings() {
  prefs.begin("firstaid", false);
  prefs.putInt("forceThresh", configSettings.forceThreshold);
  prefs.putInt("pulseMin", configSettings.pulseMinBpm);
  prefs.putInt("pulseMax", configSettings.pulseMaxBpm);
  prefs.putInt("spo2Min", configSettings.spo2Min);
  prefs.putInt("piezoThresh", configSettings.piezoThreshold);
  prefs.putBool("buzzerEn", configSettings.buzzerEnabled);
  prefs.end();
  Serial.println("[CONFIG] Da luu cai dat moi vao Flash NVS thanh cong!");
}

// ==============================================================================
// WIFI PORTAL + MQTT WSS (mqtt.duynguyen.io.vn) — ĐỊNH DANH BẰNG CHIP ID
// Topic: tele/<chipId>/oled   Lệnh: cmnd/<chipId>/BTN  và  cmnd/<chipId>/SCREEN
// ==============================================================================
static const char *MQTT_HOST = "mqtt.duynguyen.io.vn";
static const int MQTT_PORT = 443;
static const char *MQTT_PATH = "/mqtt";
static const IPAddress AP_IP(192, 168, 4, 1);

void initChipId() {
  uint64_t mac = ESP.getEfuseMac();
  snprintf(chipId, sizeof(chipId), "%06X", (uint32_t)(mac & 0xFFFFFF));
  snprintf(apSsid, sizeof(apSsid), "AID_%s", chipId);
}

void consumeRemoteButton() {
  if (!remoteBtn) return;
  Button *b = nullptr;
  if (remoteBtn == 'M') b = &btnMenu;
  else if (remoteBtn == 'U') b = &btnUp;
  else if (remoteBtn == 'D') b = &btnDown;
  else if (remoteBtn == 'E') b = &btnEnter;
  remoteBtn = 0;
  if (b) b->pressedEvent = true;
}

void loadWifiCreds() {
  prefs.begin("aidwifi", true);
  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("pass", "");
  prefs.end();
  ssid.toCharArray(wifiSsid, sizeof(wifiSsid));
  pass.toCharArray(wifiPass, sizeof(wifiPass));
}

void saveWifiCreds(const String &ssid, const String &pass) {
  prefs.begin("aidwifi", false);
  prefs.putString("ssid", ssid);
  prefs.putString("pass", pass);
  prefs.end();
  ssid.toCharArray(wifiSsid, sizeof(wifiSsid));
  pass.toCharArray(wifiPass, sizeof(wifiPass));
}

void ensureSoftAp() {
  WiFi.softAPConfig(AP_IP, AP_IP, IPAddress(255, 255, 255, 0));
  WiFi.softAP(apSsid);
}

const char PORTAL_PAGE[] PROGMEM = R"HTML(
<!DOCTYPE html><html><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AID WiFi</title>
<style>
body{font-family:sans-serif;background:#101612;color:#e8ffe8;padding:16px}
button,input{width:100%;padding:12px;margin:6px 0;box-sizing:border-box;border-radius:8px;border:0}
button{background:#1fa971;color:#fff;font-weight:700}
input{background:#1c2820;color:#fff}
.ap{padding:10px;background:#1c2820;border-radius:8px;margin:6px 0}
</style></head><body>
<h2>Smart First AID</h2>
<p id="chip">Dang tai chip...</p>
<button onclick="scan()">Quet WiFi</button>
<div id="list"></div>
<input id="ssid" placeholder="Ten WiFi">
<input id="pass" type="password" placeholder="Mat khau">
<button onclick="save()">Luu va ket noi</button>
<pre id="st"></pre>
<script>
chip.textContent = "Phat WiFi: " + location.hostname;
async function scan(){
  list.textContent = "Dang quet...";
  try {
    const rows = await (await fetch("/scan")).json();
    list.innerHTML = rows.map(n =>
      `<div class="ap" onclick="ssid.value=this.dataset.s" data-s="${n.ssid}">${n.ssid} (${n.rssi})</div>`
    ).join("") || "Khong thay mang";
  } catch (e) { list.textContent = "Loi quet"; }
}
async function save(){
  st.textContent = "Dang luu...";
  const body = "ssid=" + encodeURIComponent(ssid.value) + "&pass=" + encodeURIComponent(pass.value);
  const res = await fetch("/connect", {method:"POST", headers:{"Content-Type":"application/x-www-form-urlencoded"}, body});
  st.textContent = await res.text();
}
</script></body></html>
)HTML";

void handleRoot() {
  webServer.send_P(200, "text/html", PORTAL_PAGE);
}

void handleScan() {
  WiFi.mode(WIFI_AP_STA);
  int n = WiFi.scanNetworks(false, false);
  String json = "[";
  for (int i = 0; i < n; i++) {
    if (i) json += ",";
    String ss = WiFi.SSID(i);
    ss.replace("\\", "\\\\");
    ss.replace("\"", "\\\"");
    json += "{\"ssid\":\"" + ss + "\",\"rssi\":" + String(WiFi.RSSI(i)) + "}";
  }
  json += "]";
  if (n > 0) WiFi.scanDelete();
  ensureSoftAp();
  webServer.send(200, "application/json", json);
}

void handleConnect() {
  String ssid = webServer.arg("ssid");
  String pass = webServer.arg("pass");
  ssid.trim();
  if (ssid.length() == 0 || ssid.length() > 31) {
    webServer.send(200, "application/json", "{\"ok\":false,\"msg\":\"Thieu ten WiFi\"}");
    return;
  }
  saveWifiCreds(ssid, pass);
  wifiBeginPending = true;
  webServer.send(200, "application/json", "{\"ok\":true,\"msg\":\"Da luu. ESP dang ket noi WiFi.\"}");
}

void startPortal() {
  if (portalActive) return;
  portalActive = true;
  WiFi.persistent(false);
  WiFi.setSleep(false);
  WiFi.mode(WIFI_AP_STA);
  delay(80);
  ensureSoftAp();
  dnsServer.start(53, "*", AP_IP);
  static bool routesReady = false;
  if (!routesReady) {
    routesReady = true;
    webServer.on("/", HTTP_GET, handleRoot);
    webServer.on("/scan", HTTP_GET, handleScan);
    webServer.on("/connect", HTTP_POST, handleConnect);
    webServer.onNotFound([]() {
      webServer.sendHeader("Location", "http://192.168.4.1/", true);
      webServer.send(302, "text/plain", "");
    });
  }
  webServer.begin();
  Serial.printf("[WIFI] Portal %s -> http://192.168.4.1  chip %s\n", apSsid, chipId);
}

void stopPortal() {
  if (!portalActive) return;
  webServer.stop();
  dnsServer.stop();
  WiFi.softAPdisconnect(true);
  WiFi.mode(WIFI_STA);
  portalActive = false;
}

void ensureMqtt() {
  if (mqttStackReady) return;
  mqttStackReady = true;
  wsClient.beginSSL(MQTT_HOST, MQTT_PORT, MQTT_PATH);
  wsClient.setExtraHeaders("Sec-WebSocket-Protocol: mqtt");
  wsClient.setReconnectInterval(5000);
  mqttClient.begin(wsClient);
  mqttClient.setTimeout(4000);
  mqttClient.setCleanSession(true);
  Serial.printf("[MQTT] WSS %s:%d%s  client AID-%s\n", MQTT_HOST, MQTT_PORT, MQTT_PATH, chipId);
}

void onRemoteBtn(const char *payload, size_t len) {
  if (!payload || len == 0) return;
  char c = (char)toupper((unsigned char)payload[0]);
  if (c == 'M' || c == 'U' || c == 'D' || c == 'E') remoteBtn = c;
}

void onRemoteScreen(const char *payload, size_t len) {
  if (!payload || len == 0) return;
  if (payload[0] >= '0' && payload[0] <= '5') {
    currentScreen = (ScreenMode)(payload[0] - '0');
    settingEditMode = false;
  }
}

void mqttConnect() {
  if (mqttClient.isConnected()) return;
  char clientId[20];
  char willTopic[40];
  snprintf(clientId, sizeof(clientId), "AID-%s", chipId);
  snprintf(willTopic, sizeof(willTopic), "tele/%s/status", chipId);
  mqttClient.setWill(willTopic, "offline", true, 1);
  if (!mqttClient.connect(clientId, "", "")) {
    mqttOnline = false;
    Serial.println("[MQTT] Khong ket noi duoc broker");
    return;
  }
  mqttOnline = true;
  Serial.printf("[MQTT] Da ket noi. Chip %s\n", chipId);
  mqttClient.publish(willTopic, "online", true, 1);

  char topicBtn[40];
  char topicScreen[44];
  snprintf(topicBtn, sizeof(topicBtn), "cmnd/%s/BTN", chipId);
  snprintf(topicScreen, sizeof(topicScreen), "cmnd/%s/SCREEN", chipId);
  mqttClient.subscribe(topicBtn, onRemoteBtn);
  mqttClient.subscribe(topicScreen, onRemoteScreen);
}

const char *badgeText() {
  if (!configSettings.buzzerEnabled) return "[OFF]";
  if (buzzerMuted) return "[M]";
  if (alarmActive) return "[!]";
  if (!mqttOnline) return "NET";
  return "[OK]";
}

void screenTitle(char *out, size_t n) {
  switch (currentScreen) {
    case SCREEN_DASHBOARD: snprintf(out, n, "1. %s", chipId); break;
    case SCREEN_PULSE: snprintf(out, n, "2. NHIP TIM (PULSE)"); break;
    case SCREEN_FORCE: snprintf(out, n, "3. CAM BIEN LUC"); break;
    case SCREEN_SPO2: snprintf(out, n, "4. OXY MAU (SPO2)"); break;
    case SCREEN_PIEZO: snprintf(out, n, "5. DIEN THE (PIEZO)"); break;
    default: snprintf(out, n, "6. CAI DAT NGUONG"); break;
  }
}

void publishOled() {
  if (!mqttClient.isConnected()) {
    mqttOnline = false;
    return;
  }
  mqttOnline = true;

  char title[28];
  char reason[48];
  char ip[16];
  screenTitle(title, sizeof(title));
  strncpy(reason, alarmReason.c_str(), sizeof(reason) - 1);
  reason[sizeof(reason) - 1] = 0;
  for (char *p = reason; *p; ++p) {
    if (*p == '"' || *p == '\\') *p = ' ';
  }
  if (WiFi.status() == WL_CONNECTED) WiFi.localIP().toString().toCharArray(ip, sizeof(ip));
  else strncpy(ip, "0.0.0.0", sizeof(ip));

  char body[1000];
  int pos = snprintf(
      body, sizeof(body),
      "{\"id\":\"%s\",\"screen\":%d,\"title\":\"%s\",\"badge\":\"%s\","
      "\"alarm\":%d,\"reason\":\"%s\",\"mute\":%d,\"bz\":%d,\"edit\":%d,\"cursor\":%d,"
      "\"hr\":%d,\"hrAdc\":%d,\"force\":%.1f,\"grams\":%.0f,"
      "\"spo2\":%.0f,\"spo2hr\":%.0f,\"maxOk\":%d,\"finger\":%d,"
      "\"piezo\":%.1f,\"volt\":%.2f,"
      "\"aHr\":%d,\"aF\":%d,\"aO2\":%d,\"aPz\":%d,"
      "\"fMax\":%d,\"hrMin\":%d,\"hrMax\":%d,\"o2Min\":%d,\"pMax\":%d,"
      "\"wifi\":%d,\"mqtt\":1,\"rssi\":%d,\"ip\":\"%s\",\"w\":[",
      chipId, (int)currentScreen, title, badgeText(),
      alarmActive ? 1 : 0, reason, buzzerMuted ? 1 : 0, configSettings.buzzerEnabled ? 1 : 0,
      settingEditMode ? 1 : 0, settingCursor,
      pulseBPM, rawPulseADC, forcePercent, forceGrams,
      maxSpo2, maxBpm, maxOnline ? 1 : 0, maxFinger ? 1 : 0,
      piezoPercent, piezoVoltage,
      alarmPulse ? 1 : 0, alarmForce ? 1 : 0, alarmSpo2 ? 1 : 0, alarmPiezo ? 1 : 0,
      configSettings.forceThreshold, configSettings.pulseMinBpm, configSettings.pulseMaxBpm,
      configSettings.spo2Min, configSettings.piezoThreshold,
      1, WiFi.RSSI(), ip);

  if (pos < 0 || pos >= (int)sizeof(body) - 8) return;

  const uint8_t *wave = nullptr;
  if (currentScreen == SCREEN_PULSE) wave = pulseWaveBuffer;
  else if (currentScreen == SCREEN_FORCE) wave = forceWaveBuffer;
  else if (currentScreen == SCREEN_SPO2) wave = spo2WaveBuffer;
  else if (currentScreen == SCREEN_PIEZO) wave = piezoWaveBuffer;

  if (wave) {
    for (int i = 0; i < GRAPH_WIDTH; i += 4) {
      int wrote = snprintf(body + pos, sizeof(body) - pos, "%s%u", (i == 0 ? "" : ","), wave[i]);
      if (wrote < 0 || pos + wrote >= (int)sizeof(body) - 3) break;
      pos += wrote;
    }
  }
  snprintf(body + pos, sizeof(body) - pos, "]}");

  char topic[40];
  snprintf(topic, sizeof(topic), "tele/%s/oled", chipId);
  mqttClient.publish(topic, body, false, 0);
}

void netSetup() {
  WiFi.persistent(false);
  WiFi.setSleep(false);
  WiFi.mode(WIFI_STA);
  loadWifiCreds();
  Serial.printf("[NET] Chip %s  AP %s\n", chipId, apSsid);
  if (wifiSsid[0]) {
    Serial.printf("[WIFI] Dang ket noi %s\n", wifiSsid);
    WiFi.begin(wifiSsid, wifiPass);
    uint32_t t0 = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t0 < 8000) delay(200);
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("[WIFI] OK ");
    Serial.println(WiFi.localIP());
    ensureMqtt();
    lastWifiTry = millis();
  } else {
    Serial.println("[WIFI] Chua co mang. Mo portal cau hinh.");
    startPortal();
    lastWifiTry = millis();
  }
}

void netLoop() {
  if (portalActive) {
    dnsServer.processNextRequest();
    webServer.handleClient();
  }

  if (wifiBeginPending && wifiSsid[0]) {
    wifiBeginPending = false;
    WiFi.mode(WIFI_AP_STA);
    ensureSoftAp();
    WiFi.begin(wifiSsid, wifiPass);
    lastWifiTry = millis();
    Serial.printf("[WIFI] Thu ket noi %s\n", wifiSsid);
  }

  if (WiFi.status() == WL_CONNECTED) {
    if (portalActive) stopPortal();
    ensureMqtt();
    if (!mqttClient.isConnected()) {
      mqttOnline = false;
      wsClient.loop();
      if (millis() - lastMqttTry > 6000) {
        lastMqttTry = millis();
        mqttConnect();
      }
    } else {
      mqttClient.update();
      mqttOnline = mqttClient.isConnected();
      if (mqttOnline && millis() - lastTele >= 500) {
        lastTele = millis();
        publishOled();
      }
    }
  } else {
    mqttOnline = false;
    if (!portalActive) startPortal();
    if (wifiSsid[0] && millis() - lastWifiTry > 15000) {
      lastWifiTry = millis();
      WiFi.mode(WIFI_AP_STA);
      ensureSoftAp();
      WiFi.begin(wifiSsid, wifiPass);
      Serial.println("[WIFI] Thu lai mang da luu");
    }
  }
}

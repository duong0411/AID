# Smart First AID

App Flutter theo dõi thiết bị sơ cấp cứu — khung giống [LenMen](https://github.com/duong0411/lenmen).

## Hai chế độ

| Chế độ | Khi nào dùng | Cách vào |
|--------|----------------|----------|
| **Từ xa (MQTT)** | Điện thoại ở mạng khác, Internet | Chip ID (mặc định `777`) |
| **Gần máy** | Đứng cạnh thiết bị | Wi-Fi SoftAP → `192.168.4.1` |

### MQTT từ xa (một lần trên mạch)

1. Nạp firmware có `Smart_Mqtt.h` (cần thư viện **WebSockets** + **MQTTPubSubClient**).
2. Vào Wi-Fi `Smart-First-AID` / `12345678`.
3. Mở `http://192.168.4.1/wifi` → điền **Wi-Fi nhà** + Chip ID `777` → Lưu.
4. Mạch lên Internet → broker `wss://mqtt.duynguyen.io.vn/mqtt`.
5. App chọn **Từ xa**, Chip `777`, Kết nối.

### Topic

- `tele/777/status` → `online` / `offline`
- `tele/777_vitals/status` → JSON cảm biến
- `cmnd/777_mute/POWER`, `cmnd/777_test/POWER`, `cmnd/777_settings/VALUE`

## Chạy / build APK

```bash
cd smart_first_aid_app
flutter pub get
flutter run
flutter build apk --release
```

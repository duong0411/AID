# AID

Smart First AID: ESP32 đọc cảm biến, vẽ OLED, và gửi đúng nội dung đó lên app Flutter qua MQTT `mqtt.duynguyen.io.vn`.

## MQTT

- Broker: `mqtt.duynguyen.io.vn` cổng 443, đường dẫn `/mqtt` (WSS)
- Chip ID: 6 ký tự hex cuối địa chỉ MAC, in trên OLED lúc khởi động và ở màn tổng quan (`1. A1B2C3`)
- App cũng thấy chip ID trong tên WiFi phát ra: `AID_<CHIP>`
- Dữ liệu: `tele/<CHIP_ID>/oled`
- Trạng thái: `tele/<CHIP_ID>/status` (`online` / `offline`)
- Nút từ điện thoại: `cmnd/<CHIP_ID>/BTN` với `MENU`, `UP`, `DOWN`, `ENTER`
- Đổi màn hình: `cmnd/<CHIP_ID>/SCREEN` với `0` đến `5`

## Firmware

Sketch: `firmware/Smart_First_AID/Smart_First_AID.ino`

Thư viện Arduino:

- Adafruit GFX
- Adafruit SSD1306
- WebSockets (Markus Sattler)
- MQTTPubSubClient (Hideaki Tai)

Lần đầu chưa có WiFi, ESP phát mạng `AID_<CHIP>`. Vào `http://192.168.4.1`, chọn WiFi và lưu. Mật khẩu được ghi trong bộ nhớ flash.

## App

App hiện 6 màn giống OLED: tổng quan, nhịp tim, lực, SpO2, điện thế, cài đặt ngưỡng. Bốn nút MENU / UP / DOWN / ENTER gửi về thiết bị.

```bash
flutter pub get
flutter run
```

## GitHub Actions

Workflow `.github/workflows/build.yml` chạy khi đẩy lên nhánh `main`:

- Android: `AID.apk`
- iOS: `AID.ipa` (bản CI chưa ký mã)

File nằm trong mục Actions và trong Release của repository.

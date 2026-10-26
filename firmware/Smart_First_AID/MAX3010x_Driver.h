#pragma once

#include <Arduino.h>
#include <Wire.h>

// MAX30102 (part 0x15) và MAX30100 (part 0x11), địa chỉ I2C 0x57.
class MAX3010x_Driver {
 public:
  bool begin(TwoWire* wire, int sda, int scl, uint32_t freq) {
    bus = wire;
    if (!bus) return false;
    bus->begin(sda, scl, freq);
    bus->setTimeOut(50);
    delay(20);
    if (!present()) return false;

    uint8_t part = readReg(0xFF);
    is30100 = (part == 0x11);
    if (part != 0x15 && part != 0x11) return false;

    if (is30100) init30100();
    else init30102();

    irDc = 0;
    redDc = 0;
    irAmp = 1;
    redAmp = 1;
    finger = false;
    spo2 = 0;
    hr = 0;
    acWave = 0;
    lastBeat = 0;
    above = false;
    return true;
  }

  void update() {
    if (!bus) return;
    int got = is30100 ? readFifo30100() : readFifo30102();
    if (got <= 0) {
      if (millis() - lastSampleMs > 2000) finger = false;
      return;
    }
    lastSampleMs = millis();
  }

  bool isFingerDetected() const { return finger; }
  float getSpO2() const { return finger ? spo2 : 0; }
  float getHeartRate() const { return finger ? hr : 0; }
  float getACWave() const { return acWave; }

 private:
  TwoWire* bus = nullptr;
  bool is30100 = false;
  bool finger = false;
  bool above = false;
  float spo2 = 0;
  float hr = 0;
  float acWave = 0;
  float irDc = 0;
  float redDc = 0;
  float irAmp = 1;
  float redAmp = 1;
  uint32_t lastBeat = 0;
  uint32_t lastSampleMs = 0;
  uint32_t lastSpo2Ms = 0;

  bool present() {
    bus->beginTransmission(0x57);
    return bus->endTransmission() == 0;
  }

  void writeReg(uint8_t reg, uint8_t val) {
    bus->beginTransmission(0x57);
    bus->write(reg);
    bus->write(val);
    bus->endTransmission();
  }

  uint8_t readReg(uint8_t reg) {
    bus->beginTransmission(0x57);
    bus->write(reg);
    if (bus->endTransmission(false) != 0) return 0;
    if (bus->requestFrom((uint8_t)0x57, (uint8_t)1) != 1) return 0;
    return bus->read();
  }

  void init30102() {
    writeReg(0x09, 0x40);
    delay(30);
    writeReg(0x04, 0x00);
    writeReg(0x05, 0x00);
    writeReg(0x06, 0x00);
    writeReg(0x08, 0x4F);  // avg x4, rollover
    writeReg(0x0A, 0x27);  // 100 Hz, 411 us
    writeReg(0x0C, 0x24);
    writeReg(0x0D, 0x24);
    writeReg(0x09, 0x03);  // SpO2 mode, red + IR
  }

  void init30100() {
    writeReg(0x06, 0x40);
    delay(30);
    writeReg(0x02, 0x00);
    writeReg(0x04, 0x00);
    writeReg(0x06, 0x03);  // SpO2 mode
    writeReg(0x07, 0x43);  // 100 Hz, 16-bit, high LED
    writeReg(0x09, 0x88);  // ~20 mA red + IR
  }

  void pushSample(uint32_t ir, uint32_t red) {
    uint32_t now = millis();
    float irF = (float)ir;
    float redF = (float)red;
    if (irDc <= 1) {
      irDc = irF;
      redDc = redF;
    }
    irDc = 0.99f * irDc + 0.01f * irF;
    redDc = 0.99f * redDc + 0.01f * redF;

    float irAc = irF - irDc;
    float redAc = redF - redDc;
    acWave = irAc;

    if (fabsf(irAc) > irAmp) irAmp = 0.8f * irAmp + 0.2f * fabsf(irAc);
    else irAmp *= 0.995f;
    if (fabsf(redAc) > redAmp) redAmp = 0.8f * redAmp + 0.2f * fabsf(redAc);
    else redAmp *= 0.995f;
    if (irAmp < 1) irAmp = 1;
    if (redAmp < 1) redAmp = 1;

    float fingerMin = is30100 ? 4000.0f : 12000.0f;
    finger = irDc > fingerMin;
    if (!finger) {
      spo2 = 0;
      hr = 0;
      above = false;
      return;
    }

    float thresh = irAmp * 0.45f;
    if (thresh < 30) thresh = 30;
    if (irAc > thresh) {
      if (!above && (now - lastBeat > 330)) {
        uint32_t dt = now - lastBeat;
        lastBeat = now;
        above = true;
        if (dt > 330 && dt < 1500) {
          float instant = 60000.0f / (float)dt;
          if (hr < 1) hr = instant;
          else hr = 0.7f * hr + 0.3f * instant;
        }
      }
    } else if (irAc < -thresh * 0.3f) {
      above = false;
    }
    if (now - lastBeat > 2500) hr = 0;

    if (now - lastSpo2Ms > 400 && redDc > 1000 && irDc > fingerMin) {
      lastSpo2Ms = now;
      float r = (redAmp / redDc) / (irAmp / irDc);
      float est = 110.0f - 25.0f * r;
      if (est < 70) est = 70;
      if (est > 100) est = 100;
      if (spo2 < 1) spo2 = est;
      else spo2 = 0.8f * spo2 + 0.2f * est;
    }
  }

  int readFifo30102() {
    uint8_t wr = readReg(0x04);
    uint8_t rd = readReg(0x06);
    int n = (int)((wr - rd) & 0x1F);
    if (n <= 0) return 0;
    if (n > 4) n = 4;

    bus->beginTransmission(0x57);
    bus->write(0x07);
    if (bus->endTransmission(false) != 0) return 0;
    int need = n * 6;
    if (bus->requestFrom((uint8_t)0x57, (uint8_t)need) != need) return 0;

    for (int i = 0; i < n; i++) {
      uint32_t red = ((uint32_t)bus->read() << 16) | ((uint32_t)bus->read() << 8) | bus->read();
      uint32_t ir = ((uint32_t)bus->read() << 16) | ((uint32_t)bus->read() << 8) | bus->read();
      red &= 0x3FFFF;
      ir &= 0x3FFFF;
      pushSample(ir, red);
    }
    return n;
  }

  int readFifo30100() {
    uint8_t wr = readReg(0x02);
    uint8_t rd = readReg(0x04);
    int n = (int)((wr - rd) & 0x0F);
    if (n <= 0) return 0;
    if (n > 4) n = 4;

    bus->beginTransmission(0x57);
    bus->write(0x05);
    if (bus->endTransmission(false) != 0) return 0;
    int need = n * 4;
    if (bus->requestFrom((uint8_t)0x57, (uint8_t)need) != need) return 0;

    for (int i = 0; i < n; i++) {
      uint32_t ir = ((uint32_t)bus->read() << 8) | bus->read();
      uint32_t red = ((uint32_t)bus->read() << 8) | bus->read();
      pushSample(ir, red);
    }
    return n;
  }
};

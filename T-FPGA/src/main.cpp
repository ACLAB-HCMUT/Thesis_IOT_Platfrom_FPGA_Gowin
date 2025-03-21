#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
//#include "pins_config.h"  // Ensure this file defines PIN_LED, PIN_IIC_SDA, and PIN_IIC_SCL
#include "XPowersLib.h" //https://github.com/lewisxhe/XPowersLib
#include <Adafruit_MQTT.h>
#include <Adafruit_MQTT_Client.h>

// #pragma once

// #define PIN_BTN      0

// #define PIN_IIC_SDA  38
// #define PIN_IIC_SCL  39
// #define PIN_PMU_IRQ  40

// #define PIN_LED      46

// #define PIN_FPGA_CS  1
// #define PIN_FPGA_SCK 2
// #define PIN_FPGA_D0  3
// #define PIN_FPGA_D1  5
// #define PIN_FPGA_D2  6
// #define PIN_FPGA_D3  4

//cloud integration

#define WLAN_SSID       "*"
#define WLAN_PASS       "*"


#define AIO_SERVER      "io.adafruit.com"
#define AIO_SERVERPORT  1883  
#define AIO_USERNAME    "*"
#define AIO_KEY         "*"


WiFiClient client;
Adafruit_MQTT_Client mqtt(&client, AIO_SERVER, AIO_SERVERPORT, AIO_USERNAME, AIO_KEY);
//Publish feed
Adafruit_MQTT_Publish feed = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME"/feeds/io");
Adafruit_MQTT_Publish myFeedPub_sensor_temp = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME "/feeds/temp");
Adafruit_MQTT_Publish myFeedPub_sensor_humid = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME "/feeds/humid");
//Subscribe feed
Adafruit_MQTT_Subscribe myFeedSub_io = Adafruit_MQTT_Subscribe(&mqtt, AIO_USERNAME "/feeds/gowin-io");

//wifi connect
void connectToWiFi() {
  Serial.print("Connecting to ");
  Serial.println(WLAN_SSID);
  WiFi.begin(WLAN_SSID, WLAN_PASS);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
}
uint8_t receivedData = 0;
//uint8_t fpga_address = 0x34;
// void receiveData(){
//   // Read the data from FPGA
//     Wire1.requestFrom(fpga_address, 1);  // Request 1 byte
//     if (Wire1.available()) {
//         receivedData = Wire1.read();
//         Serial.print("Received data from FPGA: ");
//         Serial.println(receivedData);
//     } else {
//         Serial.println("No data received from FPGA.");
//     }
// };
//Mqtt connect
void MQTT_connect() {
  int8_t ret;
  
  if (mqtt.connected()) {
    return;
  }

  Serial.print("Connecting to MQTT... ");
  
  while ((ret = mqtt.connect()) != 0) {
    Serial.println(mqtt.connectErrorString(ret));
    Serial.println("Retrying MQTT connection in 5 seconds...");
    mqtt.disconnect();
    delay(5000);  
  }
  
  Serial.println("MQTT Connected!");
}
//LED feed back
void mqtt_Feedback(int duration){
        for (int i = 0; i < duration; i++) {
          digitalWrite(PIN_LED, HIGH);  
          delay(250);                   
          digitalWrite(PIN_LED, LOW);   
          delay(250);                   
        }
}

float humidity = 0.0;
float temperature = 0.0;
XPowersAXP2101 PMU;
#define FPGA_ADDR 0x34  // FPGA I2C Slave Address

void scan_i2c_device(TwoWire &wire);
void fpga_led(bool en);
void read_fpga_status();


// Function to turn FPGA LED ON/OFF
void fpga_led(bool en)
{
    Wire1.beginTransmission(FPGA_ADDR);
    Wire1.write(en);  // Send 1 (ON) or 0 (OFF)
    uint8_t result = Wire1.endTransmission();
    
    if (result == 0) {
        Serial.println("FPGA LED command sent successfully.");
    } else {
        Serial.print("I2C Write Error: ");
        Serial.println(result);
    }
}

// Function to read 5 bytes from FPGA
void read_fpga_status()
{
    uint8_t register_data[5] = {0};  // Array to store received bytes

    Wire1.requestFrom(FPGA_ADDR, 5);  // Request 5 bytes from FPGA

    int i = 0;
    while (Wire1.available() && i < 5) {
        register_data[i] = Wire1.read();  // Store received 
        Serial.printf("0x%02X ", register_data[i]);
        i++;
    }
 Serial.println();
    // Check if we successfully read all 5 bytes
    // if (i == 5) {
    //     Serial.print("Received 5 Bytes from FPGA: ");
    //     for (int j = 0; j < 5; j++) {
    //         Serial.printf("0x%02X ", register_data[j]);  // Print each byte in HEX format
    //     }
    //     Serial.println();
    // } else {
    //     Serial.println("Error: Incomplete data received from FPGA.");
    // }

    // Kiểm tra xem có nhận đủ 5 byte không
if (i == 5) {
    // Giải mã giá trị độ ẩm
    uint16_t humidity_raw = (register_data[0] << 8) | register_data[1];
    humidity = (humidity_raw / 65536.0) * 100.0;

    // Giải mã giá trị nhiệt độ
    uint16_t temperature_raw = (register_data[2] << 8) | register_data[3];
    temperature = (temperature_raw / 65536.0) * 200.0 - 50.0;

    // Hiển thị kết quả
    Serial.printf("Humidity: %.2f%% RH\n", humidity);
    Serial.printf("Temperature: %.2f°C\n", temperature);
} else {
    Serial.println("Error: Incomplete data received from FPGA.");
}
}
//7a ad c6 5c d4
// I2C Scanner function
void scan_i2c_device(TwoWire &wire)
{
    Serial.println("Scanning for I2C devices...");
    Serial.print("      ");
    for (int i = 0; i < 0x10; i++) {
        Serial.printf("0x%02X|", i);
    }
    uint8_t error;
    for (int j = 0; j < 0x80; j += 0x10) {
        Serial.println();
        Serial.printf("0x%02X |", j);
        for (int i = 0; i < 0x10; i++) {
            wire.beginTransmission(i | j);
            error = wire.endTransmission();
            if (error == 0)
                Serial.printf("0x%02X|", i | j);
            else
                Serial.print(" -- |");
        }
    }
    Serial.println();
    Serial.println("I2C scan complete.");
}

void adaFruit_control(String feed_value){
      if (feed_value == "ON") {
        fpga_led(1);
      }
      if (feed_value == "OFF") {
        fpga_led(0);
      }
      if (feed_value == "AUTO") {
        //fpga_led(1);
        Serial.print("Reading sht20...\n");
      } 
      if (feed_value == "STOP") {
        //fpga_led(0);
        Serial.print("Stop reading\n");
      }
}

void publishing() {
    // Đọc dữ liệu từ FPGA
    read_fpga_status();

    // Gửi giá trị độ ẩm lên feed Adafruit IO
    if (!myFeedPub_sensor_humid.publish((float)humidity)) {
        Serial.println("Failed to publish humidity data to Adafruit IO");
    } else {
        Serial.print("Published Humidity MQTT: ");
        Serial.print(humidity);
        Serial.println("% RH");
    }

    // Gửi giá trị nhiệt độ lên feed Adafruit IO
    if (!myFeedPub_sensor_temp.publish((float)temperature)) {
        Serial.println("Failed to publish temperature data to Adafruit IO");
    } else {
        Serial.print("Published Temperature MQTT: ");
        Serial.print(temperature);
        Serial.println("°C");
    }

    //vTaskResume(ledTaskHandle);  // Kích hoạt lại task LED (nếu có)
    delay(15000);  // Chờ 5 giây trước khi gửi dữ liệu tiếp theo
}

void setup()
{
    Serial.begin(115200);
    pinMode(PIN_LED, OUTPUT);
    Serial.println("Hello T-FPGA-CORE");
    connectToWiFi();
    PMU.setChargingLedMode(XPOWERS_CHG_LED_OFF);
    mqtt.subscribe(&myFeedSub_io);

    bool result = PMU.begin(Wire, AXP2101_SLAVE_ADDRESS, PIN_IIC_SDA, PIN_IIC_SCL);

    if (result == false) {
        Serial.println("PMU is not online...");
        while (1)
            delay(50);
    }
  
    PMU.setDC4Voltage(1200);   // Here is the FPGA core voltage. Careful review of the manual is required before modification.
    PMU.setALDO1Voltage(3300); // BANK0 area voltage
    PMU.setALDO2Voltage(3300); // BANK1 area voltage
    PMU.setALDO3Voltage(2500); // BANK2 area voltage
    PMU.setALDO4Voltage(1800); // BANK3 area voltage

    PMU.enableALDO1();
    PMU.enableALDO2();
    PMU.enableALDO3();
    PMU.enableALDO4();

    delay(1000);

    // Initialize I2C (Wire1 for FPGA communication)
    Wire1.begin(PIN_IIC_SDA, PIN_IIC_SCL, 400000);  // SDA, SCL, 400kHz speed

    //delay(1000);

    // Scan I2C devices
    scan_i2c_device(Wire1);
}

void loop()
{   

  // Kết nối MQTT
  MQTT_connect();
  PMU.setChargingLedMode(XPOWERS_CHG_LED_ON);
  //Kiểm tra các gói tin từ MQTT
  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(50))) {
    if (subscription == &myFeedSub_io) {
      // Nhận lệnh từ Adafruit IO
      String value = (char *)myFeedSub_io.lastread;
      Serial.print("Received: ");
      Serial.println(value);
      adaFruit_control(value);
      //publishing();
      Serial.print("Data Updated\n");
    }
  }
  publishing();
    // fpga_led(false);
    // delay(1000); 
 
    // fpga_led(true);
    // delay(1000);   
    
    // // Read FPGA response
    // read_fpga_status();
    // delay(5000);
}

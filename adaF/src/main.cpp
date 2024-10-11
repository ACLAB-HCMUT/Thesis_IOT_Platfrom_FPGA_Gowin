#include <Arduino.h>
#include <WiFi.h>
#include <Adafruit_MQTT.h>
#include <Adafruit_MQTT_Client.h>

// Thông tin WiFi
#define WLAN_SSID       "***"
#define WLAN_PASS       "***"

// Thông tin Adafruit IO
#define AIO_SERVER      "io.adafruit.com"
#define AIO_SERVERPORT  1883  
#define AIO_USERNAME    "***"
#define AIO_KEY         "***"

// Khởi tạo client WiFi và MQTT
WiFiClient client;
Adafruit_MQTT_Client mqtt(&client, AIO_SERVER, AIO_SERVERPORT, AIO_USERNAME, AIO_KEY);
//Feed để publishing
Adafruit_MQTT_Publish feed = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME"/feeds/io");
// Feed để subscribe
Adafruit_MQTT_Subscribe myFeedSub = Adafruit_MQTT_Subscribe(&mqtt, AIO_USERNAME "/feeds/gowin-io");
#define LED_PIN 2  // Chân LED trên board Wemos D1 R32 (GPIO2)
#define LED_UART 2
// UART pinout cho giao tiếp với board fpga
#define UART_TX_PIN 1  // cho TX
#define UART_RX_PIN 3  // cho RX (nếu cần)

// Kết nối WiFi
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

// Kết nối MQTT
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
void mqtt_Feedback(int duration){
        for (int i = 0; i < duration; i++) {
          digitalWrite(LED_PIN, HIGH);  
          delay(250);                   
          digitalWrite(LED_PIN, LOW);   
          delay(250);                   
        }
}
void uART_control(String feed_value){
      // Gửi lệnh điều khiển LED cho board qua UART
      if (feed_value == "1") {
        // Bật đèn (gửi lệnh 0x01)
        Serial1.write(0x01);
        Serial.println("Sent: Turn ON LED (0x01)");
        // LED Blink when sending
        mqtt_Feedback(5);
      } else if (feed_value == "0") {
        // Tắt đèn (gửi lệnh 0x00)
        Serial1.write(0x00);
        Serial.println("Sent: Turn OFF LED (0x00)");
        // LED Blink when sending
        mqtt_Feedback(2);
      }
}
//char hexString[10];
//byte index = 0;
unsigned long hexToDec(const char* hexString) {
  unsigned long decValue = 0;
  
  // Duyệt qua từng ký tự trong chuỗi HEX
  while (*hexString) {
    char hexDigit = *hexString;

    // Chuyển đổi ký tự HEX thành giá trị thập phân
    if (hexDigit >= '0' && hexDigit <= '9') {
      decValue = (decValue << 4) | (hexDigit - '0');
    } 
    else if (hexDigit >= 'A' && hexDigit <= 'F') {
      decValue = (decValue << 4) | (hexDigit - 'A' + 10);
    } 
    else if (hexDigit >= 'a' && hexDigit <= 'f') {
      decValue = (decValue << 4) | (hexDigit - 'a' + 10);
    }
    
    hexString++;
  }
  
  return decValue;
}


// int flag = 0;
 unsigned long lastPublishTime = 0;  // To store the last publish time
 unsigned long publishInterval = 5000;  // Minimum interval in milliseconds (2000 ms = 2 seconds)

// void uArt_receiv() {
//   while (Serial1.available() > 0) {
//     char receivedData =Serial1.read();
// if ((receivedData >= '0' && receivedData <= '9') ||
//         (receivedData >= 'A' && receivedData <= 'F') ||
//         (receivedData >= 'a' && receivedData <= 'f')) {

//       // Thêm ký tự vào chuỗi HEX
//       hexString[index++] = receivedData;
//       hexString[index] = '\0';  // Đảm bảo chuỗi kết thúc bằng null

//       // Nếu đủ 4 ký tự HEX, chuyển sang số thập phân
//       if (index >= 4) {
//         unsigned long decimalValue = hexToDec(hexString);
//         index = 0;
//       }
//         }
//     //Serial.print("Received from UART: ");
//     //Serial.println(receivedData);
//     //long sending_value = hexToDec(receivedData);
//     unsigned long currentTime = millis();  // Get the current time

//     // Ensure at least 2 seconds have passed since the last publish
//     if (currentTime - lastPublishTime >= publishInterval) {
//       if (!feed.publish((int)receivedData)) {
//         Serial.println("Failed to publish received data");
//       } else {
//         Serial.print("Published to Adafruit IO: ");
//         Serial.println(receivedData);
//         lastPublishTime = currentTime;  // Update last publish time
//       }
//     } else {
//       Serial.println("Skipping publish to avoid rate limit");
//     }

//     if (receivedData == '1' && flag != 1) {
//       digitalWrite(LED_UART, HIGH);
//       flag = 1;
//       delay(250);
//       digitalWrite(LED_UART, LOW);
//     }

//     if (flag == 1) {
//       digitalWrite(LED_UART, LOW);
//       delay(3000);
//       flag = 0;
//     }
//   }
// }
 int testvalue = 0;
 void upDate_value(int duration){
  testvalue += 1;
 }
void publishing(){
    upDate_value(10);
    unsigned long currentTime = millis();  // Get the current time

    // Ensure at least 2 seconds have passed since the last publish
    if (currentTime - lastPublishTime >= publishInterval) {
      if (!feed.publish((int)testvalue)) {
        Serial.println("Failed to publish received data");
      } else {
        Serial.print("Published to Adafruit IO: ");
        Serial.println(testvalue);
        mqtt_Feedback(3);
        lastPublishTime = currentTime;  // Update last publish time
      }
    } else {
      Serial.println("Skipping publish to avoid rate limit");
    } 
}
void setup() {
  // Khởi tạo UART để giao tiếp với board fpga
  Serial.begin(115200);          // Serial cho debug
  Serial1.begin(9600, SERIAL_8N1, UART_RX_PIN, UART_TX_PIN);  // UART1 (9600 baud)

  connectToWiFi();
  
  // Đăng ký feed MQTT
  mqtt.subscribe(&myFeedSub);
  
  // Cấu hình chân LED là OUTPUT
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  pinMode(LED_UART, OUTPUT);
  digitalWrite(LED_UART, LOW);
}

void loop() {
  // Kết nối MQTT
  MQTT_connect();
  
  // Kiểm tra các gói tin từ MQTT
  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(5000))) {
    if (subscription == &myFeedSub) {
      // Nhận lệnh từ Adafruit IO
      String value = (char *)myFeedSub.lastread;
      Serial.print("Received: ");
      Serial.println(value);
      uART_control(value);
    }
  }
  publishing();
  //uArt_receiv();
  // Ping MQTT để giữ kết nối
  mqtt.processPackets(10000);
  mqtt.ping();
}

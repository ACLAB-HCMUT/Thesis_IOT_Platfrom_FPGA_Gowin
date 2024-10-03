#include <Arduino.h>
#include <WiFi.h>
#include <Adafruit_MQTT.h>
#include <Adafruit_MQTT_Client.h>

// Thông tin WiFi
#define WLAN_SSID       "Hong them"
#define WLAN_PASS       "quang1234"

// Thông tin Adafruit IO
#define AIO_SERVER      "io.adafruit.com"
#define AIO_SERVERPORT  1883   // Cổng MQTT cho Adafruit IO
#define AIO_USERNAME    "1zy"
#define AIO_KEY         "aio_sLEc45YmuEr4GPjEjXaOhTRh0XyR"

// Khởi tạo client WiFi và MQTT
WiFiClient client;
Adafruit_MQTT_Client mqtt(&client, AIO_SERVER, AIO_SERVERPORT, AIO_USERNAME, AIO_KEY);

// Feed để subscribe
Adafruit_MQTT_Subscribe myFeedSub = Adafruit_MQTT_Subscribe(&mqtt, AIO_USERNAME "/feeds/gowin-io");
#define LED_PIN 2  // Chân LED trên board Wemos D1 R32 (GPIO2)

// UART pinout cho giao tiếp với Tang Nano 9K
#define UART_TX_PIN 1  // GPIO1 cho TX
#define UART_RX_PIN 3  // GPIO3 cho RX (nếu cần)

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
    delay(5000);  // Chờ 5 giây rồi thử lại
  }
  
  Serial.println("MQTT Connected!");
}

void setup() {
  // Khởi tạo UART để giao tiếp với Tang Nano 9K
  Serial.begin(115200);          // Serial cho debug
  Serial1.begin(9600, SERIAL_8N1, UART_RX_PIN, UART_TX_PIN);  // UART1 cho Tang Nano (9600 baud)

  connectToWiFi();
  
  // Đăng ký feed MQTT
  mqtt.subscribe(&myFeedSub);
  
  // Cấu hình chân LED là OUTPUT
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);  // Đèn tắt lúc khởi động
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

      // Gửi lệnh điều khiển LED cho Tang Nano 9K qua UART
      if (value == "1") {
        // Bật đèn (gửi lệnh 0x01)
        Serial1.write(0x01);
        Serial.println("Sent: Turn ON LED (0x01)");

        // Nhấp nháy LED trên Wemos
        for (int i = 0; i < 5; i++) {
          digitalWrite(LED_PIN, HIGH);  // Bật LED
          delay(250);                   // Chờ 250 ms
          digitalWrite(LED_PIN, LOW);   // Tắt LED
          delay(250);                   // Chờ 250 ms
        }
      } else if (value == "0") {
        // Tắt đèn (gửi lệnh 0x00)
        Serial1.write(0x00);
        Serial.println("Sent: Turn OFF LED (0x00)");
      }
    }
  }

  // Ping MQTT để giữ kết nối
  mqtt.processPackets(10000);
  mqtt.ping();
}

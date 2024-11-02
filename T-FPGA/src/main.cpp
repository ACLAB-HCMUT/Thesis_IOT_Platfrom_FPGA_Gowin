#include <Arduino.h>
#include <WiFi.h>
#include <Adafruit_MQTT.h>
#include <Adafruit_MQTT_Client.h>
#include "XPowersLib.h" //https://github.com/lewisxhe/XPowersLib
#include "pins_config.h"

#define WLAN_SSID       "Hong them"
#define WLAN_PASS       "quang1234"


#define AIO_SERVER      "io.adafruit.com"
#define AIO_SERVERPORT  1883  
#define AIO_USERNAME    "1zy"
#define AIO_KEY         "*"


WiFiClient client;
Adafruit_MQTT_Client mqtt(&client, AIO_SERVER, AIO_SERVERPORT, AIO_USERNAME, AIO_KEY);
//Feed để publishing
Adafruit_MQTT_Publish feed = Adafruit_MQTT_Publish(&mqtt, AIO_USERNAME"/feeds/io");
// Feed để subscribe
Adafruit_MQTT_Subscribe myFeedSub = Adafruit_MQTT_Subscribe(&mqtt, AIO_USERNAME "/feeds/gowin-io");

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
uint8_t receivedData = 0;
uint8_t fpga_address = 0x30;
void receiveData(){
  // Read the data from FPGA
    Wire1.requestFrom(fpga_address, 1);  // Request 1 byte
    if (Wire1.available()) {
        receivedData = Wire1.read();
        Serial.print("Received data from FPGA: ");
        Serial.println(receivedData);
    } else {
        Serial.println("No data received from FPGA.");
    }
};

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

XPowersAXP2101 PMU;

void led_task(void *param);
void fpga_led(uint8_t en);

void scan_i2c_device(TwoWire &wire)
{
    Serial.println("Scanning for I2C devices ...");
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
    Serial.println("I2C device scan ends");
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
void adaFruit_control(String feed_value){
      if (feed_value == "ON") {
        fpga_led(1);
      } else if (feed_value == "OFF") {
        fpga_led(0);
      }
}
void sendingSuccess(int counts){
  for(int i = 0; i < counts; i++){
    PMU.setChargingLedMode(XPOWERS_CHG_LED_ON);
    delay(250);
    PMU.setChargingLedMode(XPOWERS_CHG_LED_OFF);
    delay(250);

  }
}

TaskHandle_t ledTaskHandle = NULL;  // Define task handle for the LED task
void led_task(void *param){
    pinMode(PIN_LED, OUTPUT);
    while (true) {
        // Wait for the task to be resumed by publishing event
        vTaskSuspend(NULL); //suspend the task until resumed
        // Blink the LED
        mqtt_Feedback(3);
        // Suspend again after the blink
        vTaskSuspend(NULL);
    }
}

void fpga_led(uint8_t en)
{
    Wire1.beginTransmission(0x30);
    Wire1.write(en);
    Wire1.endTransmission();
}

 unsigned long lastPublishTime = 0;  // To store the last publish time
 unsigned long publishInterval = 15000;  // Minimum interval 

void publishing(){
    receiveData();
    //unsigned long currentTime = millis();  // Get the current time

    //if (currentTime - lastPublishTime >= publishInterval) {
      if (!feed.publish((uint8_t)receivedData)) {
        Serial.println("Failed to publish received data");
      } else {
        Serial.print("Published to Adafruit IO: ");
        Serial.println(receivedData);
        vTaskResume(ledTaskHandle);
        //lastPublishTime = currentTime;  // Update last publish time
      }
      delay (5000);
    } 
    // else {
    //   Serial.println("Skipping publish to avoid rate limit");
    // } 
//}


void setup() {
  Serial.begin(115200);        

  connectToWiFi();
  PMU.setChargingLedMode(XPOWERS_CHG_LED_OFF);
  // Đăng ký feed MQTT
  mqtt.subscribe(&myFeedSub);

    Serial.println("Hello T-FPGA-CORE");
    xTaskCreatePinnedToCore(led_task, "led_task", 1024, NULL, 1, &ledTaskHandle, 1);

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
    Wire1.begin(PIN_FPGA_D0, PIN_FPGA_SCK);
    scan_i2c_device(Wire1);
}
uint8_t en = 0;
void loop() { 
  // Kết nối MQTT
  MQTT_connect();
  PMU.setChargingLedMode(XPOWERS_CHG_LED_ON);
  //Kiểm tra các gói tin từ MQTT
  Adafruit_MQTT_Subscribe *subscription;
  while ((subscription = mqtt.readSubscription(5000))) {
    if (subscription == &myFeedSub) {
      // Nhận lệnh từ Adafruit IO
      String value = (char *)myFeedSub.lastread;
      Serial.print("Received: ");
      Serial.println(value);
      adaFruit_control(value);
    }
  }
  //fpga_led(en);
  //en++;
  //if (en == 5) //sendingSuccess(5);
  //if (en == 10) en = 0;
  publishing();

  //mqtt.processPackets(10000);
  //mqtt.ping();
}

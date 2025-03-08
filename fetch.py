print("Hello Core IOT")
import paho.mqtt.client as mqttclient
import time
import json

# Cấu hình Adafruit IO
ADA_BROKER = "io.adafruit.com"
ADA_PORT = 1883
ADA_USERNAME = "*"
ADA_KEY = "*"
ADA_FEED = "io"

# Cấu hình App Core IoT
CORE_BROKER = "app.coreiot.io"
CORE_PORT = 1883
CORE_ACCESS_TOKEN = "gowinfpga"
CORE_ACCESS_USERNAME = "Quang_admin"

# Hàm xử lý khi nhận dữ liệu từ Adafruit
def on_adafruit_message(client, userdata, msg):
    payload = msg.payload.decode("utf-8")
    print(f"📩 Nhận dữ liệu từ Adafruit: {payload}")

    try:
        data_value = float(payload)  # Chuyển đổi giá trị nhận được
        send_to_coreiot(data_value)  # Gửi dữ liệu lên App Core IoT
    except ValueError:
        print("⚠️ Lỗi: Dữ liệu nhận không hợp lệ!")

# Hàm gửi dữ liệu lên App Core IoT
def send_to_coreiot(value):
    collect_data = {'temperature': value}  # Chỉnh lại tên key nếu cần
    client_coreiot.publish('v1/devices/me/telemetry', json.dumps(collect_data), 1)
    print(f"📤 Đã gửi dữ liệu lên App Core IoT: {collect_data}")

# Kết nối đến Adafruit IO
client_adafruit = mqttclient.Client("Adafruit_Client")
client_adafruit.username_pw_set(ADA_USERNAME, ADA_KEY)
client_adafruit.on_message = on_adafruit_message
client_adafruit.connect(ADA_BROKER, ADA_PORT)
client_adafruit.subscribe(f"{ADA_USERNAME}/feeds/{ADA_FEED}")

# Kết nối đến App Core IoT
client_coreiot = mqttclient.Client("GW1")
client_coreiot.username_pw_set(CORE_ACCESS_USERNAME, CORE_ACCESS_TOKEN)
client_coreiot.connect(CORE_BROKER, CORE_PORT)

# Bắt đầu vòng lặp để nhận dữ liệu
client_adafruit.loop_start()
client_coreiot.loop_start()

try:
    while True:
        time.sleep(5)  # Giữ kết nối liên tục
except KeyboardInterrupt:
    print("⏹️ Dừng chương trình...")
    client_adafruit.loop_stop()
    client_coreiot.loop_stop()

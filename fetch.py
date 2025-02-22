import paho.mqtt.client as mqtt
import requests
import time

# Địa chỉ server MQTT của Adafruit IO
ADA_URL = "io.adafruit.com"
ADA_FEED = "IO"
ADA_USERNAME = "username"
ADA_KEY = "*" #API key

# ThingsBoard MQTT configuration
THINGSBOARD_HOST = "http://localhost:8080"
ACCESS_TOKEN = "C1_TEST_TOKEN"

# Tạo client MQTT cho Adafruit IO
def on_connect(client, userdata, flags, rc):
    print(f"Kết nối với {ADA_URL}, mã trạng thái: {rc}")
    client.subscribe(f"{ADA_USERNAME}/feeds/{ADA_FEED}")

def on_message(client, userdata, msg):
    payload = msg.payload.decode("utf-8")
    print(f"Nhận dữ liệu từ Adafruit: {payload}")

    try:
        payload = float(payload)  # Chuyển đổi thành số
        send_data_to_thingsboard(payload)
    except ValueError:
        print("Lỗi: Dữ liệu nhận được không hợp lệ!")

def send_data_to_thingsboard(payload):
    url = f"{THINGSBOARD_HOST}/api/v1/{ACCESS_TOKEN}/telemetry"
    data = {"temperature": payload}
    headers = {"Content-Type": "application/json"}

    try:
        response = requests.post(url, json=data, headers=headers, timeout=5)
        if response.status_code == 200:
            print(f"Gửi dữ liệu lên ThingsBoard thành công: {data}")
        else:
            print(f"Lỗi gửi dữ liệu: {response.status_code}, {response.text}")
    except requests.exceptions.RequestException as e:
        print(f"Lỗi kết nối ThingsBoard: {e}")

# Tạo client MQTT với Paho MQTT v2
client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION1)
client.username_pw_set(ADA_USERNAME, ADA_KEY)
client.on_connect = on_connect
client.on_message = on_message

try:
    client.connect(ADA_URL, 1883, 60)
    print("Kết nối MQTT thành công!")

    client.loop_forever()  # Chạy vòng lặp liên tục

except Exception as e:
    print(f"Lỗi kết nối MQTT: {e}")

finally:
    print("Dừng kết nối MQTT...")
    client.loop_stop()
    client.disconnect()

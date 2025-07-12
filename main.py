import time
from sensor import generate_sensor_data
from prediction import predict_risk
from logger import log_event
from alert import send_alert
from mesh import broadcast_alert, listen_for_alerts

# Start mesh listener (runs in a background thread)
#listen_for_alerts(lambda msg: print(f"[Mesh Handler] {msg}"))

while True:
    sensor_data = generate_sensor_data()
    risk = predict_risk(sensor_data)

    print(f"Sensor Data: {sensor_data}")
    print(f"Risk Assessment: {risk}")

    if "Risk" in risk:
        send_alert(risk)
        log_event(sensor_data, risk)
        broadcast_alert(f"{risk} | Data: {sensor_data}")

    time.sleep(2)

# logger.py
import json
import hashlib
from datetime import datetime

def log_event(data, prediction):
    entry = {
        "timestamp": datetime.utcnow().isoformat(),
        "sensor_data": data,
        "prediction": prediction
    }
    entry_string = json.dumps(entry, sort_keys=True)
    entry["hash"] = hashlib.sha256(entry_string.encode()).hexdigest()

    with open("alert_log.json", "a") as f:
        f.write(json.dumps(entry) + "\n")

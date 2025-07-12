# sensor.py
import random
import time

def generate_sensor_data():
    return {
        "Rainfall_mm": round(random.uniform(0, 10), 2),
        "Slope_Angle": round(random.uniform(15, 45), 2),
        "Soil_Saturation": round(random.uniform(30, 100), 2),
        "Vegetation_Cover": round(random.uniform(0, 100), 2),
        "Earthquake_Activity": round(random.uniform(0, 5), 2),
        "Proximity_to_Water": round(random.uniform(0, 1000), 2),
        "Soil_Type_Gravel": random.choice([0, 1]),
        "Soil_Type_Sand": random.choice([0, 1]),
        "Soil_Type_Silt": random.choice([0, 1]),
        "Soil_Type_Clay": random.choice([0, 1]),
        "temperature": round(random.uniform(20, 40), 2),
        "humidity": round(random.uniform(40, 90), 2),
        "soil_moisture": round(random.uniform(10, 60), 2),
        "vibration": round(random.uniform(0, 1), 2)
    }

if __name__ == "__main__":
    while True:
        data = generate_sensor_data()
        print(data)
        time.sleep(2)

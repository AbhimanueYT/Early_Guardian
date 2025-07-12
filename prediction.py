# predictor.py
import joblib
import pandas as pd

model = joblib.load("risk_model.pkl")

def predict_risk(sensor_data):
    # Convert sensor data to DataFrame with correct column names
    X = pd.DataFrame([{
        'Rainfall_mm': sensor_data['Rainfall_mm'],
        'Slope_Angle': sensor_data['Slope_Angle'],
        'Soil_Saturation': sensor_data['Soil_Saturation'],
        'Vegetation_Cover': sensor_data['Vegetation_Cover'],
        'Earthquake_Activity': sensor_data['Earthquake_Activity'],
        'Proximity_to_Water': sensor_data['Proximity_to_Water'],
        'Soil_Type_Gravel': sensor_data['Soil_Type_Gravel'],
        'Soil_Type_Sand': sensor_data['Soil_Type_Sand'],
        'Soil_Type_Silt': sensor_data['Soil_Type_Silt']
    }])
    
    probabilities = model.predict_proba(X)[0]
    # Use 0.4 threshold instead of 0.5 to increase sensitivity
    return "High Risk: Landslide Likely" if probabilities[1] > 0.4 else "Normal"

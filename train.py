import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from joblib import dump

# Load data
df = pd.read_csv("landslide.csv")  # Replace with your actual filename

# Define features and label
X = df[['Rainfall_mm', 'Slope_Angle', 'Soil_Saturation', 'Vegetation_Cover',
        'Earthquake_Activity', 'Proximity_to_Water',
        'Soil_Type_Gravel', 'Soil_Type_Sand', 'Soil_Type_Silt']]

y = df['Landslide']  # Target variable (0 = no, 1 = yes)

# Fill any missing values (optional, in case)
X = X.fillna(0)

# Train/test split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Train model
model = RandomForestClassifier()
model.fit(X_train, y_train)

# Save model
dump(model, "risk_model.pkl")
print("✅ Model trained and saved as risk_model.pkl")

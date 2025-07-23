model_uri = "" # Copy mlflow:uri from your project mlflow:model link
registered_model = mlflow.sklearn.load_model(model_uri)
registered_model

import joblib
joblib.dump(registered_model, "wine-quality-model.joblib")

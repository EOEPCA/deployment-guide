#!/usr/bin/env python
import os
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error, r2_score
import mlflow
import mlflow.sklearn


def main():
    # Check we have the right env variables set
    tracking_uri = os.environ.get("MLFLOW_TRACKING_URI")
    if not tracking_uri:
        raise EnvironmentError("MLFLOW_TRACKING_URI environment variable is not set.")
    print(f"Using MLflow tracking URI: {tracking_uri}")
    mlflow.set_tracking_uri(tracking_uri)

    tracking_token = os.environ.get("MLFLOW_TRACKING_TOKEN")
    if tracking_token:
        print("Using MLflow tracking token from environment variable.")
    else:
        print(
            "Warning: MLFLOW_TRACKING_TOKEN not set; your MLflow server might require authentication."
        )

    experiment_name = "example (1)"
    mlflow.set_experiment(experiment_name)
    mlflow.autolog()

    data_path = "wine-quality.csv"
    try:
        data = pd.read_csv(data_path)
    except Exception as e:
        raise FileNotFoundError(f"Failed to load data from {data_path}: {e}")

    if "quality" not in data.columns:
        raise ValueError(
            "The dataset is incorrectly loaded. It should contain a column named 'quality'."
        )

    data = data.dropna()
    X = data.drop("quality", axis=1)
    y = data["quality"]

    # split the data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    # Start an MLflow run
    with mlflow.start_run():
        mlflow.log_param("model_type", "LinearRegression")
        mlflow.log_param("test_size", 0.2)
        mlflow.log_param("random_state", 42)

        model = LinearRegression()
        model.fit(X_train, y_train)

        predictions = model.predict(X_test)

        mse = mean_squared_error(y_test, predictions)
        r2 = r2_score(y_test, predictions)

        mlflow.log_metric("mse", mse)
        mlflow.log_metric("r2", r2)

        mlflow.sklearn.log_model(model, "model")

        print("Model training complete.")
        print(f"Mean Squared Error: {mse}")
        print(f"R^2 Score: {r2}")


if __name__ == "__main__":
    main()

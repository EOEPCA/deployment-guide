#!/usr/bin/env python3
import warnings
warnings.filterwarnings("ignore")
import pandas as pd
import os
import mlflow

columns = ['fixed acidity', 'volatile acidity', 'citric acid', 'residual sugar', 'chlorides', 'free sulfur dioxide', 'total sulfur dioxide', 'density', 'pH', 'sulphates', 'alcohol']
inputs = [[14.23, 1.71, 2.43, 15.6, 127.0, 2.8, 3.06, 0.28, 2.29, 5.64, 1.04]]
data = pd.DataFrame(inputs, columns=columns)

logged_model = 'runs:/'+os.environ['TRAINING_RUN']+'/model'

print("Context: model={} inputs={}".format(logged_model, inputs))

logged_model = 'runs:/'+os.environ['TRAINING_RUN']+'/model'

print("Predict: {}".format(prediction))

#Load model as a PyFuncModel
loaded_model = mlflow.pyfunc.load_model(logged_model)

#Predict on a Pandas DataFrame
prediction = loaded_model.predict(data)

#Display prediction
print("Predict: {}".format(prediction))


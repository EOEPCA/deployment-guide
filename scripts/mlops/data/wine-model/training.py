#!/usr/bin/env python3

#Import required libraries
import warnings
warnings.filterwarnings("ignore")
import pandas as pd
import os
import time
from pathlib import Path
from pystac import Item, StacIO
import urllib.request

#Download the training data
stac_io = StacIO.default()
stac_io.headers = {"X-Gitlab-Token": os.environ['MLFLOW_TRACKING_TOKEN']}

# Get STAC item and download his assets
item = Item.from_file(os.environ['INPUT_STAC_DATASET'], stac_io=stac_io)

opener = urllib.request.build_opener()
opener.addheaders = [("X-Gitlab-Token", os.environ['MLFLOW_TRACKING_TOKEN'])]
urllib.request.install_opener(opener)

for name, asset in item.get_assets().items():
    urllib.request.urlretrieve(asset.href, name)

#Load the dataset with Pandas as a DataFrame
data = pd.read_csv("wine-quality.csv", sep=",")

#Import the model
from model import WineQuality

#Prepare the data
train_x = data.drop(["quality"], axis=1)
train_y = data[["quality"]]

#Setup MLFlow
import mlflow

mlflow.set_tracking_uri(os.environ['MLFLOW_TRACKING_TOKEN'])
mlflow.set_experiment(os.environ['LOGNAME'])
mlflow.autolog()

#Training RUN
import random

alpha = random.random() * 10 # Constant that multiplies the penalty terms
l1_ratio = random.random() # 0 <= l1_ratio <= 1
random_state = random.randint(1, 100) # The seed of the pseudo random number generator that selects a random feature to update

wq = WineQuality(alpha=alpha, l1_ratio=l1_ratio, random_state=random_state)
wq.fit(train_x, train_y)


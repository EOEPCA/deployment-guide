---
assets:
- "training.py"
- "inference.py"
ml-model:
  type: ml-model
  learning_approach: supervised
  prediction_type: classification
  architecture: ElasticNet
  training-processor-type: cpu
  training-os: linux
related:
  dataset: wine-dataset
---

# Wine Model

![Wine](./preview.png)

Wine Model is a scikit-learn model used to predict a wine quality from its chemical composition.

## Usage

### Setup environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install mlflow==2.14.2 setuptools pystac
```

### Training (using mlflow)

Run training via mlflow

```bash
source venv/bin/activate
export MLFLOW_TRACKING_TOKEN=... your auth token
export MLFLOW_TRACKING_URI=... your traking url, something like https://myserver.com/root/wine-model/tracking/
export LOGNAME=wine-model
./training.py
```

### Inference (using mlflow)


```bash
./inference_remote.py
```

### Export model (for local inference)


### Inference (local)

Run the inference script:

```bash
source training/bin/activate
```


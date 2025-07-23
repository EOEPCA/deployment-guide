import joblib
from sklearn.linear_model import ElasticNet


class WineQuality(ElasticNet):
    pass


def load_model(path):
    model = joblib.load(path)
    if not isinstance(model, WineQuality):
        raise TypeError("Loaded object is not of the type WineQuality")
    return model

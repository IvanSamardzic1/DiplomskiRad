import json
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score, accuracy_score

FEATURES = [
    "tipObroka",
    "vrijemePripremeMin",
    "userOdabranBefore",
    "userIzvrsenBefore",
    "globalnoIzvrsenBefore",
]

df = pd.read_csv("dataset.csv", sep=";", header=None)

df.columns = [
    "idPlanObroka",
    "idKorisnik",
    "idRecept",
    "tipObroka",
    "vrijemePripremeMin",
    "userOdabranBefore",
    "userIzvrsenBefore",
    "globalnoIzvrsenBefore",
    "label",
]

X = df[FEATURES].astype(float)
y = df["label"].astype(int)

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

scaler = StandardScaler()
X_train_s = scaler.fit_transform(X_train)
X_test_s = scaler.transform(X_test)

model = LogisticRegression(max_iter=300)
model.fit(X_train_s, y_train)

pred_prob = model.predict_proba(X_test_s)[:, 1]
pred_bin = (pred_prob >= 0.5).astype(int)

print("AUC:", roc_auc_score(y_test, pred_prob))
print("ACC:", accuracy_score(y_test, pred_bin))

payload = {
    "feature_order": FEATURES,
    "coef": model.coef_[0].tolist(),
    "intercept": float(model.intercept_[0]),
    "mean": scaler.mean_.tolist(),
    "scale": scaler.scale_.tolist(),
}

with open("../Kod/assets/weights.json", "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=True, indent=2)

print("Saved model to assets/weights.json")

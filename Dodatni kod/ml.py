import json
from pathlib import Path

import pandas as pd #glavni alat za tablicne podatke
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

# redoslijed featurea je identican onom koji se koristi u app
# takav redoslijed se sprema u weights.json
FEATURES = [
    "vrijemePripremeMin",
    "pokrivenostZaliha",
    "fifoSignal",
    "userOdabranCount",
    "userIzvrsenCount",
    "trazeniTipObrokaId",
]

ALL_COLUMNS = [
    "idPlanObroka",
    "idKorisnik",
    "idRecept",
    "vrijemePripremeMin",
    "pokrivenostZaliha",
    "fifoSignal",
    "userOdabranCount",
    "userIzvrsenCount",
    "trazeniTipObrokaId",
    "label",
]

#Ucitavanje CSV datotke
DATASET_PATH = "dataset.csv"
OUTPUT_PATH = Path("../Kod/assets/weights.json")


def _to_numeric_series(s: pd.Series) -> pd.Series:
    # Podrzava i "0,5" i "0.5", trimma razmake i pretvara nevaljano u 0.
    return pd.to_numeric(
        s.astype(str).str.strip().str.replace(",", ".", regex=False),
        errors="coerce",
    ).fillna(0.0)


def load_dataset(path: str) -> pd.DataFrame:
    # Pokusaj s headerom
    df = pd.read_csv(path, sep=";", dtype=str)

    if set(ALL_COLUMNS).issubset(df.columns):
        pass
    else:
        #Fallback bez headera
        df = pd.read_csv(path, sep=";", header=None, dtype=str)
        if df.shape[1] != len(ALL_COLUMNS):
            raise ValueError(
                f"Ocekivano {len(ALL_COLUMNS)} stupaca, dobiveno {df.shape[1]}. "
                "Provjeri dataset.csv format."
            )
        df.columns = ALL_COLUMNS

    # Normalizacija numerickih stupaca (posebno radi decimalnog zareza)
    for col in ALL_COLUMNS:
        if col in df.columns:
            df[col] = _to_numeric_series(df[col])

    # Label mora biti 0/1 int
    df["label"] = (df["label"] > 0).astype(int)

    return df


def main() -> None:
    df = load_dataset(DATASET_PATH)

    # X su ulazni feature-i, a y je label, odnosno je li recept izvrsen ili ne
    X = df[FEATURES].astype(float)
    y = df["label"].astype(int)

    # Ako slucajno imas samo jednu klasu, model se ne moze trenirati
    class_count = y.nunique()
    if class_count < 2:
        raise ValueError(
            "Label ima samo jednu klasu (sve 0 ili sve 1). "
            "Trebas dataset s obje klase za LogisticRegression."
        )



    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=0.2, #80 posto ide u trening
        random_state=42, # seed za slucajnost
        stratify=y, # čuva omjer klase u train i test skupu
    )

    # StandardScaler centrira i skalira feature-e.
    # To je vazno za logisticku regresiju jer stabilizira optimizaciju
    # i cini koeficijente usporedivima.
    scaler = StandardScaler()
    # 
    X_train_s = scaler.fit_transform(X_train)
    X_test_s = scaler.transform(X_test)

    # LogisticRegression vraca linearan model koji je lako interpretirati:
    # predznak koeficijenta govori smjer utjecaja feature-a na vjerojatnost.
    model = LogisticRegression(max_iter=500, class_weight="balanced")
    model.fit(X_train_s, y_train)


    pred_prob = model.predict_proba(X_test_s)[:, 1]
    pred_bin = (pred_prob >= 0.5).astype(int)

    # AUC mjeri kvalitetu rangiranja, ACC tocnost klasifikacije.
    # Koristimo oboje jer ACC sam moze varati kod neuravnotezenih klasa.
    print("AUC:", roc_auc_score(y_test, pred_prob))
    print("ACC:", accuracy_score(y_test, pred_bin))

    #ono sto exportamo
    # - coef/intercept: tezine logisticke regresije
    # - mean/scale: parametri standardizacije
    payload = {
        "feature_order": FEATURES,
        "coef": model.coef_[0].tolist(),
        "intercept": float(model.intercept_[0]),
        "mean": scaler.mean_.tolist(),
        "scale": scaler.scale_.tolist(),
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=True, indent=2)

    print(f"Saved model to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()

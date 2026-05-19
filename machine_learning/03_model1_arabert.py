
# library imports 
import os
import sys
import json
import time
import warnings
warnings.filterwarnings("ignore")

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import (
    accuracy_score, f1_score, precision_score, recall_score,
    classification_report, confusion_matrix,
)
from sklearn.preprocessing import LabelEncoder

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import (
    DATA_DIR, RESULTS_DIR, MODEL1_DIR, CHART_DPI, CHART_STYLE,
    INTENT_CATEGORIES, COLORS, MODEL_LABELS, TRAINING_CONFIG,
)

MODEL_NAME  = "aubmindlab/bert-base-arabertv02"
MODEL_LABEL = "AraBERT"
MODEL_KEY   = "model1"
RESULTS_PFX = os.path.join(RESULTS_DIR, "model1")


random_seed  = TRAINING_CONFIG["seed"]
max_len      = TRAINING_CONFIG["max_len"]
batch_size   = TRAINING_CONFIG["batch_size"]
lr           = TRAINING_CONFIG["lr"]
max_epochs   = TRAINING_CONFIG["max_epochs"]
weight_decay = TRAINING_CONFIG["weight_decay"]
warmup_ratio = TRAINING_CONFIG["warmup_ratio"]


# data loading

def load_data():
    train = pd.read_csv(os.path.join(DATA_DIR, "train.csv"), encoding="utf-8-sig")
    val   = pd.read_csv(os.path.join(DATA_DIR, "val.csv"),   encoding="utf-8-sig")
    test  = pd.read_csv(os.path.join(DATA_DIR, "test.csv"),  encoding="utf-8-sig")
    return train, val, test


def encode_labels(train, val, test):
    # Map intent strings to fixed integer indices
    le = LabelEncoder()
    le.fit(INTENT_CATEGORIES)
    for df in (train, val, test):
        df["label"] = le.transform(df["intent"])
    return le


# transformer approach

def train_transformer(train_df, val_df, test_df, le):
    # Load tokenizer + AraBERT + add classification head
    from transformers import (
        AutoTokenizer, AutoModelForSequenceClassification,
        TrainingArguments, Trainer, TrainerCallback,
    )
    import torch
    from torch.utils.data import Dataset

    class IntentDataset(Dataset):
        def __init__(self, texts, labels, tokenizer, max_length):
            # Tokenise all texts at once with uniform padding
            self.encodings = tokenizer(
                texts, truncation=True, padding=True,
                max_length=max_length, return_tensors="pt",
            )
            self.labels = torch.tensor(labels, dtype=torch.long)

        def __len__(self):
            return len(self.labels)

        def __getitem__(self, idx):
            item = {k: v[idx] for k, v in self.encodings.items()}
            item["labels"] = self.labels[idx]
            return item

    print(f"  Loading tokenizer: {MODEL_NAME}")
    try:
        tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    except Exception as e:
        raise RuntimeError(f"Failed to load tokenizer '{MODEL_NAME}'. Check internet connection.\n{e}")

    num_labels = len(INTENT_CATEGORIES)
    print(f"  Loading model: {MODEL_NAME}  ({num_labels} labels)")
    try:
        model = AutoModelForSequenceClassification.from_pretrained(
            MODEL_NAME, num_labels=num_labels,
            id2label={i: l for i, l in enumerate(INTENT_CATEGORIES)},
            label2id={l: i for i, l in enumerate(INTENT_CATEGORIES)},
        )
    except Exception as e:
        raise RuntimeError(f"Failed to load model '{MODEL_NAME}'. Check internet connection.\n{e}")

    train_ds = IntentDataset(train_df["text"].fillna("").tolist(), train_df["label"].tolist(), tokenizer, max_len)
    val_ds   = IntentDataset(val_df["text"].fillna("").tolist(),   val_df["label"].tolist(),   tokenizer, max_len)
    test_ds  = IntentDataset(test_df["text"].fillna("").tolist(),  test_df["label"].tolist(),  tokenizer, max_len)

    os.makedirs(MODEL1_DIR, exist_ok=True)
    # Training settings: optimizer, eval strategy, checkpointing
   args = TrainingArguments(
        output_dir=MODEL1_DIR,
        num_train_epochs=max_epochs,
        per_device_train_batch_size=batch_size,
        per_device_eval_batch_size=batch_size,
        learning_rate=lr,
        weight_decay=weight_decay,
        warmup_ratio=warmup_ratio,
        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        seed=random_seed,
        logging_steps=20,
        report_to="none",
        no_cuda=not torch.cuda.is_available(),
    )    history = {"train_loss": [], "val_loss": [], "train_acc": [], "val_acc": []}

    class _HistCB(TrainerCallback):
        # Record loss at each logging step
        def on_log(self, args, state, control, logs=None, **kwargs):
            if logs:
                if "loss" in logs:
                    history["train_loss"].append(logs["loss"])
                if "eval_loss" in logs:
                    history["val_loss"].append(logs["eval_loss"])

    # Training loop
    trainer = Trainer(
        model=model,
        args=args,
        train_dataset=train_ds,
        eval_dataset=val_ds,
        callbacks=[_HistCB()],
    )

    t0 = time.time()
    trainer.train()
    training_time = time.time() - t0
    print(f"  Training completed in {training_time:.1f}s")

    # Measure inference latency in ms per sample
    t1 = time.time()
    preds_output = trainer.predict(test_ds)
    inf_ms = ((time.time() - t1) / len(test_df)) * 1000

    y_pred = np.argmax(preds_output.predictions, axis=1)
    y_true = test_df["label"].tolist()

    trainer.save_model(MODEL1_DIR)
    tokenizer.save_pretrained(MODEL1_DIR)
    print(f"  Model saved to: {MODEL1_DIR}")

    return y_true, y_pred, inf_ms, training_time, history, MODEL_LABEL


# evaluation & charts

def build_metrics(y_true, y_pred, inf_ms, training_time, le):
    acc        = accuracy_score(y_true, y_pred)
    macro_f1   = f1_score(y_true, y_pred, average="macro", zero_division=0)
    macro_prec = precision_score(y_true, y_pred, average="macro", zero_division=0)
    macro_rec  = recall_score(y_true, y_pred, average="macro", zero_division=0)

    # Per-class scores using one-vs-rest
    per_class = {}
    for i, intent in enumerate(INTENT_CATEGORIES):
        mask = np.array(y_true) == i
        if mask.sum() == 0:
            per_class[intent] = {"f1": 0.0, "precision": 0.0, "recall": 0.0, "support": 0}
            continue
        yi_true = (np.array(y_true) == i).astype(int)
        yi_pred = (np.array(y_pred) == i).astype(int)
        per_class[intent] = {
            "f1":        round(f1_score(yi_true, yi_pred, zero_division=0), 4),
            "precision": round(precision_score(yi_true, yi_pred, zero_division=0), 4),
            "recall":    round(recall_score(yi_true, yi_pred, zero_division=0), 4),
            "support":   int(mask.sum()),
        }

    cm = confusion_matrix(y_true, y_pred, labels=list(range(len(INTENT_CATEGORIES))))

    return {
        "accuracy":          round(acc, 4),
        "macro_f1":          round(macro_f1, 4),
        "macro_precision":   round(macro_prec, 4),
        "macro_recall":      round(macro_rec, 4),
        "per_class":         per_class,
        "inference_time_ms": round(inf_ms, 4),
        "training_time_s":   round(training_time, 2),
        "confusion_matrix":  cm.tolist(),
    }


def save_confusion_matrix(cm_data, model_label):
    try:
        plt.style.use(CHART_STYLE)
    except OSError:
        pass
    cm = np.array(cm_data)
    fig, ax = plt.subplots(figsize=(14, 12))
    sns.heatmap(
        cm, annot=True, fmt="d", cmap="Greens",
        xticklabels=INTENT_CATEGORIES,
        yticklabels=INTENT_CATEGORIES,
        linewidths=0.4, linecolor="white", ax=ax,
    )
    ax.set_title(f"Confusion Matrix — {model_label}", fontsize=14, fontweight="bold", pad=14)
    ax.set_xlabel("Predicted Intent", fontsize=12)
    ax.set_ylabel("True Intent", fontsize=12)
    plt.xticks(rotation=40, ha="right", fontsize=9)
    plt.yticks(rotation=0, fontsize=9)
    fig.tight_layout()
    path = f"{RESULTS_PFX}_confusion_matrix.png"
    fig.savefig(path, dpi=CHART_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  [saved] {path}")


def save_per_class_chart(per_class, model_label):
    try:
        plt.style.use(CHART_STYLE)
    except OSError:
        pass
    f1s  = [per_class[i]["f1"]        for i in INTENT_CATEGORIES]
    prec = [per_class[i]["precision"] for i in INTENT_CATEGORIES]
    rec  = [per_class[i]["recall"]    for i in INTENT_CATEGORIES]

    x, w = np.arange(len(INTENT_CATEGORIES)), 0.27
    fig, ax = plt.subplots(figsize=(16, 7))
    ax.bar(x - w, f1s,  w, label="F1",       color=COLORS["model1"], edgecolor="white")
    ax.bar(x,     prec, w, label="Precision", color=COLORS["model2"], edgecolor="white")
    ax.bar(x + w, rec,  w, label="Recall",    color=COLORS["model3"], edgecolor="white")
    ax.set_xticks(x)
    ax.set_xticklabels(INTENT_CATEGORIES, rotation=35, ha="right", fontsize=10)
    ax.set_ylim(0, 1.15)
    ax.set_ylabel("Score", fontsize=12)
    ax.set_title(f"Per-Class Metrics — {model_label}", fontsize=14, fontweight="bold", pad=14)
    ax.legend(fontsize=11)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    path = f"{RESULTS_PFX}_per_class.png"
    fig.savefig(path, dpi=CHART_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  [saved] {path}")





# main

def main():
    print("\n=== 03_model1_arabert.py — Whisper + AraBERT Pipeline ===\n")
    os.makedirs(RESULTS_DIR, exist_ok=True)
    os.makedirs(MODEL1_DIR,  exist_ok=True)

    # Load data and encode labels
    print("Loading data …")
    train_df, val_df, test_df = load_data()
    le = encode_labels(train_df, val_df, test_df)
    print(f"  Train:{len(train_df)}  Val:{len(val_df)}  Test:{len(test_df)}")

    # Train the model
    print(f"\nLoading HuggingFace model: {MODEL_NAME} …")
    result = train_transformer(train_df, val_df, test_df, le)
    y_true, y_pred, inf_ms, training_time, history, used_label = result

    print(f"\nEvaluating {used_label} …")
    metrics = build_metrics(y_true, y_pred, inf_ms, training_time, le)
    metrics["model_label"] = used_label
    metrics["model_name"]  = MODEL_NAME

    print(f"  Accuracy  : {metrics['accuracy']:.4f}")
    print(f"  Macro F1  : {metrics['macro_f1']:.4f}")
    print(f"  Precision : {metrics['macro_precision']:.4f}")
    print(f"  Recall    : {metrics['macro_recall']:.4f}")
    print(f"  Inf. time : {metrics['inference_time_ms']:.2f} ms/sample")
    print(f"  Train time: {metrics['training_time_s']:.1f} s")

    # Save metrics — used later by comparison and report scripts
    metrics_path = os.path.join(RESULTS_DIR, "model1_metrics.json")
    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(metrics, f, ensure_ascii=False, indent=2)
    print(f"\n  [saved] {metrics_path}")

    save_confusion_matrix(metrics["confusion_matrix"], used_label)
    save_per_class_chart(metrics["per_class"], used_label)

    print(f"\nModel 1 ({used_label}) complete.\n")


if __name__ == "__main__":
    main()

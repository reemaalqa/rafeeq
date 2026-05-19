import os
import sys
import random
import warnings
warnings.filterwarnings("ignore")

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def safe_print(text: str) -> None:
    try:
        print(text)
    except UnicodeEncodeError:
        enc = sys.stdout.encoding or "ascii"
        print(text.encode(enc, errors="replace").decode(enc, errors="replace"))

from config import (
    DATASET_PATH, DATASET_ENCODING, DATA_DIR, EDA_DIR, CHART_DPI, CHART_STYLE,
    INTENT_CATEGORIES, INTENT_KEYWORDS, SYNTHETIC_COMMANDS,
    COLORS, TRAINING_CONFIG,
)

RANDOM_SEED = TRAINING_CONFIG["seed"]
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)


# ── Helpers ────────────────────────────────────────────────────────────────

def label_intent(text: str) -> str | None:
    """Score each intent by keyword matches and return the best one."""
    if not isinstance(text, str) or text.strip() == "":
        return None

    scores = {intent: 0 for intent in INTENT_CATEGORIES}

    for intent, keywords in INTENT_KEYWORDS.items():
        for kw in keywords:
            if kw in text:
                scores[intent] += 1

    best_intent = max(scores, key=lambda k: scores[k])
    if scores[best_intent] == 0:
        return None
    return best_intent


def generate_synthetic_data() -> pd.DataFrame:
    """Generate augmented Saudi Arabic utterances (original + 3x prefix/suffix)."""
    rows = []

    prefixes = [
        "رفيق", "يا رفيق", "ابغى", "ممكن", "قولي", "ساعدني",
        "احتاج", "ابغى تساعدني", "", "", "",
    ]
    suffixes = [
        "الحين", "بسرعة", "لوسمحت", "يا أخوي", "", "", "",
    ]

    for intent, commands in SYNTHETIC_COMMANDS.items():
        for cmd in commands:
            rows.append({"text": cmd.strip(), "intent": intent, "source": "synthetic"})
            for _ in range(3):
                pre  = random.choice(prefixes)
                suf  = random.choice(suffixes)
                text = f"{pre} {cmd} {suf}".strip()
                text = " ".join(text.split())
                rows.append({"text": text, "intent": intent, "source": "synthetic_aug"})

    df = pd.DataFrame(rows)
    return df.drop_duplicates(subset="text").reset_index(drop=True)


def load_and_label_saudial() -> pd.DataFrame:
    """Load SauDial CSV and auto-label each row using keyword matching."""
    df = pd.read_csv(DATASET_PATH, encoding=DATASET_ENCODING)
    safe_print(f"  SauDial raw rows: {len(df):,}")

    results = []
    for _, row in df.iterrows():
        text   = str(row.get("Dialect Translation", ""))
        intent = label_intent(text)
        if intent is not None:
            results.append({
                "text":   text.strip(),
                "intent": intent,
                "source": "saudial",
            })

    labelled = pd.DataFrame(results)
    safe_print(f"  SauDial labelled rows: {len(labelled):,} "
               f"({100*len(labelled)/len(df):.1f}% coverage)")
    return labelled


def save_distribution_chart(df: pd.DataFrame) -> None:
    """Bar chart: intent distribution of the combined dataset."""
    os.makedirs(DATA_DIR, exist_ok=True)
    counts = df["intent"].value_counts().reindex(INTENT_CATEGORIES, fill_value=0)

    try:
        plt.style.use(CHART_STYLE)
    except OSError:
        pass

    fig, ax = plt.subplots(figsize=(14, 7))
    palette = [COLORS["model1"], COLORS["model2"], COLORS["baseline"],
               "#7B1FA2", "#00838F", "#E65100", "#37474F",
               "#AD1457", "#00695C", "#4527A0"]
    bars = ax.bar(counts.index, counts.values,
                  color=palette[:len(counts)], edgecolor="white", linewidth=0.8)
    ax.bar_label(bars, fmt="%d", padding=5, fontsize=11, fontweight="bold")
    ax.set_title("Intent Distribution — Combined Dataset (SauDial + Synthetic)",
                 fontsize=14, fontweight="bold", pad=14)
    ax.set_xlabel("Intent", fontsize=12)
    ax.set_ylabel("Sample Count", fontsize=12)
    ax.set_ylim(0, counts.max() * 1.18)
    plt.xticks(rotation=30, ha="right", fontsize=10)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    path = os.path.join(DATA_DIR, "intent_distribution.png")
    fig.savefig(path, dpi=CHART_DPI, bbox_inches="tight")
    plt.close(fig)
    safe_print(f"  [saved] {path}")


def print_class_distribution(df: pd.DataFrame, title: str = "Class Distribution") -> None:
    """Print intent counts and percentages to the console."""
    counts = df["intent"].value_counts().reindex(INTENT_CATEGORIES, fill_value=0)
    sep = "-" * 48
    safe_print(f"\n  {title}")
    safe_print(f"  {sep}")
    safe_print(f"  {'Intent':<25} {'Count':>7}  {'%':>6}")
    safe_print(f"  {sep}")
    total = len(df)
    for intent in INTENT_CATEGORIES:
        c = counts[intent]
        safe_print(f"  {intent:<25} {c:>7}  {100*c/total:>5.1f}%")
    safe_print(f"  {sep}")
    safe_print(f"  {'TOTAL':<25} {total:>7}")


# ── Main ───────────────────────────────────────────────────────────────────

def main() -> None:
    safe_print("\n=== 02_preprocessing.py -- Data Preparation ===\n")
    os.makedirs(DATA_DIR, exist_ok=True)

    safe_print("Step 1: Loading and auto-labelling SauDial dataset ...")
    saudial_df = load_and_label_saudial()

    safe_print("\nStep 2: Generating synthetic Saudi Arabic commands ...")
    synthetic_df = generate_synthetic_data()
    safe_print(f"  Synthetic rows: {len(synthetic_df):,}")

    safe_print("\nStep 3: Combining datasets ...")
    combined = pd.concat([saudial_df, synthetic_df], ignore_index=True)
    combined = combined.drop_duplicates(subset="text").reset_index(drop=True)
    safe_print(f"  Combined unique rows: {len(combined):,}")
    print_class_distribution(combined, "Combined Dataset - Class Distribution")

    safe_print("\nStep 4: Splitting into train / val / test (70 / 15 / 15) ...")
    from sklearn.model_selection import train_test_split

    train_df, temp_df = train_test_split(
        combined, test_size=0.30,
        random_state=RANDOM_SEED, stratify=combined["intent"],
    )
    val_df, test_df = train_test_split(
        temp_df, test_size=0.50,
        random_state=RANDOM_SEED, stratify=temp_df["intent"],
    )

    safe_print(f"  Train : {len(train_df):,} rows")
    safe_print(f"  Val   : {len(val_df):,} rows")
    safe_print(f"  Test  : {len(test_df):,} rows")

    train_path = os.path.join(DATA_DIR, "train.csv")
    val_path   = os.path.join(DATA_DIR, "val.csv")
    test_path  = os.path.join(DATA_DIR, "test.csv")
    train_df.to_csv(train_path, index=False, encoding="utf-8-sig")
    val_df.to_csv(val_path,    index=False, encoding="utf-8-sig")
    test_df.to_csv(test_path,  index=False, encoding="utf-8-sig")
    safe_print(f"\n  [saved] {train_path}")
    safe_print(f"  [saved] {val_path}")
    safe_print(f"  [saved] {test_path}")

    safe_print("\nStep 5: Saving intent distribution chart ...")
    save_distribution_chart(combined)

    print_class_distribution(train_df, "Train Set - Class Distribution")
    print_class_distribution(val_df,   "Validation Set - Class Distribution")
    print_class_distribution(test_df,  "Test Set - Class Distribution")

    safe_print(f"\nPreprocessing complete. Data saved to: {DATA_DIR}\n")


if __name__ == "__main__":
    main()

import os
import sys
import warnings
warnings.filterwarnings("ignore")

# Force UTF-8 on Windows console
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
import matplotlib.patches as mpatches
import seaborn as sns

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from config import DATASET_PATH, DATASET_ENCODING, EDA_DIR, CHART_DPI, CHART_STYLE, COLORS


# ── Helpers ────────────────────────────────────────────────────────────────

def save_fig(fig: plt.Figure, name: str) -> None:
    """Save figure to EDA output directory."""
    os.makedirs(EDA_DIR, exist_ok=True)
    path = os.path.join(EDA_DIR, name)
    fig.savefig(path, dpi=CHART_DPI, bbox_inches="tight")
    plt.close(fig)
    print(f"  [saved] {path}")


def word_count(series: pd.Series) -> pd.Series:
    """Count words per row, ignoring NaN."""
    return series.fillna("").astype(str).apply(lambda x: len(x.split()))


def safe_print(text: str) -> None:
    try:
        print(text)
    except UnicodeEncodeError:
        print(text.encode(sys.stdout.encoding or "ascii", errors="replace").decode(sys.stdout.encoding or "ascii", errors="replace"))


# ── Charts ─────────────────────────────────────────────────────────────────

def chart_dialect_bar(df: pd.DataFrame) -> None:
    """Bar chart: sample count per dialect."""
    counts = df["Dialect"].value_counts().sort_values(ascending=False)
    fig, ax = plt.subplots(figsize=(10, 6))
    colors = [COLORS["model1"], COLORS["model2"], COLORS["baseline"]]
    bars = ax.bar(counts.index, counts.values, color=colors[:len(counts)], edgecolor="white", linewidth=0.8)
    ax.bar_label(bars, fmt="%d", padding=4, fontsize=11, fontweight="bold")
    ax.set_title("Sample Count per Dialect", fontsize=15, fontweight="bold", pad=14)
    ax.set_xlabel("Dialect", fontsize=12)
    ax.set_ylabel("Number of Samples", fontsize=12)
    ax.set_ylim(0, counts.max() * 1.15)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    save_fig(fig, "01_dialect_bar.png")


def chart_scenario_bar(df: pd.DataFrame) -> None:
    """Bar chart: top 15 scenarios by sample count."""
    counts = df["Scenario"].value_counts().head(15)
    fig, ax = plt.subplots(figsize=(14, 7))
    bars = ax.barh(counts.index[::-1], counts.values[::-1], color=COLORS["model2"], edgecolor="white")
    ax.bar_label(bars, fmt="%d", padding=4, fontsize=10)
    ax.set_title("Top 15 Scenarios by Sample Count", fontsize=15, fontweight="bold", pad=14)
    ax.set_xlabel("Number of Samples", fontsize=12)
    ax.set_ylabel("Scenario", fontsize=12)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    save_fig(fig, "02_scenario_bar.png")


def chart_dialect_pie(df: pd.DataFrame) -> None:
    """Pie chart: dialect distribution."""
    counts = df["Dialect"].value_counts()
    colors = [COLORS["model1"], COLORS["model2"], COLORS["baseline"]]
    fig, ax = plt.subplots(figsize=(9, 9))
    wedges, texts, autotexts = ax.pie(
        counts.values, labels=counts.index, autopct="%1.1f%%",
        colors=colors[:len(counts)], startangle=140, pctdistance=0.82,
        wedgeprops=dict(edgecolor="white", linewidth=1.5),
    )
    for at in autotexts:
        at.set_fontsize(12)
        at.set_fontweight("bold")
    ax.set_title("Dialect Distribution", fontsize=15, fontweight="bold", pad=18)
    fig.tight_layout()
    save_fig(fig, "03_dialect_pie.png")


def chart_difficulty_bar(df: pd.DataFrame) -> None:
    """Bar chart: localization difficulty distribution."""
    counts = df["Localization Difficulty"].value_counts().sort_index()
    palette = sns.color_palette("YlOrRd", n_colors=len(counts))
    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.bar(counts.index.astype(str), counts.values, color=palette, edgecolor="white")
    ax.bar_label(bars, fmt="%d", padding=4, fontsize=11, fontweight="bold")
    ax.set_title("Localization Difficulty Distribution", fontsize=15, fontweight="bold", pad=14)
    ax.set_xlabel("Difficulty Level (1 = Easy … 5 = Very Hard)", fontsize=12)
    ax.set_ylabel("Count", fontsize=12)
    ax.set_ylim(0, counts.max() * 1.15)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    save_fig(fig, "04_difficulty_bar.png")


def chart_dialect_scenario_heatmap(df: pd.DataFrame) -> None:
    """Heatmap: dialect vs top 15 scenarios."""
    top_scenarios = df["Scenario"].value_counts().head(15).index
    sub = df[df["Scenario"].isin(top_scenarios)]
    pivot = sub.groupby(["Dialect", "Scenario"]).size().unstack(fill_value=0)
    fig, ax = plt.subplots(figsize=(16, 6))
    sns.heatmap(pivot, annot=True, fmt="d", cmap="YlGn",
                linewidths=0.4, linecolor="white", cbar_kws={"label": "Count"}, ax=ax)
    ax.set_title("Dialect × Scenario Frequency Heatmap (Top 15 Scenarios)", fontsize=14, fontweight="bold", pad=14)
    ax.set_xlabel("Scenario", fontsize=11)
    ax.set_ylabel("Dialect", fontsize=11)
    plt.xticks(rotation=40, ha="right", fontsize=9)
    plt.yticks(rotation=0, fontsize=10)
    fig.tight_layout()
    save_fig(fig, "05_dialect_scenario_heatmap.png")


def chart_avg_word_count(df: pd.DataFrame) -> None:
    """Bar chart: average word count per dialect (English / MSA / Dialect)."""
    df = df.copy()
    df["wc_en"]  = word_count(df["English Text"])
    df["wc_msa"] = word_count(df["Modern Standard Arabic (MSA) Translation"])
    df["wc_dia"] = word_count(df["Dialect Translation"])
    grouped = df.groupby("Dialect")[["wc_en", "wc_msa", "wc_dia"]].mean()
    dialects = grouped.index.tolist()
    x = np.arange(len(dialects))
    width = 0.25
    fig, ax = plt.subplots(figsize=(12, 7))
    b1 = ax.bar(x - width, grouped["wc_en"],  width, label="English",  color="#4CAF50", edgecolor="white")
    b2 = ax.bar(x,         grouped["wc_msa"], width, label="MSA",      color=COLORS["model2"], edgecolor="white")
    b3 = ax.bar(x + width, grouped["wc_dia"], width, label="Dialect",  color=COLORS["baseline"], edgecolor="white")
    for b in [b1, b2, b3]:
        ax.bar_label(b, fmt="%.1f", padding=3, fontsize=9)
    ax.set_xticks(x)
    ax.set_xticklabels(dialects, fontsize=11)
    ax.set_title("Average Word Count per Dialect (English / MSA / Dialect)", fontsize=14, fontweight="bold", pad=14)
    ax.set_ylabel("Avg. Word Count", fontsize=12)
    ax.legend(fontsize=11)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    save_fig(fig, "06_avg_word_count.png")


def chart_word_count_boxplot(df: pd.DataFrame) -> None:
    """Box plot: dialect word count distribution."""
    df = df.copy()
    df["wc_dia"] = word_count(df["Dialect Translation"])
    fig, ax = plt.subplots(figsize=(12, 7))
    palette = {d: c for d, c in zip(df["Dialect"].unique(),
               [COLORS["model1"], COLORS["model2"], COLORS["baseline"]])}
    sns.boxplot(data=df, x="Dialect", y="wc_dia", palette=palette, ax=ax,
                linewidth=1.2, flierprops=dict(marker="o", markersize=4, alpha=0.5))
    ax.set_title("Word Count Distribution per Dialect", fontsize=14, fontweight="bold", pad=14)
    ax.set_xlabel("Dialect", fontsize=12)
    ax.set_ylabel("Word Count", fontsize=12)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    save_fig(fig, "07_word_count_boxplot.png")


def chart_tone_bar(df: pd.DataFrame) -> None:
    """Bar chart: tone distribution."""
    counts = df["Tone"].value_counts()
    palette = sns.color_palette("Set2", n_colors=len(counts))
    fig, ax = plt.subplots(figsize=(12, 6))
    bars = ax.bar(counts.index, counts.values, color=palette, edgecolor="white")
    ax.bar_label(bars, fmt="%d", padding=4, fontsize=10, fontweight="bold")
    ax.set_title("Tone Distribution Across Dataset", fontsize=14, fontweight="bold", pad=14)
    ax.set_xlabel("Tone", fontsize=12)
    ax.set_ylabel("Count", fontsize=12)
    plt.xticks(rotation=30, ha="right")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    save_fig(fig, "08_tone_bar.png")


def chart_game_type_bar(df: pd.DataFrame) -> None:
    """Bar chart: game type distribution."""
    counts = df["Game Type"].value_counts()
    palette = sns.color_palette("tab10", n_colors=len(counts))
    fig, ax = plt.subplots(figsize=(12, 6))
    bars = ax.barh(counts.index[::-1], counts.values[::-1], color=palette[::-1], edgecolor="white")
    ax.bar_label(bars, fmt="%d", padding=4, fontsize=10)
    ax.set_title("Game Type Distribution", fontsize=14, fontweight="bold", pad=14)
    ax.set_xlabel("Count", fontsize=12)
    ax.set_ylabel("Game Type", fontsize=12)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    save_fig(fig, "09_game_type_bar.png")


def print_summary(df: pd.DataFrame) -> None:
    """Print dataset statistics summary."""
    sep = "-" * 60
    safe_print(f"\n{sep}")
    safe_print("  SauDial Dataset -- Statistics Summary")
    safe_print(sep)
    safe_print(f"  Total rows        : {len(df):,}")
    safe_print(f"  Total columns     : {len(df.columns)}")
    safe_print(f"  Missing values    : {df.isnull().sum().sum():,}")
    safe_print("")
    safe_print("  Dialect distribution:")
    for d, c in df["Dialect"].value_counts().items():
        safe_print(f"    {d:<25} {c:>5}  ({100*c/len(df):.1f}%)")
    safe_print("")
    safe_print("  Localization Difficulty (mean per dialect):")
    for d, v in df.groupby("Dialect")["Localization Difficulty"].mean().items():
        safe_print(f"    {d:<25} {v:.2f}")
    safe_print("")
    safe_print("  Tone distribution (top 5):")
    for t, c in df["Tone"].value_counts().head(5).items():
        safe_print(f"    {t:<25} {c:>5}")
    safe_print("")
    df = df.copy()
    df["wc_en"]  = word_count(df["English Text"])
    df["wc_msa"] = word_count(df["Modern Standard Arabic (MSA) Translation"])
    df["wc_dia"] = word_count(df["Dialect Translation"])
    safe_print("  Average word count (overall):")
    safe_print(f"    English    : {df['wc_en'].mean():.1f} words")
    safe_print(f"    MSA        : {df['wc_msa'].mean():.1f} words")
    safe_print(f"    Dialect    : {df['wc_dia'].mean():.1f} words")
    safe_print(sep)


# ── Main ───────────────────────────────────────────────────────────────────

def main() -> None:
    safe_print("\n=== 01_eda.py -- SauDial Dataset Exploration ===\n")
    os.makedirs(EDA_DIR, exist_ok=True)

    safe_print(f"Loading dataset: {DATASET_PATH}")
    df = pd.read_csv(DATASET_PATH, encoding=DATASET_ENCODING)
    safe_print(f"  Shape: {df.shape}")

    try:
        plt.style.use(CHART_STYLE)
    except OSError:
        plt.style.use("ggplot")

    safe_print("\nGenerating charts:")
    chart_dialect_bar(df)
    chart_scenario_bar(df)
    chart_dialect_pie(df)
    chart_difficulty_bar(df)
    chart_dialect_scenario_heatmap(df)
    chart_avg_word_count(df)
    chart_word_count_boxplot(df)
    chart_tone_bar(df)
    chart_game_type_bar(df)

    print_summary(df)
    safe_print(f"\nAll EDA charts saved to: {EDA_DIR}\n")


if __name__ == "__main__":
    main()

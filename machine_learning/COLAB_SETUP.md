# Rafeeq ML Pipeline — Google Colab Setup Guide

## Prerequisites

- A Google account with Google Drive access
- The complete project folder on your local machine

---

## Step 1: Upload Project to Google Drive

1. Open [Google Drive](https://drive.google.com)
2. Create a new folder named **`rafeeq_ml`** (inside My Drive)
3. Upload all project files into that folder so the structure looks exactly like this:

```
My Drive/
└── rafeeq_ml/
    ├── config.py
    ├── run_all.py
    ├── 01_eda.py
    ├── 02_preprocessing.py
    ├── 03_model1_arabert.py
    ├── 04_model2_camelbert.py
    ├── 05_model3_lstm.py
    ├── 06_comparison.py
    ├── 07_report.py
    ├── requirements.txt
    ├── rafeeq_colab.ipynb
    └── dataset/
        └── SauDial Dataset.csv
```

> The `outputs/` folder will be created automatically when the pipeline runs.
> You do not need to upload it.

---

## Step 2: Open the Notebook in Google Colab

**Option A — Open directly from Drive:**
1. In Google Drive, right-click `rafeeq_colab.ipynb`
2. Select **Open with → Google Colaboratory**

**Option B — Upload from your computer:**
1. Go to [colab.research.google.com](https://colab.research.google.com)
2. Click **File → Upload notebook**
3. Select `rafeeq_colab.ipynb` from your local machine

---

## Step 3: Enable GPU Runtime

The BERT models (AraBERT, CAMeL-BERT) train significantly faster on a GPU.

1. In Colab, click **Runtime** in the top menu
2. Select **Change runtime type**
3. Under **Hardware accelerator**, choose **T4 GPU**
4. Click **Save**

> If you skip this step the pipeline still runs, but Steps 3 and 4 (BERT fine-tuning) will be much slower.

---

## Step 4: Run the Notebook

Run each cell **from top to bottom** in order. Do not skip cells.

| Cell | What it does |
|------|-------------|
| Step 1 — Mount Drive | Connects Colab to your Google Drive and sets the working directory to `rafeeq_ml/` |
| Step 2 — Install packages | Installs all Python dependencies via `pip` |
| Step 3 — Verify setup | Confirms GPU is available and the dataset file exists |
| Pipeline Step 1 | Runs `01_eda.py` — generates 9 exploratory data analysis charts |
| Pipeline Step 2 | Runs `02_preprocessing.py` — labels, augments, and splits the dataset |
| Pipeline Step 3 | Runs `03_model1_arabert.py` — fine-tunes AraBERT (~500 MB download) |
| Pipeline Step 4 | Runs `04_model2_camelbert.py` — fine-tunes CAMeL-BERT (~400 MB download) |
| Pipeline Step 5 | Runs `05_model3_lstm.py` — trains BiLSTM from scratch (no download) |
| Pipeline Step 6 | Runs `06_comparison.py` — generates 10 comparison charts |
| Pipeline Step 7 | Runs `07_report.py` — builds the final HTML report |
| Preview cells | Displays charts and the HTML report inline |
| Download cell | Downloads `rafeeq_ml_report.html` to your computer |

---

## Step 5: Access the Outputs

All output files are saved directly inside your Google Drive folder:

```
rafeeq_ml/
└── outputs/
    ├── eda/              ← 9 exploratory charts (PNG)
    ├── data/             ← train.csv, val.csv, test.csv
    ├── models/           ← saved model weights
    ├── results/          ← per-model metrics (JSON) and charts (PNG)
    ├── comparison/       ← 10 cross-model comparison charts (PNG)
    └── report/
        └── rafeeq_ml_report.html   ← final self-contained report
```

You can download any file directly from Google Drive, or use the **Download cell** at the bottom of the notebook to download the HTML report automatically.

---

## Troubleshooting

### "Folder not found" error in Step 1
The `PROJECT_DIR` variable in the notebook defaults to `/content/drive/MyDrive/rafeeq_ml`.
If your folder is named differently or is inside a subfolder, edit that line:

```python
PROJECT_DIR = '/content/drive/MyDrive/YOUR_FOLDER_NAME'
```

### "Dataset not found" error in Step 3
Make sure the CSV file is inside a subfolder called `dataset/` and the file name is exactly:
```
SauDial Dataset.csv
```
Note the space in the name — it must match exactly.

### AraBERT / CAMeL-BERT download fails
This happens when Colab has no internet access or HuggingFace is unreachable.
The scripts have an automatic fallback: they switch to a **TF-IDF + Logistic Regression** baseline and continue. Results will be labelled "simulated" in the report.

### Session disconnects during training
Colab free-tier sessions disconnect after ~90 minutes of inactivity or ~12 hours total.
- All outputs written so far are saved in Google Drive and will not be lost.
- Re-open the notebook and re-run only the cells that did not complete.
- You can skip already-completed steps — the later scripts read from the saved CSV and JSON files.

### Out of RAM / GPU memory
If you get a memory error during BERT fine-tuning, reduce the batch size in `config.py`:

```python
TRAINING_CONFIG = {
    ...
    "batch_size": 8,   # reduce from 16 to 8
    ...
}
```

---

## Expected Runtime (T4 GPU)

| Step | Approximate time |
|------|-----------------|
| Install packages | 2 – 3 minutes |
| EDA | < 1 minute |
| Preprocessing | < 1 minute |
| AraBERT fine-tuning | 10 – 20 minutes |
| CAMeL-BERT fine-tuning | 10 – 20 minutes |
| BiLSTM training | 5 – 10 minutes |
| Comparison + Report | < 2 minutes |
| **Total** | **~30 – 55 minutes** |

> On CPU only (no GPU), BERT training steps take 3 – 5× longer.

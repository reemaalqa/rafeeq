"""
run_all.py — Main entry point for the Rafeeq ML Comparison Pipeline.

Runs all seven pipeline scripts in sequence with progress reporting,
error handling, and coloured terminal output.

Usage:
    python run_all.py [--skip-training]

Options:
    --skip-training   Skip model training (03, 04, 05) — run EDA, preprocessing,
                      comparison and report only.  Useful if metrics JSON files
                      already exist.
"""

# ── standard library imports ───────────────────────────────────────────────
# Used for file paths, subprocess launching, timing, argparse CLI, etc.
import os
import sys
import time
import subprocess
import argparse
import traceback
import datetime

# ── optional coloured terminal output ──────────────────────────────────────
# colorama makes ANSI colour codes work on Windows.  If it's not installed
# we gracefully fall back to plain (non-coloured) output using dummy stubs.
try:
    from colorama import init as colorama_init, Fore, Back, Style
    colorama_init(autoreset=True)
    HAS_COLOR = True
except ImportError:
    HAS_COLOR = False
    # Dummy colour stubs — any attribute access returns "" so that
    # f-strings still work when colorama is missing.
    class _Dummy:
        def __getattr__(self, _):
            return ""
    Fore = Style = Back = _Dummy()

# Absolute directory of this script — used to locate sibling scripts.
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Ordered list of all pipeline steps.  Each entry describes one script
# to run, with a human name, short description, and group ("analysis",
# "training" or "reporting") so that users can skip groups via flags.
STEPS = [
    {
        "script":      "01_eda.py",
        "name":        "EDA — Dataset Exploration",
        "description": "Generates 9 EDA charts from the SauDial dataset.",
        "group":       "analysis",
    },
    {
        "script":      "02_preprocessing.py",
        "name":        "Preprocessing — Data Preparation",
        "description": "Labels, augments, and splits the dataset into train/val/test.",
        "group":       "analysis",
    },
    {
        "script":      "03_model1_arabert.py",
        "name":        "Model 1 — Whisper + AraBERT",
        "description": "Fine-tunes AraBERT for intent classification (with TF-IDF fallback).",
        "group":       "training",
    },
    {
        "script":      "04_model2_camelbert.py",
        "name":        "Model 2 — Wav2Vec2 + CAMeL-BERT",
        "description": "Fine-tunes CAMeL-BERT for intent classification (with fallback).",
        "group":       "training",
    },
    {
        "script":      "05_model3_lstm.py",
        "name":        "Model 3 — DeepSpeech + BiLSTM",
        "description": "Trains a from-scratch BiLSTM attention model in PyTorch.",
        "group":       "training",
    },
    {
        "script":      "06_comparison.py",
        "name":        "Comparison — Full Pipeline Analysis",
        "description": "Generates 10 comparison charts and prints 4 result tables.",
        "group":       "reporting",
    },
    {
        "script":      "07_report.py",
        "name":        "Report — HTML Report Generator",
        "description": "Assembles a self-contained professional HTML report.",
        "group":       "reporting",
    },
]


# ── helpers ────────────────────────────────────────────────────────────────

def hr(char: str = "─", width: int = 72) -> str:
    # Return a horizontal rule string used for section separators.
    return char * width


def banner(text: str, color=None) -> None:
    """Print a coloured banner."""
    c = color or Fore.CYAN
    print(f"\n{c}{hr('═')}")
    print(f"  {text}")
    print(f"{hr('═')}{Style.RESET_ALL}\n")


def step_header(n: int, total: int, name: str, desc: str) -> None:
    # Print a visually distinct header for each pipeline step including
    # a progress percentage (e.g. "[3/7] Model 1 — (43%)").
    pct = f"{100 * n / total:.0f}%"
    print(f"\n{Fore.GREEN}{'─'*72}")
    print(f"  [{n}/{total}] {name}  ({pct})")
    print(f"  {Fore.YELLOW}{desc}")
    print(f"{Fore.GREEN}{'─'*72}{Style.RESET_ALL}")


def run_script(script_path: str, timeout: int = 3600) -> tuple[bool, float, str]:
    """
    Run a Python script as a subprocess.

    Returns (success, elapsed_seconds, error_message).
    """
    # Record start time so we can report how long this step took.
    t0 = time.time()
    try:
        # Launch the script in its own process using the SAME Python
        # interpreter (sys.executable).  capture_output=False means the
        # subprocess prints directly to our terminal in real time.
        result = subprocess.run(
            [sys.executable, script_path],
            capture_output=False,   # let stdout/stderr pass through
            timeout=timeout,
        )
        elapsed = time.time() - t0
        # Return code 0 means the script finished successfully.
        if result.returncode == 0:
            return True, elapsed, ""
        else:
            return False, elapsed, f"Exit code {result.returncode}"
    except subprocess.TimeoutExpired:
        # The script ran longer than the allowed timeout.
        return False, time.time() - t0, f"Timeout after {timeout}s"
    except Exception as exc:
        # Catch-all for any other launch failure (missing interpreter, etc.).
        return False, time.time() - t0, str(exc)


def format_elapsed(seconds: float) -> str:
    """Format seconds as mm:ss."""
    m, s = divmod(int(seconds), 60)
    return f"{m:02d}:{s:02d}"


# ── progress tracking ──────────────────────────────────────────────────────

class PipelineResult:
    """Stores the result of a pipeline step (success flag, elapsed time,
    error message if any).  Used to build the final summary table."""

    def __init__(self, step: dict, success: bool, elapsed: float, error: str = ""):
        self.script  = step["script"]
        self.name    = step["name"]
        self.success = success
        self.elapsed = elapsed
        self.error   = error

    def status_str(self) -> str:
        if self.success:
            return f"{Fore.GREEN}PASS{Style.RESET_ALL}"
        return f"{Fore.RED}FAIL{Style.RESET_ALL}"

    def elapsed_str(self) -> str:
        return format_elapsed(self.elapsed)


# ── summary ────────────────────────────────────────────────────────────────

def print_summary(results: list[PipelineResult], report_path: str, total_elapsed: float) -> None:
    """Print the final pipeline summary table."""
    banner("PIPELINE SUMMARY", Fore.CYAN)

    sep = "─" * 74
    print(f"  {'Script':<30} {'Status':>6}  {'Time':>7}  {'Notes'}")
    print(f"  {sep}")

    all_pass = True
    for r in results:
        status = f"{Fore.GREEN}  PASS{Style.RESET_ALL}" if r.success else f"{Fore.RED}  FAIL{Style.RESET_ALL}"
        note   = "" if r.success else f"{Fore.RED}{r.error[:40]}{Style.RESET_ALL}"
        print(f"  {r.script:<30} {status}  {r.elapsed_str():>7}  {note}")
        if not r.success:
            all_pass = False

    print(f"  {sep}")
    print(f"  {'TOTAL':<30}        {format_elapsed(total_elapsed):>7}")

    if all_pass:
        print(f"\n{Fore.GREEN}All steps completed successfully!{Style.RESET_ALL}")
    else:
        failed = [r for r in results if not r.success]
        print(f"\n{Fore.YELLOW}{len(failed)} step(s) failed — check output above.{Style.RESET_ALL}")

    if os.path.exists(report_path):
        print(f"\n{Fore.CYAN}HTML Report:{Style.RESET_ALL}")
        print(f"  {report_path}")
        size_kb = os.path.getsize(report_path) / 1024
        print(f"  Size: {size_kb:.1f} KB")

    print()


# ── main ───────────────────────────────────────────────────────────────────

def main():
    """Run the complete Rafeeq ML pipeline."""
    parser = argparse.ArgumentParser(
        description="Rafeeq ML Pipeline — run all scripts in sequence."
    )
    parser.add_argument(
        "--skip-training", action="store_true",
        help="Skip model training scripts (03, 04, 05)",
    )
    parser.add_argument(
        "--only", type=str, default="",
        help="Comma-separated list of script numbers to run (e.g. '1,2,6,7')",
    )
    args = parser.parse_args()

    # Parse --only flag: if given, only the listed step numbers run.
    only_nums = set()
    if args.only:
        for x in args.only.split(","):
            x = x.strip()
            if x.isdigit():
                only_nums.add(int(x))

    # Filter the full STEPS list based on --only and --skip-training.
    steps_to_run = []
    for i, step in enumerate(STEPS, start=1):
        if only_nums and i not in only_nums:
            continue
        if args.skip_training and step["group"] == "training":
            continue
        steps_to_run.append(step)

    # Welcome banner shown once at the top of the run.
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    banner(
        f"Rafeeq AI Voice Assistant — ML Comparison Pipeline\n"
        f"  Started: {now}\n"
        f"  Steps to run: {len(steps_to_run)} / {len(STEPS)}",
        Fore.CYAN,
    )

    if args.skip_training:
        print(f"{Fore.YELLOW}[--skip-training] Model training steps will be skipped.{Style.RESET_ALL}\n")

    # Verify dataset exists — the pipeline cannot proceed without it.
    sys.path.insert(0, BASE_DIR)
    try:
        from config import DATASET_PATH, REPORT_PATH
    except ImportError:
        print(f"{Fore.RED}ERROR: Cannot import config.py.  Make sure you are running from the correct directory.{Style.RESET_ALL}")
        sys.exit(1)

    if not os.path.exists(DATASET_PATH):
        print(f"{Fore.RED}ERROR: Dataset not found: {DATASET_PATH}{Style.RESET_ALL}")
        sys.exit(1)
    else:
        print(f"{Fore.GREEN}Dataset found: {DATASET_PATH}{Style.RESET_ALL}\n")

    # Run each step sequentially, collecting results so we can build
    # a final summary table at the end.
    results: list[PipelineResult] = []
    pipeline_start = time.time()

    for step_num, step in enumerate(steps_to_run, start=1):
        step_header(step_num, len(steps_to_run), step["name"], step["description"])
        script_path = os.path.join(BASE_DIR, step["script"])

        if not os.path.exists(script_path):
            print(f"{Fore.RED}  ERROR: Script not found: {script_path}{Style.RESET_ALL}")
            results.append(PipelineResult(step, False, 0.0, "Script not found"))
            continue

        success, elapsed, error = run_script(script_path)

        if success:
            print(f"\n{Fore.GREEN}  Done in {format_elapsed(elapsed)} — {step['name']}{Style.RESET_ALL}")
        else:
            print(f"\n{Fore.RED}  FAILED after {format_elapsed(elapsed)}: {error}{Style.RESET_ALL}")

        results.append(PipelineResult(step, success, elapsed, error))

    total_elapsed = time.time() - pipeline_start

    # Final summary
    print_summary(results, REPORT_PATH, total_elapsed)

    # Return non-zero exit code if any step failed
    any_fail = any(not r.success for r in results)
    sys.exit(1 if any_fail else 0)


if __name__ == "__main__":
    main()

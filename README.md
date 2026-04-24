
- `flutter_app/` — the mobile/web client (Flutter).
- `rafeeq_ai_api/` — the self-hosted FastAPI backend (Whisper ASR + AraBERT
  intent classifier + diet catalog).

`machine_learning/` holds training notebooks and is not needed to run the app.

---

## 1. Run `rafeeq_ai_api` (FastAPI backend)

### Prerequisites

- Python 3.10+
- `ffmpeg` on `PATH` (required by Whisper for audio decoding)
- ~2 GB free disk for Whisper + AraBERT weights on first run

### Setup

```bash
cd rafeeq_ai_api

python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS / Linux
source .venv/bin/activate

python -m pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
```

### Start the server

```bash
python main.py
```

This runs `uvicorn` on `http://0.0.0.0:8000` with `--reload`. Equivalent
manual command:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## 2. Run `flutter_app` (Flutter client)

### Prerequisites

- Flutter SDK `>=3.0.0 <4.0.0` — run `flutter doctor` until everything is
  green for your target platform (Android / iOS / Web / Windows).
- Backend from step 1 running and reachable.

### Setup

```bash
cd flutter_app
flutter pub get
```

### Point the app at your backend

`lib/core/constants/app_constants.dart` reads `BASE_URL` from the build
environment.

### Run

```bash
# Android / iOS emulator (pick a device with `flutter devices`)
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000

```
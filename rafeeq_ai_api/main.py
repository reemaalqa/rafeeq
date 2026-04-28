"""
Rafeeq Voice Assistant — FastAPI Backend
=========================================
Pipeline:
  Audio file  ──►  Whisper (ASR)  ──►  Arabic text
  Arabic text ──►  AraBERT (NLU)  ──►  Intent label

Endpoints:
  GET  /health          — liveness check
  POST /predict/text    — text  → intent
  POST /predict/audio   — audio → text + intent
  GET  /diet/meals      — full Saudi meal catalog (shared with the Flutter app)
  POST /diet/plan       — filtered breakfast/lunch/dinner plan for a user
  python -m pip install --upgrade pip setuptools wheel
  python -m pip install openai-whisper
"""

import json
import os
import tempfile
import logging
from contextlib import asynccontextmanager
from typing import List, Optional

import torch
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# ─── Logging ─────────────────────────────────────────────────────────────────

logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
log = logging.getLogger("rafeeq")

# ─── Intent categories ───────────────────────────────────────────────────────

INTENTS = [
    "emergency",
    "prayer_time",
    "medication",
    "diet",
    "reminders",
    "quran",
    "islamic_advice",
    "locations",
    "conversation",
    "general",
]

INTENTS_AR = {
    "emergency":      "طوارئ",
    "prayer_time":    "أوقات الصلاة",
    "medication":     "الدواء",
    "diet":           "النظام الغذائي",
    "reminders":      "التذكيرات",
    "quran":          "القرآن",
    "islamic_advice": "النصيحة الإسلامية",
    "locations":      "المواقع",
    "conversation":   "محادثة",
    "general":        "عام",
}

# ─── Keyword fallback (used when AraBERT weights are not available) ───────────

_KEYWORDS: dict[str, list[str]] = {
    "emergency":      ["نجدة", "ساعدني", "طحت", "وقعت", "إسعاف", "طوارئ", "وجع", "ألم", "مريض", "حادث", "خطر", "إغماء",
                       "سكري نزل", "نزل السكر", "السكر نازل", "السكر نزل"],
    "prayer_time":    ["صلاة", "أذان", "الفجر", "الظهر", "العصر", "المغرب", "العشاء", "وقت الصلاة", "متى الأذان",
                       "متى ياذن", "متى يأذن", "متى الاذان", "وقت الصله"],
    "medication":     ["دواء", "دوائي", "حبوب", "حبة", "جرعة", "علاج", "صيدلية", "ذكرني بالدواء", "وقت دوائي",
                       "حبوبي", "حبتي", "دواي"],
    "diet":           ["أكل", "طعام", "غذاء", "جوعان", "وش أكل", "كالوري", "سعرات", "رجيم", "فطور", "غداء", "عشاء",
                       "اسمن", "انحف", "تخسيس", "زيادة وزن", "خسارة وزن"],
    "reminders":      ["ذكرني", "تذكير", "موعد", "اضبط", "نبهني", "منبه", "جدول", "لا تنسى", "ذكرني بعد",
                       "بعدين ذكرني", "ذكرني بدواي", "بعدين ذكرني بدواي"],
    "quran":          ["قرآن", "قران", "سورة", "سوره", "آية", "ايه", "تلاوة", "الفاتحة", "البقرة", "ياسين", "الكهف", "الملك"],
    "islamic_advice": ["نصيحة", "نصيحه", "نصائح", "دعاء", "حديث", "حكمة", "ذكر الله", "استغفر", "علمني دعاء",
                       "اذكار", "أذكار", "ذكر", "ادعيه", "ادعية", "ماشاء الله", "ماشاءالله"],
    "locations":      ["مسجد", "مستشفى", "صيدلية", "عيادة", "وين", "أقرب", "دلني", "خريطة", "موقع",
                       "مستوصف", "مركز صحي", "حديقة", "حديقه"],
    "conversation":   ["قصة", "نكتة", "سولف", "كلمني", "حدثني", "ترفيه", "قولي",
                       "ابشر", "شخبارك", "بشرني عنك", "طفشان", "مالي خلق",
                       "وش قلت", "الحمدالله بخير", "الحمد لله بخير", "زين",
                       "فمان الله", "في امان الله", "معسلامه", "مع السلامه"],
    "general":        [],
}

# ── Strong single-word triggers ──────────────────────────────────────────────
# When the user utters ONLY one of these (or the utterance is dominated by it),
# the intent is unambiguous — bypass AraBERT entirely. This protects against
# low-confidence model drift on canonical vocabulary.
_STRONG_TRIGGERS: dict[str, str] = {
    # islamic_advice
    "نصيحة": "islamic_advice", "نصيحه": "islamic_advice",
    "نصائح": "islamic_advice", "اذكار": "islamic_advice",
    "أذكار": "islamic_advice", "دعاء":  "islamic_advice",
    "حديث":  "islamic_advice", "ذكر":   "islamic_advice",
    "ادعيه": "islamic_advice", "ادعية": "islamic_advice",
    # quran
    "قرآن":  "quran", "قران": "quran", "سورة": "quran", "سوره": "quran",
    "الفاتحة": "quran", "البقرة": "quran", "ياسين": "quran",
    # prayer_time
    "صلاة": "prayer_time", "أذان": "prayer_time", "اذان": "prayer_time",
    "الفجر": "prayer_time", "الظهر": "prayer_time", "العصر": "prayer_time",
    "المغرب": "prayer_time", "العشاء": "prayer_time",
    # medication / reminders / diet / emergency
    "دواء":   "medication",  "حبوب":  "medication",  "حبة": "medication",
    "حبوبي":  "medication",
    "ذكرني":  "reminders",   "تذكير": "reminders",   "نبهني": "reminders",
    "أكل":    "diet",        "طعام":  "diet",        "فطور": "diet",
    "غداء":   "diet",        "عشاء":  "diet",
    "نجدة":   "emergency",   "طوارئ": "emergency",   "إسعاف": "emergency",
    # locations
    "مسجد":   "locations",   "مستشفى": "locations",  "صيدلية": "locations",
    "مستوصف": "locations",
}

# Confidence threshold below which we don't trust AraBERT and prefer the
# keyword scorer. The 10-class model's uniform prior is 10%, so anything
# under ~55% means the model is mostly guessing between 2-3 classes.
_ARABERT_MIN_CONFIDENCE = 0.55

def _normalise(text: str) -> str:
    """Strip Arabic diacritics/tatweel and normalise common variants so
    keyword matching isn't thrown off by tashkeel."""
    import re
    t = text.strip().lower()
    t = re.sub(r"[ً-ٟؐ-ؚـٰ]", "", t)
    t = (t.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
          .replace("ة", "ه").replace("ى", "ي"))
    return re.sub(r"\s+", " ", t).strip()


def _keyword_scores(text: str) -> dict[str, int]:
    """Count keyword matches per intent, with diacritic-insensitive matching."""
    norm = _normalise(text)
    scores: dict[str, int] = {}
    for intent, keywords in _KEYWORDS.items():
        scores[intent] = sum(1 for kw in keywords if _normalise(kw) in norm)
    return scores


def _keyword_classify(text: str) -> tuple[str, int]:
    """Returns (intent, score) for the best keyword match, or ("general", 0)."""
    scores = _keyword_scores(text)
    best_intent, best_score = "general", 0
    for intent, s in scores.items():
        if s > best_score:
            best_intent, best_score = intent, s
    return best_intent, best_score


def _check_strong_trigger(text: str) -> str | None:
    """Return the intent when the utterance is essentially a single known
    trigger word (e.g. user just said "نصيحة"). None otherwise."""
    norm = _normalise(text)
    tokens = norm.split()
    # Single-word utterance that matches a known trigger → unambiguous.
    if len(tokens) == 1 and tokens[0] in {_normalise(k) for k in _STRONG_TRIGGERS}:
        for k, v in _STRONG_TRIGGERS.items():
            if _normalise(k) == tokens[0]:
                return v
    # Short utterances (≤3 tokens) where at least one token is a trigger.
    if len(tokens) <= 3:
        for k, v in _STRONG_TRIGGERS.items():
            if _normalise(k) in tokens:
                return v
    return None

# ── Dialect detection ────────────────────────────────────────────────────────
# Pure pattern-matching — no model weights, zero latency, runs offline.
# Matches the Dart DialectDetector in lib/core/services/dialect_detector.dart.

import re as _re

_DIALECT_LABELS = {
    "najdi":    "نجدي",
    "janoubi":  "جنوبي",
    "shamali":  "شمالي",
    "sharqawi": "شرقاوي",
}

# Najdi – Central (Riyadh / Qassim)
# Suffix "هس/مس" on pronouns, confirmation "ايه", greeting "ابشر".
_r_najdi_enc  = _re.compile(r"(?<=[كهم])س(?=\s|$|[،.؟!])")
_r_najdi_lex  = _re.compile(r"\b(ابشر|ابشري|ايه(?!\s*والله)|شعليك|عساكم?|تسلمس?|شنو)\b")

# Janoubi – Southern (Abha / Jizan / Najran)
# Suffix "كش/هش/مش", markers وينش، كيفش، علاش.
_r_janoubi_enc = _re.compile(r"(?<=[كهم])ش(?=\s|$|[،.؟!])")
_r_janoubi_lex = _re.compile(r"\b(وينش|كيفش|شخبارش|شبيكش|ليش|علاش|ايش)\b")

# Shamali – Northern (Hail / Jouf / Tabuk)
# Greeting cluster شبيك/شخبارك and feminine "-كي" enclitic.
_r_shamali_greet = _re.compile(r"\b(شبيكي?|شخباركي?|شلونكي?|هلا\s+والله)\b")
_r_shamali_ki    = _re.compile(r"كي(?=\s|$|[،.؟!])")

# Sharqawi – Eastern (Dammam / Ahsa / Qatif)
# Suffix "كت/هت", filler "عاد", "إي/اي والله".
_r_sharqawi_enc = _re.compile(r"(?<=[كهم])ت(?=\s|$|[،.؟!])")
_r_sharqawi_lex = _re.compile(r"\b(عاد\b|اي\s+والله|إي\s+والله|وش\s+اخبارك|وينت|كيفت|شفيت)\b")

_DIALECT_MIN_SIGNAL     = 1.5
_DIALECT_MIN_CONFIDENCE = 0.45


def _dialect_scores(text: str) -> dict[str, float]:
    n = _normalise(text)
    return {
        "najdi":    len(_r_najdi_enc.findall(n))  * 3.0 + len(_r_najdi_lex.findall(n))  * 1.5,
        "janoubi":  len(_r_janoubi_enc.findall(n)) * 3.0 + len(_r_janoubi_lex.findall(n)) * 1.5,
        "shamali":  len(_r_shamali_greet.findall(n)) * 3.0 + len(_r_shamali_ki.findall(n)) * 2.0,
        "sharqawi": len(_r_sharqawi_enc.findall(n)) * 3.0 + len(_r_sharqawi_lex.findall(n)) * 1.5,
    }


def _detect_dialect(text: str) -> dict:
    """
    Returns a dict with keys: dialect, dialect_ar, confidence, scores.
    dialect is None when the signal is too weak to commit.
    """
    if not text.strip():
        return {"dialect": None, "dialect_ar": None, "confidence": 0.0, "scores": {}}

    scores = _dialect_scores(text)
    best   = max(scores, key=scores.get)
    best_s = scores[best]
    total  = sum(scores.values())
    conf   = best_s / total if total > 0 else 0.0

    log.info("Dialect scores: %s", scores)

    if best_s < _DIALECT_MIN_SIGNAL or conf < _DIALECT_MIN_CONFIDENCE:
        log.info("Dialect: no confident match (best=%s score=%.1f conf=%.0f%%)",
                 best, best_s, conf * 100)
        return {"dialect": None, "dialect_ar": None, "confidence": conf, "scores": scores}

    log.info("Dialect detected: %s (confidence=%.0f%%)", best, conf * 100)
    return {
        "dialect":    best,
        "dialect_ar": _DIALECT_LABELS[best],
        "confidence": round(conf, 3),
        "scores":     scores,
    }


# ─── Global model handles (loaded once at startup) ───────────────────────────

_whisper = None          # openai-whisper model
_tokenizer = None        # AraBERT tokenizer
_arabert = None          # AraBERT sequence-classifier

# Path where fine-tuned AraBERT weights are expected.
# Run the ML training scripts first to generate these files.
_ARABERT_WEIGHTS = os.path.abspath(os.path.join(
    os.path.dirname(__file__),
    "..",
    "machine_learning",
    "outputs",
    "models",
    "model1_arabert",
))
_ARABERT_HUB = "aubmindlab/bert-base-arabertv02"
_WHISPER_SIZE = "small"   # tiny / base / small / medium / large

# ─── Startup / shutdown ───────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    global _whisper, _tokenizer, _arabert

    # ── Load Whisper ─────────────────────────────────────────────────────────
    log.info("Loading Whisper (%s) …", _WHISPER_SIZE)
    try:
        import whisper
        _whisper = whisper.load_model(_WHISPER_SIZE)
        log.info("Whisper ready.")
    except Exception as exc:
        log.warning("Whisper not available: %s  (audio endpoint disabled)", exc)

    # ── Load AraBERT ─────────────────────────────────────────────────────────
    # Only load the fine-tuned intent classifier when its weights actually
    # exist on disk. Loading the raw HuggingFace hub model would give us a
    # randomly-initialised classification head that predicts garbage (e.g.
    # "medication" for every input). In that case we intentionally leave
    # _arabert = None so _classify() uses the Arabic keyword fallback.
    if os.path.isdir(_ARABERT_WEIGHTS):
        log.info("Loading AraBERT intent classifier from %s …", _ARABERT_WEIGHTS)
        try:
            from transformers import AutoTokenizer, AutoModelForSequenceClassification

            _tokenizer = AutoTokenizer.from_pretrained(_ARABERT_WEIGHTS)
            _arabert = AutoModelForSequenceClassification.from_pretrained(
                _ARABERT_WEIGHTS,
                num_labels=len(INTENTS),
                id2label={i: l for i, l in enumerate(INTENTS)},
                label2id={l: i for i, l in enumerate(INTENTS)},
            )
            _arabert.eval()
            log.info("AraBERT ready  (device: %s).", "cuda" if torch.cuda.is_available() else "cpu")
        except Exception as exc:
            log.warning("AraBERT load failed: %s  (keyword fallback active)", exc)
            _tokenizer = None
            _arabert = None
    else:
        log.warning(
            "Fine-tuned AraBERT weights not found at %s — using Arabic keyword "
            "fallback. Run machine_learning/03_model1_arabert.py to train.",
            _ARABERT_WEIGHTS,
        )

    yield  # ── app runs here ──

    log.info("Shutting down …")

# ─── FastAPI app ──────────────────────────────────────────────────────────────

app = FastAPI(
    title="Rafeeq Voice API",
    description="Arabic voice assistant backend — Whisper ASR + AraBERT NLU",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Core classification logic ────────────────────────────────────────────────

def _classify(text: str) -> tuple[str, str, str]:
    """
    Returns (intent_key, intent_ar, method_used).

    Decision policy:
      1. If the input is a short utterance dominated by a known trigger word
         (e.g. "نصيحة", "قرآن"), use the strong-trigger mapping directly.
         AraBERT is fine-tuned but still drifts on single-word canonical
         vocabulary — at ~35% confidence it's effectively guessing.
      2. Run AraBERT. If its top confidence is ≥ _ARABERT_MIN_CONFIDENCE AND
         it doesn't contradict a strong keyword signal, trust it.
      3. Otherwise fall back to keyword scoring.
    """
    log.info("─" * 70)
    log.info("INPUT: %s", text)

    # ── 1) Strong single-word triggers ─────────────────────────────────────
    trigger = _check_strong_trigger(text)
    if trigger is not None:
        log.info("Strong trigger match → %s", trigger)
        log.info(
            "RESULT: %s (%s)  method=strong_trigger",
            trigger, INTENTS_AR[trigger],
        )
        return trigger, INTENTS_AR[trigger], "strong_trigger"

    # Keyword scores (used for veto + fallback, log once).
    kw_scores = _keyword_scores(text)
    kw_best, kw_best_score = _keyword_classify(text)

    # ── 2) AraBERT with confidence gating ──────────────────────────────────
    if _arabert is not None and _tokenizer is not None:
        try:
            inputs = _tokenizer(
                text,
                return_tensors="pt",
                truncation=True,
                max_length=128,
                padding=True,
            )
            with torch.no_grad():
                logits = _arabert(**inputs).logits
                probs = torch.softmax(logits, dim=-1)[0]

            idx = int(torch.argmax(probs).item())
            intent = INTENTS[idx]
            confidence = float(probs[idx].item())

            # Per-class probability table, sorted high→low.
            ranked = sorted(
                zip(INTENTS, probs.tolist()),
                key=lambda kv: kv[1],
                reverse=True,
            )
            log.info("AraBERT probabilities:")
            for name, p in ranked:
                marker = "  ◄" if name == intent else ""
                log.info("  %-16s %6.2f%%%s", name, p * 100, marker)

            # Low-confidence → trust keywords instead (if any matched).
            if confidence < _ARABERT_MIN_CONFIDENCE and kw_best_score > 0:
                log.info(
                    "AraBERT confidence %.1f%% < %.0f%% AND keywords match %s "
                    "(score %d) → preferring keywords",
                    confidence * 100, _ARABERT_MIN_CONFIDENCE * 100,
                    kw_best, kw_best_score,
                )
                log.info(
                    "RESULT: %s (%s)  method=keyword_override",
                    kw_best, INTENTS_AR[kw_best],
                )
                return kw_best, INTENTS_AR[kw_best], "keyword_override"

            # Keyword veto: if the user clearly mentioned a trigger word but
            # AraBERT picked something else, prefer the keyword. This catches
            # cases like input="نصيحة" → AraBERT says "reminders" at 35%.
            if kw_best_score > 0 and kw_best != intent:
                kw_intent_score = kw_scores.get(kw_best, 0)
                arabert_intent_kw_score = kw_scores.get(intent, 0)
                if kw_intent_score > arabert_intent_kw_score:
                    log.info(
                        "Keyword veto: input contains %s keywords (score %d) "
                        "but AraBERT chose %s (kw score %d) → preferring keywords",
                        kw_best, kw_intent_score, intent, arabert_intent_kw_score,
                    )
                    log.info(
                        "RESULT: %s (%s)  method=keyword_veto",
                        kw_best, INTENTS_AR[kw_best],
                    )
                    return kw_best, INTENTS_AR[kw_best], "keyword_veto"

            log.info(
                "RESULT: %s (%s)  confidence=%.2f%%  method=arabert",
                intent, INTENTS_AR[intent], confidence * 100,
            )
            return intent, INTENTS_AR[intent], "arabert"
        except Exception as exc:
            log.warning("AraBERT inference error: %s — falling back to keywords", exc)

    # ── 3) Keyword fallback ────────────────────────────────────────────────
    log.info("Keyword match scores:")
    for name, score in sorted(kw_scores.items(), key=lambda kv: kv[1], reverse=True):
        marker = "  ◄" if name == kw_best else ""
        log.info("  %-16s %d%s", name, score, marker)
    log.info(
        "RESULT: %s (%s)  method=keyword_fallback",
        kw_best, INTENTS_AR[kw_best],
    )
    return kw_best, INTENTS_AR[kw_best], "keyword_fallback"

# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.get("/health", summary="Liveness check")
def health():
    return {
        "status": "ok",
        "whisper": _whisper is not None,
        "arabert": _arabert is not None,
        "nlu_mode": "arabert" if _arabert is not None else "keyword_fallback",
    }


class TextRequest(BaseModel):
    text: str


@app.post("/predict/text", summary="Text → intent + dialect")
def predict_text(req: TextRequest):
    """
    Receives Arabic text and returns the detected intent and dialect.

    Example body:
        {"text": "ذكرني بالدواء الساعة ثلاثة"}
    """
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="text field is empty")

    intent, intent_ar, method = _classify(req.text)
    dialect_info = _detect_dialect(req.text)

    return {
        "text":       req.text,
        "intent":     intent,
        "intent_ar":  intent_ar,
        "method":     method,
        "dialect":    dialect_info["dialect"],
        "dialect_ar": dialect_info["dialect_ar"],
        "dialect_confidence": dialect_info["confidence"],
    }


@app.post("/predict/dialect", summary="Text → dialect detection")
def predict_dialect(req: TextRequest):
    """
    Detects which Saudi Arabic sub-dialect the text is written in.

    Returns null for 'dialect' when the signal is too weak.

    Test examples — paste each into the Swagger UI:

    """
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="text field is empty")

    result = _detect_dialect(req.text)
    return {"text": req.text, **result}


@app.post("/predict/audio", summary="Audio → text + intent")
async def predict_audio(audio: UploadFile = File(...)):
    """
    Receives a WAV/MP3/M4A audio file, transcribes it with Whisper,
    then classifies the resulting Arabic text with AraBERT.

    Returns the transcription, detected intent, and confidence details.
    """
    if _whisper is None:
        raise HTTPException(
            status_code=503,
            detail="Whisper is not loaded. Install openai-whisper and restart.",
        )

    # Save upload to a temporary file so Whisper can read it.
    suffix = os.path.splitext(audio.filename or ".wav")[1] or ".wav"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await audio.read())
        tmp_path = tmp.name

    try:
        log.info("Transcribing %s …", audio.filename)
        result = _whisper.transcribe(tmp_path, language="ar", fp16=False)
        text = result["text"].strip()
        log.info("Transcription: %s", text)
    finally:
        os.unlink(tmp_path)

    if not text:
        raise HTTPException(status_code=422, detail="Could not transcribe audio — no speech detected.")

    intent, intent_ar, method = _classify(text)
    return {
        "text":      text,
        "intent":    intent,
        "intent_ar": intent_ar,
        "method":    method,
    }


# ─── Diet plan (shared dataset with the Flutter app) ──────────────────────────
#
# The JSON catalog lives at flutter_app/assets/data/saudi_meals.json and is
# bundled into the mobile app as an offline asset. Serving it from the API
# ensures both sides draw from the same ~38 professionally curated Saudi
# meals with full nutrition, allergen tags, and BMI suitability flags.

_MEALS_JSON_PATH = os.path.abspath(os.path.join(
    os.path.dirname(__file__),
    "..",
    "flutter_app",
    "assets",
    "data",
    "saudi_meals.json",
))

_ALLERGEN_NAME_TO_TAG: dict[str, str] = {
    # English
    "dairy": "dairy", "gluten": "gluten", "wheat": "wheat", "eggs": "eggs",
    "nuts": "nuts", "peanuts": "peanuts", "shellfish": "shellfish",
    "fish": "fish", "sesame": "sesame", "sugar": "sugar", "soy": "soy",
    "spicy food": "spicy", "spicy": "spicy", "caffeine": "caffeine",
    # Arabic (l10n display names used by the Flutter profile screen)
    "ألبان": "dairy", "جلوتين": "gluten", "قمح": "wheat",
    "بيض": "eggs", "مكسرات": "nuts", "فول سوداني": "peanuts",
    "محار": "shellfish", "سمك": "fish", "سمسم": "sesame",
    "سكر": "sugar", "صويا": "soy", "طعام حار": "spicy", "كافيين": "caffeine",
}

_ALLERGEN_INGREDIENT_KEYWORDS: dict[str, set[str]] = {
    "dairy":     {"حليب", "لبن", "جبن", "زبدة", "سمن", "قشطة", "كريمة", "لبنة"},
    "gluten":    {"قمح", "جريش", "عجين", "دقيق", "خبز", "هريس", "شعير", "برغل", "تميس", "توست"},
    "wheat":     {"قمح", "جريش", "عجين", "دقيق", "خبز", "هريس", "برغل", "تميس"},
    "eggs":      {"بيض", "بيضة", "بياض"},
    "nuts":      {"لوز", "جوز", "فستق", "بندق", "كاجو"},
    "peanuts":   {"فول سوداني"},
    "shellfish": {"روبيان", "جمبري", "كابوريا", "بطلينوس"},
    "fish":      {"سمك", "سمكة", "تونة", "هامور", "فيليه"},
    "sesame":    {"سمسم", "طحينة", "زعتر"},
    "sugar":     {"سكر", "عسل", "حلويات", "شراب"},
    "spicy":     {"فلفل حار", "شطة", "هريسة"},
}

_meals_cache: Optional[dict] = None


def _load_meals() -> dict:
    """Reads and memoises the JSON catalog. Raises 503 if the file is missing."""
    global _meals_cache
    if _meals_cache is not None:
        return _meals_cache
    if not os.path.isfile(_MEALS_JSON_PATH):
        raise HTTPException(
            status_code=503,
            detail=f"Saudi meal dataset missing at {_MEALS_JSON_PATH}",
        )
    with open(_MEALS_JSON_PATH, "r", encoding="utf-8") as f:
        _meals_cache = json.load(f)
    return _meals_cache


def _allergen_tag(display_name: str) -> str:
    """Normalise an allergy display name (Arabic or English) to a canonical tag."""
    key = display_name.strip().lower()
    return (_ALLERGEN_NAME_TO_TAG.get(key)
            or _ALLERGEN_NAME_TO_TAG.get(display_name.strip())
            or "")


@app.get("/diet/meals", summary="Full Saudi meal catalog")
def list_meals(meal_time: Optional[str] = None, bmi: Optional[str] = None):
    """
    Return every meal in the shared JSON catalog.

    Optional filters:
      - meal_time: breakfast | lunch | dinner | snack
      - bmi:       underweight | normal | overweight | obese
    """
    data = _load_meals()
    meals = data["meals"]
    if meal_time:
        meals = [m for m in meals if m["meal_time"] == meal_time]
    if bmi:
        meals = [m for m in meals if bmi in m["suitable_for_bmi"]]
    return {
        "version": data.get("version"),
        "count": len(meals),
        "meals": meals,
    }


class DietPlanRequest(BaseModel):
    bmi_category: str = Field(..., description="underweight|normal|overweight|obese")
    allergies: List[str] = Field(default_factory=list, description="Allergy names (Arabic or English display strings)")
    disliked_foods: List[str] = Field(default_factory=list, description="Individual ingredients to avoid")
    include_snack: bool = Field(default=True)
    rotation_index: int = Field(
        default=0,
        description="Advance this on each call so consecutive requests return different meals per slot.",
    )


@app.post("/diet/plan", summary="Daily plan for a user")
def build_plan(req: DietPlanRequest):
    """
    Build a one-day plan (breakfast / lunch / dinner + optional snack) from
    the shared catalog. Filters out any meal whose allergen tags overlap the
    user's allergy list, whose ingredients substring-match a disliked food,
    or that isn't flagged as suitable for the user's BMI band.

    When every candidate in a slot is filtered out, falls back to the first
    BMI-suitable meal so the user always receives a complete plan — same
    behaviour as the Flutter offline fallback.
    """
    if req.bmi_category not in ("underweight", "normal", "overweight", "obese"):
        raise HTTPException(
            status_code=400,
            detail="bmi_category must be underweight|normal|overweight|obese",
        )

    data = _load_meals()
    catalog = data["meals"]
    bmi_key = req.bmi_category

    allergen_tags = {_allergen_tag(a) for a in req.allergies if _allergen_tag(a)}
    dislike_terms = {d.lower() for d in req.disliked_foods if d.strip()}
    # Backup: map allergens to ingredient-string keywords so partial-tag data
    # is still vetoed by substring match.
    for a in req.allergies:
        tag = _allergen_tag(a)
        dislike_terms.update(
            kw.lower() for kw in _ALLERGEN_INGREDIENT_KEYWORDS.get(tag, set())
        )

    def compatible(m: dict) -> bool:
        if bmi_key not in m.get("suitable_for_bmi", []):
            return False
        if any(tag in m.get("allergens", []) for tag in allergen_tags):
            return False
        for ing in m.get("ingredients_ar", []):
            lower_ing = ing.lower()
            if any(term and term in lower_ing for term in dislike_terms):
                return False
        return True

    slots = ["breakfast", "lunch", "dinner"]
    if req.include_snack:
        slots.append("snack")

    # Rotate which meal per slot is picked so repeated calls with the same
    # profile cycle through variety. Each slot gets its own offset so all
    # three don't advance in lock-step.
    picked: list[dict] = []
    for slot_idx, slot in enumerate(slots):
        slot_meals = [m for m in catalog if m["meal_time"] == slot]
        if not slot_meals:
            continue
        slot_for_bmi = [m for m in slot_meals if bmi_key in m.get("suitable_for_bmi", [])]
        pool = slot_for_bmi or slot_meals
        compat = [m for m in pool if compatible(m)]
        candidates = compat or pool
        idx = (req.rotation_index + slot_idx * 7) % len(candidates)
        picked.append(candidates[idx])

    total_calories = sum(
        m["nutrition"].get("calories", 0)
        for m in picked
        if m["meal_time"] != "snack"
    )
    band = data.get("bmi_bands", {}).get(bmi_key, {})

    return {
        "bmi_category": bmi_key,
        "target_calories": band.get("calorie_target"),
        "total_calories": total_calories,
        "slots": slots,
        "meals": picked,
    }


# ─── Run directly ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

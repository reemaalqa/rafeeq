# Rafeeq Flutter App

Elderly-care companion app. Flutter front-end for the FastAPI backend in
`../backend/`.

## Run locally

```bash
flutter pub get
flutter run                 # Android / iOS emulator
flutter run -d chrome       # Web
```

## Build & deploy web (Firebase Hosting)

The doctor asked us to host the app on Firebase. The `firebase.json` +
`.firebaserc` files in this folder configure Hosting only — we do NOT
store user data in Firebase; preferences live in MySQL (see backend).

First-time setup on a new machine:

```bash
npm install -g firebase-tools    # one-time
firebase login                   # browser opens
firebase use rafeeq-app          # or whatever project id you created
```

Build and deploy:

```bash
flutter build web --release
firebase deploy --only hosting
```

`firebase.json` points Hosting's public folder to `build/web`, adds a
SPA rewrite so deep links work, and sets long cache headers on JS/CSS
while keeping `index.html` un-cached so new deploys propagate.

## AI response preferences

When a new user signs up, right after OTP verification they see a
3-question screen (`preferences_onboarding_page.dart`) that asks:

1. Short or long replies?
2. Simple or detailed explanations?
3. Want examples?

Answers are `PUT` to `/users/preferences` and also cached in
SharedPreferences (`StorageKeys.aiReplyLength` etc.). Before every call
to Gemini, `ConversationCubit._buildSystemInstruction()` reads those
keys and prepends them to the system prompt so the LLM shapes its reply
to the user's taste. Food quantities in Gemini replies are forced into
spoon units via the same instruction.

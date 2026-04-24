# WhoIsThere? 🧩

A multiplayer puzzle guessing game built with Flutter + Firebase.

## Game Rules

- **2-8 players**, each on their own device
- **Phase 1:** Double voting — choose an image, then choose difficulty
  - Host vote = 2 points weight; ties broken by host
- **Phase 2:** Take turns placing puzzle pieces on the board
  - Correct placement: stays on board, score increases
  - Wrong placement: piece returns to pool
  - Each turn: place a piece (optional) + one guess attempt
  - Wrong guess = lose points; reach 0 = eliminated
- **Win:** Correctly identify the person/place in the image

## Difficulty Levels

| Level | Pieces | Starting pts | Place piece | Wrong guess | Win |
|-------|--------|-------------|------------|------------|-----|
| Very Easy | 9 | 10 | +1 | -1 | +10 |
| Easy | 25 | 15 | +2 | -2 | +20 |
| Medium | 50 | 20 | +3 | -3 | +30 |
| Hard | 100 | 25 | +4 | -4 | +40 |

## Tech Stack

- **Flutter** 3.x — iOS + Android
- **Firebase Auth** — Google Sign In + Apple Sign In
- **Cloud Firestore** — Real-time multiplayer state
- **Firebase Storage** — Puzzle images
- **Riverpod** — State management
- **GoRouter** — Navigation
- **Google Fonts (Nunito)** — Typography
- **flutter_animate** — Animations
- **confetti** — Win celebration

## Setup

### 1. Flutter
```bash
flutter pub get
```

### 2. Firebase
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (creates firebase_options.dart)
flutterfire configure --project=YOUR_PROJECT_ID
```

### 3. Firebase Console
- Enable **Authentication**: Google + Apple
- Enable **Firestore**
- Deploy **Firestore rules**: `firebase deploy --only firestore:rules`
- Seed images using `firestore_seed_images.json`

### 4. Run
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── core/
│   ├── constants/      # Colors, game rules
│   ├── theme/          # AppTheme
│   └── utils/          # Router, code generator
├── models/             # Data models (User, Room, Image, Player)
├── services/           # Firebase services (Auth, Room)
├── providers/          # Riverpod providers
├── screens/
│   ├── splash/
│   ├── home/
│   ├── auth/
│   ├── room/           # Create, Join, Lobby
│   ├── voting/         # Image vote, Difficulty vote
│   ├── game/           # Game board
│   ├── win/
│   ├── profile/
│   └── store/
└── widgets/common/     # Reusable UI components
```

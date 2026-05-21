# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app (requires a connected device or emulator)
flutter run

# Analyze for lint errors
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Regenerate Riverpod providers (after adding @riverpod annotations)
dart run build_runner build --delete-conflicting-outputs

# Deploy Firestore security rules
firebase deploy --only firestore:rules
```

## Architecture

### Game Flow

The app is a multiplayer landmark-guessing game. The full game session lifecycle follows this phase progression, all stored in a single Firestore `rooms` document:

```
waiting → votingImage → votingDifficulty → playing → finished
```

`GamePhase` and `Difficulty` enums (with all scoring parameters) live in `lib/core/constants/game_constants.dart`. All game-phase transitions are written to Firestore by `RoomService` — screens never write to Firestore directly.

### State Management

Riverpod providers are centralized in `lib/providers/providers.dart`. The key dependency chain:

- `firebaseUserProvider` (Firebase Auth stream) → drives router redirect logic
- `currentUserProvider` → `UserModel` from Firestore `/users/{uid}`
- `roomStreamProvider(roomId)` → real-time `RoomModel` stream, used by all game screens
- `economyServiceProvider` → depends on `localEconomyCacheProvider` (async SharedPreferences cache); gracefully handles null cache while it initializes
- `walletProvider` → coin balance stream for the current user

`routerProvider` creates the `GoRouter` instance exactly once and uses `_RouterNotifier` (a `ChangeNotifier` wrapping `firebaseUserProvider`) to trigger redirects without recreating the router.

`TurnStateNotifier` / `TurnState` track per-turn UI state (has placed piece, has guessed) locally in the provider — this state is never persisted to Firestore.

### Service Layer

- **`AuthService`** — Firebase Auth + Firestore user sync. Supports anonymous, Google, and Apple sign-in. Contains a workaround for a Pigeon type-cast bug with `firebase_auth 4.16.0` + `firebase_core 2.32.x` (see `pubspec.yaml` comment); catch `TypeError` in `signInAnonymously` and fall back to `currentUser`.
- **`RoomService`** — all Firestore room operations. Image data is loaded from bundled JSON (`assets/game_places/data/israel_places.json`) — not from Firestore. Uses exposure history (`users/{uid}/exposure_history`) to prefer images players haven't seen recently.
- **`EconomyService`** — coin wallet at `users/{uid}/economy/wallet`, with transactions logged to `users/{uid}/economy_transactions`. All mutations use Firestore transactions. `LocalEconomyCache` (SharedPreferences) mirrors the coin balance for instant offline reads.
- **`HintEconomyGuard`** — thin wrapper that checks affordability and calls `EconomyService.spendCoins`.
- **`QaLoggerService`** — persistent in-memory + SharedPreferences event log (singleton). Call `QaLoggerService.instance.log('TAG', 'EVENT')` anywhere; the log can be copied from the Profile screen.

### Screen / Widget Separation

From `PROJECT_RULES.md`:

- **Screen files** (`lib/screens/<feature>/<screen>.dart`) own all state, logic, providers, Firestore calls, navigation, and callbacks passed to widgets.
- **Widget files** (`lib/screens/<feature>/widgets/`) must be UI-only: `StatelessWidget`, no providers, no services, no `setState`, no business rules. They receive data and callbacks through constructors.

`GameBoardScreen` is the most complex screen — it orchestrates bot turn simulation, audio players, economy rewards, confetti, and a guess dialog, all wired into `GameLayout` (a pure widget).

### Routing

All routes are declared in `lib/core/utils/app_router.dart`. Deep links (`whoisthere://join?code=XXXXXX` or `https://rotem-ya.github.io/apps-share-pages/whoisthere/join?code=XXXXXX`) are handled in `main.dart` via `app_links`. On cold start, the code is stored in `pendingJoinCodeProvider` and consumed by the router redirect after auth completes.

### Theming & Styling

The entire app uses a single dark "vault" visual identity defined in `lib/core/theme/app_styles.dart` (`AppStyles`). Use `AppStyles.backgroundGradient`, `AppStyles.glassCard()`, `AppStyles.glossyButton()`, and the predefined `TextStyle` constants (`heading1`/`heading2`/`bodyLarge` etc.) rather than inline decorations. The app is locked to RTL (`TextDirection.rtl`) globally via `MaterialApp.router`'s `builder`.

### Hebrew Answer Matching

`GameImageModel.isCorrectAnswer` normalizes Hebrew final letters (כ↔ך, מ↔ם, נ↔ן, פ↔ף, צ↔ץ) before comparing. The normalization function `normalizeHebrewFinals` is defined in `lib/widgets/game/letter_bank_input.dart` and imported by `game_image_model.dart`. All answer comparison must go through this function.

### Image Data

All puzzle images are Israeli landmarks, bundled as assets. `RoomService._loadLocalImages()` reads `assets/game_places/data/israel_places.json` once (cached via `_localImagesFuture`). Each entry uses Hebrew fields: `name_he`, `answer_he`, `aliases_he`. The active set is gated by `_availableLocalPlaceIds` in `RoomService`.

### Firestore Schema

- `rooms/{roomId}` — full game state (`RoomModel`)
  - `placedPieces: {pieceIndex: userId | 'revealed'}` — keys are stringified ints
  - `players: {userId: PlayerModel}` — map, not array
  - `phase`, `turnOrder`, `currentTurnIndex`, `lastGuessEvent`, `guessCount`
- `users/{userId}` — user profile
- `users/{userId}/economy/wallet` — `UserEconomyModel`
- `users/{userId}/economy_transactions/{txId}` — ledger
- `users/{userId}/exposure_history` — `{imageId: count}` for smart image selection

## Conventions

- **File naming**: `snake_case.dart`; widget class must match filename in `PascalCase`.
- **One main exported widget per file**; private helpers use a leading underscore and stay in the same file.
- **File size**: 700+ lines is a warning sign to split only if there is a second distinct responsibility — not for line count alone.
- **Linting**: `prefer_single_quotes`, `prefer_const_constructors`, `avoid_print` (use `debugPrint` or `QaLoggerService`).
- **Bot players** are created with IDs prefixed `virtual_` and flagged `isBot: true` in `PlayerModel`. All bot turn logic (delay, guess probability) runs client-side in `GameBoardScreen._scheduleBotTurn`.
- **Never push directly to `main`** — changes must pass GitHub Actions build validation.
- Do not mix visual changes with logic changes in a single commit unless the task explicitly requires both.

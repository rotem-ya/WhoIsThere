# PROJECT RULES - WhoIsThere

## Folder Structure

```text
lib/screens/<feature>/<screen>.dart
lib/screens/<feature>/widgets/<widget_name>.dart
lib/screens/<feature>/models/<local_model>.dart
lib/screens/<feature>/utils/<feature_helper>.dart
```

Example for the game feature:

```text
lib/screens/game/game_board_screen.dart
lib/screens/game/widgets/game_layout.dart
lib/screens/game/widgets/game_board_view.dart
lib/screens/game/widgets/game_top_hud.dart
lib/screens/game/widgets/game_actions.dart
lib/screens/game/widgets/game_banners.dart
lib/screens/game/widgets/answer_slots.dart
```

## Naming Rules

- File names use snake_case: `game_board_view.dart`
- Public widgets use PascalCase: `GameBoardView`
- Private widgets use a leading underscore only inside the same file: `_PrivateWidget`
- One main widget per file
- File name should match the main widget name

## File Size Rule

- 700+ lines is a warning sign
- Split only when the file has more than one responsibility
- Split when logic and UI are mixed
- Split when the file is hard to understand quickly
- Do not split only because of line count

## Responsibility Rules

### screen.dart

Screen files may contain:

- State variables
- Game logic
- `setState`
- Provider orchestration
- Navigation
- Callbacks passed into widgets

### widgets/

Widget files must be UI-only:

- Prefer StatelessWidget
- No providers
- No services
- No Firestore access
- No `setState`
- No business rules
- Receive data and callbacks through constructors

## Golden Rule

UI is dumb. Logic stays in the screen or service layer.

## Flutter UI Rules

- Mobile-first layout
- No fixed screen-height assumptions
- Use `SafeArea` where needed
- Use `Flexible`, `Expanded`, `FittedBox`, or `LayoutBuilder` to avoid overflow
- Do not hide overflow problems with scrolling unless scrolling is the intended UX
- Buttons must be readable and tappable on small Android phones
- Hebrew screens must preserve RTL behavior

## Build Rule

Feature branches must run the APK workflow before merge.

## Pre-Commit Checklist

Before every commit:

1. Build passes through GitHub Actions
2. No missing imports
3. No private widget is used across files
4. No logic moved into UI widgets
5. No accidental files or junk files
6. No unrelated refactor mixed with a feature change
7. No visual change unless the task explicitly requires it

## What Not To Do

- Do not move game logic into widgets
- Do not create deep widget nesting without reason
- Do not split blindly
- Do not push directly to main unless the change is explicitly approved
- Do not commit without build validation when the change touches Flutter code

## Goal

Fast development, stable builds, clean structure, and production-ready code.

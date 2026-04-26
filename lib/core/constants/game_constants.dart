enum Difficulty { veryEasy, easy, medium, hard }

extension DifficultyExtension on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.veryEasy:
        return 'קל מאוד';
      case Difficulty.easy:
        return 'קל';
      case Difficulty.medium:
        return 'בינוני';
      case Difficulty.hard:
        return 'קשה';
    }
  }

  int get pieces {
    switch (this) {
      case Difficulty.veryEasy:
        return 9;
      case Difficulty.easy:
        return 25;
      case Difficulty.medium:
        return 50;
      case Difficulty.hard:
        return 100;
    }
  }

  int get gridSize {
    switch (this) {
      case Difficulty.veryEasy:
        return 3;
      case Difficulty.easy:
        return 5;
      case Difficulty.medium:
        return 7; // 7x7 = 49, rounded to 50 logically
      case Difficulty.hard:
        return 10;
    }
  }

  int get startingPoints {
    switch (this) {
      case Difficulty.veryEasy:
        return 10;
      case Difficulty.easy:
        return 15;
      case Difficulty.medium:
        return 20;
      case Difficulty.hard:
        return 25;
    }
  }

  int get placePiecePoints {
    switch (this) {
      case Difficulty.veryEasy:
        return 1;
      case Difficulty.easy:
        return 2;
      case Difficulty.medium:
        return 3;
      case Difficulty.hard:
        return 4;
    }
  }

  int get wrongGuessPenalty {
    switch (this) {
      case Difficulty.veryEasy:
        return 1;
      case Difficulty.easy:
        return 2;
      case Difficulty.medium:
        return 3;
      case Difficulty.hard:
        return 4;
    }
  }

  int get winReward {
    switch (this) {
      case Difficulty.veryEasy:
        return 10;
      case Difficulty.easy:
        return 20;
      case Difficulty.medium:
        return 30;
      case Difficulty.hard:
        return 40;
    }
  }

  String get emoji {
    switch (this) {
      case Difficulty.veryEasy:
        return '🟢';
      case Difficulty.easy:
        return '🟡';
      case Difficulty.medium:
        return '🟠';
      case Difficulty.hard:
        return '🔴';
    }
  }
}

enum GamePhase {
  waiting,
  votingImage,
  votingDifficulty,
  playing,
  finished,
}

enum ImageCategory {
  singer,
  actor,
  athlete,
  politician,
  place,
  landmark,
}

extension ImageCategoryExtension on ImageCategory {
  String get label {
    switch (this) {
      case ImageCategory.singer:
        return 'זמר/ת';
      case ImageCategory.actor:
        return 'שחקן/ית';
      case ImageCategory.athlete:
        return 'ספורטאי/ת';
      case ImageCategory.politician:
        return 'פוליטיקאי/ת';
      case ImageCategory.place:
        return 'מקום';
      case ImageCategory.landmark:
        return 'אתר';
    }
  }
}

class GameConstants {
  static const int maxPlayers = 8;
  static const int minPlayers = 1;
  static const int roomCodeLength = 6;
  static const int hostVoteWeight = 2;
  static const int regularVoteWeight = 1;

  static const int votingTimeoutSeconds = 60;
  static const int turnTimeoutSeconds = 90;

  // Store costs
  static const int hintCost = 5;
  static const int categoryHintCost = 3;
  static const int premiumImagePackCost = 50;
  static const int themeCost = 30;
}

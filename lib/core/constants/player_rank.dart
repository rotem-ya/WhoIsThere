import 'package:flutter/material.dart';

enum PlayerRank {
  blind,
  beginner,
  curious,
  detective,
  researcher,
  expert,
  legend,
}

extension PlayerRankX on PlayerRank {
  String get label {
    switch (this) {
      case PlayerRank.blind: return 'עיוור';
      case PlayerRank.beginner: return 'מתחיל';
      case PlayerRank.curious: return 'סקרן';
      case PlayerRank.detective: return 'בלש';
      case PlayerRank.researcher: return 'חוקר';
      case PlayerRank.expert: return 'מומחה';
      case PlayerRank.legend: return 'אגדה';
    }
  }

  String get emoji {
    switch (this) {
      case PlayerRank.blind: return '👁';
      case PlayerRank.beginner: return '🌱';
      case PlayerRank.curious: return '🔍';
      case PlayerRank.detective: return '🕵';
      case PlayerRank.researcher: return '🔭';
      case PlayerRank.expert: return '💎';
      case PlayerRank.legend: return '👑';
    }
  }

  Color get color {
    switch (this) {
      case PlayerRank.blind: return const Color(0xFF9E9E9E);
      case PlayerRank.beginner: return const Color(0xFF66BB6A);
      case PlayerRank.curious: return const Color(0xFF26C6DA);
      case PlayerRank.detective: return const Color(0xFF5C9CE6);
      case PlayerRank.researcher: return const Color(0xFF9B59B6);
      case PlayerRank.expert: return const Color(0xFFFFB300);
      case PlayerRank.legend: return const Color(0xFFFF5252);
    }
  }

  int get minPoints {
    switch (this) {
      case PlayerRank.blind: return 0;
      case PlayerRank.beginner: return 50;
      case PlayerRank.curious: return 200;
      case PlayerRank.detective: return 500;
      case PlayerRank.researcher: return 1000;
      case PlayerRank.expert: return 2500;
      case PlayerRank.legend: return 5000;
    }
  }

  static PlayerRank fromPoints(int points) {
    if (points >= 5000) return PlayerRank.legend;
    if (points >= 2500) return PlayerRank.expert;
    if (points >= 1000) return PlayerRank.researcher;
    if (points >= 500) return PlayerRank.detective;
    if (points >= 200) return PlayerRank.curious;
    if (points >= 50) return PlayerRank.beginner;
    return PlayerRank.blind;
  }
}

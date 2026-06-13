import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/economy/coin_icon.dart';
import 'detective_toolbar.dart';

/// Opens the in-game tools sheet — a tidy bottom-sheet list of every
/// spend-to-help action (bomb / spotlight / targeted / fast-forward / hint /
/// reveal). Consolidating them here keeps the play screen uncluttered and the
/// board image large. Tapping a tool closes the sheet and runs it.
void showGameToolsSheet(BuildContext context, List<DetectiveAction> tools) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final bottom = MediaQuery.paddingOf(sheetCtx).bottom;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF0B1A2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('תחבולות',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ),
              for (final t in tools)
                _ToolRow(
                  action: t,
                  onRun: () {
                    if (Navigator.canPop(sheetCtx)) Navigator.of(sheetCtx).pop();
                    t.onTap();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ToolRow extends StatelessWidget {
  final DetectiveAction action;
  final VoidCallback onRun;

  const _ToolRow({required this.action, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final on = action.enabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: on
            ? () {
                HapticFeedback.lightImpact();
                onRun();
              }
            : null,
        child: Opacity(
          opacity: on ? 1 : 0.42,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF07101F).withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: action.color.withOpacity(on ? 0.45 : 0.16)),
            ),
            child: Row(
              children: [
                Text(action.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action.label,
                    style: TextStyle(
                      color: action.color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (action.price > 0) ...[
                  Text('${action.price}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: 4),
                  const CoinIcon(size: 14),
                ] else
                  const Text('חינם',
                      style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

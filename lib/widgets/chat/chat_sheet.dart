import 'package:flutter/material.dart';

import '../../models/chat_message.dart';

/// Bottom-sheet text chat: a live message feed, an optional quick emoji row, and
/// a free-text input. Pure widget (no Riverpod) — the caller wires the stream
/// and the send/react callbacks. Used both in-game and in the friends lobby.
class ChatSheet extends StatefulWidget {
  final Stream<List<ChatMessage>> stream;
  final String myUid;

  /// Quick emoji reactions. Pass an empty list to hide the row (e.g. in the
  /// lobby, where there's no board to animate reactions onto).
  final List<String> emojis;
  final void Function(String text) onSend;
  final void Function(String emoji) onReact;

  const ChatSheet({
    super.key,
    required this.stream,
    required this.myUid,
    this.emojis = const [],
    required this.onSend,
    this.onReact = _noop,
  });

  static void _noop(String _) {}

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Lift the sheet above the keyboard when open, otherwise above the system
    // navigation bar / gesture area (so the input + emoji row aren't hidden).
    final bottomInset =
        mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Color(0xFF0B1422),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('צ׳אט',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: widget.stream,
                builder: (context, snap) {
                  final msgs = snap.data ?? const <ChatMessage>[];
                  if (msgs.isEmpty) {
                    return const Center(
                      child: Text('אין הודעות עדיין · כתבו משהו!',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13)),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scroll.hasClients) {
                      _scroll.jumpTo(_scroll.position.maxScrollExtent);
                    }
                  });
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final mine = m.senderId == widget.myUid;
                      return Align(
                        alignment:
                            mine ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.7),
                          decoration: BoxDecoration(
                            color: mine
                                ? const Color(0xFF1E4D6B)
                                : const Color(0xFF18202E),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!mine)
                                Text(m.senderName,
                                    style: const TextStyle(
                                        color: Color(0xFF6BC6FF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              Text(m.text,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Quick emoji reactions (broadcast a floating emoji to the board).
            if (widget.emojis.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final e in widget.emojis)
                      GestureDetector(
                        onTap: () => widget.onReact(e),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textDirection: TextDirection.rtl,
                      maxLength: 120,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'כתבו הודעה…',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF18202E),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22D3EE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Color(0xFF06121F), size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single in-game text chat message, stored under `rooms/{id}/messages`.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final int ts;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.ts,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data) {
    return ChatMessage(
      id: id,
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      ts: (data['ts'] as num?)?.toInt() ?? 0,
    );
  }
}

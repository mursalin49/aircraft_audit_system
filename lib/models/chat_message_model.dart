class ChatMessage {
  final String id;
  final String senderName;
  final String? senderImage;
  final String message;
  final String time;
  final bool isUserMessage;

  ChatMessage({
    required this.id,
    required this.senderName,
    this.senderImage,
    required this.message,
    required this.time,
    required this.isUserMessage,
  });
}
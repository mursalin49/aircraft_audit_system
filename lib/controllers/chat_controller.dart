import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/chat_message_model.dart';

class ChatScreenController extends GetxController {
  final RxList<ChatMessage> messages = <ChatMessage>[
    ChatMessage(
      id: '1',
      senderName: 'John Smith',
      senderImage: 'assets/images/mursalin.jpg',
      message: 'Hey! How was the new design project coming along?',
      time: '10:30 AM',
      isUserMessage: false,
    ),
    ChatMessage(
      id: '2',
      senderName: 'You',
      message: 'It is going great! Just finishing the final screens.',
      time: '10:32 AM',
      isUserMessage: true,
    ),
  ].obs;

  final messageController = TextEditingController();

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    messages.add(
      ChatMessage(
        id: DateTime.now().toString(),
        senderName: 'You',
        message: text,
        time: TimeOfDay.now().format(Get.context!),
        isUserMessage: true,
      ),
    );

    messageController.clear();
  }

  @override
  void onClose() {
    messageController.dispose();
    super.onClose();
  }
}
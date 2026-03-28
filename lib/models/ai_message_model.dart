import 'package:flutter/material.dart';

enum MessageType { user, ai, system }

class AIMessageModel {
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? imagePath;
  final String? documentName;
  final bool isProcessing;

  AIMessageModel({
    required this.content,
    required this.type,
    required this.timestamp,
    this.imagePath,
    this.documentName,
    this.isProcessing = false,
  });

  factory AIMessageModel.user({
    required String content,
    String? imagePath,
    String? documentName,
  }) {
    return AIMessageModel(
      content: content,
      type: MessageType.user,
      timestamp: DateTime.now(),
      imagePath: imagePath,
      documentName: documentName,
    );
  }

  factory AIMessageModel.ai({
    required String content,
    bool isProcessing = false,
  }) {
    return AIMessageModel(
      content: content,
      type: MessageType.ai,
      timestamp: DateTime.now(),
      isProcessing: isProcessing,
    );
  }

  factory AIMessageModel.system(String content) {
    return AIMessageModel(
      content: content,
      type: MessageType.system,
      timestamp: DateTime.now(),
    );
  }

  Alignment get alignment {
    switch (type) {
      case MessageType.user:
        return Alignment.centerRight;
      case MessageType.ai:
      case MessageType.system:
        return Alignment.centerLeft;
    }
  }

  Color get bubbleColor {
    switch (type) {
      case MessageType.user:
        return const Color(0xFF6B4EFF); // Primary Purple
      case MessageType.ai:
        return const Color(0xFF2E3B4E); // Dark Blue-Grey
      case MessageType.system:
        return const Color(0xFF4CAF50); // Green
    }
  }

  String get senderName {
    switch (type) {
      case MessageType.user:
        return 'You';
      case MessageType.ai:
        return 'NaijaCampus AI';
      case MessageType.system:
        return 'System';
    }
  }
}
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_repository.dart';
import '../domain/ai_message.dart';

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  final List<AiMessage> messages;
  final bool isLoading;
  final String? error;

  AiChatState copyWith({
    List<AiMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  @override
  AiChatState build() {
    return AiChatState(
      messages: [
        AiMessage(
          id: 'welcome',
          text: 'Здравствуйте! Я ИИ-помощник Sabt CRM. Могу рассказать о статусе ваших задач, проектов, дедлайнах или подготовить сводку. Чем помочь?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  Future<void> sendUserMessage(String prompt) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) return;

    final userMsg = AiMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      text: cleanPrompt,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      final reply = await ref.read(aiRepositoryProvider).askAi(message: cleanPrompt);
      final aiMsg = AiMessage(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearHistory() {
    state = build();
  }
}

final aiChatProvider = NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);

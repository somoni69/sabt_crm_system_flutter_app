import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../domain/ai_message.dart';
import 'ai_providers.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  final _suggestions = const [
    'Что по моим задачам на сегодня?',
    'Какие проекты горят по дедлайнам?',
    'Подготовь сводку для руководства',
    'Кто больше всего загружен?',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? customText]) {
    final text = customText ?? _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    ref.read(aiChatProvider.notifier).sendUserMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);

    return AppPage(
      header: AppHeader(
        title: 'ИИ-помощник',
        subtitle: 'Умная аналитика и поиск по CRM',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            size: 40,
            onPressed: () => ref.read(aiChatProvider.notifier).clearHistory(),
          ),
        ],
      ),
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Suggestions horizontal bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: _suggestions.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _sendMessage(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentBright,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              // Messages list
              ...chatState.messages.map((m) => _ChatBubble(message: m)),

              if (chatState.isLoading) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'ИИ думает...',
                              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (chatState.error != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Ошибка: ${chatState.error}',
                    style: const TextStyle(fontSize: 12, color: AppColors.danger),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Input row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(color: AppColors.text, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Спросите что-нибудь у Sabt AI...',
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: AppColors.accentBright),
                      onPressed: () => _sendMessage(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.accent : AppColors.surface1,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser ? AppColors.accentBright : AppColors.borderSoft,
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isUser ? Colors.white : AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

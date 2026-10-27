import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../domain/ai_message.dart';
import 'ai_providers.dart';

/// AI assistant chat.
///
/// Messenger layout, like every native chat: the header is pinned at
/// the top, messages scroll in the middle, and the composer is glued
/// to the bottom (above the keyboard) via [AppPage.footer]. The input
/// previously lived at the end of the scrolling column, so with a
/// short history it floated mid-screen over an empty void.
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
    final text = (customText ?? _inputController.text).trim();
    if (text.isEmpty) return;
    _inputController.clear();
    ref.read(aiChatProvider.notifier).sendUserMessage(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Motion.duration(context, Motion.standard),
        curve: Motion.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);

    // Land on the newest message whenever the history grows (send,
    // reply, error state changes keep the same length — no scroll).
    ref.listen(aiChatProvider.select((s) => s.messages.length), (
      previous,
      next,
    ) {
      if (previous != null && next > previous) _scrollToBottom();
    });
    ref.listen(aiChatProvider.select((s) => s.isLoading), (previous, next) {
      if (next) _scrollToBottom();
    });

    return AppPage(
      controller: _scrollController,
      showBottomBarSpace: false,
      bottomPadding: MediaQuery.paddingOf(context).bottom + 78,
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
      footer: _ChatComposer(
        controller: _inputController,
        loading: chatState.isLoading,
        onSend: () => _sendMessage(),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: context.palette.surface2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: context.palette.borderSoft,
                            ),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.palette.accentBright,
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

              if (chatState.isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.palette.surface1,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.palette.borderSoft),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.palette.accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ИИ думает...',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.palette.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (chatState.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Ошибка: ${chatState.error}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.palette.danger,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The pinned bottom composer: a solid bar with a hairline top edge,
/// a growing multiline field, and a circular send button that wakes
/// up only when there is something to send.
class _ChatComposer extends StatefulWidget {
  const _ChatComposer({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canSend = widget.controller.text.trim().isNotEmpty && !widget.loading;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface1,
        border: Border(top: BorderSide(color: palette.borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.surface2,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: palette.border),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(color: palette.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Спросите что-нибудь у Sabt AI...',
                      hintStyle: TextStyle(
                        color: palette.textTertiary,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (canSend) widget.onSend();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Отправить',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canSend
                      ? () {
                          HapticFeedback.lightImpact();
                          widget.onSend();
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: Motion.duration(context, Motion.micro),
                    curve: Motion.easeOut,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: canSend
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF7A63E0),
                                palette.brandPurple,
                              ],
                            )
                          : null,
                      color: canSend ? null : palette.surface3,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: canSend ? Colors.white : palette.textDisabled,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: context.palette.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? context.palette.accent
                    : context.palette.surface1,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? context.palette.accentBright
                      : context.palette.borderSoft,
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isUser ? Colors.white : context.palette.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

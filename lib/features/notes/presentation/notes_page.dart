import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';
import 'notes_providers.dart';

class MyNotesPage extends ConsumerStatefulWidget {
  const MyNotesPage({super.key});

  @override
  ConsumerState<MyNotesPage> createState() => _MyNotesPageState();
}

class _MyNotesPageState extends ConsumerState<MyNotesPage> {
  void _openCreateSheet(BuildContext context) {
    showGlassSheet<void>(
      context: context,
      title: 'Новая заметка',
      child: _CreateNoteSheet(
        onCreated: (text, date) async {
          Navigator.pop(context);
          try {
            await ref.read(notesRepositoryProvider).createNote(text: text, date: date);
            ref.read(dataRevisionProvider.notifier).bump();
            if (mounted) {
              ref.read(dependenciesProvider).banners.show(const AppBanner(
                    title: 'Заметка сохранена',
                    message: 'Личная задача добавлена в список.',
                    tone: BannerTone.success,
                  ));
            }
          } catch (e) {
            if (mounted) {
              ref.read(dependenciesProvider).banners.show(AppBanner(
                    title: 'Ошибка сохранения',
                    message: e.toString(),
                    tone: BannerTone.danger,
                  ));
            }
          }
        },
      ),
    );
  }

  Future<void> _toggleDone(Note note) async {
    try {
      await ref.read(notesRepositoryProvider).updateNote(
            id: note.id,
            done: !note.done,
          );
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (_) {}
  }

  Future<void> _deleteNote(Note note) async {
    try {
      await ref.read(notesRepositoryProvider).deleteNote(note.id);
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(myNotesProvider);
    final selectedDate = ref.watch(selectedNoteDateProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return AppPage(
      header: AppHeader(
        title: 'Мои заметки',
        subtitle: 'Личные задачи и напоминания',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.add_rounded,
            size: 40,
            onPressed: () => _openCreateSheet(context),
          ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(myNotesProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Все',
                      selected: selectedDate == null,
                      onTap: () => ref.read(selectedNoteDateProvider.notifier).setDate(null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Сегодня',
                      selected: selectedDate == todayStr,
                      onTap: () => ref.read(selectedNoteDateProvider.notifier).setDate(todayStr),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'С дедлайном',
                      selected: selectedDate == 'has_date',
                      onTap: () => ref.read(selectedNoteDateProvider.notifier).setDate('has_date'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              notesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить заметки',
                  message: error.toString(),
                  actionLabel: 'Повторить',
                  onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (notes) {
                  final filtered = notes.where((n) {
                    if (selectedDate == null) return true;
                    if (selectedDate == 'has_date') return n.date != null;
                    return n.date == selectedDate;
                  }).toList();

                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.edit_note_rounded,
                      title: 'Заметок пока нет',
                      message: 'Создавайте быстрые личные задачи и напоминания.',
                      actionLabel: 'Добавить заметку',
                      onAction: () => _openCreateSheet(context),
                    );
                  }

                  return Column(
                    children: filtered.map((note) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: note.done ? AppColors.borderSoft : AppColors.border,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _toggleDone(note),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  margin: const EdgeInsets.only(top: 2, right: 12),
                                  decoration: BoxDecoration(
                                    color: note.done ? AppColors.success : AppColors.surface2,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: note.done ? AppColors.success : AppColors.border,
                                    ),
                                  ),
                                  child: note.done
                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                      : null,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note.text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        decoration: note.done ? TextDecoration.lineThrough : null,
                                        color: note.done ? AppColors.textTertiary : AppColors.text,
                                      ),
                                    ),
                                    if (note.date != null) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today_rounded,
                                              size: 12,
                                              color: note.date == todayStr
                                                  ? AppColors.warning
                                                  : AppColors.textTertiary),
                                          const SizedBox(width: 4),
                                          Text(
                                            note.date!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: note.date == todayStr
                                                  ? AppColors.warning
                                                  : AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: AppColors.textTertiary),
                                onPressed: () => _deleteNote(note),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accentBright : AppColors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CreateNoteSheet extends StatefulWidget {
  const _CreateNoteSheet({required this.onCreated});

  final void Function(String text, String? date) onCreated;

  @override
  State<_CreateNoteSheet> createState() => _CreateNoteSheetState();
}

class _CreateNoteSheetState extends State<_CreateNoteSheet> {
  final _controller = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Что нужно сделать или запомнить?',
              hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderSoft),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.event_rounded, size: 16),
                label: Text(
                  _selectedDate == null
                      ? 'Указать дату'
                      : DateFormat('dd.MM.yyyy').format(_selectedDate!),
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _selectedDate == null ? AppColors.textSecondary : AppColors.accentBright,
                  side: BorderSide(
                    color: _selectedDate == null ? AppColors.border : AppColors.accent,
                  ),
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? now,
                    firstDate: now.subtract(const Duration(days: 30)),
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              if (_selectedDate != null) ...[
                IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: AppColors.textTertiary),
                  onPressed: () => setState(() => _selectedDate = null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Сохранить',
            variant: AppButtonVariant.primary,
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isEmpty) return;
              final dateStr = _selectedDate == null ? null : DateFormat('yyyy-MM-dd').format(_selectedDate!);
              widget.onCreated(text, dateStr);
            },
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class SmartWidgetScreen extends StatelessWidget {
  const SmartWidgetScreen({super.key});

  static const routeName = '/smart-widget';

  Future<void> _syncNow(BuildContext context) async {
    final controller = TodoAppScope.of(context);
    await controller.refreshSmartWidget();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Home-screen widget synced with your latest tasks.'),
        ),
      );
  }

  Future<void> _pinWidget(BuildContext context) async {
    final controller = TodoAppScope.of(context);
    await controller.pinSmartWidget();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Choose where to place the ToDoUp widget.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final controller = TodoAppScope.of(context);
    final previewTasks = _previewTasks(controller.tasks);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              title: 'Smart Widgets',
              subtitle: 'Daily score, focus list, and live reminders',
              leading: _SmartWidgetBackButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Text(
                                '${controller.productivityScore.round()}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily score widget',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(controller.completionRate * 100).round()}% complete - ${controller.pendingTasks} pending',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withValues(alpha: 0.65),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF134E4A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ToDoUp',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    letterSpacing: 0.3,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${controller.productivityScore.round()}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'daily score',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ...previewTasks.map(
                              (task) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _WidgetPreviewTask(task: task),
                              ),
                            ),
                            if (previewTasks.isEmpty)
                              Text(
                                'Your next focus items will appear here after sync.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notifications_active_rounded),
                        title: const Text('Reminder notifications'),
                        subtitle: Text(
                          controller.notificationsEnabled
                              ? 'Enabled. Tasks with reminders will schedule local alerts.'
                              : 'Currently off. Enable notifications in Settings first.',
                        ),
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.watch_later_outlined),
                        title: Text('Reminder behavior'),
                        subtitle: Text(
                          'One-time reminders fire at the task time. Daily, weekly, monthly, and yearly repeats reschedule automatically.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add the widget',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _installationCopy,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.70),
                        ),
                      ),
                      const SizedBox(height: 18),
                      PrimaryGradientButton(
                        label: 'Sync Widget Now',
                        icon: Icons.sync_rounded,
                        onPressed: () => _syncNow(context),
                      ),
                      if (!kIsWeb && Platform.isAndroid) ...[
                        const SizedBox(height: 12),
                        FutureBuilder<bool>(
                          future: controller.canPinSmartWidget(),
                          builder: (context, snapshot) {
                            final canPin = snapshot.data == true;
                            return MutedButton(
                              label: canPin
                                  ? 'Pin To Home Screen'
                                  : 'Open Widget Picker',
                              onPressed: canPin
                                  ? () => _pinWidget(context)
                                  : () => _showManualPinHelp(context),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<TaskItem> _previewTasks(List<TaskItem> tasks) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final tomorrowOnly = todayOnly.add(const Duration(days: 1));

    final todayItems = tasks
        .where(
          (task) =>
              !task.completed &&
              !task.dueDate.isBefore(todayOnly) &&
              task.dueDate.isBefore(tomorrowOnly),
        )
        .take(3)
        .toList(growable: false);
    if (todayItems.isNotEmpty) {
      return todayItems;
    }

    return tasks
        .where((task) => !task.completed)
        .take(3)
        .toList(growable: false);
  }

  String get _installationCopy {
    if (!kIsWeb && Platform.isIOS) {
      return 'On iPhone, long-press the Home Screen, tap Edit, choose Add Widget, and select ToDoUp. The widget reads your synced daily score and focus tasks.';
    }
    return 'On Android, long-press the Home Screen and open Widgets to add ToDoUp. If pinning is supported on your launcher, you can place it directly from this screen.';
  }

  void _showManualPinHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add widget manually'),
          content: const Text(
            'Long-press an empty area on the Home Screen, open Widgets, then drag ToDoUp to the spot you want.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _SmartWidgetBackButton extends StatelessWidget {
  const _SmartWidgetBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
    );
  }
}

class _WidgetPreviewTask extends StatelessWidget {
  const _WidgetPreviewTask({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _categoryIcon(task.category),
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                task.dueTime == null
                    ? task.dueLabel
                    : '${task.dueLabel} - ${formatTimeOfDayLabel(task.dueTime!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _categoryIcon(TaskCategory category) {
    switch (category) {
      case TaskCategory.work:
        return Icons.work_outline_rounded;
      case TaskCategory.personal:
        return Icons.favorite_border_rounded;
      case TaskCategory.health:
        return Icons.fitness_center_rounded;
      case TaskCategory.study:
        return Icons.menu_book_rounded;
      case TaskCategory.shopping:
        return Icons.shopping_bag_outlined;
      case TaskCategory.others:
        return Icons.task_alt_rounded;
    }
  }
}

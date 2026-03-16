import 'package:flutter/material.dart';

import 'models.dart';
import 'settings_screens.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  static const routeName = '/app';
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeTab(),
      const ActivityTab(),
      const AnalyticsTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (value) => setState(() => _currentIndex = value),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<void> _showAddTask(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTaskSheet(),
    );
  }

  Future<void> _showAssistant(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiAssistantPanel(),
    );
  }

  Future<void> _showTaskDetails(BuildContext context, TaskItem task) {
    final controller = TodoAppScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailsSheet(
        task: task,
        attachments: controller.attachmentsForTask(task.id),
      ),
    );
  }

  Future<bool> _confirmDeleteTask(BuildContext context, TaskItem task) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete task?'),
              content: Text(
                'This will permanently remove "${task.title}" from your task list.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.destructive,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = TodoAppScope.of(context);
    final tasks = controller.tasks;
    final completed = controller.completedTasks;
    final total = tasks.length;

    return Stack(
      children: [
        if (!controller.isOnline || controller.hasPendingSync || controller.isSyncing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _OfflineBanner(
                  isOnline: controller.isOnline,
                  isSyncing: controller.isSyncing,
                  hasPending: controller.hasPendingSync,
                ),
              ),
            ),
          ),
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: controller.refreshDashboard,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: GradientHeader(
                  title: total == 0 ? 'Plan your day' : 'Good Morning!',
                  subtitle: formatFullDate(DateTime.now()),
                  trailing: _HomeRefreshButton(
                    isLoading: controller.isLoading,
                    onTap: controller.isLoading
                        ? null
                        : () => controller.refreshDashboard(),
                  ),
                  bottomSpacing: 40,
                  child: Column(
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Today's Progress",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color
                                                  ?.withValues(alpha: 0.60),
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$completed/$total',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${(controller.completionRate * 100).round()}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 10,
                                value: controller.completionRate,
                                backgroundColor:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.mutedDark
                                    : AppColors.mutedLight,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (controller.error != null) ...[
                        const SizedBox(height: 16),
                        _DashboardNoticeCard(
                          icon: Icons.cloud_off_rounded,
                          title: 'Sync issue',
                          message: controller.error!,
                          actionLabel: 'Retry',
                          onAction: controller.refreshDashboard,
                        ),
                      ],
                      if (!controller.isLoading && tasks.isEmpty) ...[
                        const SizedBox(height: 16),
                        _DashboardEmptyState(
                          onAddTaskTap: () => _showAddTask(context),
                          onAssistantTap: () => _showAssistant(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (controller.isLoading && tasks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 120),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 14),
                          Text('Syncing your dashboard...'),
                        ],
                      ),
                    ),
                  ),
                )
              else if (tasks.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 112),
                  sliver: SliverList.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Dismissible(
                        key: ValueKey('task-${task.id}'),
                        direction: DismissDirection.endToStart,
                        background: const _DeleteTaskBackground(),
                        confirmDismiss: (_) =>
                            _confirmDeleteTask(context, task),
                        onDismissed: (_) => controller.deleteTask(task.id),
                        child: TaskCard(
                          task: task,
                          onToggle: () => controller.toggleTask(task.id),
                          attachments: controller.attachmentsForTask(task.id),
                          onTap: () => _showTaskDetails(context, task),
                        ),
                      );
                    },
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
        if (controller.isLoading && tasks.isNotEmpty)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primary,
            ),
          ),
        _HomeActionButtons(
          onAssistantTap: () => _showAssistant(context),
          onAddTaskTap: () => _showAddTask(context),
        ),
      ],
    );
  }
}

class _HomeRefreshButton extends StatelessWidget {
  const _HomeRefreshButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

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
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _DashboardNoticeCard extends StatelessWidget {
  const _DashboardNoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.70),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            PrimaryGradientButton(
              label: actionLabel!,
              expanded: false,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({
    required this.onAddTaskTap,
    required this.onAssistantTap,
  });

  final VoidCallback onAddTaskTap;
  final VoidCallback onAssistantTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.checklist_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No tasks yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your first task or let the assistant draft one for you.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              PrimaryGradientButton(
                label: 'Add Task',
                expanded: false,
                icon: Icons.add_rounded,
                onPressed: onAddTaskTap,
              ),
              MutedButton(label: 'Ask Assistant', onPressed: onAssistantTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteTaskBackground extends StatelessWidget {
  const _DeleteTaskBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.16),
        borderRadius: AppTheme.cardRadius,
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(Icons.delete_outline_rounded, color: AppColors.destructive),
          SizedBox(height: 6),
          Text(
            'Delete',
            style: TextStyle(
              color: AppColors.destructive,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionButtons extends StatelessWidget {
  const _HomeActionButtons({
    required this.onAssistantTap,
    required this.onAddTaskTap,
  });

  final VoidCallback onAssistantTap;
  final VoidCallback onAddTaskTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalInset = screenWidth < 360 ? 14.0 : 18.0;
    final bottomInset = screenWidth < 360 ? 8.0 : 12.0;
    final assistantSize = screenWidth < 360 ? 60.0 : 64.0;
    final addSize = screenWidth < 360 ? 52.0 : 56.0;

    return Positioned(
      left: horizontalInset,
      right: horizontalInset,
      bottom: bottomInset,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _GradientActionButton(
            icon: Icons.auto_awesome_rounded,
            size: assistantSize,
            iconSize: 30,
            shadowAlpha: 0.36,
            onTap: onAssistantTap,
          ),
          _GradientActionButton(
            icon: Icons.add_rounded,
            size: addSize,
            iconSize: 26,
            shadowAlpha: 0.22,
            onTap: onAddTaskTap,
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({
    required this.isOnline,
    required this.isSyncing,
    required this.hasPending,
  });

  final bool isOnline;
  final bool isSyncing;
  final bool hasPending;

  @override
  Widget build(BuildContext context) {
    final bg = isOnline
        ? const Color(0xFF0EA5E9).withValues(alpha: 0.12)
        : const Color(0xFFF59E0B).withValues(alpha: 0.16);
    final text = isOnline
        ? 'Syncing drafts to Supabase...'
        : 'Offline mode • tasks are saved locally';
    final pendingLabel = isSyncing
        ? 'Syncing now'
        : hasPending
            ? 'Waiting for connection'
            : 'Up to date';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOnline
              ? const Color(0xFF0EA5E9).withValues(alpha: 0.38)
              : const Color(0xFFF59E0B).withValues(alpha: 0.48),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.32),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isOnline ? Icons.cloud_sync_rounded : Icons.wifi_off_rounded,
                      color: Colors.black87,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  pendingLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.70),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.shadowAlpha,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final double shadowAlpha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: shadowAlpha),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final controller = TodoAppScope.of(context);
    final heatmap = _buildHeatmapData(controller.tasks);
    final weeklyActivity = _buildWeeklyActivity(controller.tasks);
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: GradientHeader(
            title: 'Activity',
            subtitle: 'Track your productivity journey',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFB923C), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Streak',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.60),
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${controller.currentStreak} ${controller.currentStreak == 1 ? 'Day' : 'Days'}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'This Week',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ...List.generate(_days.length, (index) {
                      final value = weeklyActivity[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                _days[index],
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 10,
                                  value: (value / 20).clamp(0.0, 1.0),
                                  backgroundColor:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.mutedDark
                                      : AppColors.mutedLight,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 24,
                              child: Text(
                                '$value',
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Monthly Activity',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      itemCount: heatmap.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemBuilder: (context, index) {
                        final intensity = heatmap[index];
                        final color = intensity > 0.7
                            ? const Color(0xFF22C55E)
                            : intensity > 0.4
                            ? const Color(0xFF4ADE80)
                            : intensity > 0.2
                            ? const Color(0xFF86EFAC)
                            : Theme.of(context).brightness == Brightness.dark
                            ? AppColors.mutedDark
                            : AppColors.mutedLight;
                        return Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Total Tasks',
                      value: '${controller.totalTasks}',
                      icon: Icons.assignment_turned_in_rounded,
                      tint: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      label: 'Completed',
                      value: '${controller.completedTasks}',
                      icon: Icons.check_circle_outline_rounded,
                      tint: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  static const _weeklyLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _productivityLabels = [
    '6AM',
    '9AM',
    '12PM',
    '3PM',
    '6PM',
    '9PM',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = TodoAppScope.of(context);
    final weeklyValues = _buildWeeklyActivity(
      controller.tasks,
    ).map((value) => value.toDouble()).toList(growable: false);
    final productivityPoints = _buildProductivityCurve(controller.tasks);
    final categories = _buildCategoryDistribution(controller.tasks);

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: GradientHeader(
            title: 'Analytics',
            subtitle: 'Insights into your productivity',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Completion Rate',
                      value: '${(controller.completionRate * 100).round()}%',
                      icon: Icons.track_changes_rounded,
                      tint: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      label: 'Avg Daily',
                      value: controller.averageDailyTasks.toStringAsFixed(1),
                      icon: Icons.trending_up_rounded,
                      tint: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bar_chart_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Weekly Completion',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    WeeklyBarChart(values: weeklyValues, labels: _weeklyLabels),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.show_chart_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Productivity',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ProductivityLineChart(
                      points: productivityPoints,
                      labels: _productivityLabels,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.pie_chart_outline_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Task Categories',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    CategoryDonutChart(values: categories),
                    const SizedBox(height: 12),
                    ...categories.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: item.category.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(item.category.label),
                            const Spacer(),
                            Text(
                              '${item.value.toInt()}%',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TodoAppScope.of(context);
    final profile = controller.profile;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: GradientHeader(
            title: 'Profile',
            bottomSpacing: 56,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CircleIconButton(
                  icon: Icons.edit_rounded,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(ProfileEditScreen.routeName),
                ),
                const SizedBox(width: 10),
                _CircleIconButton(
                  icon: Icons.settings_rounded,
                  onTap: () =>
                      Navigator.of(context).pushNamed(SettingsScreen.routeName),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Total Tasks',
                      value: '${controller.totalTasks}',
                      icon: Icons.track_changes_rounded,
                      tint: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Streak Days',
                      value: '${controller.currentStreak}',
                      icon: Icons.emoji_events_outlined,
                      tint: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Success Rate',
                      value: '${(controller.completionRate * 100).round()}%',
                      icon: Icons.trending_up_rounded,
                      tint: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Productivity Score',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${controller.productivityScore.round()}',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: controller.productivityScore / 100,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? AppColors.mutedDark
                            : AppColors.mutedLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "You're doing great. Keep up the momentum.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Recent Achievements'),
                    SizedBox(height: 14),
                    _AchievementTile(
                      icon: Icons.emoji_events_outlined,
                      title: 'First Week Complete',
                      subtitle: 'Completed 7 days',
                    ),
                    SizedBox(height: 10),
                    _AchievementTile(
                      icon: Icons.bolt_rounded,
                      title: 'Speed Demon',
                      subtitle: 'Finished 10 tasks in one day',
                    ),
                    SizedBox(height: 10),
                    _AchievementTile(
                      icon: Icons.gps_fixed_rounded,
                      title: 'Perfect Week',
                      subtitle: '100% completion rate',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.isDarkMode,
                      onChanged: (_) => controller.toggleTheme(),
                      title: const Text('Dark Mode'),
                      secondary: Icon(
                        controller.isDarkMode
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.settings_rounded),
                      title: const Text('All Settings'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(SettingsScreen.routeName),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

List<int> _buildWeeklyActivity(List<TaskItem> tasks) {
  final today = DateUtils.dateOnly(DateTime.now());
  final values = List<int>.filled(7, 0);

  for (final task in tasks) {
    final sourceDate = task.completedAt ?? task.dueDate;
    final date = DateUtils.dateOnly(sourceDate);
    final difference = today.difference(date).inDays;
    if (difference >= 0 && difference < 7) {
      values[6 - difference] += 1;
    }
  }

  return values;
}

List<double> _buildHeatmapData(List<TaskItem> tasks) {
  final today = DateUtils.dateOnly(DateTime.now());
  final counts = List<int>.filled(28, 0);

  for (final task in tasks) {
    final sourceDate = task.completedAt ?? task.dueDate;
    final date = DateUtils.dateOnly(sourceDate);
    final difference = today.difference(date).inDays;
    if (difference >= 0 && difference < 28) {
      counts[27 - difference] += 1;
    }
  }

  final maxCount = counts.fold<int>(0, (current, item) {
    return item > current ? item : current;
  });
  if (maxCount == 0) {
    return List<double>.generate(
      28,
      (index) => 0.08 + ((index % 4) * 0.06),
      growable: false,
    );
  }

  return counts
      .map((item) => item == 0 ? 0.06 : item / maxCount)
      .toList(growable: false);
}

List<double> _buildProductivityCurve(List<TaskItem> tasks) {
  final values = List<double>.filled(6, 0);

  for (final task in tasks) {
    final hour = task.dueTime?.hour ?? 9;
    if (hour < 9) {
      values[0] += 1;
    } else if (hour < 12) {
      values[1] += 1;
    } else if (hour < 15) {
      values[2] += 1;
    } else if (hour < 18) {
      values[3] += 1;
    } else if (hour < 21) {
      values[4] += 1;
    } else {
      values[5] += 1;
    }
  }

  return values;
}

List<({TaskCategory category, double value})> _buildCategoryDistribution(
  List<TaskItem> tasks,
) {
  final categories = [
    TaskCategory.work,
    TaskCategory.personal,
    TaskCategory.shopping,
    TaskCategory.others,
  ];

  if (tasks.isEmpty) {
    return categories
        .map((category) => (category: category, value: 0.0))
        .toList(growable: false);
  }

  final total = tasks.length;
  return categories
      .map((category) {
        final count = tasks.where((task) => task.category == category).length;
        return (category: category, value: (count / total) * 100);
      })
      .toList(growable: false);
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
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
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.mutedDark.withValues(alpha: 0.40)
            : AppColors.mutedLight.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(
          alpha: isDark ? 0.88 : 0.90,
        ),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.cardRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 84});

  final double size;
  static const _assetPath = 'assets/branding/logo.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.16),
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return Icon(
              Icons.task_alt_rounded,
              color: Colors.white,
              size: size * 0.52,
            );
          },
        ),
      ),
    );
  }
}

class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.bottomSpacing = 48,
    this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final double bottomSpacing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomSpacing),
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 16)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (child != null) ...[const SizedBox(height: 24), child!],
          ],
        ),
      ),
    );
  }
}

class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.45),
                  AppColors.primaryLight.withValues(alpha: 0.45),
                ],
              )
            : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class MutedButton extends StatelessWidget {
  const MutedButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
        ),
      ),
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<({IconData icon, String label})> _items = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.insights_rounded, label: 'Activity'),
    (icon: Icons.bar_chart_rounded, label: 'Analytics'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.surfaceDark : Colors.white).withValues(
            alpha: 0.92,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final active = index == currentIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          item.icon,
                          size: 24,
                          color: active
                              ? AppColors.primary
                              : Theme.of(context).textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: active
                              ? AppColors.primary
                              : Theme.of(context).textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.60),
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tint),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.attachments,
    this.onTap,
  });

  final TaskItem task;
  final VoidCallback onToggle;
  final List<TaskAttachment> attachments;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subdued = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60);

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.drag_indicator_rounded, size: 18, color: subdued),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: task.completed ? AppColors.primaryGradient : null,
                border: Border.all(
                  color: task.completed
                      ? Colors.transparent
                      : subdued?.withValues(alpha: 0.45) ?? Colors.grey,
                  width: 2,
                ),
              ),
              child: task.completed
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: task.completed ? subdued : null,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: task.priority.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                if (task.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: subdued),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaChip(
                      icon: Icons.calendar_today_rounded,
                      label: task.dueLabel,
                    ),
                    Icon(
                      Icons.flag_rounded,
                      size: 14,
                      color: task.priority.color,
                    ),
                    _CategoryChip(category: task.category),
                    if (task.reminder)
                      const Icon(
                        Icons.notifications_active_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    if (task.subtasks.isNotEmpty)
                      Text(
                        '${task.completedSubtasks}/${task.subtasks.length} subtasks',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: subdued,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (attachments.isNotEmpty)
                      _MetaChip(
                        icon: Icons.attach_file_rounded,
                        label:
                            '${attachments.length} attachment${attachments.length == 1 ? '' : 's'}',
                      ),
                  ],
                ),
                if (task.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: task.completedSubtasks / task.subtasks.length,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? AppColors.mutedDark
                          : AppColors.mutedLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final TaskCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: category.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_outlined, size: 12, color: category.color),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: category.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subtaskController = TextEditingController();
  DateTime _dueDate = DateTime.now();
  TimeOfDay _dueTime = const TimeOfDay(hour: 9, minute: 0);
  TaskPriority _priority = TaskPriority.medium;
  TaskCategory _category = TaskCategory.work;
  bool _reminder = false;
  String _repeat = 'None';
  bool _showSubtasks = false;
  bool _isSubmitting = false;
  String? _selectedTemplateId;
  final List<String> _subtasks = [];
  final List<PendingTaskAttachment> _attachments = [];

  static const _repeatOptions = [
    'None',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (result != null) {
      setState(() => _dueDate = result);
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (result != null) {
      setState(() => _dueTime = result);
    }
  }

  void _appendSubtask() {
    final value = _subtaskController.text.trim();
    if (value.isEmpty) {
      return;
    }
    setState(() {
      _subtasks.add(value);
      _subtaskController.clear();
    });
  }

  void _applyTemplate(TaskTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _titleController.text = template.title;
      _descriptionController.text = template.description ?? '';
      _priority = template.priority;
      _category = template.category;
      _reminder = template.reminder;
      _repeat = template.repeat;
      _showSubtasks = template.subtasks.isNotEmpty;
      _subtasks
        ..clear()
        ..addAll(template.subtasks);
    });
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (!mounted || result == null) {
      return;
    }

    final pickedAttachments = result.files
        .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
        .map(
          (file) => PendingTaskAttachment(
            fileName: file.name,
            bytes: file.bytes!,
            mimeType: _inferMimeType(file),
            sizeBytes: file.size,
          ),
        )
        .toList(growable: false);

    if (pickedAttachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to read the selected files on this device.'),
        ),
      );
      return;
    }

    setState(() {
      _attachments.addAll(pickedAttachments);
    });
  }

  String _inferMimeType(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _createTask() async {
    if (_titleController.text.trim().isEmpty || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    final created = await TodoAppScope.of(context).addTask(
      title: _titleController.text,
      description: _descriptionController.text,
      dueDate: _dueDate,
      dueTime: _dueTime,
      priority: _priority,
      category: _category,
      reminder: _reminder,
      repeat: _repeat,
      subtasks: _subtasks,
      attachments: _attachments,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);
    if (created) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = TodoAppScope.of(context);
    final templates = controller.templates;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final subdued = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60);

    return StatefulBuilder(
      builder: (context, setModalState) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 760),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 5,
                          margin: const EdgeInsets.only(right: 18),
                          decoration: BoxDecoration(
                            color: subdued?.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Text(
                          'Create New Task',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (templates.isNotEmpty) ...[
                            const _SectionLabel(
                              icon: Icons.auto_awesome_rounded,
                              title: 'Templates',
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: templates
                                    .map((template) {
                                      final selected =
                                          _selectedTemplateId == template.id;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        child: _ChoicePill(
                                          label: template.title,
                                          color: template.category.color,
                                          selected: selected,
                                          onTap: () => _applyTemplate(template),
                                        ),
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          TextField(
                            controller: _titleController,
                            onChanged: (_) => setModalState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Task Name *',
                              hintText: 'What needs to be done?',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              hintText: 'Add context, notes, or task details',
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _SectionLabel(
                            icon: Icons.attach_file_rounded,
                            title: 'Attachments',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: MutedButton(
                                  label: 'Add Files',
                                  onPressed: _isSubmitting
                                      ? () {}
                                      : _pickAttachments,
                                ),
                              ),
                              if (_attachments.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Text(
                                  '${_attachments.length} file${_attachments.length == 1 ? '' : 's'} selected',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: subdued),
                                ),
                              ],
                            ],
                          ),
                          if (_attachments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ...List.generate(_attachments.length, (index) {
                              final attachment = _attachments[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.mutedDark.withValues(
                                          alpha: 0.40,
                                        )
                                      : AppColors.mutedLight.withValues(
                                          alpha: 0.80,
                                        ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.insert_drive_file_outlined,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            attachment.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            formatFileSizeLabel(
                                              attachment.sizeBytes,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: subdued),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => setState(
                                              () =>
                                                  _attachments.removeAt(index),
                                            ),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.destructive,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: _PickerTile(
                                  icon: Icons.calendar_today_rounded,
                                  label: 'Due Date',
                                  value: relativeDueLabel(_dueDate),
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PickerTile(
                                  icon: Icons.schedule_rounded,
                                  label: 'Time',
                                  value: formatTimeOfDayLabel(_dueTime),
                                  onTap: _pickTime,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const _SectionLabel(
                            icon: Icons.flag_rounded,
                            title: 'Priority',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: TaskPriority.values.map((priority) {
                              final selected = priority == _priority;
                              return _ChoicePill(
                                label: priority.label,
                                color: priority.color,
                                selected: selected,
                                onTap: () =>
                                    setState(() => _priority = priority),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          const _SectionLabel(
                            icon: Icons.local_offer_outlined,
                            title: 'Category',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: TaskCategory.values.map((category) {
                              return _ChoicePill(
                                label: category.label,
                                color: category.color,
                                selected: category == _category,
                                onTap: () =>
                                    setState(() => _category = category),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _ToggleTile(
                                  title: 'Reminder',
                                  icon: Icons.notifications_active_rounded,
                                  selected: _reminder,
                                  label: _reminder ? 'On' : 'Off',
                                  onTap: () =>
                                      setState(() => _reminder = !_reminder),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(_repeat),
                                  initialValue: _repeat,
                                  decoration: const InputDecoration(
                                    labelText: 'Repeat',
                                    prefixIcon: Icon(Icons.repeat_rounded),
                                  ),
                                  items: _repeatOptions
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _repeat = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _showSubtasks = !_showSubtasks),
                            icon: Icon(
                              _showSubtasks
                                  ? Icons.expand_less
                                  : Icons.add_rounded,
                              color: AppColors.primary,
                            ),
                            label: Text(
                              _showSubtasks ? 'Hide Subtasks' : 'Add Subtasks',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_showSubtasks) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _subtaskController,
                                    decoration: const InputDecoration(
                                      hintText: 'Add a subtask...',
                                    ),
                                    onSubmitted: (_) {
                                      _appendSubtask();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                PrimaryGradientButton(
                                  label: '',
                                  onPressed: () {
                                    _appendSubtask();
                                  },
                                  icon: Icons.add_rounded,
                                  expanded: false,
                                ),
                              ],
                            ),
                            if (_subtasks.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              ...List.generate(_subtasks.length, (index) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.mutedDark.withValues(
                                            alpha: 0.40,
                                          )
                                        : AppColors.mutedLight.withValues(
                                            alpha: 0.80,
                                          ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(_subtasks[index])),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => setState(
                                          () => _subtasks.removeAt(index),
                                        ),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: AppColors.destructive,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: MutedButton(
                            label: 'Cancel',
                            onPressed: _isSubmitting
                                ? () {}
                                : () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryGradientButton(
                            label: _isSubmitting
                                ? 'Creating...'
                                : 'Create Task',
                            onPressed:
                                _titleController.text.trim().isEmpty ||
                                    _isSubmitting
                                ? null
                                : _createTask,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TaskDetailsSheet extends StatelessWidget {
  const TaskDetailsSheet({
    super.key,
    required this.task,
    required this.attachments,
  });

  final TaskItem task;
  final List<TaskAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    final subdued = Theme.of(
      context,
    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60);

    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          icon: Icons.calendar_today_rounded,
                          label: task.dueLabel,
                        ),
                        _CategoryChip(category: task.category),
                        _MetaChip(
                          icon: Icons.flag_rounded,
                          label: task.priority.label,
                        ),
                        if (task.reminder)
                          const _MetaChip(
                            icon: Icons.notifications_active_rounded,
                            label: 'Reminder on',
                          ),
                      ],
                    ),
                    if (task.description != null &&
                        task.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _SectionLabel(
                        icon: Icons.notes_rounded,
                        title: 'Notes',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        task.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (task.subtasks.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _SectionLabel(
                        icon: Icons.checklist_rounded,
                        title: 'Subtasks',
                      ),
                      const SizedBox(height: 10),
                      ...task.subtasks.map(
                        (subtask) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.circle,
                                size: 8,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(subtask)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const _SectionLabel(
                      icon: Icons.attach_file_rounded,
                      title: 'Attachments',
                    ),
                    const SizedBox(height: 10),
                    if (attachments.isEmpty)
                      Text(
                        'No attachments on this task.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: subdued),
                      )
                    else
                      ...attachments.map(
                        (attachment) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.mutedDark.withValues(alpha: 0.40)
                                : AppColors.mutedLight.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.insert_drive_file_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attachment.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatFileSizeLabel(attachment.sizeBytes),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: subdued),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? color
                : Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.16) ??
                      Colors.grey,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: InputDecorator(
        decoration: InputDecoration(labelText: title, prefixIcon: Icon(icon)),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? AppColors.primary : null,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class AiAssistantPanel extends StatefulWidget {
  const AiAssistantPanel({super.key});

  @override
  State<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends State<AiAssistantPanel> {
  static const _suggestions = [
    'Add gym tomorrow at 7pm',
    'Meeting with team',
    'Buy groceries',
    'Study for exam',
  ];

  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final prompt = _inputController.text;
    if (prompt.trim().isEmpty) {
      return;
    }
    TodoAppScope.of(context).sendAssistantPrompt(prompt);
    _inputController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 140,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = TodoAppScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final messages = controller.assistantMessages;
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Assistant',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            Text(
                              'Always here to help',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.84),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isUser = message.role == AssistantRole.user;
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 310),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: isUser ? AppColors.primaryGradient : null,
                            color: isUser
                                ? null
                                : (isDark
                                          ? AppColors.mutedDark
                                          : AppColors.mutedLight)
                                      .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: isUser ? Colors.white : null,
                                    ),
                              ),
                              if (message.preview != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color:
                                          Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withValues(alpha: 0.08) ??
                                          Colors.transparent,
                                    ),
                                  ),
                                  child: _AssistantPreviewCard(
                                    message: message,
                                    onConfirm: message.confirmed
                                        ? null
                                        : () {
                                            controller.confirmAssistantTask(
                                              message.id,
                                            );
                                            ScaffoldMessenger.of(context)
                                              ..hideCurrentSnackBar()
                                              ..showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Task added to your list.',
                                                  ),
                                                ),
                                              );
                                          },
                                    onEdit: () {
                                      _inputController.text =
                                          message.preview!.title;
                                    },
                                    onDelete: () {
                                      controller.resetAssistant();
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (messages.length == 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions.map((suggestion) {
                        return ActionChip(
                          label: Text(suggestion),
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.08,
                          ),
                          onPressed: () => setState(
                            () => _inputController.text = suggestion,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          decoration: const InputDecoration(
                            hintText: 'Type your task...',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _send,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssistantPreviewCard extends StatelessWidget {
  const _AssistantPreviewCard({
    required this.message,
    required this.onConfirm,
    required this.onEdit,
    required this.onDelete,
  });

  final AssistantMessage message;
  final VoidCallback? onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = message.preview!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: preview.priority.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                preview.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Date: ${preview.dateLabel}'),
        Text('Time: ${preview.timeLabel}'),
        Text('Priority: ${preview.priority.label}'),
        Text('Category: ${preview.category.label}'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PrimaryGradientButton(
                label: message.confirmed ? 'Confirmed' : 'Confirm',
                onPressed: onConfirm,
                icon: Icons.check_rounded,
              ),
            ),
            const SizedBox(width: 8),
            _MiniIconButton(icon: Icons.edit_rounded, onTap: onEdit),
            const SizedBox(width: 8),
            _MiniIconButton(
              icon: Icons.delete_outline_rounded,
              color: AppColors.destructive,
              onTap: onDelete,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({required this.icon, required this.onTap, this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: (color ?? Theme.of(context).textTheme.bodyMedium!.color!)
              .withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}

class CategoryDonutChart extends StatelessWidget {
  const CategoryDonutChart({super.key, required this.values});

  final List<({TaskCategory category, double value})> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: CustomPaint(
        painter: _DonutChartPainter(values),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '100%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Distribution',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductivityLineChart extends StatelessWidget {
  const ProductivityLineChart({
    super.key,
    required this.points,
    required this.labels,
  });

  final List<double> points;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.65,
          child: CustomPaint(
            painter: _LineChartPainter(
              points: points,
              lineColor: AppColors.primary,
              gridColor:
                  Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.12) ??
                  Colors.black12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map(
                (label) => Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({super.key, required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.reduce(math.max);
    return SizedBox(
      height: 210,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (index) {
          final heightFactor = maxValue == 0 ? 0.0 : values[index] / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    values[index].toStringAsFixed(0),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heightFactor.clamp(0.10, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    labels[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter(this.values);

  final List<({TaskCategory category, double value})> values;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final background = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, background);

    var startAngle = -math.pi / 2;
    for (final value in values) {
      final sweep = math.pi * 2 * (value.value / 100);
      final paint = Paint()
        ..color = value.category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep + 0.04;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> points;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 16;
    const padding = 12.0;
    final usableWidth = size.width - padding * 2;
    final maxPoint = points.isEmpty ? 0.0 : points.reduce(math.max);
    final safeMaxPoint = maxPoint <= 0 ? 1.0 : maxPoint;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = chartHeight * (i / 3);
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    final linePaint = Paint()
      ..shader = AppColors.primaryGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.16),
          lineColor.withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = padding + usableWidth * (i / (points.length - 1));
      final y =
          chartHeight - ((points[i] / safeMaxPoint) * (chartHeight - padding));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath
          ..moveTo(x, chartHeight)
          ..lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath
      ..lineTo(size.width - padding, chartHeight)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final x = padding + usableWidth * (i / (points.length - 1));
      final y =
          chartHeight - ((points[i] / safeMaxPoint) * (chartHeight - padding));
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = lineColor);
      canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

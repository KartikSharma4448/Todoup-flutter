import 'dart:typed_data';

import 'package:flutter/material.dart';

enum TaskPriority { low, medium, high }

enum TaskCategory { work, personal, health, study, shopping, others }

enum AssistantRole { user, assistant }

enum AuthActionResult { success, confirmationPending, failure }

extension TaskPriorityX on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  String get apiValue {
    switch (this) {
      case TaskPriority.low:
        return 'low';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.high:
        return 'high';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return Colors.grey.shade500;
      case TaskPriority.medium:
        return const Color(0xFFF59E0B);
      case TaskPriority.high:
        return const Color(0xFFEF4444);
    }
  }
}

extension TaskCategoryX on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.work:
        return 'Work';
      case TaskCategory.personal:
        return 'Personal';
      case TaskCategory.health:
        return 'Health';
      case TaskCategory.study:
        return 'Study';
      case TaskCategory.shopping:
        return 'Shopping';
      case TaskCategory.others:
        return 'Others';
    }
  }

  String get apiValue {
    switch (this) {
      case TaskCategory.work:
        return 'work';
      case TaskCategory.personal:
        return 'personal';
      case TaskCategory.health:
        return 'health';
      case TaskCategory.study:
        return 'study';
      case TaskCategory.shopping:
        return 'shopping';
      case TaskCategory.others:
        return 'others';
    }
  }

  Color get color {
    switch (this) {
      case TaskCategory.work:
        return const Color(0xFF3B82F6);
      case TaskCategory.personal:
        return const Color(0xFF8B5CF6);
      case TaskCategory.health:
        return const Color(0xFF22C55E);
      case TaskCategory.study:
        return const Color(0xFF6366F1);
      case TaskCategory.shopping:
        return const Color(0xFFF59E0B);
      case TaskCategory.others:
        return const Color(0xFF64748B);
    }
  }
}

TaskPriority taskPriorityFromApi(String? value) {
  switch (value) {
    case 'low':
      return TaskPriority.low;
    case 'high':
      return TaskPriority.high;
    case 'medium':
    default:
      return TaskPriority.medium;
  }
}

TaskCategory taskCategoryFromApi(String? value) {
  switch (value) {
    case 'work':
      return TaskCategory.work;
    case 'health':
      return TaskCategory.health;
    case 'study':
      return TaskCategory.study;
    case 'shopping':
      return TaskCategory.shopping;
    case 'others':
      return TaskCategory.others;
    case 'personal':
    default:
      return TaskCategory.personal;
  }
}

class AppSettings {
  const AppSettings({
    required this.darkMode,
    required this.notificationsEnabled,
    required this.premium,
  });

  const AppSettings.defaults()
    : darkMode = false,
      notificationsEnabled = true,
      premium = false;

  final bool darkMode;
  final bool notificationsEnabled;
  final bool premium;

  AppSettings copyWith({
    bool? darkMode,
    bool? notificationsEnabled,
    bool? premium,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      premium: premium ?? this.premium,
    );
  }

  factory AppSettings.fromApi(Map<String, dynamic> json) {
    return AppSettings(
      darkMode: json['darkMode'] == true,
      notificationsEnabled: json['notificationsEnabled'] != false,
      premium: json['premium'] == true,
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'darkMode': darkMode,
      'notificationsEnabled': notificationsEnabled,
      'premium': premium,
    };
  }
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.completed,
    required this.dueDate,
    required this.dueLabel,
    required this.priority,
    required this.category,
    this.description,
    this.reminder = false,
    this.repeat = 'None',
    this.subtasks = const [],
    this.completedSubtasks = 0,
    this.dueTime,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final bool completed;
  final DateTime dueDate;
  final String dueLabel;
  final TaskPriority priority;
  final TaskCategory category;
  final String? description;
  final bool reminder;
  final String repeat;
  final List<String> subtasks;
  final int completedSubtasks;
  final TimeOfDay? dueTime;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskItem copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? dueDate,
    String? dueLabel,
    TaskPriority? priority,
    TaskCategory? category,
    String? description,
    bool? reminder,
    String? repeat,
    List<String>? subtasks,
    int? completedSubtasks,
    TimeOfDay? dueTime,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      dueDate: dueDate ?? this.dueDate,
      dueLabel: dueLabel ?? this.dueLabel,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      description: description ?? this.description,
      reminder: reminder ?? this.reminder,
      repeat: repeat ?? this.repeat,
      subtasks: subtasks ?? this.subtasks,
      completedSubtasks: completedSubtasks ?? this.completedSubtasks,
      dueTime: dueTime ?? this.dueTime,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TaskItem.fromApi(Map<String, dynamic> json) {
    final dueDate = _parseDateTime(json['dueDate']) ?? DateTime.now();
    final subtasks = (json['subtasks'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);

    return TaskItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      completed: json['completed'] == true,
      dueDate: DateTime(dueDate.year, dueDate.month, dueDate.day),
      dueLabel: json['dueLabel']?.toString() ?? _buildRelativeDueLabel(dueDate),
      priority: taskPriorityFromApi(json['priority']?.toString()),
      category: taskCategoryFromApi(json['category']?.toString()),
      description: json['description']?.toString(),
      reminder: json['reminder'] == true,
      repeat: json['repeat']?.toString() ?? 'None',
      subtasks: subtasks,
      completedSubtasks: (json['completedSubtasks'] as num?)?.toInt() ?? 0,
      dueTime: _parseTimeOfDay(json['dueTime']?.toString()),
      completedAt: _parseDateTime(json['completedAt']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) =>
      TaskItem.fromApi(json);

  Map<String, dynamic> toApi() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'dueDate': _formatDate(dueDate),
      'dueLabel': dueLabel.isEmpty ? _buildRelativeDueLabel(dueDate) : dueLabel,
      'priority': priority.apiValue,
      'category': category.apiValue,
      'description': description,
      'reminder': reminder,
      'repeat': repeat,
      'subtasks': subtasks,
      'completedSubtasks': completedSubtasks,
      'dueTime': dueTime == null ? null : _formatTime(dueTime!),
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toApi();
}

class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.category,
    this.reminder = false,
    this.repeat = 'None',
    this.subtasks = const [],
  });

  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskCategory category;
  final bool reminder;
  final String repeat;
  final List<String> subtasks;
}

class PendingTaskAttachment {
  PendingTaskAttachment({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  final int sizeBytes;
}

class TaskAttachment {
  const TaskAttachment({
    required this.id,
    required this.taskId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.createdAt,
  });

  final String id;
  final String taskId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime? createdAt;

  factory TaskAttachment.fromApi(Map<String, dynamic> json) {
    return TaskAttachment(
      id: json['id']?.toString() ?? '',
      taskId: json['taskId']?.toString() ?? json['task_id']?.toString() ?? '',
      storagePath:
          json['storagePath']?.toString() ??
          json['storage_path']?.toString() ??
          '',
      fileName:
          json['fileName']?.toString() ?? json['file_name']?.toString() ?? '',
      mimeType:
          json['mimeType']?.toString() ?? json['mime_type']?.toString() ?? '',
      sizeBytes:
          (json['sizeBytes'] as num?)?.toInt() ??
          (json['size_bytes'] as num?)?.toInt() ??
          0,
      createdAt: _parseDateTime(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'storagePath': storagePath,
      'fileName': fileName,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    required this.occupation,
    required this.bio,
  });

  const UserProfile.empty()
    : name = '',
      email = '',
      phone = '',
      location = '',
      occupation = '',
      bio = '';

  final String name;
  final String email;
  final String phone;
  final String location;
  final String occupation;
  final String bio;

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? location,
    String? occupation,
    String? bio,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      occupation: occupation ?? this.occupation,
      bio: bio ?? this.bio,
    );
  }

  factory UserProfile.fromApi(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      occupation: json['occupation']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      UserProfile.fromApi(json);

  Map<String, dynamic> toApi() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'location': location,
      'occupation': occupation,
      'bio': bio,
    };
  }

  Map<String, dynamic> toJson() => toApi();
}

class AssistantTaskPreview {
  const AssistantTaskPreview({
    required this.title,
    required this.dateLabel,
    required this.dateValue,
    required this.timeLabel,
    required this.timeValue,
    required this.priority,
    required this.category,
  });

  final String title;
  final String dateLabel;
  final String dateValue;
  final String timeLabel;
  final String timeValue;
  final TaskPriority priority;
  final TaskCategory category;

  AssistantTaskPreview copyWith({
    String? title,
    String? dateLabel,
    String? dateValue,
    String? timeLabel,
    String? timeValue,
    TaskPriority? priority,
    TaskCategory? category,
  }) {
    return AssistantTaskPreview(
      title: title ?? this.title,
      dateLabel: dateLabel ?? this.dateLabel,
      dateValue: dateValue ?? this.dateValue,
      timeLabel: timeLabel ?? this.timeLabel,
      timeValue: timeValue ?? this.timeValue,
      priority: priority ?? this.priority,
      category: category ?? this.category,
    );
  }

  factory AssistantTaskPreview.fromApi(Map<String, dynamic> json) {
    final parsedDate = _parseDateTime(json['dateValue']) ?? DateTime.now();
    final dateLabel =
        json['dateLabel']?.toString() ?? _buildRelativeDueLabel(parsedDate);
    final parsedTime = _parseTimeOfDay(json['timeValue']?.toString());
    final timeLabel =
        json['timeLabel']?.toString() ??
        (parsedTime == null ? '7:00 PM' : _formatDisplayTime(parsedTime));

    return AssistantTaskPreview(
      title: json['title']?.toString() ?? '',
      dateLabel: dateLabel,
      dateValue: json['dateValue']?.toString() ?? _formatDate(parsedDate),
      timeLabel: timeLabel,
      timeValue:
          json['timeValue']?.toString() ?? _normalizeTimeValue(parsedTime),
      priority: taskPriorityFromApi(json['priority']?.toString()),
      category: taskCategoryFromApi(json['category']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'dateLabel': dateLabel,
      'dateValue': dateValue,
      'timeLabel': timeLabel,
      'timeValue': timeValue,
      'priority': priority.apiValue,
      'category': category.apiValue,
    };
  }
}

class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.role,
    required this.content,
    this.preview,
    this.confirmed = false,
    this.createdAt,
  });

  final String id;
  final AssistantRole role;
  final String content;
  final AssistantTaskPreview? preview;
  final bool confirmed;
  final DateTime? createdAt;

  AssistantMessage copyWith({
    String? id,
    AssistantRole? role,
    String? content,
    AssistantTaskPreview? preview,
    bool? confirmed,
    DateTime? createdAt,
  }) {
    return AssistantMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      preview: preview ?? this.preview,
      confirmed: confirmed ?? this.confirmed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    return AssistantMessage(
      id: json['id']?.toString() ?? '',
      role: json['role'] == 'user'
          ? AssistantRole.user
          : AssistantRole.assistant,
      content: json['content']?.toString() ?? '',
      preview: json['preview'] is Map<String, dynamic>
          ? AssistantTaskPreview.fromApi(
              json['preview'] as Map<String, dynamic>,
            )
          : null,
      confirmed: json['confirmed'] == true,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role == AssistantRole.user ? 'user' : 'assistant',
      'content': content,
      'preview': preview?.toJson(),
      'confirmed': confirmed,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.toString();
  if (normalized.isEmpty) {
    return null;
  }
  return DateTime.tryParse(normalized);
}

TimeOfDay? _parseTimeOfDay(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  final parts = value.split(':');
  if (parts.length != 2) {
    return null;
  }

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }

  return TimeOfDay(hour: hour, minute: minute);
}

String _formatDate(DateTime date) {
  return date.toIso8601String().split('T').first;
}

String _formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String _formatDisplayTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _normalizeTimeValue(TimeOfDay? time) {
  if (time == null) {
    return '19:00';
  }
  return _formatTime(time);
}

String _buildRelativeDueLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = target.difference(today).inDays;

  if (difference == 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Tomorrow';
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String formatFileSizeLabel(int sizeBytes) {
  if (sizeBytes < 1024) {
    return '$sizeBytes B';
  }

  final kilobytes = sizeBytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(kilobytes >= 100 ? 0 : 1)} KB';
  }

  final megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(megabytes >= 100 ? 0 : 1)} MB';
}

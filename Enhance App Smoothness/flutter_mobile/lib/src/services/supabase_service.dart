import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../assistant_config.dart';
import '../models.dart';
import '../supabase_config.dart';

class SupabaseService {
  SupabaseService() : _client = Supabase.instance.client;

  final SupabaseClient _client;
  static const _uuid = Uuid();

  static String get baseUrl => SupabaseConfig.baseUrlForMessages;
  static const String _attachmentBucket = 'task-attachments';
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  bool get hasActiveSession => _client.auth.currentSession != null;

  Future<String?> getToken() async {
    return _client.auth.currentSession?.accessToken;
  }

  Future<void> setToken(String token) async {
    // Supabase manages auth persistence internally.
  }

  Future<void> removeToken() async {
    await _client.auth.signOut();
  }

  Future<void> login(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await _ensureCurrentProfile();
    } on AuthException catch (error) {
      throw Exception(error.message);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<AuthActionResult> register(Map<String, dynamic> userData) async {
    final name = userData['name']?.toString().trim() ?? '';
    final email = userData['email']?.toString().trim() ?? '';
    final password = userData['password']?.toString() ?? '';

    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': userData['phone']?.toString() ?? '',
          'location': userData['location']?.toString() ?? '',
          'occupation': userData['occupation']?.toString() ?? '',
          'bio': userData['bio']?.toString() ?? '',
        },
        emailRedirectTo: kIsWeb
            ? Uri.base.origin
            : SupabaseConfig.mobileRedirectUrl,
      );

      if (response.user == null) {
        throw Exception('Unable to create your account.');
      }

      if (response.session == null) {
        return AuthActionResult.confirmationPending;
      }

      await _ensureCurrentProfile(seedData: userData);
      return AuthActionResult.success;
    } on AuthException catch (error) {
      throw Exception(error.message);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Future<UserProfile> getProfile() async {
    final row = await _ensureCurrentProfile();
    return _profileFromRecord(row);
  }

  Future<void> updateProfile(UserProfile profile) async {
    final user = _requireUser();

    try {
      await _client
          .from('users')
          .update({
            'email': profile.email.trim(),
            'name': profile.name.trim(),
            'phone': profile.phone.trim(),
            'location': profile.location.trim(),
            'occupation': profile.occupation.trim(),
            'bio': profile.bio.trim(),
          })
          .eq('id', user.id);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _client.rpc('delete_current_user');
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw Exception(error.message);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<List<TaskItem>> getTasks() async {
    final user = _requireUser();

    try {
      final rows = await _client
          .from('tasks')
          .select(
            'id,user_id,title,description,priority,status,due_date,notes,recurring,tags,subtasks,created_at,category,reminder,repeat,completed_subtasks,due_time,completed_at,updated_at',
          )
          .eq('user_id', user.id)
          .order('due_date', ascending: true);

      return (rows as List<dynamic>)
          .map(
            (item) => _taskFromRecord(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<void> replaceCloudTasks(List<TaskItem> tasks) async {
    final user = _requireUser();

    try {
      await _deleteAllStoredAttachmentsForUser(user.id);
      await _client.from('tasks').delete().eq('user_id', user.id);

      if (tasks.isEmpty) {
        return;
      }

      final payload = tasks
          .map((task) => _taskInsertPayload(task.toPayload(), user.id))
          .toList(growable: false);
      await _client.from('tasks').insert(payload);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<List<TaskAttachment>> getTaskAttachments() async {
    final user = _requireUser();

    try {
      final rows = await _client
          .from('task_attachments')
          .select(
            'id,task_id,user_id,storage_path,file_name,mime_type,size_bytes,created_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      return (rows as List<dynamic>)
          .map(
            (item) =>
                _attachmentFromRecord(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<TaskItem> createTask(Map<String, dynamic> taskData) async {
    final user = _requireUser();

    try {
      final row = await _client
          .from('tasks')
          .insert(_taskInsertPayload(taskData, user.id))
          .select(
            'id,user_id,title,description,priority,status,due_date,notes,recurring,tags,subtasks,created_at,category,reminder,repeat,completed_subtasks,due_time,completed_at,updated_at',
          )
          .single();

      return _taskFromRecord(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<List<TaskAttachment>> uploadTaskAttachments(
    String taskId,
    List<PendingTaskAttachment> attachments,
  ) async {
    final user = _requireUser();
    final uploaded = <TaskAttachment>[];

    for (var index = 0; index < attachments.length; index++) {
      final attachment = attachments[index];
      final storagePath =
          '${user.id}/$taskId/${DateTime.now().microsecondsSinceEpoch}_${index}_${_sanitizeFileName(attachment.fileName)}';

      try {
        await _client.storage
            .from(_attachmentBucket)
            .uploadBinary(
              storagePath,
              attachment.bytes,
              fileOptions: FileOptions(
                contentType: attachment.mimeType.isEmpty
                    ? 'application/octet-stream'
                    : attachment.mimeType,
              ),
            );

        final row = await _client
            .from('task_attachments')
            .insert({
              'task_id': taskId,
              'user_id': user.id,
              'storage_path': storagePath,
              'file_name': attachment.fileName,
              'mime_type': attachment.mimeType,
              'size_bytes': attachment.sizeBytes,
            })
            .select(
              'id,task_id,user_id,storage_path,file_name,mime_type,size_bytes,created_at',
            )
            .single();

        uploaded.add(_attachmentFromRecord(Map<String, dynamic>.from(row)));
      } on StorageException catch (error) {
        throw Exception(error.message);
      } on PostgrestException catch (error) {
        throw Exception(error.message);
      }
    }

    return uploaded;
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> taskData) async {
    final user = _requireUser();

    try {
      await _client
          .from('tasks')
          .update(_taskUpdatePayload(taskData))
          .eq('id', taskId)
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<void> deleteTask(String taskId) async {
    final user = _requireUser();

    try {
      await _deleteStoredAttachments(taskId, user.id);
      await _client
          .from('tasks')
          .delete()
          .eq('id', taskId)
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<List<AssistantMessage>> getAssistantMessages() async {
    final user = _requireUser();

    try {
      final rows = await _client
          .from('assistant_messages')
          .select(
            'id,user_id,role,content,preview,confirmed,created_at,updated_at',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      return (rows as List<dynamic>)
          .map(
            (item) => _assistantMessageFromRecord(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<AssistantMessage> sendAssistantMessage(String message) async {
    final user = _requireUser();
    final trimmed = message.trim();

    try {
      await _client.from('assistant_messages').insert({
        'user_id': user.id,
        'role': 'user',
        'content': trimmed,
        'confirmed': false,
      });

      final draft = AssistantConfig.isEnabled
          ? await _requestAssistantDraft(trimmed)
          : _fallbackAssistantDraft(trimmed);

      final row = await _client
          .from('assistant_messages')
          .insert({
            'user_id': user.id,
            'role': 'assistant',
            'content': draft.content,
            'preview': draft.preview.toJson(),
            'confirmed': false,
          })
          .select(
            'id,user_id,role,content,preview,confirmed,created_at,updated_at',
          )
          .single();

      return _assistantMessageFromRecord(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    } on http.ClientException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<void> updateAssistantMessage(
    String messageId,
    Map<String, dynamic> data,
  ) async {
    final user = _requireUser();

    final payload = <String, dynamic>{};
    if (data.containsKey('content')) {
      payload['content'] = data['content']?.toString() ?? '';
    }
    if (data.containsKey('confirmed')) {
      payload['confirmed'] = data['confirmed'] == true;
    }
    if (data['preview'] is Map<String, dynamic>) {
      payload['preview'] = data['preview'];
    }

    try {
      await _client
          .from('assistant_messages')
          .update(payload)
          .eq('id', messageId)
          .eq('user_id', user.id);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<void> resetAssistantMessages() async {
    final user = _requireUser();

    try {
      await _client.from('assistant_messages').delete().eq('user_id', user.id);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You are not signed in.');
    }
    return user;
  }

  Future<Map<String, dynamic>> _ensureCurrentProfile({
    Map<String, dynamic>? seedData,
  }) async {
    final user = _requireUser();

    try {
      final existing = await _client
          .from('users')
          .select('id,email,name,phone,location,occupation,bio')
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) {
        return Map<String, dynamic>.from(existing);
      }

      final fallbackName = seedData?['name']?.toString().trim();
      final payload = {
        'id': user.id,
        'email': user.email ?? '',
        'name': fallbackName?.isNotEmpty == true
            ? fallbackName
            : (user.userMetadata?['name']?.toString() ??
                  (user.email?.split('@').first ?? 'User')),
        'phone': seedData?['phone']?.toString() ?? '',
        'location': seedData?['location']?.toString() ?? '',
        'occupation': seedData?['occupation']?.toString() ?? '',
        'bio': seedData?['bio']?.toString() ?? '',
      };

      final row = await _client
          .from('users')
          .upsert(payload)
          .select('id,email,name,phone,location,occupation,bio')
          .single();

      return Map<String, dynamic>.from(row);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  UserProfile _profileFromRecord(Map<String, dynamic> row) {
    return UserProfile(
      name: row['name']?.toString() ?? '',
      email: row['email']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      location: row['location']?.toString() ?? '',
      occupation: row['occupation']?.toString() ?? '',
      bio: row['bio']?.toString() ?? '',
    );
  }

  TaskAttachment _attachmentFromRecord(Map<String, dynamic> row) {
    return TaskAttachment(
      id: row['id']?.toString() ?? '',
      taskId: row['task_id']?.toString() ?? '',
      storagePath: row['storage_path']?.toString() ?? '',
      fileName: row['file_name']?.toString() ?? '',
      mimeType: row['mime_type']?.toString() ?? '',
      sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(row['created_at']),
    );
  }

  TaskItem _taskFromRecord(Map<String, dynamic> row) {
    final dueDate = _parseCloudDate(row['due_date']) ?? DateTime.now();
    final dueTimeValue = row['due_time']?.toString();
    final subtasks = _readSubtasks(row['subtasks']);
    final completedSubtasks =
        (row['completed_subtasks'] as num?)?.toInt() ??
        _inferCompletedSubtasks(row['subtasks']);
    final status = row['status']?.toString().toLowerCase();
    final completed =
        status == 'completed' ||
        status == 'done' ||
        row['completed_at'] != null;

    final serverId = row['id']?.toString();
    return TaskItem(
      localId: serverId ?? 'local-${_uuid.v4()}',
      serverId: serverId,
      title: row['title']?.toString() ?? '',
      completed: completed,
      dueDate: dueDate,
      dueLabel: _relativeDueLabel(dueDate),
      priority: taskPriorityFromApi(row['priority']?.toString()),
      category: taskCategoryFromApi(row['category']?.toString()),
      description: row['description']?.toString().isNotEmpty == true
          ? row['description']?.toString()
          : row['notes']?.toString(),
      reminder: row['reminder'] == true,
      repeat:
          row['repeat']?.toString() ??
          (row['recurring'] == true ? 'Daily' : 'None'),
      subtasks: subtasks,
      completedSubtasks: completedSubtasks,
      dueTime: _parseTimeOfDay(dueTimeValue),
      completedAt: _parseDateTime(row['completed_at']),
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
    );
  }

  Map<String, dynamic> _taskInsertPayload(
    Map<String, dynamic> taskData,
    String userId,
  ) {
    final dueDate = _coerceDateOnly(taskData['dueDate']);
    return {
      'user_id': userId,
      'title': taskData['title']?.toString().trim() ?? '',
      'description': taskData['description']?.toString().trim(),
      'priority': taskData['priority']?.toString() ?? 'medium',
      'status': taskData['completed'] == true ? 'completed' : 'pending',
      'due_date': dueDate?.toIso8601String(),
      'notes': taskData['description']?.toString().trim(),
      'recurring': (taskData['repeat']?.toString() ?? 'None') != 'None',
      'tags': const [],
      'subtasks': (taskData['subtasks'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      'category': taskData['category']?.toString() ?? 'personal',
      'reminder': taskData['reminder'] == true,
      'repeat': taskData['repeat']?.toString() ?? 'None',
      'completed_subtasks':
          (taskData['completedSubtasks'] as num?)?.toInt() ?? 0,
      'due_time': taskData['dueTime']?.toString(),
      'completed_at': taskData['completed'] == true
          ? taskData['completedAt']?.toString() ??
                DateTime.now().toIso8601String()
          : null,
    };
  }

  Map<String, dynamic> _taskUpdatePayload(Map<String, dynamic> taskData) {
    final payload = <String, dynamic>{};

    if (taskData.containsKey('title')) {
      payload['title'] = taskData['title']?.toString().trim() ?? '';
    }
    if (taskData.containsKey('description')) {
      final description = taskData['description']?.toString().trim();
      payload['description'] = description;
      payload['notes'] = description;
    }
    if (taskData.containsKey('priority')) {
      payload['priority'] = taskData['priority']?.toString() ?? 'medium';
    }
    if (taskData.containsKey('dueDate')) {
      payload['due_date'] = _coerceDateOnly(taskData['dueDate'])?.toIso8601String();
    }
    if (taskData.containsKey('category')) {
      payload['category'] = taskData['category']?.toString() ?? 'personal';
    }
    if (taskData.containsKey('reminder')) {
      payload['reminder'] = taskData['reminder'] == true;
    }
    if (taskData.containsKey('repeat')) {
      final repeat = taskData['repeat']?.toString() ?? 'None';
      payload['repeat'] = repeat;
      payload['recurring'] = repeat != 'None';
    }
    if (taskData.containsKey('subtasks')) {
      payload['subtasks'] = (taskData['subtasks'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false);
    }
    if (taskData.containsKey('completedSubtasks')) {
      payload['completed_subtasks'] =
          (taskData['completedSubtasks'] as num?)?.toInt() ?? 0;
    }
    if (taskData.containsKey('dueTime')) {
      payload['due_time'] = taskData['dueTime']?.toString();
    }
    if (taskData.containsKey('completed')) {
      final completed = taskData['completed'] == true;
      payload['status'] = completed ? 'completed' : 'pending';
      payload['completed_at'] = completed
          ? taskData['completedAt']?.toString() ??
                DateTime.now().toIso8601String()
          : null;
    } else if (taskData.containsKey('completedAt')) {
      payload['completed_at'] = taskData['completedAt']?.toString();
    }

    return payload;
  }

  AssistantMessage _assistantMessageFromRecord(Map<String, dynamic> row) {
    return AssistantMessage(
      id: row['id']?.toString() ?? '',
      role: row['role'] == 'user'
          ? AssistantRole.user
          : AssistantRole.assistant,
      content: row['content']?.toString() ?? '',
      preview: row['preview'] is Map<String, dynamic>
          ? AssistantTaskPreview.fromApi(
              Map<String, dynamic>.from(row['preview'] as Map),
            )
          : null,
      confirmed: row['confirmed'] == true,
      createdAt: _parseDateTime(row['created_at']),
    );
  }

  Future<_AssistantDraftResponse> _requestAssistantDraft(String prompt) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    final response = await http
        .post(
          AssistantConfig.draftUri,
          headers: {
            'Content-Type': 'application/json',
            if (accessToken != null && accessToken.isNotEmpty)
              'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'message': prompt}),
        )
        .timeout(const Duration(seconds: 45));

    final raw = response.body.trim();
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Assistant backend returned invalid JSON.');
    }

    final payload = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = payload['error']?.toString().trim();
      throw Exception(
        message?.isNotEmpty == true
            ? message
            : 'Assistant backend returned HTTP ${response.statusCode}.',
      );
    }

    final previewData = payload['preview'];
    if (previewData is! Map) {
      throw const FormatException(
        'Assistant backend did not return a task preview.',
      );
    }

    final preview = AssistantTaskPreview.fromApi(
      Map<String, dynamic>.from(previewData),
    );
    final content = payload['content']?.toString().trim();

    return _AssistantDraftResponse(
      content: content?.isNotEmpty == true
          ? content!
          : _fallbackAssistantDraft(prompt).content,
      preview: preview,
    );
  }

  _AssistantDraftResponse _fallbackAssistantDraft(String prompt) {
    return _AssistantDraftResponse(
      content:
          "I've created a task draft for you. Confirm it if it looks right.",
      preview: _buildPreview(prompt),
    );
  }

  AssistantTaskPreview _buildPreview(String prompt) {
    final lowered = prompt.toLowerCase();
    final now = DateTime.now();
    final dueDate = lowered.contains('today')
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final dueTime =
        _extractPromptTime(lowered) ?? const TimeOfDay(hour: 19, minute: 0);

    final category = () {
      if (lowered.contains('gym') || lowered.contains('workout')) {
        return TaskCategory.health;
      }
      if (lowered.contains('study') || lowered.contains('exam')) {
        return TaskCategory.study;
      }
      if (lowered.contains('buy') || lowered.contains('grocer')) {
        return TaskCategory.shopping;
      }
      if (lowered.contains('meeting') || lowered.contains('project')) {
        return TaskCategory.work;
      }
      return TaskCategory.personal;
    }();

    final priority = () {
      if (lowered.contains('urgent') || lowered.contains('asap')) {
        return TaskPriority.high;
      }
      if (lowered.contains('later') || lowered.contains('someday')) {
        return TaskPriority.low;
      }
      return TaskPriority.medium;
    }();

    return AssistantTaskPreview(
      title: prompt.trim(),
      dateLabel: _relativeDueLabel(dueDate),
      dateValue: dueDate.toIso8601String(),
      timeLabel: _formatDisplayTime(dueTime),
      timeValue: _formatTime(dueTime),
      priority: priority,
      category: category,
    );
  }

  TimeOfDay? _extractPromptTime(String text) {
    final match = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)').firstMatch(text);
    if (match == null) {
      return null;
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '00');
    final meridiem = match.group(3)!;

    if (meridiem == 'pm' && hour != 12) {
      hour += 12;
    } else if (meridiem == 'am' && hour == 12) {
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  List<String> _readSubtasks(Object? rawValue) {
    if (rawValue is! List) {
      return const [];
    }

    return rawValue
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item['title']?.toString() ?? '';
          }
          if (item is Map) {
            return item['title']?.toString() ?? '';
          }
          return item.toString();
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  int _inferCompletedSubtasks(Object? rawValue) {
    if (rawValue is! List) {
      return 0;
    }

    return rawValue.where((item) {
      if (item is Map<String, dynamic>) {
        return item['completed'] == true;
      }
      if (item is Map) {
        return item['completed'] == true;
      }
      return false;
    }).length;
  }

  Future<void> _deleteStoredAttachments(String taskId, String userId) async {
    final rows = await _client
        .from('task_attachments')
        .select('id,storage_path')
        .eq('task_id', taskId)
        .eq('user_id', userId);

    final attachments = (rows as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    final storagePaths = attachments
        .map((item) => item['storage_path']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    try {
      if (storagePaths.isNotEmpty) {
        await _client.storage.from(_attachmentBucket).remove(storagePaths);
      }
    } on StorageException catch (error) {
      throw Exception(error.message);
    }

    if (attachments.isNotEmpty) {
      await _client
          .from('task_attachments')
          .delete()
          .eq('task_id', taskId)
          .eq('user_id', userId);
    }
  }

  Future<void> _deleteAllStoredAttachmentsForUser(String userId) async {
    final rows = await _client
        .from('task_attachments')
        .select('storage_path')
        .eq('user_id', userId);

    final storagePaths = (rows as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .map((item) => item['storage_path']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    try {
      if (storagePaths.isNotEmpty) {
        await _client.storage.from(_attachmentBucket).remove(storagePaths);
      }
    } on StorageException catch (error) {
      throw Exception(error.message);
    }

    await _client.from('task_attachments').delete().eq('user_id', userId);
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'attachment.bin' : sanitized;
  }
}

class _AssistantDraftResponse {
  const _AssistantDraftResponse({required this.content, required this.preview});

  final String content;
  final AssistantTaskPreview preview;
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

DateTime? _parseCloudDate(Object? value) {
  final parsed = _parseDateTime(value);
  if (parsed == null) {
    return null;
  }

  final utcDate = parsed.isUtc ? parsed : parsed.toUtc();
  return DateTime(utcDate.year, utcDate.month, utcDate.day);
}

DateTime? _coerceDateOnly(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return DateTime.utc(value.year, value.month, value.day);
  }

  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) {
    return null;
  }

  return DateTime.utc(parsed.year, parsed.month, parsed.day);
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

String _formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

String _formatDisplayTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String _relativeDueLabel(DateTime date) {
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
  if (difference == -1) {
    return 'Yesterday';
  }

  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
  final base =
      '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  if (date.year == now.year) {
    return base;
  }
  return '$base, ${date.year}';
}

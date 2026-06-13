import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'connectivity_service.dart';
import 'models.dart';
import 'notification_service.dart';
import 'services/local_database_service.dart';
import 'services/supabase_service.dart';
import 'services/task_repository.dart';
import 'smart_widget_service.dart';
import 'task_templates.dart';

class TodoAppController extends ChangeNotifier {
  TodoAppController({
    NotificationService? notifications,
    SmartWidgetService? widgets,
    AuthService? auth,
    ConnectivityService? connectivity,
    SupabaseService? supabase,
    LocalDatabaseService? localDatabase,
    TaskRepository? taskRepository,
  })  : _supabase = supabase ?? SupabaseService(),
        _localDatabase = localDatabase ?? LocalDatabaseService.instance,
        _connectivity = connectivity ?? ConnectivityService.instance,
        _notifications = notifications ?? NotificationService.instance,
        _widgets = widgets ?? SmartWidgetService.instance,
        _auth = auth ?? AuthService.instance {
    _taskRepository = taskRepository ??
        TaskRepository(
          localDatabase: _localDatabase,
          supabaseService: _supabase,
        );
    _authSubscription = _supabase.authStateChanges.listen(_handleAuthStateChange);
    _bootstrap();
  }

  final SupabaseService _supabase;
  final LocalDatabaseService _localDatabase;
  late final TaskRepository _taskRepository;
  final NotificationService _notifications;
  final SmartWidgetService _widgets;
  final AuthService _auth;
  final ConnectivityService _connectivity;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  Future<void>? _sessionSyncFuture;
  SharedPreferences? _prefs;
  AppSettings _settings = const AppSettings.defaults();
  UserProfile? _profile;
  List<TaskItem> _tasks = const [];
  List<TaskTemplate> _templates = defaultTaskTemplates;
  Map<String, List<TaskAttachment>> _attachmentsByTaskId = const {};
  List<AssistantMessage> _assistantMessages = _introThread;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isOnline = true;
  bool _isSyncing = false;
  DateTime? _lastCloudBackupAt;
  ReminderSystemReport? _lastReminderReport;
  String? _error;
  TaskFilterTab _activeTab = TaskFilterTab.today;

  static const List<AssistantMessage> _introThread = [
    AssistantMessage(
      id: 'assistant-intro',
      role: AssistantRole.assistant,
      content:
          "Hi! I'm your AI assistant. Tell me what you need to do and I'll turn it into a task.",
    ),
  ];

  bool get isDarkMode => _settings.darkMode;
  bool get notificationsEnabled => _settings.notificationsEnabled;
  bool get isPremium => _settings.premium;
  UserProfile get profile => _profile ?? const UserProfile.empty();
  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  List<TaskTemplate> get templates => List.unmodifiable(_templates);
  List<AssistantMessage> get assistantMessages =>
      List.unmodifiable(_assistantMessages);
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _profile != null || _auth.isLoggedIn;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  bool get hasPendingSync => false;
  DateTime? get lastCloudBackupAt => _lastCloudBackupAt;
  ReminderSystemReport? get lastReminderReport => _lastReminderReport;
  String? get error => _error;
  TaskFilterTab get activeTab => _activeTab;
  List<TaskItem> get activeTabTasks =>
      List.unmodifiable(_filterTasksByTab(_tasks, _activeTab));
  double get activeTabCompletionRate => _tabCompletionRate(_activeTab);

  void setActiveTab(TaskFilterTab tab) {
    if (_activeTab == tab) {
      return;
    }
    _activeTab = tab;
    notifyListeners();
  }

  List<TaskAttachment> attachmentsForTask(String taskId) =>
      List.unmodifiable(_attachmentsByTaskId[taskId] ?? const []);

  int attachmentCountForTask(String taskId) =>
      _attachmentsByTaskId[taskId]?.length ?? 0;

  int get totalTasks => _tasks.length;
  int get completedTasks => _tasks.where((task) => task.completed).length;
  int get pendingTasks => _tasks.where((task) => !task.completed).length;

  double get completionRate {
    if (_tasks.isEmpty) {
      return 0;
    }
    return completedTasks / _tasks.length;
  }

  int get currentStreak {
    final completedDays =
        _tasks
            .where((task) => task.completed)
            .map((task) => task.completedAt ?? task.dueDate)
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    if (completedDays.isEmpty) {
      return 0;
    }

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    var streak = 0;

    for (final day in completedDays) {
      if (day == cursor) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }

      if (streak == 0 && day == cursor.subtract(const Duration(days: 1))) {
        streak++;
        cursor = day.subtract(const Duration(days: 1));
        continue;
      }

      break;
    }

    return streak;
  }

  double get averageDailyTasks {
    if (_tasks.isEmpty) {
      return 0;
    }

    final sorted = [..._tasks]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final first = DateUtils.dateOnly(sorted.first.dueDate);
    final last = DateUtils.dateOnly(sorted.last.dueDate);
    final span = last.difference(first).inDays.abs() + 1;
    return _tasks.length / span;
  }

  double get productivityScore {
    final completion = completionRate * 70;
    final streak = currentStreak * 5;
    final volume = totalTasks > 10 ? 10 : totalTasks.toDouble();
    final score = completion + streak + volume;
    return score.clamp(0, 100).toDouble();
  }

  Future<void> _bootstrap() async {
    _setLoading(true, notify: false);

    try {
      await _auth.initialize();
      await _localDatabase.init();
      await _taskRepository.init();
      await _connectivity.initialize();
      _isOnline = _connectivity.isOnline;
      _connectivitySubscription =
          _connectivity.onStatusChange.listen(_handleConnectivityChange);

      await _loadSettings();
      await _notifications.initialize();
      await _widgets.initialize();
      await _loadOfflineCache();

      final hasSession = await _auth.restoreSession(
        tryServerRecovery: _isOnline,
      );

      if (!hasSession) {
        _clearSessionState(notify: false);
        await _clearPlatformState();
      } else if (_isOnline) {
        await _syncSessionData();
      } else {
        await _syncPlatformState();
      }
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _isInitialized = true;
      _setLoading(false, notify: false);
      notifyListeners();
    }
  }

  Future<void> _loadSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _settings = AppSettings(
        darkMode: _prefs?.getBool('dark_mode') ?? false,
        notificationsEnabled: _prefs?.getBool('notifications_enabled') ?? true,
        premium: _prefs?.getBool('premium_unlocked') ?? false,
      );
      final backupAt = _prefs?.getString('last_cloud_backup_at');
      _lastCloudBackupAt = backupAt == null ? null : DateTime.tryParse(backupAt);
    } catch (_) {
      _prefs = null;
    }
  }

  Future<void> _persistSettings() async {
    try {
      await _prefs?.setBool('dark_mode', _settings.darkMode);
      await _prefs?.setBool(
        'notifications_enabled',
        _settings.notificationsEnabled,
      );
      await _prefs?.setBool('premium_unlocked', _settings.premium);
      if (_lastCloudBackupAt == null) {
        await _prefs?.remove('last_cloud_backup_at');
      } else {
        await _prefs?.setString(
          'last_cloud_backup_at',
          _lastCloudBackupAt!.toIso8601String(),
        );
      }
    } catch (_) {
      // Preferences are a best-effort convenience.
    }
  }

  Future<void> _loadSessionData() async {
    final profile = await _supabase.getProfile();
    List<AssistantMessage> messages = const [];

    try {
      messages = await _supabase.getAssistantMessages();
    } catch (_) {
      messages = const [];
    }

    await _taskRepository.cacheProfile(profile);

    _profile = profile;
    _tasks = _sortTasks(_taskRepository.cachedTasks);
    _templates = defaultTaskTemplates;
    _attachmentsByTaskId = _groupAttachmentsByTask(
      _taskRepository.cachedAttachments,
    );
    if (messages.isNotEmpty) {
      _assistantMessages = messages;
    } else if (_assistantMessages.isEmpty) {
      _assistantMessages = _introThread;
    }
  }

  Future<void> _loadOfflineCache() async {
    _profile = _taskRepository.cachedProfile;
    _tasks = _sortTasks(_taskRepository.cachedTasks);
    _templates = defaultTaskTemplates;
    _attachmentsByTaskId = _groupAttachmentsByTask(
      _taskRepository.cachedAttachments,
    );
    _assistantMessages = _assistantMessages.isEmpty
        ? _introThread
        : _assistantMessages;
  }

  Future<void> _handleAuthStateChange(AuthState authState) async {
    switch (authState.event) {
      case AuthChangeEvent.signedOut:
        _clearSessionState();
        return;
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.passwordRecovery:
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
      case AuthChangeEvent.mfaChallengeVerified:
        if (!_auth.isLoggedIn) {
          _clearSessionState();
          return;
        }
        await _syncSessionData();
      default:
        return;
    }
  }

  Future<void> _syncSessionData({
    bool setLoading = false,
    bool rethrowOnError = false,
  }) {
    final inFlight = _sessionSyncFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _performSessionDataSync(
      setLoading: setLoading,
      rethrowOnError: rethrowOnError,
    );
    _sessionSyncFuture = future;
    return future.whenComplete(() {
      if (identical(_sessionSyncFuture, future)) {
        _sessionSyncFuture = null;
      }
    });
  }

  Future<void> _performSessionDataSync({
    required bool setLoading,
    required bool rethrowOnError,
  }) async {
    if (!_auth.isLoggedIn) {
      _clearSessionState();
      return;
    }

    if (setLoading) {
      _setLoading(true);
    }

    try {
      _error = null;
      await _loadSessionData();
      await _syncPlatformState();
    } catch (error) {
      _error = _friendlyError(error);
      if (rethrowOnError) {
        rethrow;
      }
    } finally {
      if (setLoading) {
        _setLoading(false, notify: false);
      }
      notifyListeners();
    }
  }

  Future<void> _handleConnectivityChange(bool online) async {
    _isOnline = online;
    notifyListeners();

    if (!online) {
      return;
    }

    await _auth.restoreSession(tryServerRecovery: true);
    await _syncSessionData();
  }

  void _clearSessionState({bool notify = true}) {
    _profile = null;
    _tasks = const [];
    _attachmentsByTaskId = const {};
    _assistantMessages = _introThread;
    _isSyncing = false;
    _lastReminderReport = null;
    _error = null;
    unawaited(_clearPlatformState());
    if (notify) {
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

  Future<void> refreshDashboard() async {
    if (!isAuthenticated) {
      return;
    }

    if (!_isOnline) {
      await _loadOfflineCache();
      notifyListeners();
      return;
    }

    await _loadOfflineCache();
    await _syncSessionData(setLoading: true);
  }

  Future<void> toggleTheme() async {
    _settings = _settings.copyWith(darkMode: !_settings.darkMode);
    notifyListeners();
    await _persistSettings();
  }

  Future<void> setNotifications(bool enabled) async {
    _settings = _settings.copyWith(notificationsEnabled: enabled);
    notifyListeners();
    await _persistSettings();
    await _syncPlatformState();
  }

  Future<void> setPremium(bool enabled) async {
    _settings = _settings.copyWith(premium: enabled);
    notifyListeners();
    await _persistSettings();
  }

  Future<void> unlockPremium() => setPremium(true);

  Future<void> toggleTask(String taskId) async {
    _error = null;
    try {
      await _taskRepository.toggleTaskCompletion(taskId);
      _tasks = _sortTasks(_taskRepository.cachedTasks);
      notifyListeners();
      await _syncPlatformState();
    } catch (error) {
      _tasks = _sortTasks(_taskRepository.cachedTasks);
      _error = _friendlyError(error);
      notifyListeners();
      await _syncPlatformState();
    }
  }

  Future<bool> addTask({
    required String title,
    required String description,
    required DateTime dueDate,
    required TimeOfDay dueTime,
    required TaskPriority priority,
    required TaskCategory category,
    required bool reminder,
    required String repeat,
    required List<String> subtasks,
    List<PendingTaskAttachment> attachments = const [],
  }) async {
    try {
      _error = null;
      final createdTask = await _taskRepository.addTask(
        title: title,
        description: description,
        dueDate: dueDate,
        dueTime: dueTime,
        priority: priority,
        category: category,
        reminder: reminder,
        repeat: repeat,
        subtasks: subtasks,
      );
      _tasks = _sortTasks(_taskRepository.cachedTasks);

      if (attachments.isNotEmpty) {
        try {
          final localAttachments = await _taskRepository.uploadAttachments(
            createdTask.id,
            attachments,
          );
          await _taskRepository.saveLocalAttachments(localAttachments);
          _attachmentsByTaskId = _mergeTaskAttachments(
            _attachmentsByTaskId,
            createdTask.id,
            localAttachments,
          );
        } catch (error) {
          _error =
              'Task saved, but attachments could not be stored locally. ${_friendlyError(error)}';
        }
      }

      notifyListeners();
      await _syncPlatformState();
      return true;
    } catch (error) {
      _error = _friendlyError(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile(UserProfile updatedProfile) async {
    try {
      _error = null;
      await _supabase.updateProfile(updatedProfile);
      await _taskRepository.cacheProfile(updatedProfile);
      _profile = updatedProfile;
      notifyListeners();
      await _syncPlatformState();
    } catch (error) {
      _error = _friendlyError(error);
      notifyListeners();
    }
  }

  Future<AuthActionResult> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      final result = await _auth.login(email.trim(), password);
      if (result != AuthActionResult.success) {
        return result;
      }
      await _syncSessionData(rethrowOnError: true);
      return AuthActionResult.success;
    } catch (error) {
      _error = _friendlyError(error);
      return AuthActionResult.failure;
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthActionResult> register(Map<String, dynamic> userData) async {
    _setLoading(true);
    _error = null;

    try {
      final result = await _supabase.register(userData);
      if (result == AuthActionResult.success) {
        await _auth.restoreSession();
        await _syncSessionData(rethrowOnError: true);
      } else if (result == AuthActionResult.confirmationPending) {
        _error =
            'Registration successful. Check your email, confirm the account, then sign in.';
      }
      return result;
    } catch (error) {
      _error = _friendlyError(error);
      return AuthActionResult.failure;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _error = null;
    try {
      await _auth.logout();
      await _localDatabase.clear();
      _lastCloudBackupAt = null;
      await _persistSettings();
      _clearSessionState();
    } catch (error) {
      _error = _friendlyError(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      _error = null;
      await _supabase.deleteAccount();
      await _auth.logout();
      await _localDatabase.clear();
      _lastCloudBackupAt = null;
      await _persistSettings();
      _clearSessionState();
      return true;
    } catch (error) {
      _error = _friendlyError(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> sendAssistantPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final userMessage = AssistantMessage(
      id: 'local-user-${DateTime.now().microsecondsSinceEpoch}',
      role: AssistantRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    _assistantMessages = [..._assistantMessages, userMessage];
    notifyListeners();

    try {
      final assistantMessage = await _supabase.sendAssistantMessage(trimmed);
      _assistantMessages = [..._assistantMessages, assistantMessage];
      notifyListeners();
    } catch (error) {
      _assistantMessages = [
        ..._assistantMessages,
        _fallbackAssistantMessage(trimmed),
      ];
      _error = _friendlyError(error);
      notifyListeners();
    }
  }

  Future<void> confirmAssistantTask(String messageId) async {
    final index = _assistantMessages.indexWhere((item) => item.id == messageId);
    if (index == -1) {
      return;
    }

    final message = _assistantMessages[index];
    final preview = message.preview;
    if (preview == null || message.confirmed) {
      return;
    }

    final created = await addTask(
      title: preview.title,
      description: 'Created from AI assistant',
      dueDate: _previewDate(preview.dateValue),
      dueTime: _previewTime(preview.timeValue),
      priority: preview.priority,
      category: preview.category,
      reminder: true,
      repeat: 'None',
      subtasks: const [],
    );

    if (!created || _error != null) {
      return;
    }

    final updated = message.copyWith(
      content: 'Task created successfully.',
      confirmed: true,
    );
    _assistantMessages = [
      for (final item in _assistantMessages)
        if (item.id == messageId) updated else item,
    ];
    notifyListeners();

    try {
      await _supabase.updateAssistantMessage(messageId, updated.toJson());
    } catch (_) {
      // Keep local confirmation even if sync is unavailable.
    }
  }

  Future<void> resetAssistant() async {
    _assistantMessages = _introThread;
    notifyListeners();

    try {
      await _supabase.resetAssistantMessages();
    } catch (_) {
      // Local reset is enough to keep the UI usable.
    }
  }

  String exportUserData() {
    return const JsonEncoder.withIndent('  ').convert({
      'profile': profile.toJson(),
      'settings': _settings.toApi(),
      'tasks': _tasks.map((task) => task.toJson()).toList(growable: false),
      'taskAttachments': _attachmentsByTaskId.values
          .expand((attachments) => attachments)
          .map((attachment) => attachment.toJson())
          .toList(growable: false),
      'assistantMessages': _assistantMessages
          .map((message) => message.toJson())
          .toList(growable: false),
    });
  }

  Future<void> deleteTask(String taskId) async {
    _error = null;
    try {
      await _taskRepository.deleteTask(taskId);
      await _notifications.cancelTaskReminder(taskId);
      _tasks = _sortTasks(_taskRepository.cachedTasks);
      _attachmentsByTaskId = Map<String, List<TaskAttachment>>.from(
        _attachmentsByTaskId,
      )..remove(taskId);
      notifyListeners();
      await _syncPlatformState();
    } catch (error) {
      _error = _friendlyError(error);
      _tasks = _sortTasks(_taskRepository.cachedTasks);
      notifyListeners();
      await _syncPlatformState();
    }
  }

  Future<bool> uploadTasksToCloud() async {
    if (!_auth.isLoggedIn) {
      _error = 'Sign in to upload your cloud backup.';
      notifyListeners();
      return false;
    }
    if (!_isOnline) {
      _error = 'Connect to the internet to upload your cloud backup.';
      notifyListeners();
      return false;
    }

    _error = null;
    _isSyncing = true;
    notifyListeners();

    try {
      await _taskRepository.uploadTasksBackup();
      _lastCloudBackupAt = DateTime.now();
      await _persistSettings();
      return true;
    } catch (error) {
      _error = _friendlyError(error);
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<int?> restoreTasksFromCloud() async {
    if (!_auth.isLoggedIn) {
      _error = 'Sign in to restore your cloud backup.';
      notifyListeners();
      return null;
    }
    if (!_isOnline) {
      _error = 'Connect to the internet to restore tasks from the cloud.';
      notifyListeners();
      return null;
    }

    _error = null;
    _isSyncing = true;
    notifyListeners();

    try {
      final restoredTasks = await _taskRepository.restoreTasksBackup();
      await _taskRepository.replaceLocalSnapshot(tasks: restoredTasks);
      _tasks = _sortTasks(restoredTasks);
      _attachmentsByTaskId = const {};
      await _syncPlatformState();
      return restoredTasks.length;
    } catch (error) {
      _error = _friendlyError(error);
      return null;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<ReminderSystemReport> runReminderSystemCheck({
    bool scheduleTestReminder = true,
  }) async {
    _error = null;
    final report = await _notifications.runReminderHealthCheck(
      _tasks,
      enabled: _settings.notificationsEnabled,
      scheduleTestReminder: scheduleTestReminder,
    );
    _lastReminderReport = report;
    notifyListeners();
    return report;
  }

  Future<void> refreshSmartWidget() => _syncPlatformState();

  Future<void> pinSmartWidget() => _widgets.requestPinWidget();

  Future<bool> canPinSmartWidget() => _widgets.isPinWidgetSupported();

  void _setLoading(bool value, {bool notify = true}) {
    _isLoading = value;
    if (notify) {
      notifyListeners();
    }
  }

  List<TaskItem> _sortTasks(List<TaskItem> tasks) {
    final sorted = [...tasks];
    sorted.sort((left, right) {
      if (left.completed != right.completed) {
        return left.completed ? 1 : -1;
      }
      return left.dueDate.compareTo(right.dueDate);
    });
    return sorted;
  }

  List<TaskItem> _filterTasksByTab(
    List<TaskItem> tasks,
    TaskFilterTab tab,
  ) {
    final today = _dateOnly(DateTime.now());
    switch (tab) {
      case TaskFilterTab.today:
        return tasks
            .where((task) => _dateOnly(task.dueDate) == today)
            .toList(growable: false);
      case TaskFilterTab.upcoming:
        return tasks
            .where((task) => _dateOnly(task.dueDate).isAfter(today))
            .toList(growable: false);
      case TaskFilterTab.completed:
        return tasks.where((task) => task.completed).toList(growable: false);
      case TaskFilterTab.history:
        return tasks
            .where((task) => _dateOnly(task.dueDate).isBefore(today) && !task.completed)
            .toList(growable: false);
    }
  }

  double _tabCompletionRate(TaskFilterTab tab) {
    final filtered = _filterTasksByTab(_tasks, tab);
    if (filtered.isEmpty) {
      return 0;
    }
    final completed = filtered.where((task) => task.completed).length;
    return completed / filtered.length;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Map<String, List<TaskAttachment>> _groupAttachmentsByTask(
    List<TaskAttachment> attachments,
  ) {
    final grouped = <String, List<TaskAttachment>>{};
    for (final attachment in attachments) {
      grouped.putIfAbsent(attachment.taskId, () => []).add(attachment);
    }
    return grouped.map(
      (taskId, items) =>
          MapEntry(taskId, List<TaskAttachment>.unmodifiable(items)),
    );
  }

  Map<String, List<TaskAttachment>> _mergeTaskAttachments(
    Map<String, List<TaskAttachment>> source,
    String taskId,
    List<TaskAttachment> attachments,
  ) {
    if (attachments.isEmpty) {
      return source;
    }

    final merged = Map<String, List<TaskAttachment>>.from(source);
    final current = merged[taskId] ?? const [];
    merged[taskId] = List<TaskAttachment>.unmodifiable([
      ...current,
      ...attachments,
    ]);
    return merged;
  }

  AssistantMessage _fallbackAssistantMessage(String prompt) {
    final preview = _buildPreview(prompt);
    return AssistantMessage(
      id: 'local-ai-${DateTime.now().microsecondsSinceEpoch}',
      role: AssistantRole.assistant,
      content: "I've prepared a task draft. Confirm it if it looks right.",
      preview: preview,
      createdAt: DateTime.now(),
    );
  }

  AssistantTaskPreview _buildPreview(String prompt) {
    final lowered = prompt.toLowerCase();
    final now = DateTime.now();
    final dueDate = lowered.contains('today')
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day + 1);
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
      dateLabel: relativeDueLabel(dueDate),
      dateValue: dueDate.toIso8601String(),
      timeLabel: formatTimeOfDayLabel(dueTime),
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
    final period = match.group(3)!;

    if (period == 'pm' && hour != 12) {
      hour += 12;
    } else if (period == 'am' && hour == 12) {
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  DateTime _previewDate(String dateValue) {
    final parsed = DateTime.tryParse(dateValue);
    if (parsed == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  TimeOfDay _previewTime(String timeValue) {
    final parts = timeValue.split(':');
    if (parts.length != 2) {
      return const TimeOfDay(hour: 19, minute: 0);
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return const TimeOfDay(hour: 19, minute: 0);
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _friendlyError(Object error) {
  return friendlyErrorMessage(error, baseUrl: SupabaseService.baseUrl);
  }

  Future<void> _syncPlatformState() async {
    await _notifications.syncTaskReminders(
      _tasks,
      enabled: _settings.notificationsEnabled,
    );
    await _widgets.sync(
      tasks: _tasks,
      productivityScore: productivityScore,
      completionRate: completionRate,
      pendingTasks: pendingTasks,
      profile: _profile,
    );
  }

  Future<void> _clearPlatformState() async {
    await _notifications.syncTaskReminders(const [], enabled: false);
    await _widgets.clear();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _connectivity.dispose();
    super.dispose();
  }
}

class TodoAppScope extends InheritedNotifier<TodoAppController> {
  const TodoAppScope({
    super.key,
    required TodoAppController controller,
    required super.child,
  }) : super(notifier: controller);

  static TodoAppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TodoAppScope>();
    assert(scope != null, 'TodoAppScope is missing in the widget tree.');
    return scope!.notifier!;
  }
}

String formatFullDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatShortCalendarDate(DateTime date) {
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
  if (date.year == DateTime.now().year) {
    return base;
  }
  return '$base, ${date.year}';
}

String relativeDueLabel(DateTime date) {
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
  return formatShortCalendarDate(date);
}

String formatRelativeAndAbsoluteDate(DateTime date) {
  final relative = relativeDueLabel(date);
  final absolute = formatShortCalendarDate(date);
  if (relative == absolute) {
    return absolute;
  }
  return '$relative • $absolute';
}

String formatTaskScheduleLabel(TaskItem task) {
  final dateLabel = formatRelativeAndAbsoluteDate(task.dueDate);
  if (task.dueTime == null) {
    return dateLabel;
  }
  return '$dateLabel • ${formatTimeOfDayLabel(task.dueTime!)}';
}

bool isTaskOverdue(TaskItem task, {DateTime? now}) {
  if (task.completed) {
    return false;
  }

  final current = now ?? DateTime.now();
  final dueDate = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
  if (task.dueTime == null) {
    return dueDate.isBefore(DateTime(current.year, current.month, current.day));
  }

  final dueAt = DateTime(
    task.dueDate.year,
    task.dueDate.month,
    task.dueDate.day,
    task.dueTime!.hour,
    task.dueTime!.minute,
  );
  return dueAt.isBefore(current);
}

String greetingForNow({DateTime? now, String? name}) {
  final current = now ?? DateTime.now();
  final salutation = switch (current.hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };
  final trimmedName = name?.trim() ?? '';
  if (trimmedName.isEmpty) {
    return salutation;
  }
  return '$salutation, ${trimmedName.split(' ').first}';
}

String formatTimeOfDayLabel(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String friendlyErrorMessage(Object error, {required String baseUrl}) {
  final rawMessage = error.toString().replaceFirst('Exception: ', '').trim();
  final extractedMessage = _extractErrorMessage(rawMessage);
  final normalized = extractedMessage.toLowerCase();
  final rawNormalized = rawMessage.toLowerCase();

  if (normalized.contains('invalid login credentials') ||
      normalized.contains('invalid_credentials')) {
    return 'Invalid email or password.';
  }

  if (normalized.contains('email not confirmed') ||
      normalized.contains('email_not_confirmed')) {
    return 'Email not confirmed. Check your inbox, confirm the account, then sign in.';
  }

  if (normalized.contains('user already registered') ||
      normalized.contains('already_registered')) {
    return 'An account with this email already exists.';
  }

  if (_looksLikeConnectivityIssue(rawNormalized)) {
    return 'Unable to reach Supabase at $baseUrl. Check your internet connection and Supabase project settings.';
  }

  return extractedMessage.isEmpty ? 'Something went wrong.' : extractedMessage;
}

String _extractErrorMessage(String message) {
  final decodedMessage = _decodeJsonError(message);
  if (decodedMessage != null) {
    return decodedMessage;
  }

  final wrappedMessageMatch = RegExp(
    r'message:\s*(.+?)(?:,\s(?:statusCode|code|details|hint):|\)$)',
    caseSensitive: false,
  ).firstMatch(message);
  if (wrappedMessageMatch != null) {
    return wrappedMessageMatch.group(1)!.trim();
  }

  return message;
}

String? _decodeJsonError(String message) {
  final jsonStart = message.indexOf('{');
  final jsonEnd = message.lastIndexOf('}');
  if (jsonStart == -1 || jsonEnd <= jsonStart) {
    return null;
  }

  final candidate = message.substring(jsonStart, jsonEnd + 1);
  try {
    final decoded = jsonDecode(candidate);
    if (decoded is Map<String, dynamic>) {
      final directMessage = decoded['message'] ?? decoded['error'];
      if (directMessage is String && directMessage.trim().isNotEmpty) {
        return directMessage.trim();
      }
    }
  } catch (_) {
    // Fall through to the original message.
  }

  return null;
}

bool _looksLikeConnectivityIssue(String normalizedMessage) {
  const connectivityMarkers = [
    'failed to fetch',
    'connection refused',
    'socketexception',
    'failed host lookup',
    'timed out',
    'timeout',
    'handshakeexception',
    'network is unreachable',
    'authretryablefetchexception',
  ];

  return connectivityMarkers.any(normalizedMessage.contains);
}

String _formatTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

enum TaskFilterTab { today, upcoming, completed, history }

extension TaskFilterTabX on TaskFilterTab {
  String get label {
    switch (this) {
      case TaskFilterTab.today:
        return 'Today';
      case TaskFilterTab.upcoming:
        return 'Upcoming';
      case TaskFilterTab.completed:
        return 'Completed';
      case TaskFilterTab.history:
        return 'History';
    }
  }
}

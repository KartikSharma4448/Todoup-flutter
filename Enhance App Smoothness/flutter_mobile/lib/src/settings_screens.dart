import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'legal_support_screens.dart';
import 'smart_widget_screens.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  static const routeName = '/profile/edit';

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _occupationController;
  late final TextEditingController _bioController;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }

    final profile = TodoAppScope.of(context).profile;
    _nameController = TextEditingController(text: profile.name);
    _emailController = TextEditingController(text: profile.email);
    _phoneController = TextEditingController(text: profile.phone);
    _locationController = TextEditingController(text: profile.location);
    _occupationController = TextEditingController(text: profile.occupation);
    _bioController = TextEditingController(text: profile.bio);
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _occupationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);
    final controller = TodoAppScope.of(context);
    await controller.updateProfile(
      controller.profile.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
        occupation: _occupationController.text.trim(),
        bio: _bioController.text.trim(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);
    if (controller.error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(controller.error!)));
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              title: 'Edit Profile',
              leading: _BackButton(onTap: () => Navigator.of(context).pop()),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                GlassCard(
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Profile details sync directly with your account.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.60),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _occupationController,
                        decoration: const InputDecoration(
                          labelText: 'Occupation',
                          prefixIcon: Icon(Icons.work_outline_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: TextField(
                    controller: _bioController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'About',
                      hintText: 'Tell us about yourself...',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MutedButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryGradientButton(
                        label: _saving ? 'Saving...' : 'Save Changes',
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut(BuildContext context) async {
    final controller = TodoAppScope.of(context);
    try {
      await controller.logout();
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(controller.error ?? 'Unable to sign out.')),
        );
    }
  }

  Future<void> _exportData(BuildContext context) async {
    final controller = TodoAppScope.of(context);
    await Clipboard.setData(ClipboardData(text: controller.exportUserData()));

    if (!context.mounted) {
      return;
    }

    _showMessage(context, 'Your account data has been copied as JSON.');
  }

  Future<void> _uploadCloudBackup(BuildContext context) async {
    final controller = TodoAppScope.of(context);
    final success = await controller.uploadTasksToCloud();
    if (!context.mounted) {
      return;
    }

    _showMessage(
      context,
      success
          ? 'All local tasks were uploaded to your cloud backup.'
          : controller.error ?? 'Unable to upload the cloud backup.',
    );
  }

  Future<void> _restoreCloudBackup(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Restore cloud backup?'),
              content: const Text(
                'This replaces the tasks on this device with the last backup stored in the cloud. Local attachment files are not restored yet.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Restore'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return;
    }

    final controller = TodoAppScope.of(context);
    final restoredCount = await controller.restoreTasksFromCloud();
    if (!context.mounted) {
      return;
    }

    _showMessage(
      context,
      restoredCount == null
          ? controller.error ?? 'Unable to restore your cloud backup.'
          : 'Restored $restoredCount task${restoredCount == 1 ? '' : 's'} from the cloud.',
    );
  }

  Future<void> _runReminderCheck(BuildContext context) async {
    final controller = TodoAppScope.of(context);

    try {
      final report = await controller.runReminderSystemCheck();
      if (!context.mounted) {
        return;
      }

      final details = <String>[
        'Reminders enabled: ${report.notificationsEnabled ? 'Yes' : 'No'}',
        'Tasks with reminders: ${report.reminderTasks}',
        'Notifications currently scheduled: ${report.scheduledNotifications}',
        'Exact alarms available: ${report.canUseExactAlarms ? 'Yes' : 'No'}',
      ];
      if (report.diagnosticReminderAt != null) {
        details.add(
          'Test alert scheduled for ${formatTimeOfDayLabel(TimeOfDay.fromDateTime(report.diagnosticReminderAt!))}.',
        );
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Reminder System Check'),
            content: Text(details.join('\n')),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showMessage(context, error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete account?'),
              content: const Text(
                'This removes your profile, tasks, and assistant history from the backend.',
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

    if (!confirmed || !context.mounted) {
      return;
    }

    final controller = TodoAppScope.of(context);
    final success = await controller.deleteAccount();
    if (!context.mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(controller.error ?? 'Unable to delete account.'),
          ),
        );
    }
  }

  Future<void> _upgradePremium(BuildContext context) async {
    final controller = TodoAppScope.of(context);
    await controller.unlockPremium();
    if (!context.mounted) {
      return;
    }
    _showMessage(
      context,
      controller.isPremium
          ? 'Premium unlocked. Enjoy the pro features!'
          : 'Premium status updated.',
    );
  }

  String _cloudBackupLabel(TodoAppController controller) {
    final backupAt = controller.lastCloudBackupAt;
    if (backupAt == null) {
      return controller.isOnline
          ? 'Tasks stay on this device until you upload them manually.'
          : 'Reconnect whenever you want to upload or restore a backup.';
    }

    return 'Last upload: ${formatRelativeAndAbsoluteDate(backupAt)} • ${formatTimeOfDayLabel(TimeOfDay.fromDateTime(backupAt))}';
  }

  String _reminderSummary(TodoAppController controller) {
    final report = controller.lastReminderReport;
    if (report == null) {
      return 'Run a system check to verify notifications, alarms, and scheduled reminders on this phone.';
    }

    final testText = report.diagnosticReminderAt == null
        ? 'No test reminder scheduled.'
        : 'Test reminder at ${formatTimeOfDayLabel(TimeOfDay.fromDateTime(report.diagnosticReminderAt!))}.';
    return 'Eligible tasks: ${report.reminderTasks} • Scheduled: ${report.scheduledNotifications}. $testText';
  }

  @override
  Widget build(BuildContext context) {
    final controller = TodoAppScope.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              title: 'Settings',
              leading: _BackButton(onTap: () => Navigator.of(context).pop()),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  controller.isPremium
                                      ? 'Premium Active'
                                      : 'Upgrade to Premium',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  controller.isPremium
                                      ? 'Unlimited attachments, AI drafts, smart widgets.'
                                      : 'Unlock unlimited attachments, AI drafting, and widget extras.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withValues(alpha: 0.68),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _PremiumPerk(label: 'Unlimited attachments'),
                          _PremiumPerk(label: 'AI assistant drafts'),
                          _PremiumPerk(label: 'Home-screen widgets'),
                          _PremiumPerk(label: 'Cloud backup vault'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      PrimaryGradientButton(
                        label: controller.isPremium
                            ? 'Premium Enabled'
                            : 'Unlock Premium',
                        icon: controller.isPremium
                            ? Icons.verified_rounded
                            : Icons.lock_open_rounded,
                        onPressed:
                            controller.isPremium ? null : () => _upgradePremium(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notifications'),
                    subtitle: const Text('Local reminders stored on this device'),
                    secondary: const Icon(Icons.notifications_active_rounded),
                    value: controller.notificationsEnabled,
                    onChanged: (value) => controller.setNotifications(value),
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.cloud_upload_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Offline-First Task Vault',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _cloudBackupLabel(controller),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withValues(alpha: 0.68),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.mutedDark.withValues(alpha: 0.36)
                              : AppColors.mutedLight,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          controller.isOnline
                              ? 'Tasks now run fully offline. Use Upload to Cloud only when you want a backup, and Restore after reinstalling the app.'
                              : 'You are offline right now. Your tasks still work normally; cloud backup will be available again when the internet returns.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryGradientButton(
                              label: controller.isSyncing
                                  ? 'Uploading...'
                                  : 'Upload to Cloud',
                              icon: Icons.cloud_upload_rounded,
                              onPressed: controller.isSyncing
                                  ? null
                                  : () => _uploadCloudBackup(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MutedButton(
                              label: controller.isSyncing
                                  ? 'Please wait'
                                  : 'Restore Backup',
                              onPressed: controller.isSyncing
                                  ? () {}
                                  : () => _restoreCloudBackup(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Cloud restore currently brings back your tasks. Local file attachments stay on the device and are not part of the backup yet.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.72),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.alarm_on_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reminder & Alarm Check',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _reminderSummary(controller),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withValues(alpha: 0.68),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      PrimaryGradientButton(
                        label: 'Run Reminder Test',
                        icon: Icons.notifications_active_rounded,
                        onPressed: () => _runReminderCheck(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(SmartWidgetScreen.routeName),
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.widgets_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text('Smart Widgets'),
                    subtitle: Text('Daily score widget and reminder setup'),
                    trailing: Icon(Icons.chevron_right_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  onTap: () => _exportData(context),
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.download_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text('Export Data'),
                    subtitle: Text('Copy your tasks and profile as JSON'),
                    trailing: Icon(Icons.chevron_right_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.support_agent_rounded),
                        title: const Text('Support'),
                        subtitle: const Text(
                          'Help desk and support contact details',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(SupportScreen.routeName),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        subtitle: const Text(
                          'Review how ToDoUp handles your data',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(PrivacyPolicyScreen.routeName),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Terms of Service'),
                        subtitle: const Text('Review application usage terms'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(TermsOfServiceScreen.routeName),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.gavel_rounded),
                        title: const Text('Open Source Licenses'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'ToDoUp',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  child: const Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.info_outline_rounded),
                        title: Text('App Information'),
                      ),
                      _InfoRow(label: 'Version', value: '1.1.0'),
                      SizedBox(height: 8),
                      _InfoRow(label: 'Build', value: '2026.04.02'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassCard(
                  onTap: () => _deleteAccount(context),
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.destructive,
                    ),
                    title: Text(
                      'Delete Account',
                      style: TextStyle(color: AppColors.destructive),
                    ),
                    subtitle: Text('Permanently remove your data'),
                  ),
                ),
                const SizedBox(height: 16),
                MutedButton(
                  label: 'Sign Out',
                  onPressed: () => _signOut(context),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPerk extends StatelessWidget {
  const _PremiumPerk({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.mutedDark.withValues(alpha: 0.30)
            : AppColors.mutedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

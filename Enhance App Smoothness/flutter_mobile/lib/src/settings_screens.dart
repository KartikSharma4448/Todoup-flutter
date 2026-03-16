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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Your account data has been copied as JSON.'),
        ),
      );
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            controller.isPremium
                ? 'Premium unlocked. Enjoy the pro features!'
                : 'Premium status updated.',
          ),
        ),
      );
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
                                      : 'Unlock unlimited attachments, AI drafting, and widget sync.',
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
                          _PremiumPerk(label: 'Priority sync'),
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
                    subtitle: const Text('Task reminders and updates'),
                    secondary: const Icon(Icons.notifications_active_rounded),
                    value: controller.notificationsEnabled,
                    onChanged: (value) => controller.setNotifications(value),
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
                      _InfoRow(label: 'Version', value: '1.0.0'),
                      SizedBox(height: 8),
                      _InfoRow(label: 'Build', value: '2026.03.06'),
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

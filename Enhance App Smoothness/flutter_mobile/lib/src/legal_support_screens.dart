import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'widgets.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const routeName = '/support';
  static const supportEmail = 'support@todoup.app';
  static const responseWindow = '24 to 48 business hours';

  Future<void> _copySupportEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Support email copied to clipboard.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return _LegalScreenFrame(
      title: 'Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'Contact the ToDoUp support desk for account issues, billing questions, task-sync problems, or release support.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                const _DetailRow(label: 'Support email', value: supportEmail),
                const SizedBox(height: 10),
                const _DetailRow(
                  label: 'Response target',
                  value: responseWindow,
                ),
                const SizedBox(height: 10),
                const _DetailRow(
                  label: 'Recommended',
                  value:
                      'Include your device type, app version, and issue steps.',
                ),
                const SizedBox(height: 16),
                PrimaryGradientButton(
                  label: 'Copy Support Email',
                  expanded: false,
                  onPressed: () => _copySupportEmail(context),
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
                  'Before contacting support',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const _ChecklistItem(
                  text:
                      'Refresh the dashboard and confirm your internet connection.',
                ),
                const _ChecklistItem(
                  text:
                      'Use Export Data from Settings if you need to attach account details.',
                ),
                const _ChecklistItem(
                  text:
                      'Mention whether the issue happens on Android, iPhone, or web.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const routeName = '/legal/privacy';

  static const List<({String heading, String body})> _sections = [
    (
      heading: 'Scope',
      body:
          'ToDoUp collects only the information required to create your account, sync your tasks, and keep your settings available across supported devices.',
    ),
    (
      heading: 'Data we store',
      body:
          'This includes your profile information, tasks, assistant history, and app preferences. Authentication is handled by Supabase Auth and application records are stored in Supabase Postgres.',
    ),
    (
      heading: 'How data is used',
      body:
          'Your data is used to sign you in, show your dashboard, process task updates, and maintain assistant-generated task drafts. Data is not sold to third parties.',
    ),
    (
      heading: 'Retention and deletion',
      body:
          'You can export your data at any time from Settings. You can also delete your account from Settings, which removes your profile, tasks, and assistant history from the application backend.',
    ),
    (
      heading: 'Security',
      body:
          'ToDoUp relies on row-level security, authenticated access controls, and environment-managed release secrets. Production launch should also include backups, access reviews, and crash monitoring.',
    ),
    (
      heading: 'Support contact',
      body:
          'For privacy requests or account support, contact support@todoup.app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'Privacy Policy',
      lastUpdated: 'March 6, 2026',
      sections: _sections,
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const routeName = '/legal/terms';

  static const List<({String heading, String body})> _sections = [
    (
      heading: 'Use of service',
      body:
          'ToDoUp is provided for personal productivity and task management. You are responsible for the accuracy of the content you store in the app.',
    ),
    (
      heading: 'Accounts',
      body:
          'You are responsible for keeping your credentials secure and for activity that occurs under your account. Email confirmation and password-recovery flows are handled through Supabase Auth.',
    ),
    (
      heading: 'Acceptable use',
      body:
          'Do not use the service for unlawful content, abuse, credential attacks, or attempts to bypass access controls. Workspace and business features should respect assigned permissions once enabled.',
    ),
    (
      heading: 'Service changes',
      body:
          'Features may be updated, expanded, or removed as the product evolves. Premium and business functionality may require separate billing or subscription terms when enabled.',
    ),
    (
      heading: 'Termination',
      body:
          'You may stop using the service at any time. The application owner may suspend or terminate accounts that violate these terms or threaten platform security.',
    ),
    (
      heading: 'Liability',
      body:
          'The service is provided on an as-is basis unless separate commercial agreements apply. Production deployments should define final commercial and legal terms before public release.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'Terms of Service',
      lastUpdated: 'March 6, 2026',
      sections: _sections,
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  final String title;
  final String lastUpdated;
  final List<({String heading, String body})> sections;

  @override
  Widget build(BuildContext context) {
    return _LegalScreenFrame(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last updated: $lastUpdated',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.heading,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      section.body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalScreenFrame extends StatelessWidget {
  const _LegalScreenFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GradientHeader(
              title: title,
              leading: _LegalBackButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      ),
    );
  }
}

class _LegalBackButton extends StatelessWidget {
  const _LegalBackButton({required this.onTap});

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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.60),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

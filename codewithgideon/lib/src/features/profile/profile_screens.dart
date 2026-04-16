import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/data/demo_data.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/states/app_state_widgets.dart';
import '../home/models/student_dashboard_snapshot.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final dashboardState = ref.watch(dashboardSnapshotProvider);

    return dashboardState.when(
      loading: () => const DoubleBackToExitScope(
        child: SafeArea(
          top: false,
          child: AppLoadingState(
            compact: true,
            title: 'Loading your profile...',
            message: 'Syncing your student details and cohort access.',
          ),
        ),
      ),
      error: (error, _) => DoubleBackToExitScope(
        child: SafeArea(
          top: false,
          child: AppErrorState(
            compact: true,
            title: 'Profile unavailable',
            message: 'We could not load your profile right now.',
            onRetry: () => ref.refresh(dashboardSnapshotProvider),
          ),
        ),
      ),
      data: (dashboard) {
        final profile = dashboard.profile;
        final initials = _initialsFromName(profile.fullName);
        final progressPercent = (dashboard.progressPercent * 100).round();
        final joinedLabel = DateFormat('MMM d, y').format(profile.joinedAt);
        final memberStatus = dashboard.hasAnyPending
            ? 'Pending access'
            : 'Active member';
        final memberStatusColor = dashboard.hasAnyPending
            ? AppColors.orangeLight
            : AppColors.tealLight;

        return DoubleBackToExitScope(
          child: Stack(
            children: [
              const AppAtmosphereBackdrop(),
              SafeArea(
                top: false,
                bottom: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 30, 22, 130),
                  children: [
                    PremiumPageHeader(
                      title: 'Profile',
                      subtitle:
                          'Your learning identity, cohort access, and account details in one premium view.',
                      trailing: PremiumIconButton(
                        icon: Icons.settings_rounded,
                        onTap: () => context.push('/settings'),
                      ),
                    ),
                    const Gap(14),
                    AppCard(
                      padding: EdgeInsets.zero,
                      radius: 34,
                      color: Theme.of(
                        context,
                      ).cardColor.withValues(alpha: 0.88),
                      shadow: AppShadows.premium,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.deepBlueDark,
                              AppColors.deepBlue,
                              AppColors.tealDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(34),
                        ),
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials.isEmpty ? 'C' : initials,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                const Gap(16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _ProfileHeadlinePill(
                                        label: memberStatus,
                                        color: memberStatusColor,
                                      ),
                                      const Gap(12),
                                      Text(
                                        profile.fullName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const Gap(6),
                                      Text(
                                        profile.email,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.76,
                                              ),
                                            ),
                                      ),
                                      const Gap(4),
                                      Text(
                                        '${dashboard.path.title} • ${dashboard.activeCohort.label}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.68,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Gap(12),
                                PremiumIconButton(
                                  icon: Icons.edit_outlined,
                                  isDark: true,
                                  onTap: () => context.push('/profile/edit'),
                                ),
                              ],
                            ),
                            const Gap(22),
                            AdaptiveWrap(
                              minItemWidth: 110,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ProfileHeroStat(
                                  label: 'Weeks unlocked',
                                  value:
                                      '${dashboard.paidWeeks}/${dashboard.totalProgramWeeks}',
                                  accent: AppColors.orangeLight,
                                ),
                                _ProfileHeroStat(
                                  label: 'Progress',
                                  value: '$progressPercent%',
                                  accent: AppColors.tealLight,
                                ),
                                _ProfileHeroStat(
                                  label: 'Email',
                                  value: authState.isEmailVerified
                                      ? 'Verified'
                                      : 'Pending',
                                  accent: authState.isEmailVerified
                                      ? AppColors.tealLight
                                      : AppColors.orangeLight,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(16),
                    AppCard(
                      radius: 30,
                      color: Theme.of(
                        context,
                      ).cardColor.withValues(alpha: 0.84),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Account Snapshot',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Gap(8),
                          Text(
                            'A polished view of the details your mentors and admin team use to support your journey.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _muted(context),
                                  height: 1.55,
                                ),
                          ),
                          const Gap(18),
                          _ProfileDetailRow(
                            label: 'Phone',
                            value: profile.phone,
                            icon: Icons.call_outlined,
                          ),
                          const Gap(14),
                          _ProfileDetailRow(
                            label: 'Joined',
                            value: joinedLabel,
                            icon: Icons.event_available_rounded,
                          ),
                          const Gap(14),
                          _ProfileDetailRow(
                            label: 'Cohort',
                            value: dashboard.activeCohort.label,
                            icon: Icons.groups_rounded,
                          ),
                          const Gap(14),
                          _ProfileDetailRow(
                            label: 'Email status',
                            value: authState.isEmailVerified
                                ? 'Verified and secured'
                                : 'Verification pending',
                            icon: authState.isEmailVerified
                                ? Icons.verified_user_rounded
                                : Icons.mark_email_unread_outlined,
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    AppCard(
                      radius: 30,
                      color: Theme.of(
                        context,
                      ).cardColor.withValues(alpha: 0.84),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Learning Access',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                '$progressPercent%',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.tealDark,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                          const Gap(8),
                          Text(
                            dashboard.hasAnyPending
                                ? 'Your profile is saved. Finish approval or payment to unlock your full cohort experience.'
                                : 'Your access is live, your cohort is mapped, and your premium learning path is ready to use.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _muted(context),
                                  height: 1.55,
                                ),
                          ),
                          const Gap(18),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: dashboard.progressPercent.clamp(0, 1),
                              minHeight: 10,
                              backgroundColor: AppColors.muted,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.teal,
                              ),
                            ),
                          ),
                          const Gap(16),
                          AdaptiveWrap(
                            minItemWidth: 150,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _InfoTile(
                                label: 'Path',
                                value: dashboard.path.title,
                                icon: Icons.route_rounded,
                              ),
                              _InfoTile(
                                label: 'Remaining Weeks',
                                value: '${dashboard.remainingWeeks}',
                                icon: Icons.timelapse_rounded,
                              ),
                              _InfoTile(
                                label: 'Billing',
                                value: dashboard.hasAnyPending
                                    ? 'Pending'
                                    : 'In good standing',
                                icon: Icons.workspace_premium_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    AppCard(
                      radius: 28,
                      color: Theme.of(
                        context,
                      ).cardColor.withValues(alpha: 0.82),
                      child: Column(
                        children: [
                          _ProfileAction(
                            icon: Icons.edit_outlined,
                            title: 'Edit profile',
                            subtitle: 'Update your name and phone number',
                            onTap: () => context.push('/profile/edit'),
                          ),
                          const Divider(height: 22),
                          _ProfileAction(
                            icon: Icons.forum_outlined,
                            title: 'Community inbox',
                            subtitle:
                                'Review mentor replies and cohort announcements',
                            onTap: () => context.push('/community/messages'),
                          ),
                          const Divider(height: 22),
                          _ProfileAction(
                            icon: Icons.workspace_premium_outlined,
                            title: 'Certificates',
                            subtitle: 'See badges and progress milestones',
                            onTap: () => context.push('/certificates'),
                          ),
                          const Divider(height: 22),
                          _ProfileAction(
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            subtitle:
                                'Notifications, theme, and app preferences',
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
          children: [
            PremiumPageHeader(
              title: 'Achievements',
              subtitle: 'Your milestones, certificates, and earned progress.',
              leading: PremiumIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
            ),
            const Gap(16),
            for (final item in DemoData.certificates) ...[
              AppCard(
                radius: 28,
                color: Theme.of(context).cardColor.withValues(alpha: 0.82),
                child: Column(
                  children: [
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      'Instructor: ${item.instructor}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: _muted(context)),
                    ),
                    const Gap(4),
                    Text(
                      'Issued ${item.issueDate}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: _muted(context)),
                    ),
                  ],
                ),
              ),
              const Gap(12),
            ],
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authControllerProvider);
    final dashboard = _dashboardSnapshotOrNull(
      ref.read(dashboardSnapshotProvider),
    );
    _nameController = TextEditingController(
      text: dashboard?.profile.fullName ?? authState.session?.email ?? '',
    );
    _phoneController = TextEditingController(
      text: dashboard?.profile.phone ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = ref.read(authControllerProvider).session;
    if (session == null) return;
    setState(() => _isSaving = true);
    await ref
        .read(studentRepositoryProvider)
        .updateStudentProfile(
          uid: session.uid,
          fullName: _nameController.text,
          phone: _phoneController.text,
        );
    ref.invalidate(dashboardSnapshotProvider);
    if (!mounted) return;
    setState(() => _isSaving = false);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboardSnapshotOrNull(
      ref.watch(dashboardSnapshotProvider),
    );

    return AppScreen(
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
          children: [
            PremiumPageHeader(
              title: 'Edit Profile',
              subtitle: 'Keep your personal details polished and up to date.',
              leading: PremiumIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => context.pop(),
              ),
            ),
            const Gap(20),
            AppCard(
              radius: 28,
              color: Theme.of(context).cardColor.withValues(alpha: 0.82),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(label: 'Full name', controller: _nameController),
                  const Gap(16),
                  AppTextField(
                    label: 'Phone number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const Gap(16),
                  Text(
                    'Email',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      dashboard?.profile.email ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: _muted(context)),
                    ),
                  ),
                  const Gap(20),
                  AppButton(
                    label: 'Save changes',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final authState = ref.watch(authControllerProvider);
    final dashboard = _dashboardSnapshotOrNull(
      ref.watch(dashboardSnapshotProvider),
    );
    final email = dashboard?.profile.email ?? authState.session?.email ?? '';
    final currentPath = dashboard?.path.title ?? 'Continue registration';
    final cohortLabel =
        dashboard?.activeCohort.label ?? 'No cohort assigned yet';

    return AppScreen(
      body: Stack(
        children: [
          const AppAtmosphereBackdrop(),
          SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
              children: [
                PremiumPageHeader(
                  title: 'Settings',
                  subtitle:
                      'Shape your learning environment, notifications, and account comfort from one polished space.',
                  leading: PremiumIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                ),
                const Gap(18),
                AppCard(
                  radius: 32,
                  color: Theme.of(context).cardColor.withValues(alpha: 0.84),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandHeroLockup(
                        markSize: 84,
                        wordmarkHeight: 24,
                        wordmarkColor: AppColors.foreground,
                        center: false,
                      ),
                      const Gap(18),
                      Text(
                        'Everything here is tuned to keep your classes, updates, and payments feeling calm and predictable.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _muted(context),
                          height: 1.6,
                        ),
                      ),
                      const Gap(18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SettingsBadge(
                            icon: Icons.notifications_active_outlined,
                            label: settings.notifications
                                ? 'Alerts on'
                                : 'Alerts paused',
                          ),
                          _SettingsBadge(
                            icon: settings.darkMode
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            label: settings.darkMode
                                ? 'Dark appearance'
                                : 'Light appearance',
                          ),
                          const _SettingsBadge(
                            icon: Icons.wallet_rounded,
                            label: 'Pay as you go',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                AppCard(
                  radius: 30,
                  color: Theme.of(context).cardColor.withValues(alpha: 0.84),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Experience',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        'Manage how the app feels day to day.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: _muted(context)),
                      ),
                      const Gap(18),
                      _SettingsToggleTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        subtitle:
                            'Receive live class updates, approvals, and admin replies.',
                        accent: AppColors.teal,
                        trailing: Switch.adaptive(
                          value: settings.notifications,
                          onChanged: (_) => controller.toggleNotifications(),
                        ),
                      ),
                      const Gap(14),
                      _SettingsToggleTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'Appearance',
                        subtitle: settings.darkMode
                            ? 'Dark theme is active for a low-glare experience.'
                            : 'Light theme is active for a crisp studio feel.',
                        accent: AppColors.deepBlueLight,
                        trailing: Switch.adaptive(
                          value: settings.darkMode,
                          onChanged: (_) => controller.toggleDarkMode(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                AppCard(
                  radius: 30,
                  color: Theme.of(context).cardColor.withValues(alpha: 0.84),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Snapshot',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Gap(18),
                      _SettingsInfoRow(
                        label: 'Account email',
                        value: email.isEmpty ? 'Not available yet' : email,
                      ),
                      const Gap(14),
                      _SettingsInfoRow(
                        label: 'Current path',
                        value: currentPath,
                      ),
                      const Gap(14),
                      _SettingsInfoRow(label: 'Cohort', value: cohortLabel),
                      const Gap(14),
                      const _SettingsInfoRow(
                        label: 'Billing model',
                        value: 'Pay as you go or pay the full path upfront',
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                AppCard(
                  radius: 30,
                  color: Theme.of(context).cardColor.withValues(alpha: 0.84),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About The App',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Gap(10),
                      Text(
                        'CodeWithGideon is built for guided live learning with flexible payment options and steady mentor support.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _muted(context),
                          height: 1.6,
                        ),
                      ),
                      const Gap(16),
                      const _SettingsInfoRow(label: 'Version', value: '1.0.0'),
                    ],
                  ),
                ),
                const Gap(22),
                AppButton(
                  label: 'Logout',
                  variant: AppButtonVariant.danger,
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (!context.mounted) return;
                    context.go('/welcome');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkMuted.withValues(alpha: 0.82)
            : AppColors.muted.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.tealDark),
          const Gap(10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _muted(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeadlinePill extends StatelessWidget {
  const _ProfileHeadlinePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileHeroStat extends StatelessWidget {
  const _ProfileHeroStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.tealDark, size: 20),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _muted(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.tealDark),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: _muted(context)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.muted.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(4),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _muted(context)),
                ),
              ],
            ),
          ),
          const Gap(12),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsBadge extends StatelessWidget {
  const _SettingsBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.deepBlue.withValues(alpha: isDark ? 0.18 : 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.tealDark),
          const Gap(8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: _muted(context)),
          ),
        ),
        const Gap(14),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

Color _muted(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkMutedForeground
      : AppColors.mutedForeground;
}

String _initialsFromName(String value) {
  final parts = value
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .take(2);
  return parts.map((part) => part.trim().substring(0, 1).toUpperCase()).join();
}

StudentDashboardSnapshot? _dashboardSnapshotOrNull(
  AsyncValue<StudentDashboardSnapshot> value,
) {
  return value.maybeWhen(data: (snapshot) => snapshot, orElse: () => null);
}

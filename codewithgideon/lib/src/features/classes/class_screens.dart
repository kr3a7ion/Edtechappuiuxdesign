import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/state/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/states/app_state_widgets.dart';
import '../cohorts/models/cohort_session_model.dart';
import '../cohorts/presentation/session_status.dart';

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(classTabProvider);
    final search = ref.watch(classSearchProvider).trim().toLowerCase();
    final dashboardState = ref.watch(dashboardSnapshotProvider);

    return dashboardState.when(
      loading: () => const DoubleBackToExitScope(
        child: SafeArea(
          top: false,
          child: AppLoadingState(
            compact: true,
            title: 'Loading your classes...',
            message: 'Pulling in your latest published cohort sessions.',
          ),
        ),
      ),
      error: (error, _) => DoubleBackToExitScope(
        child: SafeArea(
          top: false,
          child: AppErrorState(
            compact: true,
            title: 'Classes unavailable',
            message: 'We could not load your class schedule right now.',
            onRetry: () => ref.refresh(dashboardSnapshotProvider),
          ),
        ),
      ),
      data: (dashboard) {
        final allSessions = dashboard.unlockedSessions.toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        final now = DateTime.now();
        final liveCount = allSessions.where((item) => item.isLive(now)).length;
        final recordingCount = allSessions
            .where(
              (item) =>
                  resolveSessionStatus(item).actionState ==
                  SessionActionState.watchRecording,
            )
            .length;
        final filtered = allSessions.where((session) {
          final tabMatches = switch (activeTab) {
            ClassTab.upcoming =>
              session.startsAt.isAfter(now) && !session.isLive(now),
            ClassTab.live => session.isLive(now),
            ClassTab.completed => session.endsAt.isBefore(now),
          };
          final searchMatches =
              search.isEmpty ||
              session.title.toLowerCase().contains(search) ||
              session.pathTitle.toLowerCase().contains(search) ||
              session.notes.toLowerCase().contains(search);
          return tabMatches && searchMatches;
        }).toList();

        return DoubleBackToExitScope(
          child: SafeArea(
            top: false,
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0E2348), Color(0xFF1F437C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: AppShadows.premium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PremiumPageHeader(
                            title: 'Classes',
                            subtitle:
                                'Stay on top of live sessions, upcoming lessons, and premium replay access from one polished schedule.',
                            onDark: true,
                          ),
                          const Gap(18),
                          AdaptiveWrap(
                            minItemWidth: 110,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _OverviewStatChip(
                                icon: PhosphorIconsDuotone.videoCamera,
                                label: 'Live',
                                value: '$liveCount',
                                tint: AppColors.teal,
                                onDark: true,
                              ),
                              _OverviewStatChip(
                                icon: PhosphorIconsDuotone.clockCountdown,
                                label: 'Upcoming',
                                value:
                                    '${allSessions.where((item) => item.startsAt.isAfter(now)).length}',
                                tint: AppColors.tealLight,
                                onDark: true,
                              ),
                              _OverviewStatChip(
                                icon: PhosphorIconsDuotone.playCircle,
                                label: 'Recordings',
                                value: '$recordingCount',
                                tint: AppColors.orangeLight,
                                onDark: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
                    child: Row(
                      children: [
                        _ClassTabChip(
                          label: 'Upcoming',
                          active: activeTab == ClassTab.upcoming,
                          onTap: () =>
                              ref.read(classTabProvider.notifier).state =
                                  ClassTab.upcoming,
                        ),
                        const Gap(10),
                        _ClassTabChip(
                          label: 'Live',
                          active: activeTab == ClassTab.live,
                          badge: allSessions
                              .where((item) => item.isLive(now))
                              .length,
                          onTap: () =>
                              ref.read(classTabProvider.notifier).state =
                                  ClassTab.live,
                        ),
                        const Gap(10),
                        _ClassTabChip(
                          label: 'Completed',
                          active: activeTab == ClassTab.completed,
                          onTap: () =>
                              ref.read(classTabProvider.notifier).state =
                                  ClassTab.completed,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 130),
                  sliver: filtered.isEmpty
                      ? SliverToBoxAdapter(
                          child: AppEmptyState(
                            title: allSessions.isEmpty
                                ? 'No classes available yet'
                                : 'No classes match this view',
                            message: allSessions.isEmpty
                                ? 'Your dashboard is live, but no published sessions have been unlocked in Firestore yet.'
                                : 'Try another search or switch between upcoming, live, and completed.',
                            icon: Icons.event_busy_outlined,
                            action: AppButton(
                              label: 'Reset Filters',
                              expanded: false,
                              onPressed: () {
                                ref.read(classSearchProvider.notifier).state =
                                    '';
                                ref.read(classTabProvider.notifier).state =
                                    ClassTab.upcoming;
                              },
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final session = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child:
                                  _ClassListCard(
                                        session: session,
                                        onTap: () => context.push(
                                          '/classes/${session.id}',
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(delay: (index * 50).ms)
                                      .slideY(begin: 0.08),
                            );
                          }, childCount: filtered.length),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ClassDetailsScreen extends ConsumerWidget {
  const ClassDetailsScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardSnapshotProvider);

    return dashboardState.when(
      loading: () => const AppScreen(
        body: SafeArea(
          top: false,
          child: AppLoadingState(
            compact: true,
            title: 'Loading class details...',
            message: 'Pulling the latest session notes and access details.',
          ),
        ),
      ),
      error: (error, _) => AppScreen(
        body: SafeArea(
          top: false,
          child: AppErrorState(
            compact: true,
            title: 'Class unavailable',
            message: 'We could not load that class right now.',
            onRetry: () => ref.refresh(dashboardSnapshotProvider),
          ),
        ),
      ),
      data: (dashboard) {
        CohortSessionModel? session;
        for (final item in dashboard.unlockedSessions) {
          if (item.id == classId) {
            session = item;
            break;
          }
        }

        if (session == null) {
          return const AppScreen(
            body: SafeArea(
              top: false,
              child: AppEmptyState(
                title: 'Class not found',
                message:
                    'That session is no longer available in your unlocked class list.',
                icon: Icons.menu_book_outlined,
              ),
            ),
          );
        }

        return AppScreen(
          body: SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
              children: [
                PremiumPageHeader(
                  title: 'Week ${session.week}',
                  subtitle: session.pathTitle,
                  leading: PremiumIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  trailing: _StatusPill(label: _statusLabel(session)),
                ),
                const Gap(12),
                Text(
                  session.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(18),
                _ClassDetailHero(session: session),
                const Gap(20),
                AppCard(
                  radius: 28,
                  color: Theme.of(context).cardColor.withValues(alpha: 0.84),
                  child: AdaptiveWrap(
                    minItemWidth: 150,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ClassMeta(
                        label: 'Status',
                        value: _accessStatusText(session),
                        icon: PhosphorIconsDuotone.clockCountdown,
                      ),
                      _ClassMeta(
                        label: 'Schedule',
                        value: resolveSessionStatus(session).scheduleLabel,
                        icon: PhosphorIconsDuotone.calendarDots,
                      ),
                      _ClassMeta(
                        label: 'Access',
                        value: _accessLabel(session),
                        icon: _accessIcon(session),
                      ),
                    ],
                  ),
                ),
                const Gap(18),
                _ClassAvailabilityStrip(session: session),
                const Gap(18),
                AppCard(
                  radius: 28,
                  color: Theme.of(context).cardColor.withValues(alpha: 0.84),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Notes',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Gap(10),
                      Text(
                        session.notes.isEmpty
                            ? 'No notes have been published for this session yet.'
                            : session.notes,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _muted(context),
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(20),
                AppButton(
                  label: _primaryActionLabel(session),
                  leading: Icon(
                    _primaryActionIcon(session),
                    color: Colors.white,
                  ),
                  onPressed: _primaryAction(context: context, session: session),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClassListCard extends StatelessWidget {
  const _ClassListCard({required this.session, required this.onTap});

  final CohortSessionModel session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = resolveSessionStatus(session);
    final recordingReady = status.isRecordingReady;
    final countdown = status.countdownLabel;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AppCard(
        radius: 28,
        color: Theme.of(context).cardColor.withValues(alpha: 0.94),
        shadow: AppShadows.premium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ClassArtwork(session: session),
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ClassBadge(
                        label: 'Week ${session.week}',
                        tint: AppColors.deepBlue,
                        icon: PhosphorIconsFill.bookOpenText,
                      ),
                      if (session.hasJoinUrl)
                        _ClassBadge(
                          label: 'Live access',
                          tint: AppColors.teal,
                          icon: PhosphorIconsFill.videoCamera,
                        ),
                      if (recordingReady)
                        _ClassBadge(
                          label: 'Recording ready',
                          tint: AppColors.orange,
                          icon: PhosphorIconsFill.playCircle,
                        ),
                    ],
                  ),
                ),
                _StatusPill(label: _statusLabel(session)),
              ],
            ),
            const Gap(10),
            Text(
              session.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkForeground
                    : AppColors.deepBlueDark,
              ),
            ),
            const Gap(8),
            Text(
              session.notes.isEmpty
                  ? 'Session notes will appear here once the mentor publishes them.'
                  : session.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _muted(context),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(14),
            AdaptiveWrap(
              minItemWidth: 142,
              spacing: 10,
              runSpacing: 10,
              children: [
                _ClassMeta(
                  label: 'Schedule',
                  value: countdown ?? _formatDateTime(session.startsAt),
                  icon: countdown != null
                      ? PhosphorIconsDuotone.clockCountdown
                      : PhosphorIconsDuotone.calendarDots,
                ),
                _ClassMeta(
                  label: 'Track',
                  value: session.pathTitle,
                  icon: PhosphorIconsDuotone.stack,
                ),
                _ClassMeta(
                  label: 'Access',
                  value: recordingReady
                      ? 'Recording ready'
                      : session.isLive(DateTime.now())
                      ? 'Join now'
                      : status.isUpcoming
                      ? 'Class starts soon'
                      : status.statusLabel,
                  icon: recordingReady
                      ? PhosphorIconsDuotone.playCircle
                      : PhosphorIconsDuotone.videoCamera,
                ),
              ],
            ),
            const Gap(14),
            Row(
              children: [
                Icon(
                  recordingReady
                      ? PhosphorIconsFill.playCircle
                      : session.isLive(DateTime.now())
                      ? PhosphorIconsFill.videoCamera
                      : PhosphorIconsFill.arrowUpRight,
                  size: 16,
                  color: recordingReady
                      ? AppColors.orange
                      : session.isLive(DateTime.now())
                      ? AppColors.teal
                      : AppColors.deepBlue,
                ),
                const Gap(8),
                Expanded(
                  child: Text(
                    recordingReady
                        ? 'Tap to watch the recorded session in-app.'
                        : session.isLive(DateTime.now())
                        ? 'Tap to open details and join the live class.'
                        : 'Tap to view class details, timing, and access state.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _muted(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassDetailHero extends StatelessWidget {
  const _ClassDetailHero({required this.session});

  final CohortSessionModel session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = resolveSessionStatus(session);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF101A2D), Color(0xFF16243D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFF7FCFB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ClassBadge(
                  label: status.statusLabel,
                  tint: _statusTone(status),
                  icon: _statusIcon(status),
                ),
                const Gap(12),
                Text(
                  buildClassStartEstimate(session),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkForeground
                        : AppColors.foreground,
                  ),
                ),
                const Gap(8),
              ],
            ),
          ),
          const Gap(16),
          _ClassHeroIcon(status: status),
        ],
      ),
    );
  }
}

class _ClassHeroIcon extends StatelessWidget {
  const _ClassHeroIcon({required this.status});

  final SessionStatusSnapshot status;

  @override
  Widget build(BuildContext context) {
    final tint = _statusTone(status);
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(_statusIcon(status), color: tint, size: 34),
    );
  }
}

class _ClassAvailabilityStrip extends StatelessWidget {
  const _ClassAvailabilityStrip({required this.session});

  final CohortSessionModel session;

  @override
  Widget build(BuildContext context) {
    final status = resolveSessionStatus(session);
    final tint = _statusTone(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon(status), color: tint, size: 20),
          const Gap(12),
          Expanded(
            child: Text(
              status.actionState == SessionActionState.watchRecording
                  ? 'Recording access is ready and will stay inside the app player.'
                  : status.actionState == SessionActionState.joinLive
                  ? 'Live access is open now. Join from the primary button below.'
                  : status.actionState == SessionActionState.startsSoon
                  ? 'The join button unlocks automatically when the countdown is up.'
                  : status.actionState == SessionActionState.awaitingRecording
                  ? 'Class has ended. Recording will appear here once published.'
                  : 'A join link has not been published yet for this session.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _muted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassArtwork extends StatelessWidget {
  const _ClassArtwork({required this.session});

  final CohortSessionModel session;

  @override
  Widget build(BuildContext context) {
    final status = resolveSessionStatus(session);
    final tint = _statusTone(status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF13213A), Color(0xFF1D2E4A)],
              )
            : const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFFFF5EC)],
              ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            bottom: -18,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: _ClassBadge(
              label: session.pathTitle,
              tint: AppColors.deepBlue,
              icon: PhosphorIconsFill.stack,
            ),
          ),
          Center(child: Icon(_statusIcon(status), color: tint, size: 42)),
        ],
      ),
    );
  }
}

class _OverviewStatChip extends StatelessWidget {
  const _OverviewStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    this.onDark = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.08)
            : tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.08)
              : tint.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tint),
          const Gap(10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: onDark ? Colors.white : null,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: onDark ? Colors.white70 : _muted(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClassBadge extends StatelessWidget {
  const _ClassBadge({
    required this.label,
    required this.tint,
    required this.icon,
  });

  final String label;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const Gap(6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassMeta extends StatelessWidget {
  const _ClassMeta({
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
            : AppColors.muted.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.tealDark),
              const Gap(8),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _muted(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isLive = label == 'Live';
    final tone = isLive ? AppColors.teal : AppColors.deepBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: tone,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ClassTabChip extends StatelessWidget {
  const _ClassTabChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? AppColors.deepBlue
                : isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppColors.deepBlue
                  : isDark
                  ? AppColors.darkBorder
                  : AppColors.deepBlue.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active
                      ? Colors.white
                      : isDark
                      ? AppColors.darkForeground
                      : AppColors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge != null && badge! > 0) ...[
                const Gap(8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.14)
                        : AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: active ? Colors.white : AppColors.tealDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(CohortSessionModel session) {
  final status = resolveSessionStatus(session);
  return switch (status.actionState) {
    SessionActionState.joinLive => 'Live',
    SessionActionState.watchRecording => 'Recording',
    SessionActionState.startsSoon => 'Upcoming',
    SessionActionState.awaitingRecording => 'Completed',
    SessionActionState.awaitingJoinLink => 'Upcoming',
  };
}

String _formatDateTime(DateTime value) {
  return DateFormat('EEE, MMM d • h:mm a').format(value);
}

Future<void> _openJoinLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    showAppSnackBar(context, 'The join link is not valid yet.');
    return;
  }
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (!context.mounted) return;
    showAppSnackBar(context, 'Could not open the join link right now.');
  }
}

String _accessLabel(CohortSessionModel session) {
  final status = resolveSessionStatus(session);
  return switch (status.actionState) {
    SessionActionState.watchRecording => 'Watch recorded session',
    SessionActionState.joinLive => 'Join live class',
    SessionActionState.startsSoon => 'Class starts soon',
    SessionActionState.awaitingRecording => 'Await recording link',
    SessionActionState.awaitingJoinLink => 'Awaiting join link',
  };
}

String _accessStatusText(CohortSessionModel session) {
  final status = resolveSessionStatus(session);
  return switch (status.actionState) {
    SessionActionState.watchRecording => 'Recording ready',
    SessionActionState.joinLive => 'Live now',
    SessionActionState.startsSoon => 'Upcoming',
    SessionActionState.awaitingRecording => 'Completed',
    SessionActionState.awaitingJoinLink => 'Pending link',
  };
}

IconData _accessIcon(CohortSessionModel session) {
  final status = resolveSessionStatus(session);
  return switch (status.actionState) {
    SessionActionState.watchRecording => PhosphorIconsDuotone.playCircle,
    SessionActionState.joinLive => PhosphorIconsDuotone.videoCamera,
    SessionActionState.startsSoon => PhosphorIconsDuotone.clockCountdown,
    SessionActionState.awaitingRecording => PhosphorIconsDuotone.clockAfternoon,
    SessionActionState.awaitingJoinLink => PhosphorIconsDuotone.link,
  };
}

String _primaryActionLabel(CohortSessionModel session) {
  final status = resolveSessionStatus(session);
  return switch (status.actionState) {
    SessionActionState.watchRecording => 'Watch Recorded Session',
    SessionActionState.joinLive => 'Join Live Class',
    SessionActionState.startsSoon => 'Class Starts Soon',
    SessionActionState.awaitingRecording => 'Back to Classes',
    SessionActionState.awaitingJoinLink => 'Back to Classes',
  };
}

IconData _primaryActionIcon(CohortSessionModel session) {
  final status = resolveSessionStatus(session);
  return switch (status.actionState) {
    SessionActionState.watchRecording => PhosphorIconsBold.playCircle,
    SessionActionState.joinLive => PhosphorIconsBold.videoCamera,
    SessionActionState.startsSoon => PhosphorIconsBold.timer,
    SessionActionState.awaitingRecording => PhosphorIconsBold.arrowLeft,
    SessionActionState.awaitingJoinLink => PhosphorIconsBold.arrowLeft,
  };
}

VoidCallback? _primaryAction({
  required BuildContext context,
  required CohortSessionModel session,
}) {
  final status = resolveSessionStatus(session);
  if (status.actionState == SessionActionState.watchRecording) {
    return () => context.push('/recorded/${session.id}');
  }
  if (status.actionState == SessionActionState.joinLive) {
    return () => _openJoinLink(context, session.joinUrl);
  }
  if (status.actionState == SessionActionState.startsSoon) {
    return null;
  }
  return () => context.pop();
}

Color _muted(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkMutedForeground
      : const Color(0xFF50627E);
}

extension on CohortSessionModel {
  bool isLive(DateTime now) => !startsAt.isAfter(now) && !endsAt.isBefore(now);
}

Color _statusTone(SessionStatusSnapshot status) {
  return switch (status.actionState) {
    SessionActionState.joinLive => AppColors.teal,
    SessionActionState.startsSoon => AppColors.deepBlue,
    SessionActionState.watchRecording => AppColors.orange,
    SessionActionState.awaitingRecording => AppColors.orange,
    SessionActionState.awaitingJoinLink => AppColors.deepBlueLight,
  };
}

IconData _statusIcon(SessionStatusSnapshot status) {
  return switch (status.actionState) {
    SessionActionState.joinLive => PhosphorIconsFill.videoCamera,
    SessionActionState.startsSoon => PhosphorIconsFill.clockCountdown,
    SessionActionState.watchRecording => PhosphorIconsFill.playCircle,
    SessionActionState.awaitingRecording => PhosphorIconsFill.clockAfternoon,
    SessionActionState.awaitingJoinLink => PhosphorIconsFill.link,
  };
}

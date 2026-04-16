import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/states/app_state_widgets.dart';
import '../catalog/models/course_model.dart';
import '../cohorts/models/cohort_session_model.dart';
import '../cohorts/presentation/session_status.dart';
import '../community/state/community_notifications_provider.dart';
import '../student/models/pending_payment_model.dart';
import 'models/student_dashboard_snapshot.dart';
import 'state/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardSnapshotProvider);
    // Watch for notifications
    ref.watch(dashboardNotificationsProvider);

    return dashboardState.when(
      // Match the final layout with a shimmer shell so loading feels intentional.
      loading: () => const DoubleBackToExitScope(
        child: SafeArea(child: _DashboardShimmer()),
      ),
      error: (error, stackTrace) => DoubleBackToExitScope(
        child: SafeArea(
          child: AppErrorState(
            compact: true,
            title: 'Dashboard unavailable',
            message:
                'We could not load your student dashboard right now. Please try again.',
            onRetry: () => ref.refresh(dashboardSnapshotProvider),
          ),
        ),
      ),
      data: (dashboard) =>
          DoubleBackToExitScope(child: _DashboardContent(snapshot: dashboard)),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.snapshot});

  final StudentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = this.snapshot;
    final heroSession = snapshot.heroSession;

    return SafeArea(
      top: false,
      bottom: false,
      child: RefreshIndicator(
        // Pull-to-refresh should trigger a fresh Firebase-backed dashboard read.
        onRefresh: () => ref.refresh(dashboardSnapshotProvider.future),
        color: AppColors.deepBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 132),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardHeader(snapshot: snapshot),
                    const Gap(20),
                    _DashboardHero(
                      snapshot: snapshot,
                      onPrimaryAction: snapshot.hasAnyPending
                          ? null
                          : _shouldOpenRecording(heroSession)
                          ? () => context.push('/recorded/${heroSession!.id}')
                          : _shouldJoinLiveClass(heroSession)
                          ? () => _openJoinLink(context, heroSession!.joinUrl)
                          : _isUpcomingJoinableSession(heroSession)
                          ? null
                          : () => context.go('/classes'),
                    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.04),
                    const Gap(28),
                    _SectionHeading(
                      title: 'Quick Summary',
                      actionLabel: null,
                      onAction: null,
                    ),
                    const Gap(14),
                    _SummaryGrid(snapshot: snapshot),
                    if (snapshot.canTopUp) ...[
                      const Gap(16),
                      _TopUpActionButton(snapshot: snapshot),
                    ],
                    if (snapshot.profile.pendingPayment != null) ...[
                      const Gap(20),
                      _PendingPaymentStrip(snapshot: snapshot),
                    ],
                    const Gap(26),
                    _SectionHeading(
                      title: 'Latest Classes',
                      actionLabel: snapshot.unlockedSessions.isNotEmpty
                          ? 'View All'
                          : null,
                      onAction: () => _handlePrimaryAction(context, snapshot),
                    ),
                    const Gap(14),
                    _SessionShelf(
                      sessions: snapshot.previewSessions,
                      emptyTitle: snapshot.hasAnyPending
                          ? 'Access is locked'
                          : 'No published classes yet',
                      emptyMessage: snapshot.hasAnyPending
                          ? 'Classes appear here once your payment is approved.'
                          : 'Your admin has not published a class for your paid weeks yet.',
                    ),

                    const Gap(28),
                    _SectionHeading(
                      title: 'Roadmap',
                      actionLabel: null,
                      onAction: null,
                    ),
                    const Gap(14),
                    _CourseRoadmap(snapshot: snapshot),

                    const Gap(8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePrimaryAction(
    BuildContext context,
    StudentDashboardSnapshot snapshot,
  ) {
    context.go('/classes');
  }

  bool _shouldOpenRecording(CohortSessionModel? heroSession) {
    if (heroSession == null) return false;
    final status = resolveSessionStatus(heroSession);
    return status.actionState == SessionActionState.watchRecording;
  }

  bool _shouldJoinLiveClass(CohortSessionModel? heroSession) {
    if (heroSession == null || !heroSession.hasJoinUrl) return false;
    return isSessionLive(heroSession);
  }

  bool _isUpcomingJoinableSession(CohortSessionModel? heroSession) {
    if (heroSession == null || !heroSession.hasJoinUrl) return false;
    final status = resolveSessionStatus(heroSession);
    return status.actionState == SessionActionState.startsSoon;
  }
}

class _DashboardHeader extends ConsumerWidget {
  const _DashboardHeader({required this.snapshot});

  final StudentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final initials = _initials(snapshot.profile.fullName);
    final greetingMood = _timeGreetingMood();
    final unreadCountAsync = ref.watch(unreadMessagesCountProvider);

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDark
                    ? const LinearGradient(
                        colors: [Color(0xFF324565), Color(0xFF18243A)],
                      )
                    : const LinearGradient(
                        colors: [AppColors.deepBlueLight, AppColors.teal],
                      ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.darkForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Welcome',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkMutedForeground
                          : AppColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(8),
                  _GreetingMoodGlyph(mood: greetingMood),
                ],
              ),
              const Gap(2),
              Text(
                snapshot.profile.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Gap(12),
        _IconBubble(
          icon: PhosphorIconsRegular.bell,
          badgeCount: unreadCountAsync.maybeWhen(
            data: (count) => count,
            orElse: () => 0,
          ),
          // Messages is the closest real notification destination available now.
          onTap: () => context.push('/community/messages'),
        ),
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.snapshot, required this.onPrimaryAction});

  final StudentDashboardSnapshot snapshot;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 340;
    final heroSession = snapshot.heroSession;
    final heroStatusLabel = heroSession == null
        ? null
        : _heroStatusLabel(snapshot, heroSession);
    final accentLabel = snapshot.hasAnyPending
        ? 'Payment Update'
        : snapshot.path.title;
    final headline = snapshot.hasAnyPending
        ? 'Classes unlock after approval'
        : heroSession == null
        ? 'Coming Soon'
        : heroSession.title;
    final caption = snapshot.hasAnyPending
        ? 'Your schedule becomes active automatically once payment is confirmed.'
        : heroSession == null
        ? 'Your admin has not published a session for your paid weeks yet.'
        : _heroScheduleLabel(heroSession);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: isDark
            ? const LinearGradient(
                colors: [
                  Color(0xFF07101F),
                  Color(0xFF0C1A30),
                  Color(0xFF14294B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [
                  Color.fromARGB(255, 253, 239, 230),
                  Color.fromARGB(255, 219, 232, 255),
                  Color.fromARGB(255, 208, 238, 236),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.deepBlue).withValues(
              alpha: isDark ? 0.18 : 0.08,
            ),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroTextBlock(
                  accentLabel: accentLabel,
                  headline: headline,
                  caption: caption,
                  heroStatusLabel: heroStatusLabel,
                  showHeroTiming:
                      !snapshot.hasAnyPending && heroSession != null,
                ),
                const Gap(12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _HeroIllustration(isPending: snapshot.hasAnyPending),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _HeroTextBlock(
                    accentLabel: accentLabel,
                    headline: headline,
                    caption: caption,
                    heroStatusLabel: heroStatusLabel,

                    showHeroTiming:
                        !snapshot.hasAnyPending && heroSession != null,
                  ),
                ),
                const Gap(8),
                _HeroIllustration(isPending: snapshot.hasAnyPending),
              ],
            ),
          if (snapshot.hasAnyPending || heroSession != null) ...[
            const Gap(18),
            // Keep the primary hero action full-width so it reads like the web CTA.
            AppButton(
              expanded: true,
              label: snapshot.hasAnyPending
                  ? 'Await Approval'
                  : _shouldWatchRecording(heroSession)
                  ? 'Watch Recorded Session'
                  : _isUpcomingJoinableSession(heroSession)
                  ? 'Class Starts Soon'
                  : _shouldJoinLiveClass(heroSession)
                  ? 'Join live class'
                  : 'View All Classes',
              leading: Icon(
                snapshot.hasAnyPending
                    ? PhosphorIconsFill.lockers
                    : _shouldWatchRecording(heroSession)
                    ? PhosphorIconsFill.playCircle
                    : _isUpcomingJoinableSession(heroSession)
                    ? PhosphorIconsFill.timer
                    : _shouldJoinLiveClass(heroSession)
                    ? PhosphorIconsFill.playCircle
                    : PhosphorIconsFill.bookOpenText,
                color: Colors.white,
                size: 20,
              ),
              onPressed: onPrimaryAction,
            ),
          ],
        ],
      ),
    );
  }

  String _heroScheduleLabel(CohortSessionModel heroSession) {
    final status = resolveSessionStatus(heroSession);
    if (status.actionState == SessionActionState.joinLive) {
      return 'Live now • ${status.scheduleLabel}';
    }
    if (status.actionState == SessionActionState.watchRecording) {
      return 'Recording is ready • ${status.scheduleLabel}';
    }
    return buildClassStartEstimate(heroSession);
  }

  String _heroStatusLabel(
    StudentDashboardSnapshot snapshot,
    CohortSessionModel heroSession,
  ) {
    final status = resolveSessionStatus(heroSession);
    if (status.actionState == SessionActionState.joinLive) {
      return 'Live now';
    }
    if (status.actionState == SessionActionState.watchRecording) {
      return 'Recording ready';
    }
    if (snapshot.nextSession?.id == heroSession.id &&
        status.countdownLabel != null) {
      return status.countdownLabel!;
    }
    return 'Latest class';
  }

  bool _shouldWatchRecording(CohortSessionModel? heroSession) {
    if (heroSession == null) return false;
    final status = resolveSessionStatus(heroSession);
    return status.actionState == SessionActionState.watchRecording;
  }

  bool _shouldJoinLiveClass(CohortSessionModel? heroSession) {
    if (heroSession == null || !heroSession.hasJoinUrl) return false;
    final status = resolveSessionStatus(heroSession);
    return status.actionState == SessionActionState.joinLive;
  }

  bool _isUpcomingJoinableSession(CohortSessionModel? heroSession) {
    if (heroSession == null || !heroSession.hasJoinUrl) return false;
    final status = resolveSessionStatus(heroSession);
    return status.actionState == SessionActionState.startsSoon;
  }
}

class _HeroTextBlock extends StatelessWidget {
  const _HeroTextBlock({
    required this.accentLabel,
    required this.headline,
    required this.caption,
    required this.heroStatusLabel,

    required this.showHeroTiming,
  });

  final String accentLabel;
  final String headline;
  final String caption;
  final String? heroStatusLabel;
  final bool showHeroTiming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          accentLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isDark ? AppColors.tealLight : AppColors.deepBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(8),
        if (showHeroTiming && heroStatusLabel != null) ...[
          _HeroTimingPill(label: heroStatusLabel!),
          const Gap(10),
        ],

        const Gap(8),

        Text(
          headline,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkForeground : AppColors.foreground,
          ),
        ),
        const Gap(8),
        Text(
          caption,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.darkMutedForeground
                : AppColors.mutedForeground,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration({required this.isPending});

  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final width = compact ? 108.0 : 128.0;
    final height = compact ? 118.0 : 136.0;

    // The illustration keeps the reference's playful balance without requiring
    // a third-party asset or mismatching the current brand system.
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 8,
            bottom: 14,
            child: Container(
              width: 94,
              height: 62,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.orangeLight : AppColors.orange)
                    .withValues(alpha: isDark ? 0.32 : 0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 24,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : AppColors.deepBlue).withValues(
                  alpha: isDark ? 0.12 : 0.08,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 14,
            child: Icon(
              isPending
                  ? PhosphorIconsFill.lockers
                  : PhosphorIconsFill.bookOpenText,
              size: 34,
              color: isDark ? AppColors.tealLight : AppColors.deepBlue,
            ),
          ),
          Positioned(
            top: 18,
            right: 20,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.deepBlueLight.withValues(alpha: 0.8)
                    : AppColors.teal.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 28,
            right: 30,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? AppColors.teal : AppColors.deepBlue,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                PhosphorIconsFill.student,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          Positioned(
            top: 64,
            right: 52,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: 44,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.teal.withValues(alpha: 0.92)
                      : AppColors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  PhosphorIconsFill.bookOpenText,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionShelf extends StatelessWidget {
  const _SessionShelf({
    required this.sessions,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<CohortSessionModel> sessions;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return AppEmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: Icons.menu_book_outlined,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        children: [
          for (var index = 0; index < sessions.length; index++) ...[
            _CourseCard(
              session: sessions[index],
              onTap: () => context.push('/classes/${sessions[index].id}'),
            ),
            if (index != sessions.length - 1) const Gap(14),
          ],
        ],
      ),
    );
  }
}

class _CourseRoadmap extends StatelessWidget {
  const _CourseRoadmap({required this.snapshot});

  final StudentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 340;
    final secondaryColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;
    final roadmapItems = _buildSyllabusItems(snapshot);

    return _SoftPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.path.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(10),
                _StatusPill(
                  text: snapshot.hasAnyPending ? 'Pending' : 'Active',
                  tone: snapshot.hasAnyPending
                      ? AppColors.orange
                      : AppColors.teal,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    snapshot.path.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusPill(
                  text: snapshot.hasAnyPending ? 'Pending' : 'Active',
                  tone: snapshot.hasAnyPending
                      ? AppColors.orange
                      : AppColors.teal,
                ),
              ],
            ),
          const Gap(10),
          Text(
            'This roadmap mirrors the path syllabus saved on the course from the web app, so each learner sees the right weekly outline.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: secondaryColor,
              height: 1.5,
            ),
          ),
          const Gap(16),
          for (var index = 0; index < roadmapItems.length; index++) ...[
            _RoadmapStep(
              item: roadmapItems[index],
              isLast: index == roadmapItems.length - 1,
            ),
            if (index != roadmapItems.length - 1) const Gap(12),
          ],
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.snapshot});

  final StudentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AdaptiveWrap(
      minItemWidth: 140,
      spacing: 12,
      runSpacing: 12,
      children: [
        _MiniStatCard(
          label: 'Progress',
          value: '${(snapshot.progressPercent * 100).round()}%',
          icon: Icons.trending_up_rounded,
          tint: AppColors.teal,
        ),
        _MiniStatCard(
          label: 'Unlocked Weeks',
          value: '${snapshot.paidWeeks} wk',
          valueSuffix: 'of ${snapshot.totalProgramWeeks} wk',
          icon: Icons.lock_open_rounded,
          tint: AppColors.deepBlue,
        ),
        _MiniStatCard(
          label: 'Recordings',
          value: '${snapshot.recordedLessons.length}',
          icon: Icons.play_circle_outline_rounded,
          tint: AppColors.orange,
        ),
        _MiniStatCard(
          label: 'Remaining',
          value: '${snapshot.remainingWeeks} wk',
          valueSuffix: snapshot.remainingWeeks == 0
              ? 'Paid'
              : _formatNaira(
                  snapshot.remainingWeeks * snapshot.course.pricePerWeek,
                ),
          icon: Icons.schedule_rounded,
          tint: AppColors.tealDark,
        ),
      ],
    );
  }
}

class _PendingPaymentStrip extends StatelessWidget {
  const _PendingPaymentStrip({required this.snapshot});

  final StudentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final payment = snapshot.profile.pendingPayment!;
    final isTopUp = payment.kind == PendingPaymentKind.topUp;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${isTopUp ? 'Top-up' : 'Payment'} in progress: ${payment.weeks} week(s) • ${_formatNaira(payment.amount)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Gap(12),
          TextButton(
            onPressed: () => context.push(
              isTopUp
                  ? '/payment?mode=topup&returnTo=%2Fdashboard'
                  : '/payment?mode=initial&returnTo=%2Fdashboard',
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _TopUpActionButton extends StatelessWidget {
  const _TopUpActionButton({required this.snapshot});

  final StudentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 340;

    // The top-up action sits below summary so the roadmap remains informational.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA86A), Color(0xFFFF7A45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () =>
              context.push('/payment?mode=topup&returnTo=%2Fdashboard'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopUpActionHeader(snapshot: snapshot),
                      const Gap(12),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _TopUpActionHeader(snapshot: snapshot)),
                      const Gap(12),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TopUpActionHeader extends StatelessWidget {
  const _TopUpActionHeader({required this.snapshot});

  final StudentDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.arrow_upward_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Up Access',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Gap(2),
              Text(
                'Unlock ${snapshot.remainingWeeks} week(s) for ${_formatNaira(snapshot.remainingWeeks * snapshot.course.pricePerWeek)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.session, required this.onTap});

  final CohortSessionModel session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = resolveSessionStatus(session);
    final accent = _accentForStatus(status.actionState);
    final actionLabel = _actionLabelForStatus(status.actionState);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 224,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0E1728) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.deepBlue.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppColors.deepBlue).withValues(
                  alpha: isDark ? 0.22 : 0.08,
                ),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Week ${session.week}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      status.statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.darkMutedForeground
                            : AppColors.mutedForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              Container(
                height: 124,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _SessionCardArtwork(session: session),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(
                                    0xFF0F1B2F,
                                  ).withValues(alpha: 0.92)
                                : Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _iconForStatus(status.actionState),
                                size: 14,
                                color: accent,
                              ),
                              const Gap(6),
                              Text(
                                actionLabel,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.darkForeground
                                          : AppColors.deepBlueDark,
                                      fontWeight: FontWeight.w800,
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
              const Gap(12),
              Text(
                session.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Gap(6),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 16, color: accent),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      _formatDateLabel(session),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkMutedForeground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? accent.withValues(alpha: 0.14)
                      : accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        status.scheduleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const Gap(10),
                    Icon(Icons.arrow_outward_rounded, size: 18, color: accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentForStatus(SessionActionState state) {
    return switch (state) {
      SessionActionState.joinLive => AppColors.teal,
      SessionActionState.startsSoon => AppColors.deepBlue,
      SessionActionState.watchRecording => AppColors.orange,
      SessionActionState.awaitingRecording => AppColors.orangeLight,
      SessionActionState.awaitingJoinLink => AppColors.deepBlueLight,
    };
  }

  IconData _iconForStatus(SessionActionState state) {
    return switch (state) {
      SessionActionState.joinLive => Icons.podcasts_rounded,
      SessionActionState.startsSoon => Icons.schedule_send_rounded,
      SessionActionState.watchRecording => Icons.play_circle_fill_rounded,
      SessionActionState.awaitingRecording => Icons.movie_creation_outlined,
      SessionActionState.awaitingJoinLink => Icons.link_rounded,
    };
  }

  String _actionLabelForStatus(SessionActionState state) {
    return switch (state) {
      SessionActionState.joinLive => 'Join live',
      SessionActionState.startsSoon => 'Starts soon',
      SessionActionState.watchRecording => 'Watch now',
      SessionActionState.awaitingRecording => 'Recording soon',
      SessionActionState.awaitingJoinLink => 'Open class',
    };
  }
}

class _SessionCardArtwork extends StatelessWidget {
  const _SessionCardArtwork({required this.session});

  final CohortSessionModel session;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLive = _isSessionLive(session, DateTime.now());

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF2B3853), Color(0xFF1B2740)],
              )
            : const LinearGradient(
                colors: [Color(0xFFE9F2FB), Color(0xFFF4FBFB)],
              ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -12,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (isLive ? AppColors.teal : AppColors.orange).withValues(
                  alpha: 0.22,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: _Badge(
              label: isLive ? 'LIVE' : 'WEEK ${session.week}',
              tint: isLive ? AppColors.teal : AppColors.deepBlue,
            ),
          ),
          Center(
            child: Icon(
              session.hasJoinUrl
                  ? PhosphorIconsFill.videoCamera
                  : PhosphorIconsFill.graduationCap,
              size: 44,
              color: isDark ? AppColors.tealLight : AppColors.deepBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.deepBlue.withValues(alpha: 0.06),
        ),
      ),
      child: child,
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.valueSuffix,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final String? valueSuffix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 340;

    return _SoftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: tint),
            ],
          ),
          const Gap(10),
          if (compact && valueSuffix != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Gap(4),
                Text(
                  valueSuffix!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.darkMutedForeground
                        : AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (valueSuffix != null) ...[
                  const Gap(6),
                  Flexible(
                    child: Text(
                      valueSuffix!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkMutedForeground
                            : AppColors.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: tone == AppColors.orange ? AppColors.foreground : tone,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tint == AppColors.orange ? AppColors.foreground : tint,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.deepBlue.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? AppColors.orangeLight : AppColors.deepBlue,
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GreetingMoodGlyph extends StatelessWidget {
  const _GreetingMoodGlyph({required this.mood});

  final _GreetingMood mood;

  @override
  Widget build(BuildContext context) {
    // Use a styled icon badge so the greeting feels more premium than raw emoji text.
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: mood.colors),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: mood.colors.first.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(mood.icon, size: 14, color: Colors.white),
    );
  }
}

class _HeroTimingPill extends StatelessWidget {
  const _HeroTimingPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : AppColors.deepBlue).withValues(
          alpha: isDark ? 0.08 : 0.08,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (isDark ? AppColors.tealLight : AppColors.deepBlue).withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsFill.timer,
            size: 12,
            color: isDark ? AppColors.tealLight : AppColors.deepBlue,
          ),
          const Gap(4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isDark ? AppColors.darkForeground : AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardShimmer extends StatelessWidget {
  const _DashboardShimmer();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 132),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    AppShimmerBlock(width: 44, height: 44, radius: 999),
                    Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppShimmerBlock(width: 92, height: 12, radius: 999),
                          Gap(8),
                          AppShimmerBlock(width: 168, height: 20, radius: 999),
                        ],
                      ),
                    ),
                    Gap(12),
                    AppShimmerBlock(width: 44, height: 44, radius: 16),
                  ],
                ),
                const Gap(20),
                const AppShimmerBlock(
                  width: double.infinity,
                  height: 210,
                  radius: 30,
                ),
                const Gap(26),
                const Row(
                  children: [
                    Expanded(
                      child: AppShimmerBlock(
                        width: 180,
                        height: 28,
                        radius: 999,
                      ),
                    ),
                  ],
                ),
                const Gap(14),
                const Row(
                  children: [
                    Expanded(
                      child: AppShimmerBlock(
                        width: 100,
                        height: 110,
                        radius: 24,
                      ),
                    ),
                    Gap(12),
                    Expanded(
                      child: AppShimmerBlock(
                        width: 100,
                        height: 110,
                        radius: 24,
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                const AppShimmerBlock(
                  width: double.infinity,
                  height: 76,
                  radius: 22,
                ),
                const Gap(24),
                const Row(
                  children: [
                    Expanded(
                      child: AppShimmerBlock(
                        width: 180,
                        height: 28,
                        radius: 999,
                      ),
                    ),
                  ],
                ),
                const Gap(14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: const [
                      _ShimmerCourseCard(),
                      Gap(14),
                      _ShimmerCourseCard(),
                    ],
                  ),
                ),
                const Gap(28),
                const AppShimmerBlock(width: 218, height: 28, radius: 999),
                const Gap(14),
                const AppShimmerBlock(
                  width: double.infinity,
                  height: 236,
                  radius: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShimmerCourseCard extends StatelessWidget {
  const _ShimmerCourseCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 172,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [AppShimmerBlock(width: 172, height: 170, radius: 24)],
      ),
    );
  }
}

class _RoadmapItem {
  const _RoadmapItem({
    required this.weekLabel,
    required this.title,
    required this.description,
    required this.topics,
    required this.icon,
    required this.tint,
    required this.isCurrent,
    required this.isUnlocked,
    required this.statusLabel,
  });

  final String weekLabel;
  final String title;
  final String description;
  final List<String> topics;
  final IconData icon;
  final Color tint;
  final bool isCurrent;
  final bool isUnlocked;
  final String statusLabel;
}

List<_RoadmapItem> _buildSyllabusItems(StudentDashboardSnapshot snapshot) {
  final syllabusItems = _resolvedSyllabusItems(snapshot);
  final unlockedWeeks = snapshot.profile.weeksToCommit.clamp(
    0,
    syllabusItems.length,
  );

  return List<_RoadmapItem>.generate(syllabusItems.length, (index) {
    final week = syllabusItems[index];
    final weekNumber = week.week;
    final isUnlocked = weekNumber <= unlockedWeeks;
    final isCurrent = weekNumber == (unlockedWeeks == 0 ? 1 : unlockedWeeks);
    final tint = switch (index % 4) {
      0 => AppColors.deepBlue,
      1 => AppColors.teal,
      2 => AppColors.orange,
      _ => AppColors.deepBlueLight,
    };

    return _RoadmapItem(
      weekLabel: 'Week $weekNumber',
      title: week.title.trim().isNotEmpty ? week.title : 'Week $weekNumber',
      description: week.topics.isNotEmpty
          ? '${week.topics.length} topic${week.topics.length == 1 ? '' : 's'}'
          : 'Weekly learning milestone',
      topics: week.topics,
      icon: isUnlocked
          ? Icons.check_circle_rounded
          : Icons.radio_button_unchecked_rounded,
      tint: tint,
      isCurrent: isCurrent,
      isUnlocked: isUnlocked,
      statusLabel: isUnlocked
          ? 'Unlocked'
          : isCurrent
          ? 'Current'
          : 'Locked',
    );
  });
}

List<CourseSyllabusWeek> _resolvedSyllabusItems(
  StudentDashboardSnapshot snapshot,
) {
  final syllabusItems = snapshot.course.syllabus;
  if (syllabusItems.isEmpty) {
    return _dummySyllabusItems(snapshot);
  }

  if (syllabusItems.length == 1 && snapshot.totalProgramWeeks > 1) {
    return _dummySyllabusItems(snapshot);
  }

  return syllabusItems;
}

class _RoadmapStep extends StatelessWidget {
  const _RoadmapStep({required this.item, required this.isLast});

  final _RoadmapItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark
        ? AppColors.darkMutedForeground
        : AppColors.mutedForeground;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.isCurrent
                    ? item.tint.withValues(alpha: 0.18)
                    : item.tint.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.tint, size: 20),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                margin: const EdgeInsets.symmetric(vertical: 6),
                color: item.isCurrent
                    ? item.tint.withValues(alpha: 0.34)
                    : secondaryColor.withValues(alpha: 0.22),
              ),
          ],
        ),
        const Gap(14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.weekLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: item.tint,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const Gap(4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: item.isCurrent ? item.tint : null,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: item.tint.withValues(
                          alpha: item.isUnlocked ? 0.14 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: item.tint,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(6),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: secondaryColor,
                    height: 1.5,
                  ),
                ),
                if (item.topics.isNotEmpty) ...[
                  const Gap(10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: item.topics
                        .map(
                          (topic) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: item.tint.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: item.tint,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const Gap(8),
                                Flexible(
                                  child: Text(
                                    topic,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: item.tint,
                                          fontWeight: FontWeight.w700,
                                          height: 1.4,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _initials(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return 'CW';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _formatDateLabel(CohortSessionModel session) {
  final now = DateTime.now();
  if (_isSessionLive(session, now)) return 'Join available now';
  return DateFormat('MMM d • h:mm a').format(session.startsAt);
}

bool _isSessionLive(CohortSessionModel session, DateTime now) {
  return !session.startsAt.isAfter(now) && !session.endsAt.isBefore(now);
}

String _formatNaira(int amount) {
  return '₦${NumberFormat.decimalPattern().format(amount)}';
}

List<CourseSyllabusWeek> _dummySyllabusItems(
  StudentDashboardSnapshot snapshot,
) {
  final title = snapshot.course.title.toLowerCase();
  final weeks = snapshot.totalProgramWeeks.clamp(4, 12);

  if (title.contains('flutter')) {
    return const [
      CourseSyllabusWeek(
        week: 1,
        title: 'Weeks 1–2: Foundations',
        topics: [
          'Flutter overview & setup',
          'Dart fundamentals',
          'Widgets & UI basics',
          'Stateless vs Stateful widgets',
        ],
      ),
      CourseSyllabusWeek(
        week: 3,
        title: 'Weeks 3–4: UI, Input & Navigation',
        topics: [
          'Layout system',
          'Forms & validation',
          'Navigation & data passing',
          'Local state with setState',
        ],
      ),
      CourseSyllabusWeek(
        week: 5,
        title: 'Weeks 5–6: Backend & Authentication',
        topics: [
          'Firebase setup',
          'Authentication',
          'Firestore basics',
          'Real-time data',
        ],
      ),
      CourseSyllabusWeek(
        week: 7,
        title: 'Weeks 7–8: State Management & Architecture',
        topics: [
          'Why state management',
          'Structured state flow',
          'Refactoring apps',
          'Cleaner architecture',
        ],
      ),
      CourseSyllabusWeek(
        week: 9,
        title: 'Weeks 9–10: APIs & Local Storage',
        topics: [
          'REST APIs',
          'HTTP requests',
          'Error handling',
          'Hive local storage',
        ],
      ),
      CourseSyllabusWeek(
        week: 11,
        title: 'Weeks 11–12: Deployment & Final Project',
        topics: [
          'Debugging & optimization',
          'Android builds',
          'Play Store requirements',
          'Final app build & presentation',
        ],
      ),
    ].take(weeks).toList();
  }

  if (title.contains('wordpress') || title.contains('web')) {
    return const [
      CourseSyllabusWeek(
        week: 1,
        title: 'Week 1: WordPress Foundations',
        topics: [
          'What is WordPress',
          'WordPress.com vs WordPress.org',
          'Domain & hosting basics',
          'Dashboard overview',
        ],
      ),
      CourseSyllabusWeek(
        week: 2,
        title: 'Week 2: Themes & Site Structure',
        topics: [
          'Choosing & installing themes',
          'Customizing site identity',
          'Pages, menus & navigation',
          'Permalinks & settings',
        ],
      ),
      CourseSyllabusWeek(
        week: 3,
        title: 'Week 3: Content Creation & Blogging',
        topics: [
          'Posts vs Pages',
          'Blogging basics',
          'Media handling',
          'Categories, tags & metadata',
        ],
      ),
      CourseSyllabusWeek(
        week: 4,
        title: 'Week 4: Plugins & Functionality',
        topics: [
          'Essential plugins',
          'Contact forms',
          'SEO basics',
          'Security & backups',
        ],
      ),
      CourseSyllabusWeek(
        week: 5,
        title: 'Week 5: Business Websites',
        topics: [
          'Landing pages',
          'Service websites',
          'Portfolio & company sites',
          'Client-ready structure',
        ],
      ),
      CourseSyllabusWeek(
        week: 6,
        title: 'Week 6: Deployment & Monetization',
        topics: [
          'Going live',
          'Maintenance basics',
          'Pricing client jobs',
          'Final website project',
        ],
      ),
    ].take(weeks).toList();
  }

  if (title.contains('ai')) {
    return const [
      CourseSyllabusWeek(
        week: 1,
        title: 'Module 1: AI for Developers',
        topics: [
          'Prompting basics',
          'Asking good technical questions',
          'Verification mindset',
        ],
      ),
      CourseSyllabusWeek(
        week: 2,
        title: 'Module 2: AI for Coding & Debugging',
        topics: ['Explaining errors', 'Refactoring code', 'Logic comparison'],
      ),
      CourseSyllabusWeek(
        week: 3,
        title: 'Module 3: AI for UI & UX',
        topics: [
          'Layout suggestions',
          'Color & design assistance',
          'Accessibility checks',
        ],
      ),
      CourseSyllabusWeek(
        week: 4,
        title: 'Module 4: AI for Project Planning',
        topics: [
          'Breaking features into tasks',
          'Estimating scope',
          'Documentation help',
        ],
      ),
      CourseSyllabusWeek(
        week: 5,
        title: 'Module 5: AI for Content & Deployment',
        topics: ['App descriptions', 'Website copy', 'Release notes'],
      ),
      CourseSyllabusWeek(
        week: 6,
        title: 'Module 6: Ethics & Responsible Use',
        topics: [
          'Avoiding dependency',
          'Verification mindset',
          'Learning vs copying',
        ],
      ),
    ].take(weeks).toList();
  }

  return List<CourseSyllabusWeek>.generate(
    weeks,
    (index) => CourseSyllabusWeek(
      week: index + 1,
      title: 'Week ${index + 1}',
      topics: ['Core syllabus module ${index + 1}'],
    ),
  );
}

_GreetingMood _timeGreetingMood() {
  final hour = DateTime.now().hour;
  // Keep greeting visuals consistent with the design system rather than raw emojis.
  if (hour < 12) {
    return const _GreetingMood(
      icon: Icons.waving_hand_rounded,
      colors: [Color(0xFFFFB347), Color(0xFFFF8A65)],
    );
  }
  if (hour < 17) {
    return const _GreetingMood(
      icon: Icons.wb_sunny_rounded,
      colors: [Color(0xFFFFC857), Color(0xFFFFA86A)],
    );
  }
  if (hour < 21) {
    return const _GreetingMood(
      icon: Icons.wb_twilight_rounded,
      colors: [Color(0xFF4F79C7), Color(0xFF7C9CF5)],
    );
  }
  return const _GreetingMood(
    icon: Icons.nights_stay_rounded,
    colors: [Color(0xFF203052), Color(0xFF364A72)],
  );
}

class _GreetingMood {
  const _GreetingMood({required this.icon, required this.colors});

  final IconData icon;
  final List<Color> colors;
}

Future<void> _openJoinLink(BuildContext context, String url) async {
  await _openExternalVideoLink(
    context,
    url,
    invalidMessage: 'Join link is invalid.',
    failedMessage: 'Could not open the join link.',
  );
}

Future<void> _openExternalVideoLink(
  BuildContext context,
  String url, {
  required String invalidMessage,
  String failedMessage = 'Could not open the video link.',
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    showAppSnackBar(context, invalidMessage);
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    showAppSnackBar(context, failedMessage);
  }
}

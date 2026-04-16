import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/demo_data.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/states/app_state_widgets.dart';
import '../cohorts/models/cohort_message_model.dart';
import '../cohorts/models/cohort_session_model.dart';
import '../home/models/student_dashboard_snapshot.dart';
import '../home/state/dashboard_provider.dart';
import '../community/state/community_notifications_provider.dart';
import 'models/mentor_request_model.dart';
import 'state/mentor_request_provider.dart';

class CommunityChannelsScreen extends StatefulWidget {
  const CommunityChannelsScreen({super.key});

  @override
  State<CommunityChannelsScreen> createState() =>
      _CommunityChannelsScreenState();
}

class _CommunityChannelsScreenState extends State<CommunityChannelsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final channels = DemoData.channels
        .where(
          (item) =>
              _query.isEmpty ||
              item.name.toLowerCase().contains(_query.toLowerCase()) ||
              item.description.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return DoubleBackToExitScope(
      child: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 14),
                child: AppCard(
                  radius: 32,
                  shadow: AppShadows.premium,
                  child: Column(
                    children: [
                      Consumer(
                        builder: (context, ref, child) {
                          final unreadCountAsync = ref.watch(
                            unreadMessagesCountProvider,
                          );
                          return PremiumPageHeader(
                            title: 'Community',
                            subtitle:
                                'Join thoughtful student spaces, browse updates, and keep mentor conversations close.',
                            trailing: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                PremiumIconButton(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  onTap: () =>
                                      context.push('/community/messages'),
                                ),
                                if (unreadCountAsync.maybeWhen(
                                  data: (count) => count > 0,
                                  orElse: () => false,
                                ))
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: AppColors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: unreadCountAsync.maybeWhen(
                                        data: (count) => Text(
                                          count > 99 ? '99+' : '$count',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(color: Colors.white),
                                          textAlign: TextAlign.center,
                                        ),
                                        orElse: () => const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Gap(18),
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: 'Search channels...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(
                              color: AppColors.teal,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 130),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Text(
                        'Channels',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${channels.length} total',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Gap(12),
                  if (channels.isEmpty)
                    AppEmptyState(
                      title: 'No channels found',
                      message:
                          'Try another keyword or clear your search to see every space.',
                      icon: Icons.forum_outlined,
                      action: AppButton(
                        label: 'Clear Search',
                        expanded: false,
                        onPressed: () => setState(() => _query = ''),
                      ),
                    )
                  else
                    for (var index = 0; index < channels.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child:
                            _ChannelCard(
                                  channel: channels[index],
                                  onTap: () => context.push(
                                    '/community/chat/${channels[index].id}',
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: (index * 60).ms)
                                .slideY(begin: 0.12),
                      ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClassChatScreen extends StatefulWidget {
  const ClassChatScreen({super.key, required this.channelId});

  final String channelId;

  @override
  State<ClassChatScreen> createState() => _ClassChatScreenState();
}

class _ClassChatScreenState extends State<ClassChatScreen> {
  final _controller = TextEditingController();
  late final List<CommunityMessage> _messages = [...DemoData.communityMessages];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add(
        CommunityMessage(
          id: '${_messages.length + 1}',
          user: 'You',
          avatar: 'ME',
          message: _controller.text.trim(),
          time: 'Now',
          isUser: true,
        ),
      );
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final channel = DemoData.channel(widget.channelId);

    return AppScreen(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(gradient: AppGradients.primary),
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 18),
              child: Row(
                children: [
                  Expanded(
                    child: PremiumPageHeader(
                      title: '#${channel.name}',
                      subtitle: '${channel.members} members active',
                      leading: PremiumIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                        isDark: true,
                      ),
                      trailing: PremiumIconButton(
                        icon: Icons.more_vert_rounded,
                        onTap: () {},
                        isDark: true,
                      ),
                      onDark: true,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: message.isMentor
                              ? AppColors.orange
                              : message.isUser
                              ? AppColors.teal
                              : Colors.grey.shade500,
                          child: Text(
                            message.avatar,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
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
                                    message.user,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: message.isMentor
                                              ? AppColors.orange
                                              : AppColors.foreground,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  if (message.isMentor) ...[
                                    const Gap(8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Mentor',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.orange,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ],
                                  const Gap(8),
                                  Text(
                                    message.time,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const Gap(8),
                              if (message.isCode)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111827),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    message.message,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF4ADE80),
                                          fontFamily: 'monospace',
                                        ),
                                  ),
                                )
                              else
                                Text(message.message),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.code_rounded),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.image_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                      ),
                    ),
                  ),
                  const Gap(8),
                  InkWell(
                    onTap: _send,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
                    ),
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

class AskMentorScreen extends ConsumerStatefulWidget {
  const AskMentorScreen({
    super.key,
    required this.sessionId,
    required this.contextType,
  });

  final String sessionId;
  final MentorRequestContext contextType;

  @override
  ConsumerState<AskMentorScreen> createState() => _AskMentorScreenState();
}

class _AskMentorScreenState extends ConsumerState<AskMentorScreen> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      showAppSnackBar(context, 'Type your question before sending it.');
      return;
    }
    setState(() => _isSending = true);

    try {
      final dashboard = await ref.read(dashboardSnapshotProvider.future);
      final session = _resolveSession(dashboard);
      if (session == null) {
        throw StateError('We could not find this class context right now.');
      }

      await ref
          .read(mentorRequestRepositoryProvider)
          .submitRequest(
            dashboard: dashboard,
            session: session,
            message: text,
            contextType: widget.contextType,
          );
      _controller.clear();
      if (!mounted) return;
      showAppSnackBar(context, 'Your message has been sent.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  CohortSessionModel? _resolveSession(StudentDashboardSnapshot dashboard) {
    for (final item in dashboard.unlockedSessions) {
      if (item.id == widget.sessionId) return item;
    }
    return null;
  }

  List<Widget> _buildConversationTiles(List<MentorChatMessage> messages) {
    if (messages.isEmpty) {
      return const [SliverToBoxAdapter(child: _MentorEmptyConversation())];
    }

    final tiles = <Widget>[];
    DateTime? previousDay;

    for (final message in messages) {
      final currentDay = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (previousDay == null || currentDay != previousDay) {
        tiles.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _MentorDayChip(date: message.createdAt),
            ),
          ),
        );
        previousDay = currentDay;
      }

      tiles.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MentorChatBubble(message: message),
          ),
        ),
      );
    }

    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardSnapshotProvider);
    final requestsAsync = ref.watch(mentorRequestsProvider(widget.sessionId));
    final session = dashboardAsync.maybeWhen(
      data: _resolveSession,
      orElse: () => null,
    );
    final heading = session?.title ?? 'Ask Mentor';
    final pathLabel = session?.pathTitle ?? 'Private support channel';
    final contextLabel = widget.contextType == MentorRequestContext.live
        ? 'Live class support'
        : 'Recorded lesson follow-up';

    return AppScreen(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B3A33),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Row(
                children: [
                  PremiumIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                    isDark: true,
                  ),
                  const Gap(12),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ask Mentor',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Gap(2),
                        Text(
                          '$contextLabel • $heading',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(10),
                  Text(
                    pathLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFE8DDD2)),
                child: requestsAsync.when(
                  loading: () => const AppLoadingState(
                    title: 'Loading conversation...',
                    message:
                        'We are syncing the latest mentor replies for you.',
                    compact: true,
                  ),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppEmptyState(
                        title: 'Messages unavailable',
                        message:
                            'We could not load this conversation right now.',
                        icon: Icons.chat_bubble_outline_rounded,
                        action: AppButton(
                          label: 'Try Again',
                          expanded: false,
                          onPressed: () => ref.invalidate(
                            mentorRequestsProvider(widget.sessionId),
                          ),
                        ),
                      ),
                    ),
                  ),
                  data: (messages) {
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                            child: _MentorIntroBubble(),
                          ),
                        ),
                        ..._buildConversationTiles(messages),
                        const SliverToBoxAdapter(child: Gap(14)),
                      ],
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0EB),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepBlue.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.mood_rounded,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Message mentor',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const Gap(10),
                  InkWell(
                    onTap: _isSending ? null : _submit,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0B8F6A),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
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

class DirectMessagesScreen extends ConsumerStatefulWidget {
  const DirectMessagesScreen({super.key});

  @override
  ConsumerState<DirectMessagesScreen> createState() =>
      _DirectMessagesScreenState();
}

class _DirectMessagesScreenState extends ConsumerState<DirectMessagesScreen> {
  Set<String> _readIds = <String>{};
  Set<String> _hiddenIds = <String>{};
  bool _notificationPrefsReady = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    final readIds = await loadReadNotificationIds();
    final hiddenIds = await loadHiddenNotificationIds();
    if (!mounted) return;
    setState(() {
      _readIds = readIds;
      _hiddenIds = hiddenIds;
      _notificationPrefsReady = true;
    });
  }

  Future<void> _openCohortMessageUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final canLaunch = await canLaunchUrl(uri);
    if (!mounted) return;

    if (!canLaunch) {
      showAppSnackBar(context, 'Cannot open this link right now.');
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCohortMessage(CohortMessageModel item) async {
    await markNotificationRead(item);
    if (!mounted) return;
    setState(() {
      _readIds = {..._readIds, item.id};
    });
    ref.invalidate(unreadMessagesCountProvider);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AppCard(
              radius: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Gap(4),
                            Text(
                              item.cohortLabel.isEmpty
                                  ? 'Cohort update'
                                  : item.cohortLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(18),
                  Text(
                    item.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                      height: 1.55,
                    ),
                  ),
                  const Gap(18),
                  if (item.hasCta)
                    AppButton(
                      label: item.ctaLabel,
                      expanded: false,
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _openCohortMessageUrl(item.ctaUrl);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAllAsRead(List<CohortMessageModel> messages) async {
    if (messages.isEmpty) return;
    await markNotificationsRead(messages);
    if (!mounted) return;
    setState(() {
      _readIds = {..._readIds, ...messages.map((item) => item.id)};
    });
    ref.invalidate(unreadMessagesCountProvider);
  }

  Future<void> _clearAllNotifications(List<CohortMessageModel> messages) async {
    if (messages.isEmpty) return;
    await clearNotifications(messages);
    if (!mounted) return;
    setState(() {
      _hiddenIds = {..._hiddenIds, ...messages.map((item) => item.id)};
      _readIds = {..._readIds, ...messages.map((item) => item.id)};
    });
    ref.invalidate(unreadMessagesCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final cohortMessages = ref.watch(cohortMessagesProvider);
    return cohortMessages.when(
      loading: () => const AppScreen(
        body: SafeArea(
          top: false,
          bottom: false,
          child: AppLoadingState(
            title: 'Loading messages...',
            message: 'We are pulling the latest cohort updates.',
            compact: true,
          ),
        ),
      ),
      error: (error, stack) => AppScreen(
        body: SafeArea(
          top: false,
          child: AppErrorState(
            title: 'Could not load messages',
            message:
                'We could not fetch your cohort messages right now. Please try again.',
            onRetry: () => ref.refresh(cohortMessagesProvider),
          ),
        ),
      ),
      data: (messages) {
        final visibleMessages = messages
            .where((item) => !_hiddenIds.contains(item.id))
            .toList();
        final unreadCount = visibleMessages
            .where((item) => !_readIds.contains(item.id))
            .length;

        return AppScreen(
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(36),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
                  child: Column(
                    children: [
                      PremiumPageHeader(
                        title: 'Notifications',
                        subtitle:
                            'Announcements, updates, and action items from your cohort team.',
                        leading: PremiumIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => context.pop(),
                          isDark: true,
                        ),
                        onDark: true,
                      ),
                      const Gap(18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    unreadCount == 0
                                        ? 'All caught up'
                                        : '$unreadCount unread update${unreadCount == 1 ? '' : 's'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    'Tap any card to open the full notification and follow links.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.white.withValues(
                                            alpha: 0.82,
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: !_notificationPrefsReady
                      ? const AppLoadingState(
                          title: 'Preparing notifications',
                          message: 'Syncing what you have already read.',
                          compact: true,
                        )
                      : visibleMessages.isEmpty
                      ? AppEmptyState(
                          title: 'No notifications left',
                          message: messages.isEmpty
                              ? 'Your admin has not sent any cohort messages yet.'
                              : 'Everything here has been cleared. New updates will appear automatically.',
                          icon: Icons.notifications_off_outlined,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: 'Mark All Read',
                                    expanded: false,
                                    variant: AppButtonVariant.outline,
                                    onPressed: () =>
                                        _markAllAsRead(visibleMessages),
                                  ),
                                ),
                                const Gap(10),
                                Expanded(
                                  child: AppButton(
                                    label: 'Clear',
                                    expanded: false,
                                    variant: AppButtonVariant.ghost,
                                    onPressed: () =>
                                        _clearAllNotifications(visibleMessages),
                                  ),
                                ),
                              ],
                            ),
                            const Gap(16),
                            ...List.generate(visibleMessages.length, (index) {
                              final item = visibleMessages[index];
                              final isUnread = !_readIds.contains(item.id);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _openCohortMessage(item),
                                    borderRadius: BorderRadius.circular(28),
                                    child: AppCard(
                                      radius: 28,
                                      color: isUnread
                                          ? AppColors.deepBlue.withValues(
                                              alpha: 0.04,
                                            )
                                          : null,
                                      border: Border.all(
                                        color: isUnread
                                            ? AppColors.teal.withValues(
                                                alpha: 0.26,
                                              )
                                            : AppColors.deepBlue.withValues(
                                                alpha: 0.06,
                                              ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  gradient: isUnread
                                                      ? AppGradients.primary
                                                      : AppGradients.accent,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  isUnread
                                                      ? Icons
                                                            .mark_chat_unread_rounded
                                                      : Icons.drafts_rounded,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const Gap(14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item.title,
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .titleMedium
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 6,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isUnread
                                                                ? AppColors
                                                                      .orange
                                                                      .withValues(
                                                                        alpha:
                                                                            0.14,
                                                                      )
                                                                : AppColors.teal
                                                                      .withValues(
                                                                        alpha:
                                                                            0.14,
                                                                      ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            isUnread
                                                                ? 'New'
                                                                : 'Read',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelSmall
                                                                ?.copyWith(
                                                                  color:
                                                                      isUnread
                                                                      ? AppColors
                                                                            .orange
                                                                      : AppColors
                                                                            .teal,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const Gap(6),
                                                    Text(
                                                      item.body,
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: AppColors
                                                                .mutedForeground,
                                                            height: 1.5,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Gap(14),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 16,
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                              const Gap(6),
                                              Text(
                                                MaterialLocalizations.of(
                                                  context,
                                                ).formatShortDate(
                                                  item.createdAt,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: AppColors
                                                          .mutedForeground,
                                                    ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                item.hasCta
                                                    ? 'Open update'
                                                    : 'View details',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      color: AppColors.teal,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const Gap(8),
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                color: AppColors.teal,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
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

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.onTap});

  final Channel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AppCard(
        radius: 26,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: channel.colors),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.tag_rounded, color: Colors.white),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${channel.name}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (channel.unread > 0) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: const BoxDecoration(
                            color: AppColors.orange,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          child: Text(
                            '${channel.unread}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Gap(8),
                  Text(
                    channel.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_rounded,
                        size: 16,
                        color: AppColors.mutedForeground,
                      ),
                      const Gap(6),
                      Text(
                        '${channel.members} members',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(12),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _MentorIntroBubble extends StatelessWidget {
  const _MentorIntroBubble();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF2C7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Mentor replies appear here as soon as your tutor responds from the admin inbox.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.deepBlueDark),
        ),
      ),
    );
  }
}

class _MentorEmptyConversation extends StatelessWidget {
  const _MentorEmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Column(
        children: [
          Icon(
            Icons.mark_chat_unread_outlined,
            color: AppColors.mutedForeground.withValues(alpha: 0.7),
            size: 28,
          ),
          const Gap(10),
          Text(
            'Start the conversation',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Gap(6),
          Text(
            'Send your first message and it will appear here like a real chat thread.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _MentorDayChip extends StatelessWidget {
  const _MentorDayChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _formatMentorDay(date),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
        ),
      ),
    );
  }
}

class _MentorChatBubble extends StatelessWidget {
  const _MentorChatBubble({required this.message});

  final MentorChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bubbleColor = isMine ? const Color(0xFFD9FDD3) : Colors.white;
    final radius = isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(6),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(22),
          );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 318),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine) ...[
                  Text(
                    message.senderName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.tealDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Gap(4),
                ],
                Text(
                  message.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.foreground,
                    height: 1.5,
                  ),
                ),
                const Gap(6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMentorMessageTime(message.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isMine) ...[
                      const Gap(6),
                      Icon(
                        message.isResolved
                            ? Icons.done_all_rounded
                            : message.isRead
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 16,
                        color: message.isResolved || message.isRead
                            ? AppColors.tealDark
                            : AppColors.mutedForeground,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMentorMessageTime(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);
  if (difference.inDays == 0) {
    final hour = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final meridiem = timestamp.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $meridiem';
  }
  return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
}

String _formatMentorDay(DateTime timestamp) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(timestamp.year, timestamp.month, timestamp.day);
  final difference = today.difference(target).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/data/demo_data.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/states/app_state_widgets.dart';
import '../cohorts/models/cohort_session_model.dart';
import '../cohorts/presentation/session_status.dart';

class RecordedPlayerScreen extends ConsumerWidget {
  const RecordedPlayerScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardSnapshotProvider);

    return dashboardState.when(
      loading: () => const AppScreen(
        body: SafeArea(
          top: false,
          child: AppLoadingState(
            compact: true,
            title: 'Loading recording...',
            message: 'Preparing your in-app playback experience.',
          ),
        ),
      ),
      error: (error, _) => AppScreen(
        body: SafeArea(
          top: false,
          child: AppErrorState(
            compact: true,
            title: 'Recording unavailable',
            message: 'We could not load this recorded session right now.',
            onRetry: () => ref.refresh(dashboardSnapshotProvider),
          ),
        ),
      ),
      data: (dashboard) {
        CohortSessionModel? session;
        for (final item in dashboard.unlockedSessions) {
          if (item.id == lessonId && item.hasRecordingUrl) {
            session = item;
            break;
          }
        }

        if (session == null) {
          return const AppScreen(
            body: SafeArea(
              top: false,
              child: AppEmptyState(
                title: 'Recording not ready',
                message:
                    'This class does not have a published recording link yet.',
                icon: Icons.play_lesson_outlined,
              ),
            ),
          );
        }

        return AppScreen(body: _ProtectedRecordedPlayer(session: session));
      },
    );
  }
}

class _ProtectedRecordedPlayer extends StatefulWidget {
  const _ProtectedRecordedPlayer({required this.session});

  final CohortSessionModel session;

  @override
  State<_ProtectedRecordedPlayer> createState() =>
      _ProtectedRecordedPlayerState();
}

class _ProtectedRecordedPlayerState extends State<_ProtectedRecordedPlayer> {
  YoutubePlayerController? _controller;
  bool _isLoading = true;
  bool _isPlayable = true;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    final recordingUri = Uri.tryParse(widget.session.recordingUrl);
    final videoId = recordingUri == null
        ? null
        : _extractYoutubeId(recordingUri);
    if (videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          loop: false,
          disableDragSeek: false,
          enableCaption: false,
          forceHD: false,
          hideControls: false,
          controlsVisibleAtStart: true,
          hideThumbnail: false,
          showLiveFullscreenButton: false,
          // Disable related videos and navigation
          // forceHideAnnotation: true, // Removed: not a valid parameter
        ),
      )..addListener(_onPlayerStateChange);
    } else {
      _isPlayable = false;
      _isLoading = false;
    }
  }

  void _onPlayerStateChange() {
    final controller = _controller;
    if (controller != null && controller.value.isReady && _isLoading) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = resolveSessionStatus(widget.session);
    final controller = _controller;

    final player = controller == null
        ? null
        : YoutubePlayer(
            controller: controller,
            showVideoProgressIndicator: true,
            progressIndicatorColor: AppColors.teal,
            progressColors: ProgressBarColors(
              playedColor: AppColors.teal,
              handleColor: AppColors.tealLight,
              bufferedColor: Colors.grey.shade400,
              backgroundColor: Colors.grey.shade600,
            ),
            onReady: () {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
          );

    if (player == null) {
      return _RecordedPlayerLayout(
        session: widget.session,
        status: status,
        isDark: isDark,
        isPlayable: _isPlayable,
        isLoading: _isLoading,
        player: null,
      );
    }

    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        if (!mounted) return;
        setState(() => _isFullscreen = true);
      },
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        if (!mounted) return;
        setState(() => _isFullscreen = false);
      },
      player: player,
      builder: (context, playerWidget) {
        return _RecordedPlayerLayout(
          session: widget.session,
          status: status,
          isDark: isDark,
          isPlayable: _isPlayable,
          isLoading: _isLoading,
          player: playerWidget,
          isFullscreen: _isFullscreen,
        );
      },
    );
  }
}

class _RecordedPlayerLayout extends StatelessWidget {
  const _RecordedPlayerLayout({
    required this.session,
    required this.status,
    required this.isDark,
    required this.isPlayable,
    required this.isLoading,
    required this.player,
    this.isFullscreen = false,
  });

  final CohortSessionModel session;
  final SessionStatusSnapshot status;
  final bool isDark;
  final bool isPlayable;
  final bool isLoading;
  final Widget? player;
  final bool isFullscreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: !isFullscreen,
      bottom: false,
      child: Column(
        children: [
          if (!isFullscreen)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 14),
              child: Row(
                children: [
                  _OverlayActionButton(
                    icon: PhosphorIconsBold.arrowLeft,
                    onTap: () => context.pop(),
                    isDark: isDark,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recorded Session',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _OverlayActionButton(
                    icon: PhosphorIconsBold.user,
                    onTap: () => context.push('/community/messages'),
                    isDark: isDark,
                  ),
                  const Gap(10),
                  _OverlayActionButton(
                    icon: PhosphorIconsBold.folderOpen,
                    onTap: () => context.push('/resources'),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: isDark
                      ? const Color(0xFF1A1A1A)
                      : Colors.grey.shade200,
                ),
                if (player != null)
                  player!
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        isPlayable
                            ? 'Preparing secure playback...'
                            : 'This recording is not in a supported YouTube format yet.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (isLoading)
                  Container(
                    color: isDark
                        ? const Color(0xFF1A1A1A)
                        : Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppShimmerBlock(
                          width: 84,
                          height: 84,
                          radius: 999,
                        ),
                        const Gap(14),
                        Text(
                          'Loading player...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!isFullscreen)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PlayerPill(
                          icon: PhosphorIconsFill.playCircle,
                          label: status.statusLabel,
                          color: AppColors.teal,
                        ),
                        const Gap(10),
                        _PlayerPill(
                          icon: PhosphorIconsFill.calendarDots,
                          label: status.scheduleLabel,
                          color: AppColors.deepBlueLight,
                        ),
                      ],
                    ),
                    const Gap(18),
                    Text(
                      session.pathTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.orangeLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      session.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(10),
                    Text(
                      session.notes.isEmpty
                          ? 'Recording is available now. Class notes will appear here when they are published.'
                          : session.notes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.65,
                      ),
                    ),
                    const Gap(18),
                    AdaptiveWrap(
                      minItemWidth: 150,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _RecordedAction(
                          icon: PhosphorIconsBold.checkCircle,
                          title: 'Mark Complete',
                          color: Colors.green,
                          onTap: () => showAppSnackBar(
                            context,
                            'Completion tracking can be connected next.',
                          ),
                        ),
                        _RecordedAction(
                          icon: PhosphorIconsBold.user,
                          title: 'Ask Mentor',
                          color: AppColors.purple,
                          onTap: () => context.push('/ai-tutor/${session.id}'),
                        ),
                        _RecordedAction(
                          icon: PhosphorIconsBold.folderOpen,
                          title: 'Resources',
                          color: Colors.blue,
                          onTap: () => context.push('/resources'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverlayActionButton extends StatelessWidget {
  const _OverlayActionButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: isDark ? Colors.white : Colors.black,
          size: 20,
        ),
      ),
    );
  }
}

class _PlayerPill extends StatelessWidget {
  const _PlayerPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const Gap(8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _extractYoutubeId(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host.contains('youtu.be')) {
    return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  }
  if (host.contains('youtube.com')) {
    final videoId = uri.queryParameters['v'];
    if (videoId != null && videoId.isNotEmpty) return videoId;
    final embedIndex = uri.pathSegments.indexOf('embed');
    if (embedIndex != -1 && embedIndex + 1 < uri.pathSegments.length) {
      return uri.pathSegments[embedIndex + 1];
    }
  }
  return null;
}

class ResourcesLibraryScreen extends StatefulWidget {
  const ResourcesLibraryScreen({super.key});

  @override
  State<ResourcesLibraryScreen> createState() => _ResourcesLibraryScreenState();
}

class _ResourcesLibraryScreenState extends State<ResourcesLibraryScreen> {
  String _query = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final resources = DemoData.libraryResources.where((resource) {
      final filterMatches =
          _filter == 'all' ||
          (_filter == 'pdf' && resource.type.toLowerCase() == 'pdf') ||
          (_filter == 'code' && resource.type.toLowerCase() != 'pdf') ||
          (_filter == 'video' && resource.type.toLowerCase() == 'video');
      final queryMatches =
          _query.isEmpty ||
          resource.name.toLowerCase().contains(_query.toLowerCase()) ||
          resource.folder.toLowerCase().contains(_query.toLowerCase());
      return filterMatches && queryMatches;
    }).toList();

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumPageHeader(
                    title: 'Resources',
                    subtitle:
                        'Browse class notes, downloads, and curated materials with quick search.',
                    leading: PremiumIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                      isDark: true,
                    ),
                    onDark: true,
                  ),
                  const Gap(10),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search resources...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      fillColor: Colors.white,
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future<void>.delayed(const Duration(milliseconds: 600));
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filter in const [
                            'all',
                            'pdf',
                            'code',
                            'video',
                          ]) ...[
                            _FilterChip(
                              label: filter,
                              active: _filter == filter,
                              onTap: () => setState(() => _filter = filter),
                            ),
                            const Gap(10),
                          ],
                        ],
                      ),
                    ),
                    const Gap(20),
                    Text(
                      'Folders',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Gap(12),
                    AdaptiveWrap(
                      minItemWidth: 150,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final folder in DemoData.libraryFolders)
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: folder.$1 == 'Projects'
                                          ? const [
                                              AppColors.orange,
                                              AppColors.orangeLight,
                                            ]
                                          : folder.$1 == 'Week 2 - Advanced'
                                          ? const [
                                              AppColors.purple,
                                              Color(0xFFA78BFA),
                                            ]
                                          : const [
                                              Color(0xFF3B82F6),
                                              Color(0xFF2563EB),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.folder_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const Gap(12),
                                Text(
                                  folder.$1,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const Gap(6),
                                Text(
                                  '${folder.$2} files',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const Gap(22),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Text(
                          'All Resources',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Sort by'),
                        ),
                      ],
                    ),
                    const Gap(12),
                    if (resources.isEmpty)
                      AppEmptyState(
                        title: 'No matching resources',
                        message:
                            'Try a broader search term or switch the selected filter.',
                        icon: Icons.folder_off_rounded,
                        action: AppButton(
                          label: 'Clear Filters',
                          expanded: false,
                          onPressed: () {
                            setState(() {
                              _query = '';
                              _filter = 'all';
                            });
                          },
                        ),
                      )
                    else
                      for (final resource in resources)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.description_outlined,
                                  color: Colors.blue,
                                ),
                              ),
                              title: Text(resource.name),
                              subtitle: Text(
                                '${resource.type} • ${resource.size} • ${resource.date}',
                              ),
                              trailing: const Icon(Icons.download_rounded),
                              onTap: () => showAppSnackBar(
                                context,
                                'Download placeholder for ${resource.name}',
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiTutorScreen extends ConsumerStatefulWidget {
  const AiTutorScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends ConsumerState<AiTutorScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref
        .read(aiTutorChatProvider(widget.lessonId).notifier)
        .sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiTutorChatProvider(widget.lessonId));

    return AppScreen(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.purple, Color(0xFF6D28D9)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 20),
              child: PremiumPageHeader(
                title: 'AI Tutor',
                subtitle: 'Always ready to help',
                leading: PremiumIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => context.pop(),
                  isDark: true,
                ),
                trailing: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.purple,
                  ),
                ),
                onDark: true,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  for (final message in state.messages)
                    Align(
                      alignment: message.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        constraints: const BoxConstraints(maxWidth: 310),
                        decoration: BoxDecoration(
                          gradient: message.isUser
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.deepBlue,
                                    AppColors.deepBlueLight,
                                  ],
                                )
                              : null,
                          color: message.isUser ? null : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(24),
                            topRight: const Radius.circular(24),
                            bottomLeft: Radius.circular(
                              message.isUser ? 24 : 8,
                            ),
                            bottomRight: Radius.circular(
                              message.isUser ? 8 : 24,
                            ),
                          ),
                          boxShadow: message.isUser ? null : AppShadows.card,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!message.isUser) ...[
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: AppColors.purple,
                                  ),
                                  const Gap(6),
                                  Text(
                                    'AI Tutor',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: AppColors.purple,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                              const Gap(8),
                            ],
                            Text(
                              message.text,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: message.isUser
                                        ? Colors.white
                                        : AppColors.foreground,
                                    height: 1.6,
                                  ),
                            ),
                            const Gap(8),
                            Text(
                              message.time,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: message.isUser
                                        ? Colors.white70
                                        : AppColors.mutedForeground,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (state.isTyping)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: AppShadows.card,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            3,
                            (index) =>
                                Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade400,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                    .animate(
                                      onPlay: (controller) =>
                                          controller.repeat(),
                                    )
                                    .fade(
                                      delay: (index * 120).ms,
                                      begin: 0.2,
                                      end: 1,
                                    )
                                    .scale(delay: (index * 120).ms),
                          ),
                        ),
                      ),
                    ),
                  if (state.messages.length == 1) ...[
                    const Gap(12),
                    Text(
                      'Quick questions:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Gap(10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final item in DemoData.quickTutorQuestions) ...[
                            OutlinedButton(
                              onPressed: () => _controller.text = item,
                              child: Text(item),
                            ),
                            const Gap(8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask me anything...',
                      ),
                    ),
                  ),
                  const Gap(10),
                  InkWell(
                    onTap: _send,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.purple, Color(0xFF6D28D9)],
                        ),
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

class _RecordedAction extends StatelessWidget {
  const _RecordedAction({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const Gap(10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.deepBlue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active ? null : AppShadows.card,
        ),
        child: Text(
          label[0].toUpperCase() + label.substring(1),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: active ? Colors.white : AppColors.foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

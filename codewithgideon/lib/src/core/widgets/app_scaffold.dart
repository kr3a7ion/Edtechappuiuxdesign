import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../state/app_providers.dart';
import '../theme/app_theme.dart';
import '../../features/community/state/community_notifications_provider.dart';
import 'bottom_nav.dart';

class PhoneViewport extends StatelessWidget {
  const PhoneViewport({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final shellColor = brightness == Brightness.dark
        ? AppColors.deepBlueDark
        : AppColors.shellBackground;
    return LayoutBuilder(
      builder: (context, constraints) {
        final useFrame = constraints.maxWidth >= 560;

        return ColoredBox(
          color: shellColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: useFrame ? 18 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(useFrame ? 36 : 0),
                  child: Material(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    elevation: useFrame ? 18 : 0,
                    shadowColor: AppColors.deepBlue.withValues(alpha: 0.12),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: const Color(0x00000000),
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: PhoneViewport(
        child: Scaffold(
          backgroundColor:
              backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          extendBody: true,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ),
    );
  }
}

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  String? _preloadedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);
    ref.watch(unreadMessagesCountProvider);
    _preloadIfNeeded();

    return AppScreen(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: PremiumBottomNav(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }

  void _preloadIfNeeded() {
    final authState = ref.read(authControllerProvider);
    final session = authState.session;
    final preloadKey =
        '${session?.uid ?? 'guest'}:${authState.enrollmentStatus.name}:${authState.isAuthenticated}';

    if (_preloadedKey == preloadKey) return;
    _preloadedKey = preloadKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (authState.isAuthenticated &&
          authState.enrollmentStatus == EnrollmentStatus.enrolled) {
        ref.read(dashboardSnapshotProvider.future);
      } else if (authState.isAuthenticated &&
          authState.enrollmentStatus == EnrollmentStatus.notRegistered) {
        ref.read(catalogRepositoryProvider).getPaths();
      }
    });
  }
}

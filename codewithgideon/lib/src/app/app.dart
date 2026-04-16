import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state/app_providers.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/states/app_state_widgets.dart';
import 'router.dart';

class CodeWithGideonApp extends ConsumerWidget {
  const CodeWithGideonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsProvider);
    final networkStatus = ref.watch(networkStatusProvider);
    final authState = ref.watch(authControllerProvider);
    final isOffline = networkStatus.maybeWhen(
      data: (value) => value == NetworkStatus.offline,
      orElse: () => false,
    );

    return MaterialApp.router(
      title: 'CodeWithGideon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        NotificationService().consumePendingNavigation();
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(
              mediaQuery.textScaler.scale(1).clamp(1, 1.25),
            ),
          ),
          child: Stack(
            children: [
              if (child != null) child,
              IgnorePointer(
                ignoring: !authState.isLoading,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: authState.isLoading ? 1 : 0,
                  child: const _GlobalLoadingOverlay(),
                ),
              ),
              AppOfflineBanner(visible: isOffline),
            ],
          ),
        );
      },
    );
  }
}

class _GlobalLoadingOverlay extends StatelessWidget {
  const _GlobalLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: (isDark ? AppColors.deepBlueDark : Colors.white).withValues(
        alpha: 0.56,
      ),
      child: SafeArea(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.deepBlue.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PremiumLoader(
                  size: 40,
                  dotSize: 7,
                  primaryColor: isDark
                      ? AppColors.darkForeground
                      : AppColors.deepBlue,
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

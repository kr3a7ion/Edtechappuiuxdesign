import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../theme/app_theme.dart';
import 'states/app_state_widgets.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

const _brandLogoAsset = 'assets/branding/codewithgideon_logo.png';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.expanded = true,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final foreground = _foregroundColor(context);
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: PremiumLoader(
              size: 18,
              dotSize: 4,
              primaryColor: foreground,
              trackColor: foreground.withValues(alpha: 0.2),
            ),
          )
        // ignore: use_null_aware_elements
        else if (leading != null)
          leading!,
        if (leading != null || isLoading) const Gap(10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: foreground),
          ),
        ),
        // ignore: use_null_aware_elements
        if (trailing != null) ...[const Gap(10), trailing!],
      ],
    );

    return SizedBox(
      width: expanded ? double.infinity : null,
      child: Semantics(
        button: true,
        enabled: onPressed != null && !isLoading,
        label: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: _gradient(),
            color: _fillColor(),
            borderRadius: BorderRadius.circular(22),
            boxShadow: _boxShadow(),
            border: variant == AppButtonVariant.outline
                ? Border.all(color: AppColors.deepBlue, width: 1.6)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading || onPressed == null
                  ? null
                  : () {
                      onPressed?.call();
                    },
              borderRadius: BorderRadius.circular(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Gradient? _gradient() {
    return switch (variant) {
      AppButtonVariant.primary => AppGradients.primary,
      AppButtonVariant.secondary => AppGradients.accent,
      AppButtonVariant.danger => AppGradients.danger,
      _ => null,
    };
  }

  Color? _fillColor() {
    return switch (variant) {
      AppButtonVariant.outline => Colors.transparent,
      AppButtonVariant.ghost => AppColors.muted,
      _ => null,
    };
  }

  Color _foregroundColor(BuildContext context) {
    return switch (variant) {
      AppButtonVariant.outline => AppColors.deepBlue,
      AppButtonVariant.ghost => Theme.of(context).colorScheme.onSurface,
      _ => Colors.white,
    };
  }

  List<BoxShadow>? _boxShadow() {
    return switch (variant) {
      AppButtonVariant.primary => AppShadows.card,
      AppButtonVariant.secondary => AppShadows.card,
      AppButtonVariant.danger => AppShadows.card,
      _ => null,
    };
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.onChanged,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(10),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          inputFormatters: inputFormatters,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: AppColors.mutedForeground),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.color,
    this.border,
    this.shadow,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return Container(
      decoration: BoxDecoration(
        color: color ?? theme.cardColor,
        borderRadius: BorderRadius.circular(radius),
        border:
            border ??
            Border.all(
              color: brightness == Brightness.dark
                  ? AppColors.darkBorder
                  : AppColors.deepBlue.withValues(alpha: 0.06),
            ),
        boxShadow:
            shadow ??
            [
              BoxShadow(
                color: brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.18)
                    : AppColors.deepBlue.withValues(alpha: 0.05),
                blurRadius: brightness == Brightness.dark ? 26 : 20,
                offset: const Offset(0, 8),
              ),
            ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class AppAtmosphereBackdrop extends StatelessWidget {
  const AppAtmosphereBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      AppColors.darkBackground,
                      const Color(0xFF0D1728),
                      const Color(0xFF122033),
                    ]
                  : [
                      AppColors.deepBlue.withValues(alpha: 0.02),
                      AppColors.deepBlueLight.withValues(alpha: 0.02),
                      AppColors.teal.withValues(alpha: 0.02),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        _BackdropOrb(
          color: isDark ? AppColors.tealLight : AppColors.teal,
          size: 280,
          top: -70,
          right: -90,
          opacity: isDark ? 0.1 : 0.1,
        ),
        _BackdropOrb(
          color: isDark ? AppColors.deepBlueLight : AppColors.deepBlue,
          size: 280,
          bottom: -80,
          left: -90,
          opacity: isDark ? 0.12 : 0.08,
        ),
      ],
    );
  }
}

class AdaptiveWrap extends StatelessWidget {
  const AdaptiveWrap({
    super.key,
    required this.children,
    this.minItemWidth = 140,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite || maxWidth <= minItemWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) Gap(runSpacing),
              ],
            ],
          );
        }

        final rawColumns = ((maxWidth + spacing) / (minItemWidth + spacing))
            .floor()
            .clamp(1, children.length);
        final columns = rawColumns;
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({
    required this.color,
    required this.size,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.opacity = 0.3,
  });

  final Color color;
  final double size;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity),
              blurRadius: 90,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 136,
    this.semanticLabel = 'CodeWithGideon logo',
  });

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Image.asset(
        _brandLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 112,
    this.showBadge = true,
    this.isCircular = false,
  });

  final double size;
  final bool showBadge;
  final bool isCircular;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Semantics(
            label: 'CodeWithGideon logo',
            image: true,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isCircular
                    ? null
                    : BorderRadius.circular(size * 0.28),
                boxShadow: AppShadows.premium,
              ),
              padding: EdgeInsets.all(size * 0.16),
              child: SvgPicture.asset(
                'assets/branding/codewithgideon_mark.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                width: size * 0.26,
                height: size * 0.26,
                decoration: BoxDecoration(
                  gradient: AppGradients.accent,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.card,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: size * 0.13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BrandHeroLockup extends StatelessWidget {
  const BrandHeroLockup({
    super.key,
    this.markSize = 124,
    this.wordmarkHeight = 28,
    this.wordmarkColor = AppColors.foreground,
    this.caption,
    this.center = true,
    this.showWordmark = true,
  });

  final double markSize;
  final double wordmarkHeight;
  final Color wordmarkColor;
  final String? caption;
  final bool center;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final alignment = center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        SizedBox(
          width: markSize * 1.72,
          height: markSize * 1.72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: markSize * 1.72,
                height: markSize * 1.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.teal.withValues(alpha: 0.24),
                      AppColors.deepBlueLight.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.1, 0.52, 1],
                  ),
                ),
              ),
              Container(
                width: markSize * 1.34,
                height: markSize * 1.34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.84),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepBlue.withValues(alpha: 0.11),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
              ),
              BrandMark(size: markSize, showBadge: false, isCircular: true),
            ],
          ),
        ),
        if (showWordmark) ...[
          const Gap(18),
          BrandWordmark(height: wordmarkHeight, color: wordmarkColor),
        ],
        if (caption != null) ...[
          const Gap(10),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: markSize * 2.5),
            child: Text(
              caption!,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
                height: 1.55,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.height = 24, this.color = Colors.white});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fontSize = height * 0.92;
    return Semantics(
      label: 'CodeWithGideon',
      child: Text(
        'CodeWithGideon',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
      ),
    );
  }
}

class PremiumIconButton extends StatelessWidget {
  const PremiumIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isDark = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.deepBlue.withValues(alpha: 0.06),
          ),
          boxShadow: isDark ? null : AppShadows.card,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white : AppColors.deepBlueDark,
        ),
      ),
    );
  }
}

class PremiumPageHeader extends StatelessWidget {
  const PremiumPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onDark = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final titleColor = onDark ? Colors.white : AppColors.deepBlueDark;
    final subtitleColor = onDark ? Colors.white70 : AppColors.mutedForeground;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const Gap(14)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Gap(10),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const Gap(6),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: subtitleColor,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const Gap(14), trailing!],
      ],
    );
  }
}

void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
}

class DoubleBackToExitScope extends StatefulWidget {
  const DoubleBackToExitScope({
    super.key,
    required this.child,
    this.message = 'Press back again to close the app.',
  });

  final Widget child;
  final String message;

  @override
  State<DoubleBackToExitScope> createState() => _DoubleBackToExitScopeState();
}

class _DoubleBackToExitScopeState extends State<DoubleBackToExitScope> {
  DateTime? _lastBackPressAt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final now = DateTime.now();
        final shouldExit =
            _lastBackPressAt != null &&
            now.difference(_lastBackPressAt!) <= const Duration(seconds: 2);

        if (shouldExit) {
          SystemNavigator.pop();
          return;
        }

        _lastBackPressAt = now;
        showAppSnackBar(context, widget.message);
      },
      child: widget.child,
    );
  }
}

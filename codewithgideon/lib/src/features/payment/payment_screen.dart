import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/payment_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_controls.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/states/app_state_widgets.dart';
import '../entry/state/auth_provider.dart';
import '../home/state/dashboard_provider.dart';
import 'models/payment_checkout_model.dart';
import 'state/payment_provider.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.kind, this.returnTo});

  final PaymentFlowKind kind;
  final String? returnTo;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late Future<PaymentCheckoutModel> _checkoutFuture;
  late final TextEditingController _weeksController;
  bool _hasSeededWeeks = false;
  bool _processing = false;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _weeksController = TextEditingController();
    final session = ref.read(authControllerProvider).session;
    _checkoutFuture = ref
        .read(paymentRepositoryProvider)
        .loadCheckout(uid: session!.uid, kind: widget.kind);
  }

  @override
  void dispose() {
    _weeksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      body: Stack(
        children: [
          SafeArea(
            top: false,
            bottom: false,
            child: FutureBuilder<PaymentCheckoutModel>(
              future: _checkoutFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return AppLoadingState(
                    title: widget.kind == PaymentFlowKind.topUp
                        ? 'Preparing your top-up'
                        : 'Preparing your payment',
                    message:
                        'We are syncing your course plan, week limit, and secure checkout details.',
                    compact: true,
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _PaymentErrorState(
                    message:
                        'We could not prepare your payment right now. Please try again.',
                    onBack: _handleExit,
                    onRetry: () {
                      setState(() {
                        final session = ref
                            .read(authControllerProvider)
                            .session;
                        _checkoutFuture = ref
                            .read(paymentRepositoryProvider)
                            .loadCheckout(uid: session!.uid, kind: widget.kind);
                      });
                    },
                  );
                }

                final checkout = snapshot.data!;
                if (!_hasSeededWeeks) {
                  _weeksController.text = '${checkout.suggestedWeeks}';
                  _hasSeededWeeks = true;
                }

                final requestedWeeks = _parseWeeks(checkout);
                final pricing = ref
                    .read(paymentRepositoryProvider)
                    .quote(checkout: checkout, weeks: requestedWeeks);
                final isWeeksValid =
                    checkout.maxAllowedWeeks > 0 &&
                    requestedWeeks >= 1 &&
                    requestedWeeks <= checkout.maxAllowedWeeks;

                return RefreshIndicator(
                  color: AppColors.deepBlue,
                  onRefresh: () async {
                    setState(() {
                      final session = ref.read(authControllerProvider).session;
                      _hasSeededWeeks = false;
                      _checkoutFuture = ref
                          .read(paymentRepositoryProvider)
                          .loadCheckout(uid: session!.uid, kind: widget.kind);
                    });
                    await _checkoutFuture;
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 40),
                    children: [
                      PremiumPageHeader(
                        leading: PremiumIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: _handleExit,
                        ),
                        title: checkout.kind.title,
                      ),
                      const Gap(24),
                      _PaymentHero(checkout: checkout, pricing: pricing),
                      const Gap(18),
                      if (checkout.hasMatchingPendingPayment)
                        _PendingPaymentCard(checkout: checkout),
                      if (checkout.hasMatchingPendingPayment) const Gap(18),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weeks to unlock',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Gap(8),
                            Text(
                              checkout.kind == PaymentFlowKind.topUp
                                  ? 'You already have ${checkout.committedWeeks} week(s). Choose how many more weeks to unlock now.'
                                  : 'Choose the number of weeks you want to unlock for this registration.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.mutedForeground),
                            ),
                            const Gap(18),
                            AppTextField(
                              label: 'Weeks',
                              hint: 'Enter number of weeks',
                              controller: _weeksController,
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.calendar_month_rounded,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setState(() {}),
                            ),
                            const Gap(14),
                            _WeekStepper(
                              value: requestedWeeks.clamp(
                                checkout.maxAllowedWeeks <= 0 ? 0 : 1,
                                checkout.maxAllowedWeeks <= 0
                                    ? 0
                                    : checkout.maxAllowedWeeks,
                              ),
                              canDecrease: requestedWeeks > 1,
                              canIncrease:
                                  checkout.maxAllowedWeeks > 0 &&
                                  requestedWeeks < checkout.maxAllowedWeeks,
                              onDecrease: () =>
                                  _adjustWeeks(checkout, delta: -1),
                              onIncrease: () =>
                                  _adjustWeeks(checkout, delta: 1),
                            ),
                            const Gap(10),
                            Text(
                              checkout.kind == PaymentFlowKind.topUp
                                  ? 'Available range: 1 to ${checkout.maxAllowedWeeks} week(s)'
                                  : 'Available range: 1 to ${checkout.totalProgramWeeks} week(s)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (!isWeeksValid) ...[
                              const Gap(10),
                              Text(
                                checkout.maxAllowedWeeks == 0
                                    ? 'All program weeks are already unlocked.'
                                    : 'Enter a value between 1 and ${checkout.maxAllowedWeeks}.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.danger),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Gap(18),
                      _PaymentSummaryCard(pricing: pricing),
                      const Gap(24),
                      AppButton(
                        label:
                            '${checkout.kind.actionLabel} • ${_formatNaira(pricing.totalPrice)}',
                        isLoading: _processing,
                        onPressed: !isWeeksValid || _processing
                            ? null
                            : () => _startPayment(checkout, pricing),
                      ),
                      const Gap(12),
                      TextButton(
                        onPressed: _processing ? null : _handleExit,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_processing)
            const Positioned.fill(child: _PaymentProcessingOverlay()),
        ],
      ),
    );
  }

  int _parseWeeks(PaymentCheckoutModel checkout) {
    final parsed = int.tryParse(_weeksController.text.trim());
    if (parsed == null) return checkout.suggestedWeeks;
    return parsed;
  }

  void _adjustWeeks(PaymentCheckoutModel checkout, {required int delta}) {
    final current = _parseWeeks(checkout);
    final upper = checkout.maxAllowedWeeks <= 0 ? 0 : checkout.maxAllowedWeeks;
    final next = upper == 0 ? 0 : (current + delta).clamp(1, upper);
    _weeksController.value = TextEditingValue(
      text: '$next',
      selection: TextSelection.collapsed(offset: '$next'.length),
    );
    setState(() {});
  }

  void _handleExit() {
    final fallback = widget.kind == PaymentFlowKind.topUp
        ? '/dashboard'
        : '/continue-registration';
    final target = widget.returnTo ?? fallback;

    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    context.go(target);
  }

  Future<void> _startPayment(
    PaymentCheckoutModel checkout,
    PaymentPriceBreakdown pricing,
  ) async {
    if (_processing) return;
    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      showAppSnackBar(context, 'Your session expired. Please sign in again.');
      return;
    }
    if (PaymentConfig.initializeUrl.isEmpty ||
        PaymentConfig.verifyUrl.isEmpty ||
        PaymentConfig.callbackUrl.isEmpty) {
      showAppSnackBar(
        context,
        'Payment is not configured yet. Add the Paystack URLs before trying again.',
      );
      return;
    }

    final paymentRepository = ref.read(paymentRepositoryProvider);
    final reference =
        checkout.matchingPendingPayment?.reference.isNotEmpty == true
        ? checkout.matchingPendingPayment!.reference
        : paymentRepository.generateReference();

    final metadata = <String, Object?>{
      'uid': checkout.profile.uid,
      'kind': checkout.kind.apiValue,
      'weeks': pricing.weeks,
      'path': checkout.profile.pathTitle,
      'pathId': checkout.profile.pathId,
      'courseId': checkout.profile.courseId,
      'cohortId': checkout.profile.cohortId,
      'cohortLabel': checkout.profile.cohortLabel,
      'cohortKey': checkout.profile.cohortKey,
      'expectedAmountKobo': pricing.totalPriceKobo,
      'baseAmountKobo': pricing.basePriceKobo,
      'processingFeeKobo': pricing.processingFeeKobo,
      'baseAmount': pricing.basePrice,
      'weeklyRate': pricing.weeklyRate,
      'app': 'codewithgideon-mobile',
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    setState(() => _processing = true);
    _paymentCompleted = false;
    try {
      final initialized = await paymentRepository.initializePayment(
        email: session.email,
        amountKobo: pricing.totalPriceKobo,
        reference: reference,
        metadata: metadata,
      );

      if (!mounted) return;

      await FlutterPaystackPlus.openPaystackPopup(
        customerEmail: session.email,
        amount: '${pricing.totalPriceKobo}',
        reference: initialized.reference,
        authorizationUrl: initialized.authorizationUrl,
        callBackUrl: PaymentConfig.callbackUrl,
        context: context,
        metadata: metadata,
        onClosed: () {
          if (!mounted) return;
          if (_paymentCompleted) return;
          setState(() => _processing = false);
          _handleExit();
        },
        onSuccess: () async {
          try {
            _paymentCompleted = true;
            await paymentRepository.verifyPayment(
              checkout: checkout,
              pricing: pricing,
              reference: initialized.reference,
            );
            if (!mounted) return;
            ref.invalidate(dashboardSnapshotProvider);
            await ref.read(authControllerProvider.notifier).refreshSession();
            if (!mounted) return;
            showAppSnackBar(
              context,
              checkout.kind == PaymentFlowKind.topUp
                  ? 'Top up confirmed. Your extra weeks are now available.'
                  : 'Payment confirmed. Welcome to your dashboard.',
            );
            context.go('/dashboard');
          } catch (error) {
            if (!mounted) return;
            showAppSnackBar(context, '$error'.replaceFirst('Bad state: ', ''));
          } finally {
            if (mounted) {
              setState(() => _processing = false);
            }
          }
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _processing = false);
      showAppSnackBar(context, _prettyPaymentError(error));
    }
  }
}

class _PaymentHero extends StatelessWidget {
  const _PaymentHero({required this.checkout, required this.pricing});

  final PaymentCheckoutModel checkout;
  final PaymentPriceBreakdown pricing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: checkout.kind == PaymentFlowKind.topUp
            ? const LinearGradient(
                colors: [Color(0xFF0F7C83), Color(0xFF17A0A7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppGradients.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppShadows.premium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            checkout.profile.pathTitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(8),
          Text(
            _formatNaira(pricing.totalPrice),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(8),
          Text(
            '${pricing.weeks} week(s) at ${_formatNaira(pricing.weeklyRate)} per week',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const Gap(12),
          Text(
            checkout.kind == PaymentFlowKind.topUp
                ? 'Add more access and keep your class schedule moving.'
                : 'Your registration is saved. Payment completes your enrollment.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({required this.pricing});

  final PaymentPriceBreakdown pricing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment summary',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Gap(16),
          _SummaryRow(label: 'Weeks', value: '${pricing.weeks}'),
          _SummaryRow(
            label: 'Base price',
            value: _formatNaira(pricing.basePrice),
          ),
          _SummaryRow(
            label: 'Processing fee',
            value: _formatNaira(pricing.processingFee),
          ),
          const Divider(height: 28),
          _SummaryRow(
            label: 'Total',
            value: _formatNaira(pricing.totalPrice),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _WeekStepper extends StatelessWidget {
  const _WeekStepper({
    required this.value,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WeekStepButton(
          icon: Icons.remove_rounded,
          enabled: canDecrease,
          onTap: onDecrease,
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.deepBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '$value week${value == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.deepBlueDark,
            ),
          ),
        ),
        const Gap(12),
        _WeekStepButton(
          icon: Icons.add_rounded,
          enabled: canIncrease,
          onTap: onIncrease,
        ),
      ],
    );
  }
}

class _WeekStepButton extends StatelessWidget {
  const _WeekStepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.deepBlue.withValues(alpha: 0.08)
              : AppColors.muted,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: enabled ? AppColors.deepBlueDark : AppColors.mutedForeground,
        ),
      ),
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {
  const _PendingPaymentCard({required this.checkout});

  final PaymentCheckoutModel checkout;

  @override
  Widget build(BuildContext context) {
    final pending = checkout.matchingPendingPayment!;
    return AppCard(
      color: AppColors.orange.withValues(alpha: 0.08),
      border: Border.all(color: AppColors.orange.withValues(alpha: 0.14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.orange),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkout.kind == PaymentFlowKind.topUp
                      ? 'Top-up checkout in progress'
                      : 'Checkout in progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Gap(6),
                Text(
                  'Reference ${pending.reference} for ${pending.weeks} week(s). Continue below when you are ready.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentProcessingOverlay extends StatefulWidget {
  const _PaymentProcessingOverlay();

  @override
  State<_PaymentProcessingOverlay> createState() =>
      _PaymentProcessingOverlayState();
}

class _PaymentProcessingOverlayState extends State<_PaymentProcessingOverlay> {
  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() {
        _stage = (_stage + 1) % _paymentStages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = _paymentStages[_stage];
    return IgnorePointer(
      child: Container(
        color: AppColors.deepBlueDark.withValues(alpha: 0.36),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppCard(
              radius: 30,
              shadow: AppShadows.premium,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PremiumLoader(size: 66, dotSize: 10),
                    const Gap(20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Text(
                        stage.title,
                        key: ValueKey(stage.title),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Gap(8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: Text(
                        stage.message,
                        key: ValueKey(stage.message),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(
                color: emphasize
                    ? AppColors.deepBlueDark
                    : AppColors.mutedForeground,
              ),
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _PaymentErrorState extends StatelessWidget {
  const _PaymentErrorState({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumPageHeader(
            leading: PremiumIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
            ),
            title: 'Payment unavailable',
            subtitle: message,
          ),
          const Spacer(),
          AppButton(label: 'Try Again', onPressed: onRetry),
        ],
      ),
    );
  }
}

String _formatNaira(int amount) {
  final format = NumberFormat.currency(
    locale: 'en_NG',
    symbol: 'N',
    decimalDigits: 0,
  );
  return format.format(amount);
}

String _prettyPaymentError(Object error) {
  final raw = '$error'.replaceFirst('Bad state: ', '').trim();
  if (raw.contains('XMLHttpRequest error') ||
      raw.contains('ClientException') ||
      raw.contains('SocketException')) {
    return 'We could not reach the payment service. Check your connection and try again.';
  }
  return raw;
}

class _PaymentStageCopy {
  const _PaymentStageCopy(this.title, this.message);

  final String title;
  final String message;
}

const _paymentStages = [
  _PaymentStageCopy(
    'Securing checkout',
    'We are preparing your protected payment session.',
  ),
  _PaymentStageCopy(
    'Connecting to Paystack',
    'Your payment window is being opened safely.',
  ),
  _PaymentStageCopy(
    'Keeping your access in sync',
    'We will update your dashboard and admin records right after payment confirmation.',
  ),
];

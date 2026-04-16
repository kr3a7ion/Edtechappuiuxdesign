import '../../catalog/models/course_model.dart';
import '../../student/models/pending_payment_model.dart';
import '../../student/models/student_profile_model.dart';

enum PaymentFlowKind { initial, topUp }

extension PaymentFlowKindX on PaymentFlowKind {
  String get apiValue => this == PaymentFlowKind.topUp ? 'topup' : 'initial';

  String get title =>
      this == PaymentFlowKind.topUp ? 'Top Up Access' : 'Complete Registration';

  String get actionLabel => this == PaymentFlowKind.topUp
      ? 'Continue To Paystack'
      : 'Pay And Finish Registration';
}

class PaymentCheckoutModel {
  const PaymentCheckoutModel({
    required this.kind,
    required this.profile,
    required this.course,
  });

  final PaymentFlowKind kind;
  final StudentProfileModel profile;
  final CourseModel course;

  int get totalProgramWeeks => course.durationWeeks;
  int get committedWeeks => profile.weeksToCommit;
  int get remainingWeeks {
    final remaining = course.durationWeeks - profile.weeksToCommit;
    return remaining < 0 ? 0 : remaining;
  }

  int get maxAllowedWeeks =>
      kind == PaymentFlowKind.topUp ? remainingWeeks : totalProgramWeeks;

  int get suggestedWeeks {
    final pending = matchingPendingPayment;
    if (pending != null) {
      return pending.weeks;
    }
    if (kind == PaymentFlowKind.topUp) {
      return maxAllowedWeeks == 0 ? 0 : 1;
    }
    if (profile.weeksToCommit > 0) {
      return profile.weeksToCommit.clamp(1, totalProgramWeeks);
    }
    return totalProgramWeeks >= 4
        ? 4
        : totalProgramWeeks.clamp(1, totalProgramWeeks);
  }

  PendingPaymentModel? get matchingPendingPayment {
    final pending = profile.pendingPayment;
    if (pending == null || !pending.isPending) return null;
    final isTopUpPending = pending.kind == PendingPaymentKind.topUp;
    if (kind == PaymentFlowKind.topUp && isTopUpPending) return pending;
    if (kind == PaymentFlowKind.initial && !isTopUpPending) return pending;
    return null;
  }

  bool get hasMatchingPendingPayment => matchingPendingPayment != null;
}

class PaymentPriceBreakdown {
  const PaymentPriceBreakdown({
    required this.weeks,
    required this.weeklyRate,
    required this.basePrice,
    required this.processingFee,
    required this.totalPrice,
  });

  final int weeks;
  final int weeklyRate;
  final int basePrice;
  final int processingFee;
  final int totalPrice;

  int get basePriceKobo => basePrice * 100;
  int get processingFeeKobo => processingFee * 100;
  int get totalPriceKobo => totalPrice * 100;
}

class PaymentInitializationResult {
  const PaymentInitializationResult({
    required this.authorizationUrl,
    required this.reference,
  });

  final String authorizationUrl;
  final String reference;
}

class PaymentVerificationResult {
  const PaymentVerificationResult({
    required this.safeWeeks,
    required this.maxWeeks,
    required this.alreadyProcessed,
  });

  final int safeWeeks;
  final int maxWeeks;
  final bool alreadyProcessed;
}

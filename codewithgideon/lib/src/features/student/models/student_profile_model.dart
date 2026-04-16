import 'pending_payment_model.dart';

enum StudentEnrollmentState { complete, pending }

class StudentProfileModel {
  const StudentProfileModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.ageRange,
    required this.gender,
    required this.pathTitle,
    required this.pathId,
    required this.courseId,
    required this.weeksToCommit,
    required this.status,
    required this.joinedAt,
    this.cohortId,
    this.cohortLabel,
    this.cohortKey,
    this.pendingPayment,
  });

  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String ageRange;
  final String gender;
  final String pathTitle;
  final String pathId;
  final String courseId;
  final int weeksToCommit;
  final StudentEnrollmentState status;
  final DateTime joinedAt;
  final String? cohortId;
  final String? cohortLabel;
  final String? cohortKey;
  final PendingPaymentModel? pendingPayment;

  bool get hasPendingPayment => pendingPayment?.isPending ?? false;
  bool get hasPendingInitialPayment =>
      pendingPayment?.isPending == true &&
      pendingPayment?.kind == PendingPaymentKind.initial;
  bool get hasPendingTopUp =>
      pendingPayment?.isPending == true &&
      pendingPayment?.kind == PendingPaymentKind.topUp;
  bool get isPending => status == StudentEnrollmentState.pending;
}

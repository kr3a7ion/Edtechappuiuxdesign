import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/payment_config.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../student/data/student_repository.dart';
import '../models/payment_checkout_model.dart';

class PaymentRepository {
  PaymentRepository({
    required FirebaseFirestore firebaseFirestore,
    required StudentRepository studentRepository,
    required CatalogRepository catalogRepository,
  }) : _firebaseFirestore = firebaseFirestore,
       _studentRepository = studentRepository,
       _catalogRepository = catalogRepository;

  final FirebaseFirestore _firebaseFirestore;
  final StudentRepository _studentRepository;
  final CatalogRepository _catalogRepository;

  Future<PaymentCheckoutModel> loadCheckout({
    required String uid,
    required PaymentFlowKind kind,
  }) async {
    final profile = await _studentRepository.getStudentProfileByUid(uid);
    if (profile == null) {
      throw StateError('Student profile could not be found for payment.');
    }
    final course = await _catalogRepository.getCourseForPath(
      profile.pathId,
      courseId: profile.courseId,
    );
    return PaymentCheckoutModel(kind: kind, profile: profile, course: course);
  }

  Future<void> setPendingPayment({
    required String uid,
    required PaymentFlowKind kind,
    required int weeks,
    required int amount,
    required int baseAmount,
    required int weeklyRate,
    required String reference,
  }) {
    return _firebaseFirestore.collection('users').doc(uid).set({
      'pendingPayment': {
        'kind': kind.apiValue,
        'status': 'Pending',
        'weeks': weeks,
        'amount': amount,
        'baseAmount': baseAmount,
        'weeklyRate': weeklyRate,
        'reference': reference,
        'createdAt': FieldValue.serverTimestamp(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<PaymentInitializationResult> initializePayment({
    required String email,
    required int amountKobo,
    required String reference,
    required Map<String, Object?> metadata,
  }) async {
    final response = await http.post(
      Uri.parse(PaymentConfig.initializeUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'amount': amountKobo,
        'reference': reference,
        'currency': 'NGN',
        'callbackUrl': PaymentConfig.callbackUrl,
        'metadata': metadata,
      }),
    );

    final json = _decodeJson(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        describeHttpError(json, 'Could not initialize payment.'),
      );
    }

    final data = json['data'];
    if (data is! Map) {
      throw StateError(
        'Payment gateway returned an invalid initialization response.',
      );
    }

    final authorizationUrl = '${data['authorization_url'] ?? ''}'.trim();
    final resolvedReference = '${data['reference'] ?? reference}'.trim();
    if (authorizationUrl.isEmpty) {
      throw StateError('Payment checkout URL was missing from the response.');
    }

    return PaymentInitializationResult(
      authorizationUrl: authorizationUrl,
      reference: resolvedReference.isEmpty ? reference : resolvedReference,
    );
  }

  Future<PaymentVerificationResult> verifyPayment({
    required PaymentCheckoutModel checkout,
    required PaymentPriceBreakdown pricing,
    required String reference,
  }) async {
    final response = await http.post(
      Uri.parse(PaymentConfig.verifyUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'reference': reference,
        'uid': checkout.profile.uid,
        'expectedAmount': pricing.totalPriceKobo,
        'weeks': pricing.weeks,
        'kind': checkout.kind.apiValue,
        'cohortId': checkout.profile.cohortId,
        'cohortLabel': checkout.profile.cohortLabel,
        'cohortKey': checkout.profile.cohortKey,
        'path': checkout.profile.pathTitle,
        'pathId': checkout.profile.pathId,
        'courseId': checkout.profile.courseId,
        'courseMaxWeeks': checkout.course.durationWeeks,
        'weeklyRate': checkout.course.pricePerWeek,
      }),
    );

    final json = _decodeJson(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        json['ok'] != true) {
      throw StateError(
        describeHttpError(json, 'We could not confirm your payment yet.'),
      );
    }

    return PaymentVerificationResult(
      safeWeeks: (json['safeWeeks'] as num?)?.toInt() ?? pricing.weeks,
      maxWeeks:
          (json['maxWeeks'] as num?)?.toInt() ?? checkout.course.durationWeeks,
      alreadyProcessed: json['alreadyProcessed'] == true,
    );
  }

  PaymentPriceBreakdown quote({
    required PaymentCheckoutModel checkout,
    required int weeks,
  }) {
    final safeWeeks = checkout.maxAllowedWeeks <= 0
        ? 0
        : weeks.clamp(1, checkout.maxAllowedWeeks);
    final basePrice = safeWeeks * checkout.course.pricePerWeek;
    final processingFee = ((basePrice * 0.015) + 100).ceil();
    return PaymentPriceBreakdown(
      weeks: safeWeeks,
      weeklyRate: checkout.course.pricePerWeek,
      basePrice: basePrice,
      processingFee: processingFee,
      totalPrice: basePrice + processingFee,
    );
  }

  String generateReference() {
    final random = Random.secure().nextInt(1000).toString().padLeft(3, '0');
    return 'CWG_${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}_$random';
  }

  Map<String, dynamic> _decodeJson(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Invalid JSON response');
  }

  static String describeHttpError(Map<String, dynamic> json, String fallback) {
    final direct = '${json['error'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;

    final details = json['details'];
    if (details is Map<String, dynamic>) {
      final detailMessage = '${details['message'] ?? details['error'] ?? ''}'
          .trim();
      if (detailMessage.isNotEmpty) return detailMessage;
    }

    return fallback;
  }
}

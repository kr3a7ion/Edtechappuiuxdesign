import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/api_client.dart';
import '../models/pending_payment_model.dart';
import '../models/student_profile_model.dart';

class StudentRepository {
  StudentRepository({
    required ApiClient apiClient,
    required FirebaseFirestore firebaseFirestore,
  }) : _apiClient = apiClient,
       _firebaseFirestore = firebaseFirestore;

  final ApiClient _apiClient;
  final FirebaseFirestore _firebaseFirestore;

  Future<StudentProfileModel> getStudentProfile(String email) {
    return _apiClient.simulateRequest(() async {
      final snapshot = await _firebaseFirestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return _mapStudent(snapshot.docs.first);
      }
      throw StateError(
        'Student profile for "$email" was not found in Firestore collection "users".',
      );
    });
  }

  Future<StudentProfileModel?> getStudentProfileByUid(String uid) {
    return _apiClient.simulateRequest(() async {
      final doc = await _firebaseFirestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return _mapStudent(doc);
    });
  }

  Future<void> completeRegistrationProfile({
    required String uid,
    required String email,
    required String fullName,
    required String phone,
    required String ageRange,
    required String gender,
    required int weeksToCommit,
    required String pathTitle,
  }) {
    return _apiClient.simulateRequest(() async {
      final paths = await _firebaseFirestore.collection('paths').get();
      String? pathId;
      for (final doc in paths.docs) {
        final title = (doc.data()['title'] as String?) ?? '';
        if (title.trim().toLowerCase() == pathTitle.trim().toLowerCase()) {
          pathId = doc.id;
          break;
        }
      }

      String? courseId;
      int pricePerWeek = 10000;
      if (pathId != null) {
        final courses = await _firebaseFirestore
            .collection('courses')
            .where('pathId', isEqualTo: pathId)
            .limit(1)
            .get();
        if (courses.docs.isNotEmpty) {
          courseId = courses.docs.first.id;
          pricePerWeek =
              (courses.docs.first.data()['pricePerWeek'] as num?)?.toInt() ??
              10000;
        }
      }

      String? cohortId;
      String? cohortLabel;
      String? cohortKey;
      if (pathId != null) {
        final activeCohort = await _firebaseFirestore
            .collection('activeCohorts')
            .doc(pathId)
            .get();
        final data = activeCohort.data();
        cohortId = data?['cohortId'] as String?;
        cohortLabel = data?['label'] as String?;
        cohortKey = data?['cohortKey'] as String?;
      }

      await _firebaseFirestore.collection('users').doc(uid).set({
        'uid': uid,
        'role': 'student',
        'status': 'Pending',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'ageRange': ageRange,
        'gender': gender,
        'weeksToCommit': weeksToCommit,
        'totalPrice': weeksToCommit * pricePerWeek,
        'path': pathTitle,
        if (pathId != null) 'pathId': pathId,
        if (courseId != null) 'courseId': courseId,
        if (cohortId != null) 'cohortId': cohortId,
        if (cohortLabel != null) 'cohortLabel': cohortLabel,
        if (cohortKey != null) 'cohortKey': cohortKey,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: false));
    });
  }

  Future<void> updateStudentProfile({
    required String uid,
    required String fullName,
    required String phone,
  }) {
    return _apiClient.simulateRequest(() async {
      await _firebaseFirestore.collection('users').doc(uid).set({
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    });
  }

  StudentProfileModel _mapStudent(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final pendingPaymentData = data['pendingPayment'];
    PendingPaymentModel? pendingPayment;
    if (pendingPaymentData is Map) {
      pendingPayment = PendingPaymentModel(
        kind: '${pendingPaymentData['kind']}' == 'topup'
            ? PendingPaymentKind.topUp
            : PendingPaymentKind.initial,
        weeks: (pendingPaymentData['weeks'] as num?)?.toInt() ?? 1,
        amount: (pendingPaymentData['amount'] as num?)?.toInt() ?? 0,
        reference: '${pendingPaymentData['reference'] ?? ''}',
        isPending: '${pendingPaymentData['status'] ?? ''}' == 'Pending',
      );
    }

    final timestamp = data['timestamp'];
    final joinedAt = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.fromMillisecondsSinceEpoch(
            (timestamp as num?)?.toInt() ??
                DateTime.now().millisecondsSinceEpoch,
          );

    return StudentProfileModel(
      uid: (data['uid'] as String?) ?? doc.id,
      fullName: (data['fullName'] as String?) ?? 'Student',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      ageRange: (data['ageRange'] as String?) ?? '18-24',
      gender: (data['gender'] as String?) ?? 'Prefer not to say',
      pathTitle: (data['path'] as String?) ?? 'Unknown Path',
      pathId: (data['pathId'] as String?) ?? '',
      courseId: (data['courseId'] as String?) ?? '',
      weeksToCommit: (data['weeksToCommit'] as num?)?.toInt() ?? 0,
      status: '${data['status'] ?? ''}' == 'Pending'
          ? StudentEnrollmentState.pending
          : StudentEnrollmentState.complete,
      joinedAt: joinedAt,
      cohortId: data['cohortId'] as String?,
      cohortLabel: data['cohortLabel'] as String?,
      cohortKey: data['cohortKey'] as String?,
      pendingPayment: pendingPayment,
    );
  }
}

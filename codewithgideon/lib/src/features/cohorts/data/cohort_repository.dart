import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/api_client.dart';
import '../models/active_cohort_model.dart';
import '../models/cohort_message_model.dart';
import '../models/cohort_model.dart';
import '../models/cohort_session_model.dart';

class CohortRepository {
  CohortRepository({
    required ApiClient apiClient,
    required FirebaseFirestore firebaseFirestore,
  }) : _apiClient = apiClient,
       _firebaseFirestore = firebaseFirestore;

  final ApiClient _apiClient;
  final FirebaseFirestore _firebaseFirestore;

  Future<ActiveCohortModel> getActiveCohortForPath(String pathId) {
    return _apiClient.simulateRequest(() async {
      final doc = await _firebaseFirestore
          .collection('activeCohorts')
          .doc(pathId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return ActiveCohortModel(
          pathId: (data['pathId'] as String?) ?? pathId,
          pathTitle: (data['path'] as String?) ?? 'Unknown Path',
          cohortId: (data['cohortId'] as String?) ?? 'CWG-DEFAULT',
          cohortKey: (data['cohortKey'] as String?) ?? 'CWG-DEFAULT',
          label: (data['label'] as String?) ?? 'Current Cohort',
          seasonKey: (data['seasonKey'] as String?) ?? '',
        );
      }
      throw StateError(
        'No active cohort found in Firestore for path "$pathId".',
      );
    });
  }

  Future<List<CohortModel>> getCohorts() {
    return _apiClient.simulateRequest(() async {
      final snapshot = await _firebaseFirestore.collection('cohorts').get();
      if (snapshot.docs.isEmpty) {
        return <CohortModel>[];
      }
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CohortModel(
          id: (data['cohortId'] as String?) ?? doc.id,
          label: (data['label'] as String?) ?? 'Current Cohort',
          cohortKey: (data['cohortKey'] as String?) ?? doc.id,
          pathId: (data['pathId'] as String?) ?? '',
          pathTitle: (data['path'] as String?) ?? 'Unknown Path',
        );
      }).toList();
    });
  }

  Future<List<CohortMessageModel>> getMessagesForCohort(String cohortKey) {
    return _apiClient.simulateRequest(() async {
      final snapshot = await _firebaseFirestore
          .collection('cohorts')
          .doc(cohortKey)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .get();
      if (snapshot.docs.isEmpty) return <CohortMessageModel>[];

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAtRaw = data['createdAt'];
        final createdAt = createdAtRaw is Timestamp
            ? createdAtRaw.toDate()
            : DateTime.tryParse('${data['createdAt']}') ?? DateTime.now();

        return CohortMessageModel(
          id: doc.id,
          cohortId: cohortKey,
          cohortLabel: (data['cohortLabel'] as String?) ?? '',
          title: (data['title'] as String?) ?? 'Announcement',
          body: (data['body'] as String?) ?? '',
          ctaLabel: (data['ctaLabel'] as String?) ?? '',
          ctaUrl: (data['ctaUrl'] as String?) ?? '',
          sentBy: (data['sentBy'] as String?) ?? 'Admin',
          createdAt: createdAt,
        );
      }).toList();
    });
  }

  Stream<List<CohortMessageModel>> watchMessagesForCohort(String cohortKey) {
    return _firebaseFirestore
        .collection('cohorts')
        .doc(cohortKey)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return <CohortMessageModel>[];

          return snapshot.docs.map((doc) {
            final data = doc.data();
            final createdAtRaw = data['createdAt'];
            final createdAt = createdAtRaw is Timestamp
                ? createdAtRaw.toDate()
                : DateTime.tryParse('${data['createdAt']}') ?? DateTime.now();

            return CohortMessageModel(
              id: doc.id,
              cohortId: cohortKey,
              cohortLabel: (data['cohortLabel'] as String?) ?? '',
              title: (data['title'] as String?) ?? 'Announcement',
              body: (data['body'] as String?) ?? '',
              ctaLabel: (data['ctaLabel'] as String?) ?? '',
              ctaUrl: (data['ctaUrl'] as String?) ?? '',
              sentBy: (data['sentBy'] as String?) ?? 'Admin',
              createdAt: createdAt,
            );
          }).toList();
        });
  }

  Future<List<CohortSessionModel>> getSessionsForCohort(String cohortKey) {
    return _apiClient.simulateRequest(() async {
      final snapshot = await _firebaseFirestore
          .collection('cohorts')
          .doc(cohortKey)
          .collection('sessions')
          .get();
      if (snapshot.docs.isEmpty) return <CohortSessionModel>[];

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final startsAtRaw = data['startsAt'];
        final endsAtRaw = data['endsAt'];
        final startsAt = startsAtRaw is Timestamp
            ? startsAtRaw.toDate()
            : DateTime.tryParse('${data['startsAt']}') ?? DateTime.now();
        final endsAt = endsAtRaw is Timestamp
            ? endsAtRaw.toDate()
            : DateTime.tryParse('${data['endsAt']}') ??
                  startsAt.add(
                    Duration(
                      minutes: (data['durationMins'] as num?)?.toInt() ?? 60,
                    ),
                  );

        return CohortSessionModel(
          id: doc.id,
          cohortKey: cohortKey,
          week: (data['week'] as num?)?.toInt() ?? 1,
          pathId: (data['pathId'] as String?) ?? '',
          pathTitle: (data['path'] as String?) ?? 'Unknown Path',
          title: (data['title'] as String?) ?? 'Session',
          startsAt: startsAt,
          endsAt: endsAt,
          joinUrl: (data['joinUrl'] as String?) ?? '',
          // Support a few likely field names so Firebase can evolve without
          // breaking the student dashboard contract.
          recordingUrl:
              (data['recordingUrl'] as String?) ??
              (data['youtubeUrl'] as String?) ??
              (data['recordedUrl'] as String?) ??
              (data['recordingLink'] as String?) ??
              '',
          notes: (data['notes'] as String?) ?? '',
          isPublished: (data['isPublished'] as bool?) ?? false,
        );
      }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    });
  }
}

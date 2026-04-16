import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/network/api_client.dart';
import '../models/course_model.dart';
import '../models/path_model.dart';

List<CourseSyllabusWeek> _parseSyllabus(dynamic rawSyllabus) {
  final list = rawSyllabus is List ? rawSyllabus : const [];
  return list
      .whereType<Map>()
      .map((item) {
        final data = Map<String, dynamic>.from(
          item.map((key, value) => MapEntry('$key', value)),
        );
        final weekValue = data['week'];
        final title = '${data['title'] ?? ''}'.trim();
        final topicsRaw = item['topics'];
        final topics = topicsRaw is List
            ? topicsRaw
                  .map((topic) => '$topic'.trim())
                  .where((t) => t.isNotEmpty)
                  .toList()
            : <String>[];

        return CourseSyllabusWeek(
          week: weekValue is num
              ? weekValue.toInt()
              : int.tryParse('$weekValue') ?? 1,
          title: title.isNotEmpty ? title : 'Module',
          topics: topics,
        );
      })
      .where((item) => item.title.isNotEmpty || item.topics.isNotEmpty)
      .toList()
    ..sort((a, b) => a.week.compareTo(b.week));
}

class CatalogRepository {
  CatalogRepository({
    required ApiClient apiClient,
    required FirebaseFirestore firebaseFirestore,
  }) : _apiClient = apiClient,
       _firebaseFirestore = firebaseFirestore;

  final ApiClient _apiClient;
  final FirebaseFirestore _firebaseFirestore;

  Future<List<PathModel>> getPaths() {
    return _apiClient.simulateRequest(() async {
      final snapshot = await _firebaseFirestore.collection('paths').get();
      if (snapshot.docs.isEmpty) {
        return <PathModel>[];
      }
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PathModel(
          id: doc.id,
          title: (data['title'] as String?) ?? 'Untitled Path',
          description: (data['description'] as String?) ?? '',
        );
      }).toList();
    });
  }

  Future<PathModel> getPath(String pathId) {
    return _apiClient.simulateRequest(() async {
      final doc = await _firebaseFirestore
          .collection('paths')
          .doc(pathId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return PathModel(
          id: doc.id,
          title: (data['title'] as String?) ?? 'Untitled Path',
          description: (data['description'] as String?) ?? '',
        );
      }
      throw StateError(
        'Path "$pathId" was not found in Firestore collection "paths".',
      );
    });
  }

  Future<List<CourseModel>> getCourses() {
    return _apiClient.simulateRequest(() async {
      final snapshot = await _firebaseFirestore.collection('courses').get();
      if (snapshot.docs.isEmpty) {
        return <CourseModel>[];
      }
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CourseModel(
          id: doc.id,
          pathId: (data['pathId'] as String?) ?? '',
          title: (data['title'] as String?) ?? 'Course',
          durationWeeks: (data['weeks'] as num?)?.toInt() ?? 4,
          pricePerWeek: (data['pricePerWeek'] as num?)?.toInt() ?? 10000,
          priceLabel: (data['priceLabel'] as String?) ?? 'N10,000 / week',
          isActive: (data['isActive'] as bool?) ?? true,
          syllabus: _parseSyllabus(data['syllabus']),
        );
      }).toList();
    });
  }

  Future<CourseModel> getCourseForPath(String pathId, {String? courseId}) {
    return _apiClient.simulateRequest(() async {
      final courses = await getCourses();
      if (courseId != null) {
        final exactMatch = courses.where((course) => course.id == courseId);
        if (exactMatch.isNotEmpty) {
          return exactMatch.first;
        }
      }
      final matches = courses.where(
        (course) => course.pathId == pathId && course.isActive,
      );
      if (matches.isNotEmpty) return matches.first;
      throw StateError(
        'No active course found in Firestore for path "$pathId".',
      );
    });
  }
}

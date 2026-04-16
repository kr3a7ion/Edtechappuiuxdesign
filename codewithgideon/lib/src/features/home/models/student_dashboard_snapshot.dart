import '../../../core/data/demo_data.dart';
import '../../catalog/models/course_model.dart';
import '../../catalog/models/path_model.dart';
import '../../cohorts/models/active_cohort_model.dart';
import '../../cohorts/models/cohort_session_model.dart';
import '../../student/models/student_profile_model.dart';

class StudentDashboardSnapshot {
  const StudentDashboardSnapshot({
    required this.profile,
    required this.path,
    required this.course,
    required this.activeCohort,
    required this.unlockedSessions,
    required this.recordedLessons,
  });

  final StudentProfileModel profile;
  final PathModel path;
  final CourseModel course;
  final ActiveCohortModel activeCohort;
  final List<CohortSessionModel> unlockedSessions;
  final List<RecordedLesson> recordedLessons;

  bool get hasAnyPending =>
      profile.isPending || profile.hasPendingInitialPayment;
  bool get hasPendingTopUp => profile.hasPendingTopUp;
  int get paidWeeks => hasAnyPending ? 0 : profile.weeksToCommit;
  int get totalProgramWeeks => course.durationWeeks;
  int get remainingWeeks =>
      (totalProgramWeeks - paidWeeks).clamp(0, totalProgramWeeks);
  double get progressPercent =>
      totalProgramWeeks == 0 ? 0 : (paidWeeks / totalProgramWeeks);
  bool get canTopUp =>
      !hasAnyPending &&
      !hasPendingTopUp &&
      profile.status == StudentEnrollmentState.complete &&
      remainingWeeks > 0;
  int get previewCount =>
      unlockedSessions.length > 3 ? 3 : unlockedSessions.length;
  List<CohortSessionModel> get previewSessions =>
      unlockedSessions.take(previewCount).toList();
  List<CohortSessionModel> get recordedSessions =>
      unlockedSessions.where((session) => session.hasRecordingUrl).toList()
        ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  CohortSessionModel? get liveSession {
    if (hasAnyPending) return null;
    final now = DateTime.now();
    for (final session in unlockedSessions) {
      if (!session.startsAt.isAfter(now) && !session.endsAt.isBefore(now)) {
        return session;
      }
    }
    return null;
  }

  CohortSessionModel? get nextSession {
    if (hasAnyPending) return null;
    final now = DateTime.now();
    for (final session in unlockedSessions) {
      if (session.startsAt.isAfter(now)) {
        return session;
      }
    }
    return null;
  }

  CohortSessionModel? get latestUnlockedSession {
    if (hasAnyPending || unlockedSessions.isEmpty) return null;
    final ordered = [...unlockedSessions]
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return ordered.firstOrNull;
  }

  CohortSessionModel? get latestRecordedSession {
    if (hasAnyPending || recordedSessions.isEmpty) return null;
    return recordedSessions.firstOrNull;
  }

  CohortSessionModel? get heroSession {
    return liveSession ?? nextSession ?? latestUnlockedSession;
  }

  String get heroLabel {
    if (hasAnyPending) return 'Sessions Locked';
    if (liveSession != null) return 'Live Now';
    if (nextSession != null) return 'Next Live Session';
    if (latestRecordedSession != null) return 'Recording Ready';
    if (unlockedSessions.isNotEmpty) return 'Latest Unlocked Class';
    return 'Class Status';
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

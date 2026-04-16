import 'package:codewithgideon/src/core/data/demo_data.dart';
import 'package:codewithgideon/src/features/catalog/models/course_model.dart';
import 'package:codewithgideon/src/features/catalog/models/path_model.dart';
import 'package:codewithgideon/src/features/cohorts/models/active_cohort_model.dart';
import 'package:codewithgideon/src/features/home/dashboard_screen.dart';
import 'package:codewithgideon/src/features/home/models/student_dashboard_snapshot.dart';
import 'package:codewithgideon/src/features/home/state/dashboard_provider.dart';
import 'package:codewithgideon/src/features/live/live_session_screen.dart';
import 'package:codewithgideon/src/features/recorded/recorded_screens.dart';
import 'package:codewithgideon/src/features/student/models/student_profile_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> configureSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  testWidgets('dashboard renders on compact width without exceptions', (
    tester,
  ) async {
    await configureSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardSnapshotProvider.overrideWithValue(
            AsyncData(
              StudentDashboardSnapshot(
                profile: StudentProfileModel(
                  uid: 'student_1',
                  fullName: 'Gideon Student',
                  email: 'gideon@example.com',
                  phone: '+234 803 000 1122',
                  ageRange: '18-24',
                  gender: 'Prefer not to say',
                  pathTitle: 'Flutter & Mobile App Development',
                  pathId: 'flutter-mobile',
                  courseId: 'course_flutter_mobile',
                  weeksToCommit: 4,
                  status: StudentEnrollmentState.complete,
                  joinedAt: DateTime(2026, 3, 1),
                  cohortId: 'FLUTTER',
                  cohortLabel: 'March 2026 Cohort',
                  cohortKey: 'FLUTTER-2026-03',
                ),
                path: const PathModel(
                  id: 'flutter-mobile',
                  title: 'Flutter & Mobile App Development',
                  description: 'Production-ready Flutter cohort.',
                ),
                course: const CourseModel(
                  id: 'course_flutter_mobile',
                  pathId: 'flutter-mobile',
                  title: 'Flutter & Mobile App Development',
                  durationWeeks: 12,
                  pricePerWeek: 10000,
                  priceLabel: 'N10,000 / week',
                  isActive: true,
                  syllabus: [],
                ),
                activeCohort: const ActiveCohortModel(
                  pathId: 'flutter-mobile',
                  pathTitle: 'Flutter & Mobile App Development',
                  cohortId: 'FLUTTER',
                  cohortKey: 'FLUTTER-2026-03',
                  label: 'March 2026 Cohort',
                  seasonKey: '2026-03',
                ),
                unlockedSessions: const [],
                recordedLessons: DemoData.recordedLessons,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resources library renders folders and list without overflow', (
    tester,
  ) async {
    await configureSurface(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResourcesLibraryScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resources'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live session renders owned text fields without rebuild errors', (
    tester,
  ) async {
    await configureSurface(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LiveSessionScreen(sessionId: '1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live Session in Progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

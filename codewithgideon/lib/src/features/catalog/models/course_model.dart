class CourseSyllabusWeek {
  const CourseSyllabusWeek({
    required this.week,
    required this.title,
    required this.topics,
  });

  final int week;
  final String title;
  final List<String> topics;
}

class CourseModel {
  const CourseModel({
    required this.id,
    required this.pathId,
    required this.title,
    required this.durationWeeks,
    required this.pricePerWeek,
    required this.priceLabel,
    required this.isActive,
    required this.syllabus,
  });

  final String id;
  final String pathId;
  final String title;
  final int durationWeeks;
  final int pricePerWeek;
  final String priceLabel;
  final bool isActive;
  final List<CourseSyllabusWeek> syllabus;
}

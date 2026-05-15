class TeacherDashboardData {
  const TeacherDashboardData({
    required this.totalStudents,
    required this.totalQuestions,
    required this.averageScore,
    required this.classroomName,
    required this.classroomCode,
    required this.classroomId,
  });

  final int totalStudents;
  final int totalQuestions;
  final double averageScore; // 0.0 a 100.0
  final String classroomName;
  final String classroomCode;
  final String classroomId;

  String get averageScoreFormatted =>
      averageScore > 0 ? '${averageScore.round()}%' : '—';
}
class ResumeScoreItem {
  const ResumeScoreItem({
    required this.label,
    required this.score,
    required this.maxScore,
    required this.feedback,
  });

  final String label;
  final int score;
  final int maxScore;
  final String feedback;
}

class ResumeScoreResult {
  const ResumeScoreResult({
    required this.totalScore,
    required this.grade,
    required this.items,
    required this.tips,
    this.extractedPreview,
  });

  final int totalScore;
  final String grade;
  final List<ResumeScoreItem> items;
  final List<String> tips;
  final String? extractedPreview;

  int get maxScore => items.fold(0, (sum, item) => sum + item.maxScore);
}

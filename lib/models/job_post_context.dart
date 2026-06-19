class JobPostContext {
  const JobPostContext({
    this.email,
    this.jobTitle,
    this.company,
    this.skills = const [],
    this.rawText,
  });

  final String? email;
  final String? jobTitle;
  final String? company;
  final List<String> skills;
  final String? rawText;

  bool get hasContext =>
      (jobTitle != null && jobTitle!.isNotEmpty) ||
      (company != null && company!.isNotEmpty) ||
      skills.isNotEmpty;

  JobPostContext copyWith({
    String? email,
    String? jobTitle,
    String? company,
    List<String>? skills,
    String? rawText,
  }) {
    return JobPostContext(
      email: email ?? this.email,
      jobTitle: jobTitle ?? this.jobTitle,
      company: company ?? this.company,
      skills: skills ?? this.skills,
      rawText: rawText ?? this.rawText,
    );
  }
}

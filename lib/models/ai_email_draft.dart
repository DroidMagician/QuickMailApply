class AiEmailDraft {
  const AiEmailDraft({
    required this.subject,
    required this.body,
    required this.generatedByAi,
  });

  final String subject;
  final String body;
  final bool generatedByAi;
}

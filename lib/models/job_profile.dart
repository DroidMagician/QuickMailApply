class JobProfile {
  const JobProfile({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.resumePath,
  });

  final String id;
  final String name;
  final String subject;
  final String body;
  final String? resumePath;

  bool get hasResume => resumePath != null && resumePath!.isNotEmpty;

  String? get resumeFileName {
    if (!hasResume) return null;
    return resumePath!.split('/').last;
  }

  JobProfile copyWith({
    String? id,
    String? name,
    String? subject,
    String? body,
    String? resumePath,
    bool clearResume = false,
  }) {
    return JobProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      resumePath: clearResume ? null : (resumePath ?? this.resumePath),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'body': body,
        'resumePath': resumePath,
      };

  factory JobProfile.fromJson(Map<String, dynamic> json) {
    return JobProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      subject: json['subject'] as String,
      body: json['body'] as String,
      resumePath: json['resumePath'] as String?,
    );
  }
}

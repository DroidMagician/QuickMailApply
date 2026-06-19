class ApplicationRecord {
  const ApplicationRecord({
    required this.id,
    required this.recruiterEmail,
    required this.profileId,
    required this.profileName,
    required this.subject,
    required this.appliedAt,
    this.jobTitle,
    this.followUpAt,
    this.followUpCompleted = false,
  });

  final String id;
  final String recruiterEmail;
  final String profileId;
  final String profileName;
  final String subject;
  final DateTime appliedAt;
  final String? jobTitle;
  final DateTime? followUpAt;
  final bool followUpCompleted;

  bool get isFollowUpDue {
    if (followUpCompleted || followUpAt == null) return false;
    return !DateTime.now().isBefore(followUpAt!);
  }

  ApplicationRecord copyWith({
    bool? followUpCompleted,
  }) {
    return ApplicationRecord(
      id: id,
      recruiterEmail: recruiterEmail,
      profileId: profileId,
      profileName: profileName,
      subject: subject,
      appliedAt: appliedAt,
      jobTitle: jobTitle,
      followUpAt: followUpAt,
      followUpCompleted: followUpCompleted ?? this.followUpCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recruiterEmail': recruiterEmail,
        'profileId': profileId,
        'profileName': profileName,
        'subject': subject,
        'appliedAt': appliedAt.toIso8601String(),
        'jobTitle': jobTitle,
        'followUpAt': followUpAt?.toIso8601String(),
        'followUpCompleted': followUpCompleted,
      };

  factory ApplicationRecord.fromJson(Map<String, dynamic> json) {
    return ApplicationRecord(
      id: json['id'] as String,
      recruiterEmail: json['recruiterEmail'] as String,
      profileId: json['profileId'] as String,
      profileName: json['profileName'] as String,
      subject: json['subject'] as String,
      appliedAt: DateTime.parse(json['appliedAt'] as String),
      jobTitle: json['jobTitle'] as String?,
      followUpAt: json['followUpAt'] != null ? DateTime.parse(json['followUpAt'] as String) : null,
      followUpCompleted: json['followUpCompleted'] as bool? ?? false,
    );
  }
}

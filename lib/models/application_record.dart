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
    this.gmailMessageId,
    this.gmailThreadId,
    this.replyStatus = 'none',
    this.lastReplySnippet,
    this.lastCheckedAt,
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
  final String? gmailMessageId;
  final String? gmailThreadId;
  final String? replyStatus;
  final String? lastReplySnippet;
  final DateTime? lastCheckedAt;

  bool get isFollowUpDue {
    if (followUpCompleted || followUpAt == null) return false;
    return !DateTime.now().isBefore(followUpAt!);
  }

  ApplicationRecord copyWith({
    bool? followUpCompleted,
    String? replyStatus,
    String? lastReplySnippet,
    DateTime? lastCheckedAt,
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
      gmailMessageId: gmailMessageId,
      gmailThreadId: gmailThreadId,
      replyStatus: replyStatus ?? this.replyStatus,
      lastReplySnippet: lastReplySnippet ?? this.lastReplySnippet,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
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
        'gmailMessageId': gmailMessageId,
        'gmailThreadId': gmailThreadId,
        'replyStatus': replyStatus,
        'lastReplySnippet': lastReplySnippet,
        'lastCheckedAt': lastCheckedAt?.toIso8601String(),
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
      gmailMessageId: json['gmailMessageId'] as String?,
      gmailThreadId: json['gmailThreadId'] as String?,
      replyStatus: json['replyStatus'] as String? ?? 'none',
      lastReplySnippet: json['lastReplySnippet'] as String?,
      lastCheckedAt: json['lastCheckedAt'] != null ? DateTime.parse(json['lastCheckedAt'] as String) : null,
    );
  }
}

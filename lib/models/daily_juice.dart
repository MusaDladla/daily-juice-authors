import '../core/juice_date.dart';
import '../template/photo_crop.dart';
import '../template/template_layout.dart';
import 'profile.dart';

enum JuiceStatus { draft, generated }

/// One Daily Juice devotional.
///
/// The author fields are a snapshot of the profile at the time of writing,
/// so a finished Daily Juice keeps its author and photo even if the profile
/// changes later. All content is stored exactly as the author entered it.
class DailyJuice {
  const DailyJuice({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.authorSurname,
    required this.branch,
    required this.profileImagePath,
    required this.profileImageCrop,
    required this.title,
    required this.date,
    required this.themeScripture,
    required this.scriptureReference,
    required this.mainMessage,
    required this.furtherStudy,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.generatedAt,
    this.exportPath,
  });

  static const int schemaVersion = 1;

  final String id;
  final String userId;
  final String authorName;
  final String authorSurname;
  final String branch;
  final String profileImagePath;
  final PhotoCrop profileImageCrop;

  final String title;
  final DateTime date;
  final String themeScripture;
  final String scriptureReference;
  final String mainMessage;
  final List<String> furtherStudy;

  final JuiceStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? generatedAt;

  /// Local path of the last exported PNG, if generated.
  final String? exportPath;

  factory DailyJuice.create({
    required String id,
    required Profile profile,
    required DateTime date,
  }) {
    final now = DateTime.now();
    return DailyJuice(
      id: id,
      userId: profile.id,
      authorName: profile.name,
      authorSurname: profile.surname,
      branch: profile.branch,
      profileImagePath: profile.photoPath,
      profileImageCrop: profile.photoCrop,
      title: '',
      date: dateOnly(date),
      themeScripture: '',
      scriptureReference: '',
      mainMessage: '',
      furtherStudy: const [],
      status: JuiceStatus.draft,
      createdAt: now,
      updatedAt: now,
    );
  }

  String get authorFullName => '${authorName.trim()} ${authorSurname.trim()}';

  bool get hasContent =>
      title.trim().isNotEmpty ||
      themeScripture.trim().isNotEmpty ||
      scriptureReference.trim().isNotEmpty ||
      mainMessage.trim().isNotEmpty ||
      furtherStudy.any((r) => r.trim().isNotEmpty);

  TemplateContent toContent() => TemplateContent(
    authorFullName: authorFullName,
    title: title,
    date: date,
    scripture: themeScripture,
    scriptureReference: scriptureReference,
    message: mainMessage,
    furtherStudy: furtherStudy,
  );

  /// Re-applies the current profile (name, branch, photo) to this Daily Juice.
  DailyJuice withAuthor(Profile p) => copyWith(
    userId: p.id,
    authorName: p.name,
    authorSurname: p.surname,
    branch: p.branch,
    profileImagePath: p.photoPath,
    profileImageCrop: p.photoCrop,
  );

  DailyJuice copyWith({
    String? userId,
    String? authorName,
    String? authorSurname,
    String? branch,
    String? profileImagePath,
    PhotoCrop? profileImageCrop,
    String? title,
    DateTime? date,
    String? themeScripture,
    String? scriptureReference,
    String? mainMessage,
    List<String>? furtherStudy,
    JuiceStatus? status,
    DateTime? updatedAt,
    DateTime? generatedAt,
    String? exportPath,
  }) => DailyJuice(
    id: id,
    userId: userId ?? this.userId,
    authorName: authorName ?? this.authorName,
    authorSurname: authorSurname ?? this.authorSurname,
    branch: branch ?? this.branch,
    profileImagePath: profileImagePath ?? this.profileImagePath,
    profileImageCrop: profileImageCrop ?? this.profileImageCrop,
    title: title ?? this.title,
    date: date ?? this.date,
    themeScripture: themeScripture ?? this.themeScripture,
    scriptureReference: scriptureReference ?? this.scriptureReference,
    mainMessage: mainMessage ?? this.mainMessage,
    furtherStudy: furtherStudy ?? this.furtherStudy,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    generatedAt: generatedAt ?? this.generatedAt,
    exportPath: exportPath ?? this.exportPath,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'userId': userId,
    'authorName': authorName,
    'authorSurname': authorSurname,
    'branch': branch,
    'profileImagePath': profileImagePath,
    'profileImageCrop': profileImageCrop.toJson(),
    'title': title,
    'date': toIsoDate(date),
    'themeScripture': themeScripture,
    'scriptureReference': scriptureReference,
    'mainMessage': mainMessage,
    'furtherStudy': furtherStudy,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'generatedAt': generatedAt?.toIso8601String(),
    'exportPath': exportPath,
  };

  factory DailyJuice.fromJson(Map<String, dynamic> json) {
    DateTime? optDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return DailyJuice(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorSurname: json['authorSurname'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      profileImagePath: json['profileImagePath'] as String? ?? '',
      profileImageCrop: PhotoCrop.fromJson(
        json['profileImageCrop'] as Map<String, dynamic>?,
      ),
      title: json['title'] as String? ?? '',
      date: parseIsoDate(json['date'] as String?) ?? dateOnly(DateTime.now()),
      themeScripture: json['themeScripture'] as String? ?? '',
      scriptureReference: json['scriptureReference'] as String? ?? '',
      mainMessage: json['mainMessage'] as String? ?? '',
      furtherStudy: (json['furtherStudy'] as List?)?.cast<String>() ?? const [],
      status:
          JuiceStatus.values.asNameMap()[json['status']] ?? JuiceStatus.draft,
      createdAt: optDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: optDate(json['updatedAt']) ?? DateTime.now(),
      generatedAt: optDate(json['generatedAt']),
      exportPath: json['exportPath'] as String?,
    );
  }
}

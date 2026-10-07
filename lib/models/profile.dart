import '../template/photo_crop.dart';

/// The author's profile. Created once, reused for every Daily Juice.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.surname,
    required this.branch,
    required this.photoPath,
    required this.photoCrop,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String surname;

  /// Youth For Christ branch. Stored with the profile and every Daily Juice;
  /// the template has no designated place for it, so it is not printed.
  final String branch;

  /// Local file path of the profile photo.
  final String photoPath;
  final PhotoCrop photoCrop;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName => '${name.trim()} ${surname.trim()}';

  Profile copyWith({
    String? name,
    String? surname,
    String? branch,
    String? photoPath,
    PhotoCrop? photoCrop,
    DateTime? updatedAt,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    surname: surname ?? this.surname,
    branch: branch ?? this.branch,
    photoPath: photoPath ?? this.photoPath,
    photoCrop: photoCrop ?? this.photoCrop,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'surname': surname,
    'branch': branch,
    'photoPath': photoPath,
    'photoCrop': photoCrop.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    surname: json['surname'] as String? ?? '',
    branch: json['branch'] as String? ?? '',
    photoPath: json['photoPath'] as String? ?? '',
    photoCrop: PhotoCrop.fromJson(json['photoCrop'] as Map<String, dynamic>?),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
